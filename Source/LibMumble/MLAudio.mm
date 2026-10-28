#import "MLInternal.hpp"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#include <mumble/Opus.hpp>
#include <speex/speex_preprocess.h>
#include <map>
#include <vector>
#include <mutex>
#include <atomic>
#include <array>
#include <cmath>
#include <unordered_map>
#include "MLCaptureBufferQueue.hpp"
#include "MLAdaptiveJitterBuffer.hpp"

NSString *MLAudioDidRestartNotification=@"MLAudioDidRestartNotification";
struct MLUserPlaybackState { BOOL muted; uint64_t revision; };
enum class MLAudioEnginePhase {Idle, Preparing, Running, Recovering, Stopping, Failed};
enum class MLAudioSessionOperation {None, Activating, Deactivating};
static BOOL MLRequiresGraphRebuild(const MLAudioSettings &previous,const MLAudioSettings &current){
    return previous.enablePreprocessor!=current.enablePreprocessor ||
        previous.preferReceiverOverSpeaker!=current.preferReceiverOverSpeaker ||
        previous.opusForceCELTMode!=current.opusForceCELTMode ||
        (previous.enableSideTone && previous.sidetoneVolume>0)!=(current.enableSideTone && current.sidetoneVolume>0);
}

@interface MLPlayback : NSObject {
@public
    std::unique_ptr<mumble::Opus::Decoder> decoder;
    uint64_t nextSequence;
    NSUInteger generation;
    double queuedSeconds;
    MLAdaptiveJitterBuffer jitter;
    BOOL jitterDrainScheduled;
}
@property(nonatomic,strong) AVAudioPlayerNode *player;
@property(nonatomic) NSTimeInterval lastPacket;
- (AVAudioPCMBuffer *)bufferWithFormat:(AVAudioFormat *)format;
- (void)recycleBuffer:(AVAudioPCMBuffer *)buffer;
@end
@implementation MLPlayback {
    NSMutableArray<AVAudioPCMBuffer *> *_freeBuffers;
}
- (instancetype)init { if ((self=[super init])) { decoder=std::make_unique<mumble::Opus::Decoder>(1); decoder->init(); _freeBuffers=[NSMutableArray array]; } return self; }
- (AVAudioPCMBuffer *)bufferWithFormat:(AVAudioFormat *)format {
    AVAudioPCMBuffer *buffer=_freeBuffers.lastObject;
    if (buffer) [_freeBuffers removeLastObject];
    else buffer=[[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:5760];
    return buffer;
}
- (void)recycleBuffer:(AVAudioPCMBuffer *)buffer {
    if (_freeBuffers.count<24) [_freeBuffers addObject:buffer];
}
@end

@implementation MLAudio {
    // Graph objects belong to _queue. Main may inspect a completed graph only
    // while its phase is Running; Preparing/Stopping keep those reads out.
    AVAudioEngine *_engine;
    AVAudioConverter *_converter;
    AVAudioPCMBuffer *_convertedInput;
    AVAudioFormat *_format;
    AVAudioPlayerNode *_sidetone;
    dispatch_queue_t _queue, _sessionQueue;
    NSMutableDictionary<NSNumber *,MLPlayback *> *_players;
    __weak MLConnection *_connection;
    __weak MLConnection *_playbackConnection;
    std::mutex _playbackRoutingMutex;
    std::unordered_map<NSUInteger, MLUserPlaybackState> _userPlaybackStates;
    uint64_t _playbackConnectionRevision, _userPlaybackRevision;
    std::atomic_size_t _queuedPlaybackPackets;
    std::unique_ptr<mumble::Opus::Encoder> _encoder;
    SpeexPreprocessState *_preprocessor;
    std::vector<int16_t> _pending;
    mumble::Buf _encodedBuffer;
    MLAudioSettings _settings, _appliedEngineSettings;
    std::atomic_uint64_t _configurationRevision;
    std::mutex _settingsMutex;
    std::atomic_bool _running, _forced, _localMuted, _localDeafened;
    std::atomic_bool _captureNeeded;
    std::atomic_size_t _meterUsers;
    std::atomic_uint64_t _tapCount, _processedCount;
    std::atomic_bool _captureWarmup;
    std::atomic_bool _meterOwnsCapture;
    std::atomic<float> _peak, _speech;
    std::atomic_uint32_t _bandwidthLimit;
    uint64_t _sequence;
    BOOL _transmitting, _tapInstalled; // Audio queue only.
    // Lifecycle state is confined to the main thread. Only one session operation may be in flight.
    BOOL _wantRunning, _sessionActive, _permissionRequested, _interrupted, _notifyRestart;
    NSUInteger _lifecycleGeneration;
    std::atomic_size_t _generation;
    dispatch_source_t _cleanupTimer;
    dispatch_source_t _captureSource;
    NSTimer *_engineRetryTimer;
    NSTimer *_captureMonitorTimer;
    uint64_t _lastTapSeen, _lastProcessedSeen;
    uint64_t _processingLogBaseline;
    NSTimeInterval _tapChangedAt, _processedChangedAt;
    NSUInteger _engineRetryCount;
    MLAudioEnginePhase _enginePhase;
    MLAudioSessionOperation _sessionOperation;
    NSMutableArray<dispatch_block_t> *_engineStopCompletions;
    NSUInteger _engineRecoveryCount;
    NSTimeInterval _engineRecoveryWindow;
}
+ (instancetype)sharedAudio { static MLAudio *audio; static dispatch_once_t once; dispatch_once(&once, ^{ audio=[self new]; }); return audio; }
- (instancetype)init {
    if ((self=[super init])) {
        _queue=dispatch_queue_create("info.mumble.libmumble.audio",dispatch_queue_attr_make_with_autorelease_frequency(DISPATCH_QUEUE_SERIAL,DISPATCH_AUTORELEASE_FREQUENCY_WORK_ITEM));
        _sessionQueue=dispatch_queue_create("info.mumble.libmumble.audio-session",DISPATCH_QUEUE_SERIAL);
        _players=[NSMutableDictionary dictionary];
        _enginePhase=MLAudioEnginePhase::Idle;_sessionOperation=MLAudioSessionOperation::None;
        _engineStopCompletions=[NSMutableArray array];
        _playbackConnectionRevision=0; _userPlaybackRevision=0; _queuedPlaybackPackets=0;
        _settings={}; _settings.quality=40000; _settings.audioPerPacket=2;
        _settings.volume=1; _settings.micBoost=1; _settings.vadMin=.65; _settings.vadMax=.75;
        _settings.noiseSuppression=-42; _settings.amplification=20; _peak=-96;
        _captureNeeded=true; _pending.reserve(8192); _encodedBuffer.resize(4096);
        NSNotificationCenter *center=NSNotificationCenter.defaultCenter;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 270000
        if (@available(iOS 27.0, *)) {
            [center addObserver:self selector:@selector(sessionBecameInactive:) name:AVAudioSessionDidBecomeInactiveNotification object:nil];
            [center addObserver:self selector:@selector(sessionMayResume:) name:AVAudioSessionResumptionRecommendationNotification object:nil];
        } else
#endif
        [center addObserver:self selector:@selector(interrupted:) name:AVAudioSessionInterruptionNotification object:nil];
        [center addObserver:self selector:@selector(routeChanged:) name:AVAudioSessionRouteChangeNotification object:nil];
        [center addObserver:self selector:@selector(mediaReset:) name:AVAudioSessionMediaServicesWereResetNotification object:nil];
        [center addObserver:self selector:@selector(engineConfigurationChanged:) name:AVAudioEngineConfigurationChangeNotification object:nil];
    }
    return self;
}
- (BOOL)isRunning {
    NSAssert(NSThread.isMainThread,@"Audio lifecycle snapshots belong to the main thread");
    return _enginePhase==MLAudioEnginePhase::Running && _running && _engine.isRunning;
}
- (BOOL)isSessionTransitioning {return _sessionOperation!=MLAudioSessionOperation::None;}
- (BOOL)isRecoveringEngine {return _enginePhase==MLAudioEnginePhase::Recovering;}
- (BOOL)isChangingEngine {return _enginePhase==MLAudioEnginePhase::Preparing || _enginePhase==MLAudioEnginePhase::Stopping;}

- (BOOL)usesAsynchronousSessionAPI {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 270000
    if (@available(iOS 27.0, *)) return YES;
#endif
    return NO;
}
- (BOOL)forceTransmit { return _forced; }
- (void)setForceTransmit:(BOOL)value {
    BOOL wasForced=_forced.exchange(value); [self updateCaptureDemand];
    if (value && !wasForced) [self requestCaptureRecovery];
}
- (MLAudioSettings)settings { std::lock_guard guard(_settingsMutex); return _settings; }
- (MLTransmitType)transmitType { return self.settings.transmitType; }
- (void)readAudioSettings:(MLAudioSettings *)settings { if (settings) *settings=self.settings; }
- (void)updateAudioSettings:(MLAudioSettings *)settings {
    if (!settings) return;
    MLAudioSettings value=*settings;
    value.quality=std::clamp(value.quality,6000,128000);
    value.audioPerPacket=value.audioPerPacket<=1?1:value.audioPerPacket<=2?2:value.audioPerPacket<=4?4:6;
    value.volume=std::clamp(value.volume,0.f,2.f); value.micBoost=std::clamp(value.micBoost,0.f,2.f);
    // Apple's voice processor owns echo cancellation, noise reduction and AGC.
    value.enableEchoCancellation=value.enablePreprocessor;
    if (value.enablePreprocessor) value.micBoost=1;
    BOOL rebuild;
    { std::lock_guard guard(_settingsMutex);rebuild=MLRequiresGraphRebuild(_settings,value);_settings=value; }
    if(rebuild){
        uint64_t revision=++_configurationRevision;
        dispatch_async(dispatch_get_main_queue(),^{
            if(revision==self->_configurationRevision && self->_wantRunning && self->_enginePhase==MLAudioEnginePhase::Running && MLRequiresGraphRebuild(self->_appliedEngineSettings,self.settings))[self restart];
        });
    }
    dispatch_async(_queue, ^{
        MLAudioSettings current=self.settings;
        if(self->_encoder || self->_engine)[self configureActivityDetectorWithSettings:current];
        if (self->_engine) self->_engine.mainMixerNode.outputVolume=current.volume;
    });
    [self updateCaptureDemand];
}
- (BOOL)echoCancellationAvailable { return YES; }
- (float)peakCleanMic { return _peak; }
- (float)speechProbablity { return _speech; }
- (void)setLocalMuted:(BOOL)muted deafened:(BOOL)deafened {
    BOOL wasMuted=_localMuted.exchange(muted), wasDeafened=_localDeafened.exchange(deafened);
    [self updateCaptureDemand];
    if (deafened && !wasDeafened) dispatch_async(_queue, ^{
        if (!self->_localDeafened) return;
        for (MLPlayback *playback in self->_players.allValues) if(playback.player) { [playback.player stop]; [self->_engine detachNode:playback.player]; }
        [self->_players removeAllObjects];
        if (self->_cleanupTimer) { dispatch_source_cancel(self->_cleanupTimer); self->_cleanupTimer=nil; }
    });
    if (wasMuted && !muted) [self requestCaptureRecovery];
}
- (void)requestCaptureRecovery {
    dispatch_async(dispatch_get_main_queue(), ^{ [self resumeIfNeeded]; });
}
- (void)resumeIfNeeded {
    NSAssert(NSThread.isMainThread,@"Audio lifecycle runs on the main thread");
    if(!_wantRunning && _meterUsers>0 && UIApplication.sharedApplication.applicationState!=UIApplicationStateBackground){_meterOwnsCapture=true;[self start];}
    if(!_wantRunning)return;
    BOOL stalled=[self captureHasStalled];
    if([self isRunning] && !stalled)return;
    if([self.delegate respondsToSelector:@selector(audioShouldBeRunning:)] && ![self.delegate audioShouldBeRunning:self])return;
    _interrupted=NO;_engineRetryCount=0;_engineRecoveryCount=0;
    if([self isChangingEngine])return; // Keep demand; the retiring graph will reconcile it.
    if(_enginePhase==MLAudioEnginePhase::Failed)_enginePhase=MLAudioEnginePhase::Idle;
    if(stalled)[self checkCaptureHealth];
    else if(_enginePhase==MLAudioEnginePhase::Running && ![self isSessionTransitioning])[self recoverStoppedEngine];
    else [self start];
}
- (void)beginMetering { ++_meterUsers; [self updateCaptureDemand]; [self requestCaptureRecovery]; }
- (void)endMetering {
    if (_meterUsers) --_meterUsers;
    [self updateCaptureDemand];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self->_meterUsers && self->_meterOwnsCapture.exchange(false)) [self stop];
    });
}
- (void)updateCaptureDemand {
    MLAudioSettings settings=self.settings;
    BOOL mayTransmit=!_localMuted && (settings.transmitType!=MLTransmitTypeToggle || _forced);
    BOOL needed=mayTransmit || _meterUsers>0;
    if (!_captureNeeded.exchange(needed) && needed) _captureWarmup=true;
    if (!mayTransmit) dispatch_async(_queue, ^{
        MLAudioSettings current=self.settings;
        if (!self->_localMuted && (current.transmitType!=MLTransmitTypeToggle || self->_forced)) return;
        MLConnection *connection=self->_connection;
        if (self->_transmitting) {
            [connection sendOpus:[NSData data] sequence:self->_sequence terminator:YES];
            dispatch_async(dispatch_get_main_queue(), ^{ [connection.model setTalkState:MLTalkStatePassive forSession:connection.model.connectedUser.session]; });
        }
        self->_transmitting=NO; self->_pending.clear(); self->_peak=-96; self->_speech=0;
    });
}
- (void)setBandwidthLimit:(uint32_t)bandwidth { _bandwidthLimit=bandwidth; }
- (void)setMainConnectionForAudio:(MLConnection *)connection {
    if (connection) _meterOwnsCapture=false;
    std::lock_guard guard(_playbackRoutingMutex);
    _playbackConnection=connection; ++_playbackConnectionRevision;
    _userPlaybackStates.clear();
    dispatch_async(_queue, ^{ self->_connection=connection; self->_pending.clear(); self->_sequence=0; self->_transmitting=NO; self->_forced=false;
        if (self->_engine) self->_engine.mainMixerNode.outputVolume=self.settings.volume;
        for (MLPlayback *playback in self->_players.allValues) if(playback.player) { [playback.player stop]; [self->_engine detachNode:playback.player]; }
        [self->_players removeAllObjects];
        [self updateCaptureDemand];
    });
}
- (void)setUserLocalMuted:(BOOL)muted session:(NSUInteger)session connection:(MLConnection *)connection {
    std::lock_guard guard(_playbackRoutingMutex);
    if (!connection || connection!=_playbackConnection) return;
    auto found=_userPlaybackStates.find(session);
    if (found!=_userPlaybackStates.end() && found->second.muted==muted) return;
    _userPlaybackStates[session]={muted,++_userPlaybackRevision};
    if (!muted) return;
    uint64_t revision=_playbackConnectionRevision;
    dispatch_async(_queue, ^{
        { std::lock_guard guard(self->_playbackRoutingMutex);
          if (revision!=self->_playbackConnectionRevision) return; }
        MLPlayback *playback=self->_players[@(session)];
        if (playback) { if(playback.player){[playback.player stop];[self->_engine detachNode:playback.player];}[self->_players removeObjectForKey:@(session)]; }
    });
}
- (void)start {
    NSAssert(NSThread.isMainThread,@"Audio lifecycle runs on the main thread");
    if(_enginePhase==MLAudioEnginePhase::Failed){_enginePhase=MLAudioEnginePhase::Idle;_engineRetryCount=0;}
    if (!_wantRunning) { _engineRetryCount=0; _engineRecoveryCount=0; _engineRecoveryWindow=0; }
    _wantRunning=YES;
    if (_enginePhase!=MLAudioEnginePhase::Idle || [self isSessionTransitioning] || _interrupted || _engineRetryTimer) return;
    if (AVAudioApplication.sharedInstance.recordPermission==AVAudioApplicationRecordPermissionUndetermined) {
        if (_permissionRequested) return;
        _permissionRequested=YES;
        [AVAudioApplication requestRecordPermissionWithCompletionHandler:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_permissionRequested=NO;
                if (granted && self->_wantRunning) [self start];
            });
        }]; return;
    }
    if (AVAudioApplication.sharedInstance.recordPermission!=AVAudioApplicationRecordPermissionGranted) return;
    MLAudioSettings settings=self.settings;
    NSUInteger generation=_lifecycleGeneration;
    _sessionOperation=MLAudioSessionOperation::Activating;
    dispatch_async(_sessionQueue, ^{
        AVAudioSession *session=AVAudioSession.sharedInstance;
        NSError *error=nil;
        // A live conversation must coexist with foreground video/music instead
        // of participating in the last-activated exclusive playback session.
        AVAudioSessionCategoryOptions options=AVAudioSessionCategoryOptionAllowBluetoothHFP | AVAudioSessionCategoryOptionMixWithOthers;
        if (!settings.preferReceiverOverSpeaker) options|=AVAudioSessionCategoryOptionDefaultToSpeaker;
        NSString *mode=settings.enablePreprocessor ? AVAudioSessionModeVoiceChat : AVAudioSessionModeDefault;
        if (![session setCategory:AVAudioSessionCategoryPlayAndRecord mode:mode options:options error:&error] ||
            ![session setPreferredSampleRate:48000 error:&error] || ![session setPreferredIOBufferDuration:.01 error:&error]) {
            [self completeActivation:NO error:error generation:generation settings:settings]; return;
        }
        NSError *alertPreferenceError=nil;
        if (![session setPrefersNoInterruptionsFromSystemAlerts:YES error:&alertPreferenceError])
            NSLog(@"Audio alert interruption preference unavailable: %@",alertPreferenceError);
        // The older SDK used by CI and iOS 18–26 use the same serialized background fallback.
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 270000
        if (@available(iOS 27.0, *)) {
          if ([self usesAsynchronousSessionAPI]) {
            [session activateWithOptions:AVAudioSessionActivationOptionNone completionHandler:^(BOOL active, NSError *activationError) {
                [self completeActivation:active error:activationError generation:generation settings:settings];
            }];
            return;
          }
        }
#endif
        BOOL active=[session setActive:YES error:&error];
        [self completeActivation:active error:error generation:generation settings:settings];
    });
}
- (void)completeActivation:(BOOL)active error:(NSError *)error generation:(NSUInteger)generation settings:(MLAudioSettings)settings {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_sessionOperation=MLAudioSessionOperation::None;
        // A failed activation does not prove a previously active session was released.
        self->_sessionActive=self->_sessionActive || active;
        if (generation!=self->_lifecycleGeneration || !self->_wantRunning || self->_interrupted) {
            if (self->_sessionActive) [self deactivateSession];
            else if (self->_wantRunning && !self->_interrupted) [self start];
            return;
        }
        if (!active) { NSLog(@"Audio session failed: %@",error); return; }
        if(MLRequiresGraphRebuild(settings,self.settings)){self->_notifyRestart=YES;[self restart];return;}
        [self prepareEngineWithSettings:settings];
    });
}
- (void)deactivateSession {
    NSAssert(NSThread.isMainThread,@"Audio lifecycle runs on the main thread");
    if ([self isSessionTransitioning] || !_sessionActive || _enginePhase!=MLAudioEnginePhase::Idle) return;
    _sessionOperation=MLAudioSessionOperation::Deactivating;
    void (^completed)(BOOL,NSError *)=^(BOOL inactive,NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_sessionOperation=MLAudioSessionOperation::None;
            self->_sessionActive=!inactive;
            if (!inactive) NSLog(@"Audio session deactivation failed: %@",error);
            if (self->_wantRunning && !self->_interrupted) [self start];
        });
    };
    dispatch_async(_sessionQueue, ^{
        AVAudioSession *session=AVAudioSession.sharedInstance;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 270000
        if (@available(iOS 27.0, *)) {
          if ([self usesAsynchronousSessionAPI]) {
            [session deactivateWithOptions:AVAudioSessionDeactivationOptionNotifyOthersOnDeactivation completionHandler:completed];
            return;
          }
        }
#endif
        NSError *error=nil;
        BOOL inactive=[session setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error];
        completed(inactive,error);
    });
}
// Lifecycle decisions stay on main; graph/DSP work never waits there.
- (void)prepareEngineWithSettings:(MLAudioSettings)settings {
    NSAssert(NSThread.isMainThread,@"Graph transitions belong to the main thread");
    if(_enginePhase!=MLAudioEnginePhase::Idle || !_wantRunning || _interrupted)return;
    _enginePhase=MLAudioEnginePhase::Preparing;
    size_t generation=++_generation;
    dispatch_async(_queue,^{
        if(generation!=self->_generation)return;
        // Use the start result; a transient isRunning snapshot is not a startup failure.
        BOOL ready=[self startEngineWithSettings:settings];
        if(!ready)return;
        dispatch_async(dispatch_get_main_queue(),^{
            if(generation!=self->_generation || self->_enginePhase!=MLAudioEnginePhase::Preparing)return;
            if(MLRequiresGraphRebuild(settings,self.settings)){[self restart];return;}
            self->_appliedEngineSettings=settings;
            self->_enginePhase=MLAudioEnginePhase::Running;self->_running=true;self->_engineRetryCount=0;
            [self startCaptureMonitor];
            if(self->_notifyRestart){self->_notifyRestart=NO;[NSNotificationCenter.defaultCenter postNotificationName:MLAudioDidRestartNotification object:self];}
        });
    });
}
- (AVAudioEngine *)makeAudioEngine { return [AVAudioEngine new]; }
- (BOOL)startEngineWithSettings:(MLAudioSettings)settings {
    NSAssert(!NSThread.isMainThread,@"Audio graph construction must not block the UI");
    NSUInteger generation=_generation;
    NSError *error=nil;
    _engine=[self makeAudioEngine];
    _engine.autoShutdownEnabled=NO;
    if (![self configureVoiceProcessingForInput:_engine.inputNode settings:settings error:&error]) { [self engineStartupFailed:error]; return NO; }
    AVAudioFormat *input=[_engine.inputNode outputFormatForBus:0];
    if (input.sampleRate<=0 || !input.channelCount) {
        [self engineStartupFailed:[NSError errorWithDomain:@"MLAudio" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Microphone input format is not ready"}]];
        return NO;
    }
    _format=[[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:48000 channels:1 interleaved:NO];
    _converter=[[AVAudioConverter alloc] initFromFormat:input toFormat:_format];
    if (!_converter) {
        [self engineStartupFailed:[NSError errorWithDomain:@"MLAudio" code:2 userInfo:@{NSLocalizedDescriptionKey:@"Audio conversion unavailable"}]];
        return NO;
    }
    if (settings.enableSideTone && settings.sidetoneVolume>0) {
        _sidetone=[AVAudioPlayerNode new]; [_engine attachNode:_sidetone];
        [_engine connect:_sidetone to:_engine.mainMixerNode format:_format];
    }
    MLAudioSettings current=self.settings;
    _engine.mainMixerNode.outputVolume=current.volume;
    [self prepareEncoderWithSettings:current];
    if(generation!=_generation)return NO;
    uint64_t tapBaseline=_tapCount;
    __weak MLAudio *weakSelf=self;
    auto buffers=std::make_shared<MLCaptureBufferQueue>(input,8192);
    if (!buffers->valid) {
        [self engineStartupFailed:[NSError errorWithDomain:@"MLAudio" code:3 userInfo:@{NSLocalizedDescriptionKey:@"Microphone buffers unavailable"}]];
        return NO;
    }
    _captureSource=dispatch_source_create(DISPATCH_SOURCE_TYPE_DATA_ADD,0,0,_queue);
    dispatch_source_t captureSource=_captureSource;
    dispatch_source_set_event_handler(captureSource, ^{
        MLAudio *audio=weakSelf;
        if (!audio || !audio->_running || generation!=audio->_generation) return;
        // Bound each drain so playback, settings and teardown can share the queue.
        for (size_t count=0;count<MLCaptureBufferQueue::slotCount;++count) {
            if (!audio->_running || generation!=audio->_generation) break;
            auto *slot=buffers->front(); if (!slot) break;
            slot->buffer.frameLength=slot->frames;
            [audio capture:slot->buffer];
            buffers->pop();
        }
        if (buffers->front()) dispatch_source_merge_data(audio->_captureSource,1);
    });
    dispatch_resume(captureSource);
    [_engine.inputNode installTapOnBus:0 bufferSize:480 format:input block:^(AVAudioPCMBuffer *buffer,AVAudioTime *time) {
        MLAudio *audio=weakSelf; if (!audio || generation!=audio->_generation) return;
        // Count callback delivery even when mute/PTT intentionally skips DSP.
        if (audio->_tapCount.fetch_add(1)==tapBaseline) {
            AVAudioFrameCount frames=buffer.frameLength;
            double rate=buffer.format.sampleRate;
            dispatch_async(audio->_queue, ^{
                if (generation==audio->_generation) NSLog(@"Microphone callbacks started: %u frames at %.0f Hz",frames,rate);
            });
        }
        if (!audio->_captureNeeded) return;
        AVAudioFrameCount frames=buffer.frameLength, offset=0;
        const AudioBufferList *inputBuffers=buffer.audioBufferList;
        while (offset<frames) {
            AVAudioFrameCount count=std::min(buffers->capacity,frames-offset);
            if (!buffers->push(*inputBuffers,count,offset)) break;
            offset+=count;
        }
        if (frames) dispatch_source_merge_data(captureSource,1);
    }];
    _tapInstalled=YES;
    if(generation!=_generation)return NO;
    [_engine prepare];
    if (![_engine startAndReturnError:&error]) { [self engineStartupFailed:error]; return NO; }
    [_sidetone play];
    AVAudioSession *session=AVAudioSession.sharedInstance;
    NSLog(@"Audio started: category=%@, mode=%@, options=%lu, voiceProcessing=%d",session.category,session.mode,(unsigned long)session.categoryOptions,settings.enablePreprocessor);

    return YES;
}
- (BOOL)configureVoiceProcessingForInput:(AVAudioInputNode *)input settings:(MLAudioSettings)settings error:(NSError **)error {
    if (!settings.enablePreprocessor) return YES;
    if (![input setVoiceProcessingEnabled:YES error:error]) return NO;
    input.voiceProcessingBypassed=NO;
    input.voiceProcessingAGCEnabled=YES;
    // VoiceIO detects local and remote speech itself. Lower competing media
    // during speech without continuously ducking it throughout the connection.
    input.voiceProcessingOtherAudioDuckingConfiguration = {YES, AVAudioVoiceProcessingOtherAudioDuckingLevelMid};
    return YES;
}
- (void)prepareEncoderWithSettings:(MLAudioSettings)settings {
    _encoder=std::make_unique<mumble::Opus::Encoder>(1);
    _encoder->init(48000,settings.opusForceCELTMode?mumble::Opus::Encoder::Preset::LowDelay:mumble::Opus::Encoder::Preset::VoIP);
    _encoder->setBitrate((uint32_t)settings.quality); _encoder->toggleVBR(true);
    if (_preprocessor) speex_preprocess_state_destroy(_preprocessor);
    _preprocessor=nullptr;
    [self configureActivityDetectorWithSettings:settings];
    // A graph rebuild on the same connection must keep voice sequence numbers.
    _pending.clear(); _transmitting=NO;
    _processingLogBaseline=_processedCount;
}
- (void)configureActivityDetectorWithSettings:(MLAudioSettings)settings {
    BOOL required=settings.enablePreprocessor && settings.vadKind==MLVADKindSignalToNoise;
    if (!required) {
        if (_preprocessor) speex_preprocess_state_destroy(_preprocessor);
        _preprocessor=nullptr; _speech=0;
        return;
    }
    if (_preprocessor) return;
    // The optional legacy SNR detector analyses a copy; it never processes
    // the PCM sent to Opus. Do not apply a second denoiser or AGC to VoiceIO.
    if (required) {
        _preprocessor=speex_preprocess_state_init(480,48000);
        if (_preprocessor) {
            int disabled=0;
            speex_preprocess_ctl(_preprocessor,SPEEX_PREPROCESS_SET_DENOISE,&disabled);
            speex_preprocess_ctl(_preprocessor,SPEEX_PREPROCESS_SET_AGC,&disabled);
        }
    }
}
- (void)startPlaybackCleanup {
    if (_cleanupTimer || !_players.count) return;
    __weak MLAudio *weakSelf=self;
    _cleanupTimer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,_queue);
    dispatch_source_set_timer(_cleanupTimer,dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),NSEC_PER_SEC,100*NSEC_PER_MSEC);
    dispatch_source_set_event_handler(_cleanupTimer, ^{
        MLAudio *audio=weakSelf; if (!audio) return;
        NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;
        for (NSNumber *session in audio->_players.allKeys) {
            MLPlayback *playback=audio->_players[session];
            if (now-playback.lastPacket>2) {
                if(playback.player){[playback.player stop];[audio->_engine detachNode:playback.player];}[audio->_players removeObjectForKey:session];
                MLConnection *connection=audio->_connection;
                dispatch_async(dispatch_get_main_queue(), ^{ [connection.model setTalkState:MLTalkStatePassive forSession:session.unsignedIntegerValue]; });
            }
        }
        if (!audio->_players.count) { dispatch_source_cancel(audio->_cleanupTimer); audio->_cleanupTimer=nil; }
    }); dispatch_resume(_cleanupTimer);
}
- (void)stop {
    NSAssert(NSThread.isMainThread,@"Audio lifecycle runs on the main thread");
    _wantRunning=NO;_notifyRestart=NO;++_lifecycleGeneration;
    [self stopEngineWithCompletion:^{[self deactivateSession];}];
}
- (void)stopEngineWithCompletion:(dispatch_block_t)completion {
    NSAssert(NSThread.isMainThread,@"Graph transitions belong to the main thread");
    if(completion)[_engineStopCompletions addObject:[completion copy]];
    _running=false;
    [_captureMonitorTimer invalidate];_captureMonitorTimer=nil;
    [_engineRetryTimer invalidate];_engineRetryTimer=nil;
    if(_enginePhase==MLAudioEnginePhase::Stopping)return;
    _enginePhase=MLAudioEnginePhase::Stopping;++_generation;
    dispatch_async(_queue,^{
        if(self->_cleanupTimer){dispatch_source_cancel(self->_cleanupTimer);self->_cleanupTimer=nil;}
        if(self->_tapInstalled){[self->_engine.inputNode removeTapOnBus:0];self->_tapInstalled=NO;}
        if(self->_captureSource){dispatch_source_cancel(self->_captureSource);self->_captureSource=nil;}
        [self->_engine stop];
        if(self->_transmitting)[self->_connection sendOpus:[NSData data] sequence:self->_sequence terminator:YES];
        MLConnection *connection=self->_connection;
        dispatch_async(dispatch_get_main_queue(),^{[connection.model setTalkState:MLTalkStatePassive forSession:connection.model.connectedUser.session];});
        for(MLPlayback *playback in self->_players.allValues)[playback.player stop];
        [self->_players removeAllObjects];self->_encoder.reset();
        if(self->_preprocessor)speex_preprocess_state_destroy(self->_preprocessor);
        self->_preprocessor=nullptr;self->_pending.clear();self->_transmitting=NO;
        self->_sidetone=nil;self->_converter=nil;self->_convertedInput=nil;self->_engine=nil;
        dispatch_async(dispatch_get_main_queue(),^{
            self->_enginePhase=MLAudioEnginePhase::Idle;
            NSArray<dispatch_block_t> *completions=[self->_engineStopCompletions copy];[self->_engineStopCompletions removeAllObjects];
            for(dispatch_block_t finish in completions)finish();
            // A start/resume can arrive while the old graph is being retired.
            if(self->_wantRunning && !self->_interrupted && !self->_engineRetryTimer && ![self isSessionTransitioning] && self->_enginePhase==MLAudioEnginePhase::Idle)[self start];
        });
    });
}
- (void)engineStartupFailed:(NSError *)error {
    if(!NSThread.isMainThread){
        size_t generation=_generation;
        dispatch_async(dispatch_get_main_queue(),^{if(generation==self->_generation && self->_enginePhase==MLAudioEnginePhase::Preparing)[self engineStartupFailed:error];});return;
    }
    NSLog(@"Audio engine startup failed: %@",error);
    NSUInteger lifecycle=_lifecycleGeneration;
    [self stopEngineWithCompletion:^{
        if(lifecycle!=self->_lifecycleGeneration || !self->_wantRunning || self->_interrupted)return;
        if(self->_engineRetryCount>=5){self->_enginePhase=MLAudioEnginePhase::Failed;return;}
        ++self->_engineRetryCount;
        NSTimeInterval delay=std::min(.5 * self->_engineRetryCount,2.0);__weak MLAudio *weakSelf=self;
        self->_engineRetryTimer=[NSTimer timerWithTimeInterval:delay repeats:NO block:^(NSTimer *timer){
            MLAudio *audio=weakSelf;if(!audio || timer!=audio->_engineRetryTimer)return;
            audio->_engineRetryTimer=nil;
            if(lifecycle==audio->_lifecycleGeneration && audio->_wantRunning && !audio->_interrupted)[audio start];
        }];
        [NSRunLoop.mainRunLoop addTimer:self->_engineRetryTimer forMode:NSRunLoopCommonModes];
    }];
}
- (void)restart {
    BOOL wanted=_wantRunning || _running; [self stop];
    if (wanted) { _notifyRestart=YES; [self start]; }
}
- (void)beginAudioInterruptionWithInactiveSession:(BOOL)inactive {
    NSAssert(NSThread.isMainThread,@"Audio lifecycle runs on the main thread");
    _interrupted=YES;
    BOOL wanted=_wantRunning;
    [self setForceTransmit:NO];
    if (inactive) _sessionActive=NO;
    [self stop]; _wantRunning=wanted; _notifyRestart=wanted;
}
- (void)endAudioInterruptionMayResume:(BOOL)mayResume allowActivationRetry:(BOOL)allowRetry {
    NSAssert(NSThread.isMainThread,@"Audio lifecycle runs on the main thread");
    // Modern recommendations can also arrive after a rejected activation.
    // Legacy late end events must not interfere with an explicit recovery.
    if (!_interrupted && !(allowRetry && mayResume && _wantRunning && !self.isRunning && ![self isSessionTransitioning])) return;
    _interrupted=NO;
    BOOL wanted=_wantRunning &&
        (![self.delegate respondsToSelector:@selector(audioShouldBeRunning:)] || [self.delegate audioShouldBeRunning:self]);
    _wantRunning=wanted;
    // A connected conversation has an ongoing input/output intent, unlike a
    // paused media player. Once the interruption ends, try activating once even
    // without the media-playback hint. The system can still refuse activation.
    if (wanted && (mayResume || _connection!=nil)) [self start];
}
- (void)interrupted:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSNumber *typeValue=notification.userInfo[AVAudioSessionInterruptionTypeKey];
        if (!typeValue) return;
        NSUInteger type=typeValue.unsignedIntegerValue;
        if (type==AVAudioSessionInterruptionTypeBegan) {
            NSLog(@"Audio interrupted (legacy), connected=%d",self->_connection!=nil);
            [self beginAudioInterruptionWithInactiveSession:NO];
        } else if (type==AVAudioSessionInterruptionTypeEnded) {
            BOOL mayResume=([notification.userInfo[AVAudioSessionInterruptionOptionKey] unsignedIntegerValue] & AVAudioSessionInterruptionOptionShouldResume)!=0;
            NSLog(@"Audio interruption ended (legacy), resume=%d",mayResume);
            [self endAudioInterruptionMayResume:mayResume allowActivationRetry:NO];
        }
    });
}
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 270000
- (void)sessionBecameInactive:(NSNotification *)notification {
    if (@available(iOS 27.0, *)) {
        AVAudioSessionDeactivationContext *context=notification.userInfo[AVAudioSessionDeactivationContextKey];
        if (!context || context.source!=AVAudioSessionDeactivationSourceSystem) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"Audio session interrupted by system, reason=%lu, connected=%d",(unsigned long)context.interruptionContext.reason,self->_connection!=nil);
            [self beginAudioInterruptionWithInactiveSession:YES];
        });
    }
}
- (void)sessionMayResume:(NSNotification *)notification {
    if (@available(iOS 27.0, *)) {
        AVAudioSessionResumptionContext *context=notification.userInfo[AVAudioSessionResumptionContextKey];
        if (!context) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL mayResume=context.recommendation==AVAudioSessionResumptionRecommendationShouldResume;
            NSLog(@"Audio session resumption recommendation=%ld, connected=%d",(long)context.recommendation,self->_connection!=nil);
            [self endAudioInterruptionMayResume:mayResume allowActivationRetry:YES];
        });
    }
}
#endif
- (void)routeChanged:(NSNotification *)notification {
    NSUInteger reason=[notification.userInfo[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];
    if (reason==AVAudioSessionRouteChangeReasonNewDeviceAvailable || reason==AVAudioSessionRouteChangeReasonOldDeviceUnavailable)
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self->_wantRunning && ![self isSessionTransitioning] && !self->_interrupted && ![self isChangingEngine]) {
                if (self->_enginePhase==MLAudioEnginePhase::Running) [self recoverStoppedEngine];
                else [self start];
            }
        });
}
- (void)recoverStoppedEngine {
    NSAssert(NSThread.isMainThread,@"Audio recovery runs on the main thread");
    if (!_wantRunning || _interrupted || [self isSessionTransitioning] || _enginePhase!=MLAudioEnginePhase::Running || !_engine || _engine.isRunning) return;
    if (![self consumeEngineRecoveryAttempt]) return;
    _enginePhase=MLAudioEnginePhase::Recovering; _running=false;
    // Resume the existing graph without toggling AVAudioSession or recreating Voice Processing.
    AVAudioEngine *engine=_engine;
    NSUInteger lifecycle=_lifecycleGeneration;
    size_t generation=_generation;
    dispatch_async(_queue, ^{
        if (generation!=self->_generation) return;
        NSError *error=nil;
        BOOL formatChanged=self->_converter && ![[engine.inputNode outputFormatForBus:0] isEqual:self->_converter.inputFormat];
        BOOL restored=NO;
        if (!formatChanged) {
            [engine prepare];
            restored=[engine startAndReturnError:&error];
            if (restored) {
                [self->_sidetone play];
                for (MLPlayback *playback in self->_players.allValues) [playback.player play];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (lifecycle!=self->_lifecycleGeneration || generation!=self->_generation || self->_engine!=engine) return;
            self->_enginePhase=MLAudioEnginePhase::Running;
            if (!self->_wantRunning || self->_interrupted) return;
            if(MLRequiresGraphRebuild(self->_appliedEngineSettings,self.settings)){[self restart];return;}
            if (restored) self->_running=true;
            else [self engineStartupFailed:error];
        });
    });
}
- (BOOL)consumeEngineRecoveryAttempt {
    NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;
    if (!_engineRecoveryWindow || now-_engineRecoveryWindow>30) { _engineRecoveryWindow=now; _engineRecoveryCount=0; }
    if (_engineRecoveryCount>=3) return NO;
    ++_engineRecoveryCount;
    return YES;
}
- (void)startCaptureMonitor {
    [_captureMonitorTimer invalidate];
    _lastTapSeen=_tapCount; _lastProcessedSeen=_processedCount;
    _tapChangedAt=_processedChangedAt=NSProcessInfo.processInfo.systemUptime;
    _captureWarmup=false;
    __weak MLAudio *weakSelf=self;
    _captureMonitorTimer=[NSTimer timerWithTimeInterval:2 repeats:YES block:^(NSTimer *timer) { [weakSelf checkCaptureHealth]; }];
    _captureMonitorTimer.tolerance=.5;
    [NSRunLoop.mainRunLoop addTimer:_captureMonitorTimer forMode:NSRunLoopCommonModes];
}
- (BOOL)captureHasStalled {
    if (_enginePhase!=MLAudioEnginePhase::Running || !_tapInstalled || !_engine) return NO;
    NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;
    uint64_t taps=_tapCount, processed=_processedCount;
    BOOL warmup=_captureWarmup.exchange(false);
    if (taps!=_lastTapSeen) { _lastTapSeen=taps; _tapChangedAt=now; }
    if (processed!=_lastProcessedSeen || warmup) {
        _lastProcessedSeen=processed; _processedChangedAt=now;
    }
    // Quiet PCM is healthy. Only missing callbacks/conversion progress count.
    return now-_tapChangedAt>4 || (_captureNeeded && now-_processedChangedAt>4);
}
- (void)checkCaptureHealth {
    NSAssert(NSThread.isMainThread,@"Capture recovery runs on the main thread");
    if(!_wantRunning || _interrupted || [self isSessionTransitioning] || _enginePhase!=MLAudioEnginePhase::Running || !_tapInstalled || !_engine)return;
    if(!_engine.isRunning){[self recoverStoppedEngine];return;}
    if(![self captureHasStalled] || ![self consumeEngineRecoveryAttempt])return;
    NSLog(@"Microphone data stalled; rebuilding the audio session");
    _notifyRestart=YES;
    [self stopEngineWithCompletion:^{
        if(self->_sessionActive)[self deactivateSession];
        else if(self->_wantRunning && !self->_interrupted)[self start];
    }];
}
- (void)engineConfigurationChanged:(NSNotification *)notification {
    // AVFAudio delivers this on its own queue; never tear down the engine there.
    // Engine teardown can itself post this notification. Do not retain its object into a block.
    uintptr_t changedEngine=(uintptr_t)(__bridge void *)notification.object;
    size_t generation=_generation;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (! [self isChangingEngine] && generation==self->_generation && changedEngine==(uintptr_t)(__bridge void *)self->_engine) [self recoverStoppedEngine];
    });
}
- (void)mediaReset:(NSNotification *)notification { dispatch_async(dispatch_get_main_queue(), ^{ [self restart]; }); }
- (void)capture:(AVAudioPCMBuffer *)input {
    if (!_captureNeeded) return;
    AVAudioPCMBuffer *converted=input;
    if (![input.format isEqual:_format]) {
        AVAudioFrameCount capacity=(AVAudioFrameCount)ceil(input.frameLength*48000/input.format.sampleRate)+8;
        if (!_convertedInput || _convertedInput.frameCapacity<capacity)
            _convertedInput=[[AVAudioPCMBuffer alloc] initWithPCMFormat:_format frameCapacity:capacity];
        converted=_convertedInput;
        converted.frameLength=0;
        __block BOOL supplied=NO;
        NSError *error=nil;
        AVAudioConverterOutputStatus result=[_converter convertToBuffer:converted error:&error withInputFromBlock:^AVAudioBuffer *(AVAudioPacketCount requested, AVAudioConverterInputStatus *status) {
            if (supplied) { *status=AVAudioConverterInputStatus_NoDataNow; return nil; }
            supplied=YES; *status=AVAudioConverterInputStatus_HaveData; return input;
        }];
        if (result==AVAudioConverterOutputStatus_Error || !converted.frameLength) return;
    }
    MLAudioSettings settings=self.settings;
    AVAudioFrameCount frameCount=converted.frameLength;
    if (!frameCount) return;
    if (_processedCount.fetch_add(1)==_processingLogBaseline)
        NSLog(@"Microphone PCM processing started: %u frames",frameCount);
    const float *inputSamples=converted.floatChannelData[0];
    size_t previousSize=_pending.size();
    _pending.resize(previousSize+frameCount);
    int16_t *outputSamples=_pending.data()+previousSize;
    for (AVAudioFrameCount i=0;i<frameCount;++i) {
        float sample=std::clamp(inputSamples[i]*settings.micBoost,-1.f,1.f);
        outputSamples[i]=(int16_t)lrintf(sample*32767);
    }
    size_t samples=(size_t)settings.audioPerPacket*480;
    size_t consumed=0;
    while (_pending.size()-consumed>=samples) {
        float peak=0, probability=0;
        for (size_t offset=0;offset<samples;offset+=480) {
            int16_t *frame=_pending.data()+consumed+offset;
            if (settings.enablePreprocessor && settings.vadKind==MLVADKindSignalToNoise && _preprocessor) {
                std::array<int16_t,480> analysis;
                std::copy_n(frame,analysis.size(),analysis.data());
                speex_preprocess_run(_preprocessor,analysis.data()); int percent=0;
                speex_preprocess_ctl(_preprocessor,SPEEX_PREPROCESS_GET_PROB,&percent); probability=std::max(probability,percent/100.f);
            }
            for (size_t i=0;i<480;++i) peak=std::max(peak,std::abs(frame[i]/32768.f));
        }
        float db=std::max(-96.f,20.f*log10f(std::max(peak,.000001f))); _peak=db; _speech=probability;
        float level=settings.vadKind==MLVADKindSignalToNoise && settings.enablePreprocessor && _preprocessor ? probability : (db+96)/96;
        BOOL transmit=settings.transmitType==MLTransmitTypeContinuous || (settings.transmitType==MLTransmitTypeToggle ? (BOOL)_forced.load() : level>=(_transmitting?settings.vadMin:settings.vadMax));
        MLConnection *connection=_connection;
        if (_localMuted) transmit=NO;
        if (transmit && connection) {
            uint32_t overhead=(uint32_t)(64*8*100/settings.audioPerPacket);
            uint32_t maximum=_bandwidthLimit;
            uint32_t bitrate=maximum ? std::min((uint32_t)settings.quality,maximum>overhead+6000?maximum-overhead:6000) : (uint32_t)settings.quality;
            if (_encoder->bitrate()!=bitrate) _encoder->setBitrate(bitrate);
            auto encoded=(*_encoder)(_encodedBuffer,mumble::Opus::IntegerViewConst(_pending.data()+consumed,samples));
            if (!encoded.empty()) [connection sendOpus:MLData(encoded) sequence:_sequence terminator:NO];
        } else if (_transmitting && connection) [connection sendOpus:[NSData data] sequence:_sequence terminator:YES];
        if (transmit!=_transmitting) {
            MLTalkState state=transmit?MLTalkStateTalking:MLTalkStatePassive;
            dispatch_async(dispatch_get_main_queue(), ^{ [connection.model setTalkState:state forSession:connection.model.connectedUser.session]; });
        }
        if (settings.enableSideTone && settings.sidetoneVolume>0 && transmit) {
            AVAudioPCMBuffer *buffer=[[AVAudioPCMBuffer alloc] initWithPCMFormat:_format frameCapacity:(AVAudioFrameCount)samples]; buffer.frameLength=(AVAudioFrameCount)samples;
            float *output=buffer.floatChannelData[0];
            for (size_t i=0;i<samples;++i) output[i]=_pending[consumed+i]/32768.f*settings.sidetoneVolume;
            [_sidetone scheduleBuffer:buffer completionHandler:nil];
        }
        _transmitting=transmit; _sequence+=samples/480; consumed+=samples;
    }
    if (consumed) _pending.erase(_pending.begin(),_pending.begin()+(long)consumed);
}
- (void)receiveOpus:(NSData *)data session:(NSUInteger)session sequence:(uint64_t)sequence terminator:(BOOL)terminator {
    MLConnection *connection;
    { std::lock_guard guard(_playbackRoutingMutex); connection=_playbackConnection; }
    [self receiveOpus:data session:session sequence:sequence terminator:terminator fromConnection:connection];
}
- (void)receiveOpus:(NSData *)data session:(NSUInteger)session sequence:(uint64_t)sequence terminator:(BOOL)terminator fromConnection:(MLConnection *)connection {
    if (!connection || !_running || _localDeafened) return;
    uint64_t connectionRevision, userRevision;
    { std::lock_guard guard(_playbackRoutingMutex);
      if (connection!=_playbackConnection) return;
      auto user=_userPlaybackStates.find(session);
      if (user!=_userPlaybackStates.end() && user->second.muted) return;
      userRevision=user==_userPlaybackStates.end()?0:user->second.revision;
      connectionRevision=_playbackConnectionRevision; }
    // Bound pending encoded data even if DSP is busy; discard old frames instead
    // of allowing transport bursts to turn into seconds of playback latency.
    if (_queuedPlaybackPackets.fetch_add(1)>=128) { --_queuedPlaybackPackets; return; }
    size_t generation=_generation;
    NSTimeInterval receivedAt=NSProcessInfo.processInfo.systemUptime;
    dispatch_async(_queue, ^{
        --self->_queuedPlaybackPackets;
        if (!self->_running || self->_localDeafened || generation!=self->_generation || NSProcessInfo.processInfo.systemUptime-receivedAt>.25) return;
        { std::lock_guard guard(self->_playbackRoutingMutex);
          auto user=self->_userPlaybackStates.find(session);
          uint64_t current=user==self->_userPlaybackStates.end()?0:user->second.revision;
          if (connectionRevision!=self->_playbackConnectionRevision || connection!=self->_playbackConnection || current!=userRevision || (user!=self->_userPlaybackStates.end() && user->second.muted)) return; }
        [self enqueueOpusFrame:data session:session sequence:sequence terminator:terminator];
    });
}
- (void)enqueueOpusFrame:(NSData *)data session:(NSUInteger)session sequence:(uint64_t)sequence terminator:(BOOL)terminator {
    unsigned frames=data.length ? mumble::Opus::packetFrames(MLBytes(data),48000) : 0;
    if(data.length && (!frames || frames>5760))return;
    MLPlayback *playback=_players[@(session)];
    if(!playback){if(!data.length)return;playback=[MLPlayback new];_players[@(session)]=playback;[self startPlaybackCleanup];}
    const uint8_t *bytes=(const uint8_t *)data.bytes;
    MLAdaptiveJitterBuffer::Packet packet;packet.sequence=sequence;packet.ticks=(frames+479)/480;packet.terminator=terminator;
    if(data.length)packet.bytes.assign(bytes,bytes+data.length);
    double now=NSProcessInfo.processInfo.systemUptime;
    if(playback->jitter.push(std::move(packet),now)){playback.lastPacket=now;[self drainJitterForSession:session playback:playback];}
}
- (void)drainJitterForSession:(NSUInteger)session playback:(MLPlayback *)playback {
    if(_players[@(session)]!=playback || !_running || _localDeafened)return;
    double now=NSProcessInfo.processInfo.systemUptime;
    while(auto packet=playback->jitter.pop(now)){
        if(packet->reset){
            [playback.player stop];playback->decoder->reset();playback->nextSequence=packet->sequence;
            playback->queuedSeconds=0;++playback->generation;[playback.player play];
        }
        NSData *data=[NSData dataWithBytes:packet->bytes.data() length:packet->bytes.size()];
        [self playOpusFrame:data session:session sequence:packet->sequence terminator:packet->terminator];
    }
    auto deadline=playback->jitter.nextDeadline();
    if(!deadline || playback->jitterDrainScheduled)return;
    playback->jitterDrainScheduled=YES;
    __weak MLAudio *weakSelf=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(std::max(.001,*deadline-now)*NSEC_PER_SEC)),_queue,^{
        playback->jitterDrainScheduled=NO;[weakSelf drainJitterForSession:session playback:playback];
    });
}
- (void)playOpusFrame:(NSData *)data session:(NSUInteger)session sequence:(uint64_t)sequence terminator:(BOOL)terminator {
        MLPlayback *playback=self->_players[@(session)];
        if (!playback && data.length) {playback=[MLPlayback new];self->_players[@(session)]=playback;}
        if (playback && !playback.player && data.length) {
            playback.player=[AVAudioPlayerNode new]; playback.lastPacket=NSProcessInfo.processInfo.systemUptime;
            [self->_engine attachNode:playback.player]; [self->_engine connect:playback.player to:self->_engine.mainMixerNode format:self->_format];
            [playback.player play]; self->_players[@(session)]=playback;
            [self startPlaybackCleanup];
        }
        if (!playback) return;
        playback.lastPacket=NSProcessInfo.processInfo.systemUptime;
        if (sequence<playback->nextSequence) return;
        if (!data.length) return;
        uint64_t gap=sequence-playback->nextSequence;
        if (playback->queuedSeconds>.18 || gap>10) { [playback.player stop]; playback->decoder->reset(); playback->queuedSeconds=0; ++playback->generation; [playback.player play]; }
        else if (gap && gap<=10) {
            for (uint64_t i=0;i<gap;++i) {
                AVAudioPCMBuffer *concealed=[playback bufferWithFormat:self->_format];
                if (!concealed) break;
                auto decoded=(*playback->decoder)(mumble::Opus::FloatView(concealed.floatChannelData[0],480),{});
                concealed.frameLength=(AVAudioFrameCount)decoded.size();
                if (concealed.frameLength) {double duration=concealed.frameLength/48000.0;playback->queuedSeconds+=duration;[self scheduleBuffer:concealed forPlayback:playback duration:duration];}
                else [playback recycleBuffer:concealed];
            }
        }
        AVAudioPCMBuffer *buffer=[playback bufferWithFormat:self->_format];
        if (!buffer) return;
        auto decoded=(*playback->decoder)(mumble::Opus::FloatView(buffer.floatChannelData[0],5760),MLBytes(data));
        buffer.frameLength=(AVAudioFrameCount)decoded.size(); if (!buffer.frameLength) { [playback recycleBuffer:buffer]; return; }
        playback->nextSequence=sequence+buffer.frameLength/480;
        double duration=buffer.frameLength/48000.0; playback->queuedSeconds+=duration;
        [self scheduleBuffer:buffer forPlayback:playback duration:duration];
}
- (void)scheduleBuffer:(AVAudioPCMBuffer *)buffer forPlayback:(MLPlayback *)playback duration:(double)duration {
    NSUInteger generation=playback->generation;
    [playback.player scheduleBuffer:buffer completionCallbackType:AVAudioPlayerNodeCompletionDataPlayedBack completionHandler:^(AVAudioPlayerNodeCompletionCallbackType type) {
        dispatch_async(self->_queue, ^{
            if (generation==playback->generation) playback->queuedSeconds=std::max(0.0,playback->queuedSeconds-duration);
            [playback recycleBuffer:buffer];
        });
    }];
}
- (NSDictionary *)copyAudioOutputMixerDebugInfo {
    __block NSMutableArray *sources=[NSMutableArray array];
    dispatch_sync(_queue, ^{ for (NSNumber *session in self->_players) [sources addObject:@{@"kind":@"Opus",@"identifier":session.stringValue}]; });
    return @{@"last-update":NSDate.date,@"sources":sources,@"removed":@[]};
}
@end
