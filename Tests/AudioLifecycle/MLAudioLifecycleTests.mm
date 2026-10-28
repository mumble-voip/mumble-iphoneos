// Loaded only into the isolated Simulator validation app by test-audio-lifecycle.sh.
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "MLClient.h"
#include <atomic>
#include <algorithm>
// Exercise the legacy interruption compatibility path even on the iOS 27 test host.
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface MLAudio (LifecycleTests)
- (void)capture:(AVAudioPCMBuffer *)buffer;
- (void)setLocalMuted:(BOOL)muted deafened:(BOOL)deafened;
- (BOOL)startEngineWithSettings:(MLAudioSettings)settings;
- (void)prepareEngineWithSettings:(MLAudioSettings)settings;
- (BOOL)isSessionTransitioning;
- (BOOL)isRecoveringEngine;
- (BOOL)isChangingEngine;
- (AVAudioEngine *)makeAudioEngine;
- (void)interrupted:(NSNotification *)notification;
- (void)recoverStoppedEngine;
- (void)engineStartupFailed:(NSError *)error;
- (void)routeChanged:(NSNotification *)notification;
- (void)receiveOpus:(NSData *)data session:(NSUInteger)session sequence:(uint64_t)sequence terminator:(BOOL)terminator;
- (BOOL)configureVoiceProcessingForInput:(AVAudioInputNode *)input settings:(MLAudioSettings)settings error:(NSError **)error;
- (void)prepareEncoderWithSettings:(MLAudioSettings)settings;
- (void)startCaptureMonitor;
- (void)checkCaptureHealth;
- (void)sessionBecameInactive:(NSNotification *)notification;
- (void)sessionMayResume:(NSNotification *)notification;
@end

@interface MLServerModel (SpeakingTests)
- (void)reset;
- (void)setTalkState:(MLTalkState)state forSession:(NSUInteger)session;
- (void)receivedVoiceForSession:(NSUInteger)session talkState:(MLTalkState)state hasAudio:(BOOL)hasAudio terminator:(BOOL)terminator;
@end

@interface NSObject (PlaybackBufferTests)
- (AVAudioPCMBuffer *)bufferWithFormat:(AVAudioFormat *)format;
- (void)recycleBuffer:(AVAudioPCMBuffer *)buffer;
- (instancetype)initWithServerModel:(MLServerModel *)model;
- (MLTalkState)talkStateForUser:(MLUser *)user;
@end

static NSMutableArray<NSString *> *results;
static NSString *lifecycleStep;
static __weak MLAudio *diagnosticAudio;
void MLVoiceIngressTests(void (^record)(NSString *));
static std::atomic<NSUInteger> engineStarts,startupFailuresRemaining,engineResumes;
static BOOL legacy;
static BOOL TestAsynchronousSessionAPI(id object, SEL command) { return !legacy; }
static AVAudioApplicationRecordPermission permissionValue=AVAudioApplicationRecordPermissionGranted;
static void (^permissionCompletion)(BOOL);
static NSUInteger permissionRequests;
static void Check(BOOL condition, NSString *message) {
    if (!condition) @throw [NSException exceptionWithName:@"AudioLifecycleTestFailure" reason:message userInfo:nil];
}
static void Wait(BOOL (^condition)(void)) {
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:3];
    while (!condition() && deadline.timeIntervalSinceNow>0)
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]];
    if(!condition()){
        NSString *detail=lifecycleStep ? [NSString stringWithFormat:@"%@; graph=%@ session=%@ retries=%@ builds=%lu remaining=%lu",lifecycleStep,[diagnosticAudio valueForKey:@"_enginePhase"],[diagnosticAudio valueForKey:@"_sessionOperation"],[diagnosticAudio valueForKey:@"_engineRetryCount"],(unsigned long)engineStarts.load(),(unsigned long)startupFailuresRemaining.load()] : @"session transition";
        Check(NO,[@"Timed out waiting for " stringByAppendingString:detail]);
    }
}
static BOOL Flag(MLAudio *audio,NSString *key){
    if([key isEqual:@"_sessionTransition"])return [audio isSessionTransitioning];
    if([key isEqual:@"_engineRecoveryInFlight"])return [audio isRecoveringEngine];
    return [[audio valueForKey:key]boolValue];
}

@interface MLTestSession : NSObject
@property(atomic,copy) void (^activation)(BOOL,NSError *);
@property(atomic,copy) void (^deactivation)(BOOL,NSError *);
@property(atomic) NSUInteger activationCount, deactivationCount;
@property(atomic) BOOL failConfiguration;
@property(atomic,copy) NSString *category, *mode;
@property(atomic) AVAudioSessionCategoryOptions options;
@property(atomic) BOOL avoidsAlertInterruptions;
@end
@implementation MLTestSession
- (AVAudioSessionCategoryOptions)categoryOptions { return _options; }
- (BOOL)setCategory:(NSString *)category mode:(NSString *)mode options:(AVAudioSessionCategoryOptions)options error:(NSError **)error {
    Check(!NSThread.isMainThread,@"Session configuration blocked the main thread");
    self.category=category; self.mode=mode; self.options=options;
    return !self.failConfiguration;
}
- (BOOL)setPrefersNoInterruptionsFromSystemAlerts:(BOOL)value error:(NSError **)error {
    Check(!NSThread.isMainThread,@"Alert interruption preference configured on main thread");
    self.avoidsAlertInterruptions=value;return YES;
}
- (BOOL)setPreferredSampleRate:(double)rate error:(NSError **)error { Check(!NSThread.isMainThread,@"Sample rate configured on main thread"); return YES; }
- (BOOL)setPreferredIOBufferDuration:(NSTimeInterval)duration error:(NSError **)error { Check(!NSThread.isMainThread,@"Buffer configured on main thread"); return YES; }
- (void)activateWithOptions:(AVAudioSessionActivationOptions)options completionHandler:(void (^)(BOOL,NSError *))handler {
    Check(!legacy,@"The compatibility build must use its background fallback");
    self.activationCount++; self.activation=handler;
}
- (void)deactivateWithOptions:(AVAudioSessionDeactivationOptions)options completionHandler:(void (^)(BOOL,NSError *))handler {
    Check(!legacy,@"The compatibility build must use its background fallback");
    Check(options==AVAudioSessionDeactivationOptionNotifyOthersOnDeactivation,@"Other audio must be allowed to resume");
    self.deactivationCount++; self.deactivation=handler;
}
- (BOOL)setActive:(BOOL)active error:(NSError **)error {
    Check(!NSThread.isMainThread,@"Synchronous activation called on main thread");
    Check(legacy,@"iOS 27 must use asynchronous activation");
    dispatch_semaphore_t signal=dispatch_semaphore_create(0);
    __block BOOL success=NO;
    self.activationCount++;
    self.activation=^(BOOL active,NSError *failure) { success=active; dispatch_semaphore_signal(signal); };
    Check(dispatch_semaphore_wait(signal,dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC))==0,@"Blocked compatibility activation timed out");
    if (!success && error) *error=[NSError errorWithDomain:@"Test" code:1 userInfo:nil];
    return success;
}
- (BOOL)setActive:(BOOL)active withOptions:(AVAudioSessionSetActiveOptions)options error:(NSError **)error {
    Check(!NSThread.isMainThread,@"Synchronous deactivation called on main thread");
    Check(legacy,@"iOS 27 must use asynchronous deactivation");
    Check(options==AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation,@"Other audio must be allowed to resume");
    dispatch_semaphore_t signal=dispatch_semaphore_create(0);
    __block BOOL success=NO;
    self.deactivationCount++;
    self.deactivation=^(BOOL inactive,NSError *failure) { success=inactive; dispatch_semaphore_signal(signal); };
    Check(dispatch_semaphore_wait(signal,dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC))==0,@"Blocked compatibility deactivation timed out");
    if (!success && error) *error=[NSError errorWithDomain:@"Test" code:1 userInfo:nil];
    return success;
}
@end
@interface MLTestMixer : NSObject
@property(nonatomic) float outputVolume;
@end
@implementation MLTestMixer
@end
@interface MLTestInputNode : NSObject
@property(nonatomic) NSUInteger removedTaps;
@end
@implementation MLTestInputNode
- (void)removeTapOnBus:(AVAudioNodeBus)bus { self.removedTaps++; }
@end
@interface MLTestEngine : NSObject
@property(nonatomic) BOOL running;
@property(nonatomic,strong) MLTestMixer *mainMixerNode;
@property(nonatomic) NSUInteger detachedNodes;
@property(nonatomic,strong) MLTestInputNode *inputNode;
@end
@implementation MLTestEngine
- (instancetype)init { if ((self=[super init])) { _mainMixerNode=[MLTestMixer new]; _inputNode=[MLTestInputNode new]; } return self; }
- (BOOL)isRunning { return self.running; }
- (void)prepare { Check(!NSThread.isMainThread,@"Engine recovery blocked the main thread"); }
- (BOOL)startAndReturnError:(NSError **)error { Check(!NSThread.isMainThread,@"Engine resumed on the main thread"); engineResumes++; self.running=YES; return YES; }
- (void)stop { self.running=NO; }
- (void)detachNode:(id)node { self.detachedNodes++; }
@end
static MLTestSession *session;
static id TestSharedSession(id self,SEL cmd) { return session; }
static AVAudioApplicationRecordPermission TestPermission(id self,SEL cmd) { return permissionValue; }
static void TestPermissionRequest(id self,SEL cmd,void (^completion)(BOOL)) { permissionRequests++; permissionCompletion=[completion copy]; }
static BOOL TestEngineStart(id self,SEL cmd,MLAudioSettings settings) {
    Check(!NSThread.isMainThread,@"Engine construction blocked the main thread");
    engineStarts++;
    if (startupFailuresRemaining) {
        startupFailuresRemaining--;
        [(MLAudio *)self engineStartupFailed:[NSError errorWithDomain:@"Test" code:3 userInfo:nil]];
        return NO;
    }
    MLTestEngine *engine=[MLTestEngine new]; engine.running=YES;
    [self setValue:engine forKey:@"_engine"];
    return YES;
}
static void FinishActivation(BOOL success) {
    Wait(^BOOL { return session.activation!=nil; });
    void (^completion)(BOOL,NSError *)=session.activation; session.activation=nil;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT,0), ^{ completion(success,success?nil:[NSError errorWithDomain:@"Test" code:1 userInfo:nil]); });
}
static void FinishDeactivation(void) {
    Wait(^BOOL { return session.deactivation!=nil; });
    void (^completion)(BOOL,NSError *)=session.deactivation; session.deactivation=nil;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT,0), ^{ completion(YES,nil); });
}
static void Record(NSString *name) { [results addObject:[@"PASS " stringByAppendingString:name]]; }
static void Cleanup(MLAudio *audio) {
    [audio stop];
    if (Flag(audio,@"_sessionActive")) FinishDeactivation();
    Wait(^BOOL { return !Flag(audio,@"_sessionTransition") && ![audio isChangingEngine]; });
}
static void Interrupt(MLAudio *audio,AVAudioSessionInterruptionType type,AVAudioSessionInterruptionOptions options) {
    [audio interrupted:[NSNotification notificationWithName:AVAudioSessionInterruptionNotification object:nil
        userInfo:@{AVAudioSessionInterruptionTypeKey:@(type),AVAudioSessionInterruptionOptionKey:@(options)}]];
}
static BOOL CaptureNeeded(MLAudio *audio) {
    Ivar field=class_getInstanceVariable(NSClassFromString(@"MLAudio"),"_captureNeeded");
    auto value=reinterpret_cast<std::atomic_bool *>(reinterpret_cast<uint8_t *>((__bridge void *)audio)+ivar_getOffset(field));
    return value->load();
}
@interface MLTestVoiceInput : NSObject
@property(nonatomic) BOOL enabled, failEnable, voiceProcessingBypassed, voiceProcessingAGCEnabled;
@property(nonatomic) AVAudioVoiceProcessingOtherAudioDuckingConfiguration voiceProcessingOtherAudioDuckingConfiguration;
@end
@implementation MLTestVoiceInput
- (BOOL)setVoiceProcessingEnabled:(BOOL)enabled error:(NSError **)error {
    if (self.failEnable) { if (error) *error=[NSError errorWithDomain:@"Test" code:9 userInfo:nil]; return NO; }
    self.enabled=enabled; return YES;
}
@end
@interface MLTestCaptureConnection : NSObject
@property(nonatomic,strong) NSMutableArray<NSData *> *frames;
@end
@implementation MLTestCaptureConnection
- (instancetype)init { if ((self=[super init])) _frames=[NSMutableArray array]; return self; }
- (MLServerModel *)model { return nil; }
- (void)sendOpus:(NSData *)data sequence:(uint64_t)sequence terminator:(BOOL)terminator { if (!terminator) [self.frames addObject:[data copy]]; }
@end
static void VoiceQualityTests(void) {
    MLAudio *audio=[NSClassFromString(@"MLAudio") new];
    MLAudioSettings settings; [audio readAudioSettings:&settings];
    settings.enablePreprocessor=YES; settings.enableEchoCancellation=NO; settings.micBoost=2;
    [audio updateAudioSettings:&settings]; [audio readAudioSettings:&settings];
    Check(settings.enableEchoCancellation && settings.micBoost==1,@"Native AGC still has extra software boost or a separate echo toggle");
    MLTestVoiceInput *input=[MLTestVoiceInput new]; input.voiceProcessingBypassed=YES;
    NSError *error=nil;
    Check([audio configureVoiceProcessingForInput:(AVAudioInputNode *)input settings:settings error:&error] && input.enabled && !input.voiceProcessingBypassed && input.voiceProcessingAGCEnabled,@"Native voice processing and AGC are not enabled together");
    Check(input.voiceProcessingOtherAudioDuckingConfiguration.enableAdvancedDucking && input.voiceProcessingOtherAudioDuckingConfiguration.duckingLevel==AVAudioVoiceProcessingOtherAudioDuckingLevelMid,@"Voice chat does not reduce competing media when participants speak");
    input=[MLTestVoiceInput new]; input.failEnable=YES;
    Check(![audio configureVoiceProcessingForInput:(AVAudioInputNode *)input settings:settings error:&error] && error && !input.voiceProcessingAGCEnabled,@"Native voice processor failure silently fell back to unprocessed capture");
    Record(@"native VoiceIO owns echo/noise/AGC; software boost bypassed; processor failure reported");

    AVAudioFormat *format=[[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:48000 channels:1 interleaved:NO];
    AVAudioPCMBuffer *buffer=[[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:4800]; buffer.frameLength=4800;
    for (UInt32 i=0;i<buffer.frameLength;++i) buffer.floatChannelData[0][i]=.25f*sin(2*M_PI*1000*i/48000)+.01f*sin(2*M_PI*60*i/48000);
    NSMutableArray *encoded=[NSMutableArray array];
    for (NSUInteger mode=0;mode<2;++mode) {
        MLAudio *capture=[NSClassFromString(@"MLAudio") new];
        MLTestCaptureConnection *connection=[MLTestCaptureConnection new];
        settings.transmitType=MLTransmitTypeContinuous; settings.audioPerPacket=2; settings.quality=40000; settings.opusForceCELTMode=NO;
        settings.vadKind=mode ? MLVADKindSignalToNoise : MLVADKindAmplitude;
        [capture updateAudioSettings:&settings]; [capture readAudioSettings:&settings];
        [capture setMainConnectionForAudio:(MLConnection *)connection]; [capture copyAudioOutputMixerDebugInfo];
        [capture setValue:format forKey:@"_format"]; [capture prepareEncoderWithSettings:settings];
        [capture capture:buffer];
        Check(connection.frames.count==5,@"Voice mode failed to encode all 20ms frames");
        [encoded addObject:[connection.frames copy]];
        Check(isfinite(capture.speechProbablity) && capture.speechProbablity>=0 && capture.speechProbablity<=1,@"SNR detector returned an invalid level");
        [capture stop];
    }
    Check([encoded[0] isEqual:encoded[1]],@"SNR detection modified the PCM/Opus output after native voice processing");
    Record(@"SNR analysis leaves native microphone Opus packets byte-for-byte unchanged");
    MLAudio *detector=[NSClassFromString(@"MLAudio") new];
    settings.vadKind=MLVADKindAmplitude; settings.transmitType=MLTransmitTypeVAD;
    [detector updateAudioSettings:&settings]; [detector copyAudioOutputMixerDebugInfo];
    [detector setValue:format forKey:@"_format"]; [detector prepareEncoderWithSettings:settings];
    [detector capture:buffer];
    uint64_t sequence=[[detector valueForKey:@"_sequence"] unsignedLongLongValue];
    settings.vadKind=MLVADKindSignalToNoise;
    [detector updateAudioSettings:&settings]; [detector copyAudioOutputMixerDebugInfo];
    uint32_t random=42;
    for (NSUInteger frame=0;frame<40;++frame) {
        for (UInt32 i=0;i<buffer.frameLength;++i) { random=random*1664525+1013904223; buffer.floatChannelData[0][i]=((int32_t)random/(float)INT32_MAX)*.0001f; }
        [detector capture:buffer];
    }
    float quiet=detector.speechProbablity;
    float speech=0;
    for (NSUInteger frame=0;frame<10;++frame) {
        for (UInt32 i=0;i<buffer.frameLength;++i) buffer.floatChannelData[0][i]=.2f*sin(2*M_PI*180*i/48000)+.08f*sin(2*M_PI*540*i/48000);
        [detector capture:buffer]; speech=std::max(speech,detector.speechProbablity);
    }
    Check(speech>quiet+.3f && speech>.5f,@"Live SNR switch has no response to voice above a quiet noise floor");
    Check([[detector valueForKey:@"_sequence"] unsignedLongLongValue]>sequence,@"Detection switch reset packet sequencing");
    settings.vadKind=MLVADKindAmplitude; settings.vadMin=.2; settings.vadMax=.4;
    [detector updateAudioSettings:&settings]; [detector copyAudioOutputMixerDebugInfo];
    Check(detector.speechProbablity==0,@"Switching back to amplitude retained the SNR detector reading");
    [detector readAudioSettings:&settings];
    Check(settings.vadMin==.2f && settings.vadMax==.4f,@"Threshold updates did not reach the active detector");
    [detector stop];
    Record(@"live amplitude/SNR switching responds to noise/voice without resetting packet sequencing; thresholds apply immediately");
    settings.enablePreprocessor=NO; settings.micBoost=.5;
    [audio updateAudioSettings:&settings]; [audio readAudioSettings:&settings];
    input=[MLTestVoiceInput new];
    Check(!settings.enableEchoCancellation && settings.micBoost==.5 && [audio configureVoiceProcessingForInput:(AVAudioInputNode *)input settings:settings error:nil] && !input.enabled,@"Raw input does not preserve manual microphone controls");
    [audio stop];
    Record(@"raw input retains manual gain with native processing disabled");
}
static void DeafenTests(void) {
    MLAudio *audio=[NSClassFromString(@"MLAudio") new];
    MLTestEngine *engine=[MLTestEngine new]; engine.running=YES;
    [audio setValue:engine forKey:@"_engine"];
    MLAudioSettings settings; [audio readAudioSettings:&settings]; settings.transmitType=MLTransmitTypeVAD;
    [audio updateAudioSettings:&settings]; [audio copyAudioOutputMixerDebugInfo];
    MLTestEngine *player=[MLTestEngine new]; player.running=YES;
    id playback=[NSClassFromString(@"MLPlayback") new]; [playback setValue:player forKey:@"player"];
    NSMutableDictionary *players=[audio valueForKey:@"_players"]; players[@12]=playback;
    [audio setLocalMuted:YES deafened:YES]; [audio copyAudioOutputMixerDebugInfo];
    Check(engine.running && !CaptureNeeded(audio),@"Deafen stopped the engine or left microphone transmission processing active");
    Check(!player.running && !players.count && engine.detachedNodes==1,@"Deafen retained queued voice that could replay on undeafen");
    [audio receiveOpus:[NSData dataWithBytes:"x" length:1] session:12 sequence:0 terminator:NO];
    [audio copyAudioOutputMixerDebugInfo]; Check(!players.count,@"Deafened audio recreated a playback source");
    [audio setLocalMuted:NO deafened:NO]; [audio copyAudioOutputMixerDebugInfo];
    Check(engine.running && CaptureNeeded(audio),@"Undeafen did not restore capture processing");
    [audio stop]; Record(@"deafen stops queued playback and skips voice; undeafen preserves the live engine");
}
static void CaptureTests(void) {
    MLAudio *audio=[NSClassFromString(@"MLAudio") new];
    MLAudioSettings settings; [audio readAudioSettings:&settings];
    settings.transmitType=MLTransmitTypeVAD; settings.enablePreprocessor=NO; settings.audioPerPacket=2;
    settings.vadMin=settings.vadMax=1; settings.micBoost=1;
    [audio updateAudioSettings:&settings]; [audio copyAudioOutputMixerDebugInfo];
    AVAudioFormat *format=[[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:48000 channels:1 interleaved:NO];
    [audio setValue:format forKey:@"_format"];
    AVAudioPCMBuffer *buffer=[[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:4800];
    buffer.frameLength=480; for (UInt32 i=0;i<4800;++i) buffer.floatChannelData[0][i]=.25;
    [audio capture:buffer]; [audio capture:buffer];
    Check([[audio valueForKey:@"_sequence"] unsignedLongLongValue]==2,@"Half packets did not retain the pending samples");
    Check(fabs(audio.peakCleanMic+12.0412)<.1,@"Native-format fast path changed microphone levels");
    Check([audio valueForKey:@"_convertedInput"]==nil,@"Native 48kHz mono input performed redundant conversion");
    buffer.frameLength=4800; [audio capture:buffer];
    Check([[audio valueForKey:@"_sequence"] unsignedLongLongValue]==12,@"Batch capture lost or duplicated samples");
    Record(@"48kHz mono bypass, microphone levels and batched packet sequence");
    settings.transmitType=MLTransmitTypeToggle; [audio updateAudioSettings:&settings]; [audio copyAudioOutputMixerDebugInfo];
    Check(!CaptureNeeded(audio),@"Closed push-to-talk still processes microphone buffers");
    [audio capture:buffer]; Check([[audio valueForKey:@"_sequence"] unsignedLongLongValue]==12,@"Closed push-to-talk processed data");
    [audio beginMetering]; Check(CaptureNeeded(audio),@"Visible voice calibration cannot meter closed push-to-talk");
    [audio capture:buffer]; [audio endMetering]; Check(!CaptureNeeded(audio),@"Hidden calibration still requests processing");
    audio.forceTransmit=YES; Check(CaptureNeeded(audio),@"Push-to-talk does not resume processing");
    [audio setLocalMuted:YES deafened:NO]; [audio copyAudioOutputMixerDebugInfo]; Check(!CaptureNeeded(audio),@"Local mute keeps preprocessing active");
    [audio setLocalMuted:NO deafened:NO]; Check(CaptureNeeded(audio),@"Unmuting did not restore held push-to-talk");
    audio.forceTransmit=NO; [audio copyAudioOutputMixerDebugInfo];
    settings.transmitType=MLTransmitTypeVAD; [audio updateAudioSettings:&settings]; [audio copyAudioOutputMixerDebugInfo];
    Check(CaptureNeeded(audio),@"Idle VAD lost microphone processing");
    Record(@"PTT and mute skip DSP; visible metering and idle VAD preserve capture");
    AVAudioFormat *stereo=[[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:44100 channels:2 interleaved:NO];
    AVAudioConverter *converter=[[AVAudioConverter alloc] initFromFormat:stereo toFormat:format]; [audio setValue:converter forKey:@"_converter"];
    AVAudioPCMBuffer *other=[[AVAudioPCMBuffer alloc] initWithPCMFormat:stereo frameCapacity:4410]; other.frameLength=4410;
    for (UInt32 c=0;c<2;++c) for (UInt32 i=0;i<4410;++i) other.floatChannelData[c][i]=.1;
    [audio capture:other]; id converted=[audio valueForKey:@"_convertedInput"]; [audio capture:other];
    Check(converted && converted==[audio valueForKey:@"_convertedInput"],@"Resampling did not reuse its scratch buffer");
    Check(isfinite(audio.peakCleanMic),@"Resampled microphone levels invalid");
    [audio stop];Wait(^BOOL{return ![audio isChangingEngine];});
    Check([audio valueForKey:@"_convertedInput"]==nil,@"Stopped audio retained conversion buffers");
    Record(@"44.1kHz stereo conversion reuses buffers and stop releases them");
}

static void AdvanceCaptureCounter(MLAudio *audio,const char *key) {
    Ivar field=class_getInstanceVariable(NSClassFromString(@"MLAudio"),key);
    auto value=reinterpret_cast<std::atomic_uint64_t *>(reinterpret_cast<uint8_t *>((__bridge void *)audio)+ivar_getOffset(field));
    ++*value;
}
static void SetupCaptureMonitor(MLAudio *audio) {
    [audio setValue:@YES forKey:@"_tapInstalled"]; [audio startCaptureMonitor];
    NSTimer *timer=[audio valueForKey:@"_captureMonitorTimer"];
    Check(timer.valid && timer.timeInterval==2 && timer.tolerance>=.5,@"Capture monitor has no tolerance or polls too frequently");
    // Drive health checks deterministically; the production timer uses this same path.
    [timer invalidate];
}
static void MakeCaptureStale(MLAudio *audio,BOOL tap,BOOL processing) {
    NSNumber *past=@(NSProcessInfo.processInfo.systemUptime-6);
    if(tap)[audio setValue:past forKey:@"_tapChangedAt"];
    if(processing)[audio setValue:past forKey:@"_processedChangedAt"];
}
static void CaptureHealthTests(Class audioClass) {
    session=[MLTestSession new];MLAudio *audio=[audioClass new];NSUInteger baseline=engineStarts;
    [audio start];FinishActivation(YES);Wait(^BOOL{return (engineStarts==baseline+1) && ![audio isChangingEngine];});SetupCaptureMonitor(audio);
    // Real silence still delivers valid PCM and must not cycle the session.
    AVAudioFormat *format=[[AVAudioFormat alloc]initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:48000 channels:1 interleaved:NO];
    AVAudioPCMBuffer *silence=[[AVAudioPCMBuffer alloc]initWithPCMFormat:format frameCapacity:960];silence.frameLength=960;
    memset(silence.floatChannelData[0],0,960*sizeof(float));[audio setValue:format forKey:@"_format"];
    MLAudioSettings initial;[audio readAudioSettings:&initial];[audio prepareEncoderWithSettings:initial];
    MakeCaptureStale(audio,YES,YES);AdvanceCaptureCounter(audio,"_tapCount");[audio capture:silence];
    Check(audio.peakCleanMic==-96,@"Silent PCM is not the quiet capture case");
    [audio checkCaptureHealth];Check(!Flag(audio,@"_engineRecoveryInFlight") && !session.deactivation,@"Quiet microphone data was treated as a stall");
    [audio setLocalMuted:YES deafened:NO];[audio copyAudioOutputMixerDebugInfo];
    MakeCaptureStale(audio,NO,YES);AdvanceCaptureCounter(audio,"_tapCount");[audio checkCaptureHealth];
    Check(!session.deactivation,@"Intentional mute rebuilt a healthy input graph");
    [audio setLocalMuted:NO deafened:NO];[audio copyAudioOutputMixerDebugInfo];[audio checkCaptureHealth];
    Check(!session.deactivation,@"Unmute has no processing startup grace");
    [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.05]];
    Record(@"quiet PCM, mute and unmute do not cause false capture recovery");
    [audio setValue:@900 forKey:@"_sequence"];
    MLAudioSettings settings;[audio readAudioSettings:&settings];[audio prepareEncoderWithSettings:settings];
    Check([[audio valueForKey:@"_sequence"] unsignedLongLongValue]==900,@"Graph rebuild reset a live voice sequence");
    MakeCaptureStale(audio,YES,YES);[audio checkCaptureHealth];[audio checkCaptureHealth];
    FinishDeactivation();FinishActivation(YES);Wait(^BOOL{return (engineStarts==baseline+2) && ![audio isChangingEngine];});
    Check([[audio valueForKey:@"_sequence"] unsignedLongLongValue]==900 && Flag(audio,@"_wantRunning"),@"Stall recovery lost voice sequencing or capture intent");
    Record(@"running engine with no microphone callbacks rebuilds its session once and preserves sequencing");
    SetupCaptureMonitor(audio);MakeCaptureStale(audio,NO,YES);AdvanceCaptureCounter(audio,"_tapCount");
    [audio checkCaptureHealth];FinishDeactivation();FinishActivation(YES);Wait(^BOOL{return (engineStarts==baseline+3) && ![audio isChangingEngine];});
    Record(@"callbacks without successful PCM conversion also trigger recovery");
    SetupCaptureMonitor(audio);MakeCaptureStale(audio,YES,YES);[audio checkCaptureHealth];
    FinishDeactivation();FinishActivation(YES);Wait(^BOOL{return (engineStarts==baseline+4) && ![audio isChangingEngine];});
    SetupCaptureMonitor(audio);MakeCaptureStale(audio,YES,YES);[audio checkCaptureHealth];
    Check(!Flag(audio,@"_engineRecoveryInFlight") && !session.deactivation,@"Stalled input created an unlimited recovery loop");
    Cleanup(audio);Check([audio valueForKey:@"_captureMonitorTimer"]==nil,@"Disconnect left the capture monitor active");
    Record(@"capture stall recovery is bounded and disconnect stops monitoring");
    session=[MLTestSession new];audio=[audioClass new];baseline=engineStarts;
    [audio start];FinishActivation(YES);Wait(^BOOL{return (engineStarts==baseline+1) && ![audio isChangingEngine];});SetupCaptureMonitor(audio);
    MakeCaptureStale(audio,YES,YES);[audio checkCaptureHealth];Cleanup(audio);
    Check(!Flag(audio,@"_wantRunning") && engineStarts==baseline+1 && !session.activation,@"Queued stall recovery reopened a disconnected microphone");
    Record(@"disconnect cancels a queued capture stall recovery");
    session=[MLTestSession new];audio=[audioClass new];baseline=engineStarts;
    [audio beginMetering];FinishActivation(YES);Wait(^BOOL{return (engineStarts==baseline+1) && ![audio isChangingEngine];});
    [audio stop];FinishDeactivation();Wait(^BOOL{return !Flag(audio,@"_sessionTransition");});
    [audio resumeIfNeeded];FinishActivation(YES);Wait(^BOOL{return (engineStarts==baseline+2) && ![audio isChangingEngine];});
    Check(Flag(audio,@"_wantRunning"),@"Visible calibration could not resume without a server connection");
    [audio endMetering];Wait(^BOOL{return !Flag(audio,@"_wantRunning");});FinishDeactivation();
    Wait(^BOOL{return !Flag(audio,@"_sessionTransition");});
    Check([audio valueForKey:@"_captureMonitorTimer"]==nil,@"Hidden standalone calibration keeps capture active");
    [audio beginMetering];FinishActivation(YES);Wait(^BOOL{return (engineStarts==baseline+3) && ![audio isChangingEngine];});
    MLTestCaptureConnection *connection=[MLTestCaptureConnection new];
    [audio setMainConnectionForAudio:(MLConnection *)connection];[audio copyAudioOutputMixerDebugInfo];
    [audio endMetering];[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.05]];
    Check(Flag(audio,@"_wantRunning") && !session.deactivation,@"Closing calibration stopped the server's microphone");
    Cleanup(audio);NSUInteger activations=session.activationCount;
    [audio beginMetering];[audio endMetering];
    [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.1]];
    Check(session.activationCount==activations && !Flag(audio,@"_wantRunning"),@"A disappearing calibration meter reopened the microphone");
    Record(@"visible calibration resumes after foreground return; disappearing meter cancels a pending start");
}

@interface MLTestDeactivationContext : NSObject
@property(nonatomic) AVAudioSessionDeactivationSource source;
@property(nonatomic,strong) id interruptionContext;
@end
@implementation MLTestDeactivationContext @end
@interface MLTestResumptionContext : NSObject
@property(nonatomic) AVAudioSessionResumptionRecommendation recommendation;
@end
@implementation MLTestResumptionContext @end
@interface MLTestAudioDelegate : NSObject <MLAudioDelegate>
@property(nonatomic) BOOL permitted;
@end
@implementation MLTestAudioDelegate
- (BOOL)audioShouldBeRunning:(MLAudio *)audio { return self.permitted; }
@end
static BOOL TestHealthyEngineStart(id self,SEL command,MLAudioSettings settings) {
    if(!TestEngineStart(self,command,settings))return NO;
    Ivar running=class_getInstanceVariable(NSClassFromString(@"MLAudio"),"_running");
    auto flag=reinterpret_cast<std::atomic_bool *>(reinterpret_cast<uint8_t *>((__bridge void *)self)+ivar_getOffset(running));
    flag->store(true);
    return YES;
}
static void NativeInactive(MLAudio *audio,AVAudioSessionDeactivationSource source) {
    MLTestDeactivationContext *context=[MLTestDeactivationContext new];context.source=source;
    [audio sessionBecameInactive:[NSNotification notificationWithName:AVAudioSessionDidBecomeInactiveNotification object:nil userInfo:@{AVAudioSessionDeactivationContextKey:context}]];
}
static void NativeResume(MLAudio *audio,AVAudioSessionResumptionRecommendation recommendation) {
    MLTestResumptionContext *context=[MLTestResumptionContext new];context.recommendation=recommendation;
    [audio sessionMayResume:[NSNotification notificationWithName:AVAudioSessionResumptionRecommendationNotification object:nil userInfo:@{AVAudioSessionResumptionContextKey:context}]];
}
static void ConnectedInterruptionTests(Class test) {
    Method engine=class_getInstanceMethod(test,@selector(startEngineWithSettings:));
    IMP previous=method_setImplementation(engine,(IMP)TestHealthyEngineStart);
    @try {
        session=[MLTestSession new];MLAudio *audio=[test new];
        MLAudioSettings settings;[audio readAudioSettings:&settings];settings.enablePreprocessor=YES;settings.transmitType=MLTransmitTypeToggle;[audio updateAudioSettings:&settings];
        MLTestCaptureConnection *connection=[MLTestCaptureConnection new];[audio setMainConnectionForAudio:(MLConnection *)connection];[audio copyAudioOutputMixerDebugInfo];
        [audio start];FinishActivation(YES);Wait(^BOOL { return audio.isRunning; });
        Check([session.category isEqual:AVAudioSessionCategoryPlayAndRecord] && [session.mode isEqual:AVAudioSessionModeVoiceChat] && (session.options&AVAudioSessionCategoryOptionMixWithOthers) && session.avoidsAlertInterruptions,@"Live conversation still uses an exclusive/alert-interruptible audio session");
        Record(@"voice chat permits media coexistence and avoids alert-only interruptions");

        audio.forceTransmit=YES;Interrupt(audio,AVAudioSessionInterruptionTypeBegan,0);Wait(^BOOL { return Flag(audio,@"_interrupted"); });
        Check(!audio.forceTransmit,@"Interrupted push-to-talk retains a pressed microphone");FinishDeactivation();Wait(^BOOL { return !Flag(audio,@"_sessionTransition"); });
        NSUInteger activations=session.activationCount;
        Interrupt(audio,AVAudioSessionInterruptionTypeEnded,0);FinishActivation(YES);Wait(^BOOL { return audio.isRunning; });
        Check(session.activationCount==activations+1 && !audio.forceTransmit && !CaptureNeeded(audio),@"Connected interruption without media ShouldResume does not restore listening safely");
        Record(@"connected conversation resumes without media hint; interrupted PTT stays released");

        if (!legacy) {
            NSUInteger deactivations=session.deactivationCount;
            NativeInactive(audio,AVAudioSessionDeactivationSourceApp);
            [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.05]];
            Check(audio.isRunning && !Flag(audio,@"_interrupted") && session.deactivationCount==deactivations,@"App deactivation notification was mistaken for a system interruption");
            NativeInactive(audio,AVAudioSessionDeactivationSourceSystem);Wait(^BOOL { return Flag(audio,@"_interrupted"); });
            Check(!audio.isRunning && !Flag(audio,@"_sessionActive") && session.deactivationCount==deactivations,@"System-inactive audio was redundantly deactivated");
            activations=session.activationCount;
            NativeResume(audio,AVAudioSessionResumptionRecommendationShouldNotResume);NativeResume(audio,AVAudioSessionResumptionRecommendationShouldNotResume);
            FinishActivation(YES);Wait(^BOOL { return audio.isRunning; });
            Check(session.activationCount==activations+1,@"Modern resumption duplicated activation of a connected conversation");
            NativeResume(audio,AVAudioSessionResumptionRecommendationShouldResume);
            [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.05]];
            Check(audio.isRunning && session.activationCount==activations+1,@"Late recommendation restarted healthy audio");
            Record(@"modern lifecycle ignores app deactivation, restores system interruption and coalesces recommendations");

            NativeInactive(audio,AVAudioSessionDeactivationSourceSystem);Wait(^BOOL { return Flag(audio,@"_interrupted"); });
            NativeResume(audio,AVAudioSessionResumptionRecommendationShouldResume);FinishActivation(NO);Wait(^BOOL { return !Flag(audio,@"_sessionTransition"); });
            activations=session.activationCount;
            [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.1]];
            Check(!audio.isRunning && session.activationCount==activations,@"Rejected background activation created an automatic retry loop");
            NativeResume(audio,AVAudioSessionResumptionRecommendationShouldResume);NativeResume(audio,AVAudioSessionResumptionRecommendationShouldResume);
            FinishActivation(YES);Wait(^BOOL { return audio.isRunning; });
            Check(session.activationCount==activations+1,@"System availability did not permit one retry after rejected activation");
            Record(@"rejected activation waits for system recommendation; later availability restores conversation once");

            NativeInactive(audio,AVAudioSessionDeactivationSourceSystem);Wait(^BOOL { return Flag(audio,@"_interrupted"); });
            [audio setMainConnectionForAudio:nil];[audio stop];activations=session.activationCount;
            NativeResume(audio,AVAudioSessionResumptionRecommendationShouldResume);
            [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.05]];
            Check(!audio.isRunning && !Flag(audio,@"_wantRunning") && session.activationCount==activations,@"Resumption reopened a disconnected conversation");
            Record(@"disconnect prevents modern resumption from reopening the microphone");
            [audio setMainConnectionForAudio:(MLConnection *)connection];[audio copyAudioOutputMixerDebugInfo];[audio start];FinishActivation(YES);Wait(^BOOL { return audio.isRunning; });
            MLTestAudioDelegate *delegate=[MLTestAudioDelegate new];delegate.permitted=NO;audio.delegate=delegate;
            NativeInactive(audio,AVAudioSessionDeactivationSourceSystem);Wait(^BOOL { return Flag(audio,@"_interrupted"); });activations=session.activationCount;
            NativeResume(audio,AVAudioSessionResumptionRecommendationShouldResume);
            [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.05]];
            Check(!Flag(audio,@"_wantRunning") && session.activationCount==activations,@"Resumption ignored the delegate's cancelled capture intent");
            audio.delegate=nil;Record(@"delegate can veto restoration of an interrupted conversation");
        }
        Cleanup(audio);
    } @finally { method_setImplementation(engine,previous); }
}
static BOOL delayCaptureRunningSnapshot=NO;
@interface MLCaptureTestInput : NSObject
@property(nonatomic,strong) AVAudioFormat *format;
@property(nonatomic,copy) AVAudioNodeTapBlock tap;
@end
@implementation MLCaptureTestInput
- (AVAudioFormat *)outputFormatForBus:(AVAudioNodeBus)bus { return _format; }
- (void)installTapOnBus:(AVAudioNodeBus)bus bufferSize:(AVAudioFrameCount)size format:(AVAudioFormat *)format block:(AVAudioNodeTapBlock)block { self.tap=block; }
- (void)removeTapOnBus:(AVAudioNodeBus)bus { self.tap=nil; }
@end
@interface MLCaptureTestEngine : NSObject
@property(nonatomic,strong) MLCaptureTestInput *inputNode;
@property(nonatomic,strong) MLTestMixer *mainMixerNode;
@property(nonatomic) BOOL autoShutdownEnabled;
@property(nonatomic,getter=isRunning) BOOL running;
@end
@implementation MLCaptureTestEngine
- (void)prepare {}
- (BOOL)startAndReturnError:(NSError **)error { _running=!delayCaptureRunningSnapshot; return YES; }
- (void)stop { _running=NO; }
@end
static AVAudioFormat *testInputFormat;
static id MakeCaptureTestEngine(id self, SEL selector) {
    MLCaptureTestEngine *engine=[MLCaptureTestEngine new]; engine.inputNode=[MLCaptureTestInput new];
    engine.inputNode.format=testInputFormat; engine.mainMixerNode=[MLTestMixer new]; return engine;
}
static uint64_t ReadCaptureCounter(MLAudio *audio, const char *name) {
    Ivar field=class_getInstanceVariable(NSClassFromString(@"MLAudio"),name);
    auto *counter=reinterpret_cast<std::atomic_uint64_t *>(reinterpret_cast<char *>((__bridge void *)audio)+ivar_getOffset(field));
    return counter->load();
}
static void CaptureQueueTests(void) {
    Class base=NSClassFromString(@"MLAudio"); Class test=objc_allocateClassPair(base,"MLCaptureQueueTestAudio",0);
    class_addMethod(test,@selector(makeAudioEngine),(IMP)MakeCaptureTestEngine,method_getTypeEncoding(class_getInstanceMethod(base,@selector(makeAudioEngine))));
    objc_registerClassPair(test);
    MLAudio *audio=[test new]; MLAudioSettings settings; [audio readAudioSettings:&settings];
    settings.transmitType=MLTransmitTypeContinuous; settings.enablePreprocessor=NO;
    [audio updateAudioSettings:&settings];
    MLTestCaptureConnection *connection=[MLTestCaptureConnection new];
    [audio setMainConnectionForAudio:(MLConnection *)connection]; [audio copyAudioOutputMixerDebugInfo];
    AVAudioFormat *mono=[[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:48000 channels:1 interleaved:NO];
    testInputFormat=mono;delayCaptureRunningSnapshot=YES; [audio setValue:@YES forKey:@"_wantRunning"];[audio prepareEngineWithSettings:settings];Wait(^BOOL{return ![audio isChangingEngine];});
    MLCaptureTestEngine *engine=[audio valueForKey:@"_engine"];
    AVAudioNodeTapBlock oldTap=engine.inputNode.tap;
    AVAudioPCMBuffer *input=[[AVAudioPCMBuffer alloc] initWithPCMFormat:mono frameCapacity:960]; input.frameLength=960;
    for (NSUInteger i=0;i<960;++i) input.floatChannelData[0][i]=.2;
    AVAudioTime *time=[AVAudioTime timeWithSampleTime:0 atRate:48000];
    oldTap(input,time);
    Wait(^BOOL { return ReadCaptureCounter(audio,"_processedCount")>0; }); [audio copyAudioOutputMixerDebugInfo];
    Check(connection.frames.count==1,@"Pooled tap did not deliver its PCM to the encoder");
    Check(!engine.isRunning && ![audio isChangingEngine],@"Delayed native running snapshot tears down successful capture");
    engine.running=YES;delayCaptureRunningSnapshot=NO;
    Record(@"successful start with a delayed running snapshot still captures PCM and sends Opus");
    [audio setLocalMuted:YES deafened:NO]; [audio copyAudioOutputMixerDebugInfo];
    uint64_t processed=ReadCaptureCounter(audio,"_processedCount"), taps=ReadCaptureCounter(audio,"_tapCount");
    oldTap(input,time); [audio copyAudioOutputMixerDebugInfo];
    Check(ReadCaptureCounter(audio,"_tapCount")==taps+1 && ReadCaptureCounter(audio,"_processedCount")==processed,@"Muted capture stopped callbacks or retained DSP work");
    [audio stop];Wait(^BOOL{return ![audio isChangingEngine];});[audio copyAudioOutputMixerDebugInfo];
    Check(!engine.inputNode.tap && [audio valueForKey:@"_captureSource"]==nil,@"Stop retained its input tap or pending capture source");
    oldTap(input,time);
    Check(ReadCaptureCounter(audio,"_tapCount")==taps+1,@"A retired tap processed input after stop");
    [audio setLocalMuted:NO deafened:NO]; [audio copyAudioOutputMixerDebugInfo];
    NSUInteger previousPackets=connection.frames.count;
    testInputFormat=[[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:44100 channels:2 interleaved:NO];
    [audio setValue:@YES forKey:@"_wantRunning"];[audio prepareEngineWithSettings:settings];Wait(^BOOL{return audio.isRunning;});
    MLCaptureTestEngine *replacement=[audio valueForKey:@"_engine"];
    oldTap(input,time);
    Check(ReadCaptureCounter(audio,"_tapCount")==taps+1,@"A retired tap entered the replacement input queue");
    AVAudioPCMBuffer *stereo=[[AVAudioPCMBuffer alloc] initWithPCMFormat:testInputFormat frameCapacity:882]; stereo.frameLength=882;
    for (NSUInteger c=0;c<2;++c) for (NSUInteger i=0;i<882;++i) stereo.floatChannelData[c][i]=.2;
    time=[AVAudioTime timeWithSampleTime:0 atRate:44100];
    replacement.inputNode.tap(stereo,time);
    replacement.inputNode.tap(stereo,time);
    Wait(^BOOL { return ReadCaptureCounter(audio,"_processedCount")>=processed+2; }); [audio copyAudioOutputMixerDebugInfo];
    Check(audio.isRunning && connection.frames.count>previousPackets,@"Input-format change failed to rebuild capture buffers and resume encoding");
    [audio stop];Wait(^BOOL{return ![audio isChangingEngine];});testInputFormat=nil;
    Record(@"pooled input reaches Opus; mute skips DSP; old taps cannot enter restarted or changed-format capture");

    id playback=[NSClassFromString(@"MLPlayback") new];
    AVAudioPCMBuffer *first=[playback bufferWithFormat:mono], *inUse=[playback bufferWithFormat:mono];
    Check(first!=inUse,@"Playback reused a buffer while the player still owns it");
    [playback recycleBuffer:first];
    Check([playback bufferWithFormat:mono]==first,@"Completed playback buffers are not reused");
    Record(@"playback buffers are reused only after returning to the free pool");
}
static void SpeakingIndicatorTests(void) {
    MLServerModel *model=[[MLServerModel alloc] initWithConnection:nil];
    MLUser *user=[MLUser new]; user.session=2;
    [(NSMutableDictionary *)[model valueForKey:@"_users"] setObject:user forKey:@2];
    [model setTalkState:MLTalkStateTalking forSession:2];
    Check(user.talkState==MLTalkStateTalking,@"Local speech did not light its indicator immediately");
    [model setTalkState:MLTalkStatePassive forSession:2];
    [model setValue:user forKey:@"_connectedUser"];
    MLAudioSettings original, ptt; [MLAudio.sharedAudio readAudioSettings:&original]; ptt=original; ptt.transmitType=MLTransmitTypeToggle;
    [MLAudio.sharedAudio updateAudioSettings:&ptt]; MLAudio.sharedAudio.forceTransmit=NO;
    id server=[[NSClassFromString(@"MUServerViewController") alloc] initWithServerModel:model];
    Check([server talkStateForUser:user]==MLTalkStateTalking && !MLAudio.sharedAudio.forceTransmit,@"PTT release bypassed the visual hold or delayed actual transmission release");
    [MLAudio.sharedAudio updateAudioSettings:&original];
    NSDate *pause=[NSDate dateWithTimeIntervalSinceNow:.15];
    while (pause.timeIntervalSinceNow>0) [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]];
    Check(user.talkState==MLTalkStateTalking,@"A brief local speech gap immediately cleared the indicator");
    [model setTalkState:MLTalkStateTalking forSession:2];
    pause=[NSDate dateWithTimeIntervalSinceNow:.2];
    while (pause.timeIntervalSinceNow>0) [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]];
    Check(user.talkState==MLTalkStateTalking,@"The previous pause timer cleared resumed speech");
    [model setTalkState:MLTalkStatePassive forSession:2];
    Wait(^BOOL { return user.talkState==MLTalkStatePassive; });
    [model receivedVoiceForSession:2 talkState:MLTalkStateTalking hasAudio:YES terminator:YES];
    Check(user.talkState==MLTalkStateTalking,@"A short remote utterance was never displayed");
    [model receivedVoiceForSession:2 talkState:MLTalkStateTalking hasAudio:NO terminator:YES];
    pause=[NSDate dateWithTimeIntervalSinceNow:.15];
    while (pause.timeIntervalSinceNow>0) [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]];
    Check(user.talkState==MLTalkStateTalking,@"Remote stop bypassed the speaking hold interval");
    [model receivedVoiceForSession:2 talkState:MLTalkStateShouting hasAudio:YES terminator:NO];
    pause=[NSDate dateWithTimeIntervalSinceNow:.2];
    while (pause.timeIntervalSinceNow>0) [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]];
    Check(user.talkState==MLTalkStateShouting,@"An old remote stop timer cleared resumed speech");
    [model receivedVoiceForSession:2 talkState:MLTalkStateShouting hasAudio:NO terminator:YES];
    Wait(^BOOL { return user.talkState==MLTalkStatePassive; });
    [model setTalkState:MLTalkStateTalking forSession:2]; user.selfMuted=YES;
    [model setTalkState:MLTalkStatePassive forSession:2];
    Check(user.talkState==MLTalkStatePassive,@"Mute left the speaking indicator active");
    user.selfMuted=NO;
    [model receivedVoiceForSession:2 talkState:MLTalkStateTalking hasAudio:YES terminator:NO];
    Wait(^BOOL { return user.talkState==MLTalkStatePassive; });
    [model setTalkState:MLTalkStateTalking forSession:2]; [model setTalkState:MLTalkStatePassive forSession:2];
    [model reset];
    Check(![model userWithSession:2] && ![(NSDictionary *)[model valueForKey:@"_talkTimers"] count],@"Disconnect retained speaking state or timers");
    Record(@"speaking starts immediately, bridges short pauses, clears after silence/mute and cancels on reset");
}
static dispatch_semaphore_t slowBuildEntered,slowBuildRelease;
static MLTestEngine *retiredBuildEngine;
static BOOL SlowEngineStart(id object,SEL command,MLAudioSettings settings){
    dispatch_semaphore_signal(slowBuildEntered);
    dispatch_semaphore_wait(slowBuildRelease,dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC));
    BOOL ready=TestEngineStart(object,command,settings);retiredBuildEngine=[object valueForKey:@"_engine"];return ready;
}
static void NonBlockingEngineTests(Class test){
    session=[MLTestSession new];MLAudio *audio=[test new];NSUInteger before=engineStarts;
    dispatch_queue_t queue=(dispatch_queue_t)[audio valueForKey:@"_queue"];
    dispatch_semaphore_t entered=dispatch_semaphore_create(0),release=dispatch_semaphore_create(0);
    dispatch_async(queue,^{dispatch_semaphore_signal(entered);dispatch_semaphore_wait(release,dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC));});
    Check(dispatch_semaphore_wait(entered,dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC))==0,@"Busy audio queue fixture did not start");
    @try{
        [audio start];FinishActivation(YES);Wait(^BOOL{return [audio isChangingEngine] && ![audio isSessionTransitioning];});
        NSTimeInterval start=NSProcessInfo.processInfo.systemUptime;[audio stop];[audio start];
        Check(NSProcessInfo.processInfo.systemUptime-start<.5,@"Stop/start waits for a busy audio queue on main");
        __block BOOL heartbeat=NO;dispatch_async(dispatch_get_main_queue(),^{heartbeat=YES;});Wait(^BOOL{return heartbeat;});
        Check(engineStarts==before && session.deactivation==nil,@"A pending graph is built or its session released before teardown");
        dispatch_semaphore_signal(release);FinishDeactivation();FinishActivation(YES);Wait(^BOOL{return audio.isRunning;});
        Check(engineStarts==before+1,@"Cancelled graph preparation builds a stale engine");Cleanup(audio);
    }@finally{dispatch_semaphore_signal(release);}
    Record(@"busy DSP cannot block main; cancelled preparation drains before session release and a fresh start");

    session=[MLTestSession new];audio=[test new];before=engineStarts;
    slowBuildEntered=dispatch_semaphore_create(0);slowBuildRelease=dispatch_semaphore_create(0);retiredBuildEngine=nil;
    Method build=class_getInstanceMethod(test,@selector(startEngineWithSettings:));IMP original=method_setImplementation(build,(IMP)SlowEngineStart);
    @try{
        [audio start];FinishActivation(YES);
        __block BOOL entered=NO;Wait(^BOOL{if(!entered)entered=dispatch_semaphore_wait(slowBuildEntered,DISPATCH_TIME_NOW)==0;return entered;});
        NSTimeInterval start=NSProcessInfo.processInfo.systemUptime;[audio stop];[audio start];
        Check(NSProcessInfo.processInfo.systemUptime-start<.5 && !audio.isRunning,@"Stopping during engine construction blocks main or publishes a stale running state");
        method_setImplementation(build,original);dispatch_semaphore_signal(slowBuildRelease);
        FinishDeactivation();FinishActivation(YES);Wait(^BOOL{return audio.isRunning;});
        Check(engineStarts==before+2 && retiredBuildEngine && !retiredBuildEngine.running,@"Retired engine survives replacement or a stale startup becomes current");Cleanup(audio);
    }@finally{method_setImplementation(build,original);dispatch_semaphore_signal(slowBuildRelease);retiredBuildEngine=nil;}
    Record(@"stop during graph construction remains responsive, rejects stale completion and retires the old graph");
    session=[MLTestSession new];audio=[test new];before=engineStarts;startupFailuresRemaining=6;
    [audio start];
    diagnosticAudio=audio;
    for(NSUInteger attempt=0;attempt<6;++attempt){lifecycleStep=[NSString stringWithFormat:@"bounded startup attempt %lu (expected build %lu)",(unsigned long)attempt,(unsigned long)(before+attempt+1)];FinishActivation(YES);Wait(^BOOL{return engineStarts==before+attempt+1 && ![audio isChangingEngine];});}
    Check(!audio.isRunning && [audio valueForKey:@"_engineRetryTimer"]==nil,@"Failed hardware remains in an automatic retry loop");
    NSUInteger activations=session.activationCount;
    [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.6]];
    Check(session.activationCount==activations && engineStarts==before+6,@"Exhausted graph retries silently restart");
    lifecycleStep=@"explicit start after exhausted budget";
    [audio start];FinishActivation(YES);Wait(^BOOL{return audio.isRunning;});Cleanup(audio);lifecycleStep=nil;diagnosticAudio=nil;
    Record(@"exhausted graph retries stay stopped; a later explicit start gets a fresh bounded attempt");
}
static void ConfigurationReconciliationTests(Class test){
    session=[MLTestSession new];MLAudio *audio=[test new];[audio start];FinishActivation(YES);Wait(^BOOL{return audio.isRunning;});
    NSUInteger before=engineStarts,activations=session.activationCount;
    MLAudioSettings settings;[audio readAudioSettings:&settings];
    settings.volume=.5;settings.quality=72000;settings.audioPerPacket=4;settings.transmitType=MLTransmitTypeToggle;
    [audio updateAudioSettings:&settings];
    settings.preferReceiverOverSpeaker=YES;[audio updateAudioSettings:&settings];
    settings.preferReceiverOverSpeaker=NO;[audio updateAudioSettings:&settings];
    [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.15]];
    Check(audio.isRunning && engineStarts==before && session.activationCount==activations,@"Live preferences or a cancelled configuration change rebuild the microphone");Cleanup(audio);
    Record(@"volume, bitrate, packet duration and transmission update live; coalesced changes avoid needless graph rebuilds");

    session=[MLTestSession new];audio=[test new];before=engineStarts;
    dispatch_queue_t queue=(dispatch_queue_t)[audio valueForKey:@"_queue"];
    dispatch_semaphore_t entered=dispatch_semaphore_create(0),release=dispatch_semaphore_create(0);
    dispatch_async(queue,^{dispatch_semaphore_signal(entered);dispatch_semaphore_wait(release,dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC));});
    Check(dispatch_semaphore_wait(entered,dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC))==0,@"Pending configuration fixture did not enter DSP");
    @try{
        [audio start];FinishActivation(YES);Wait(^BOOL{return [audio isChangingEngine] && ![audio isSessionTransitioning];});
        [audio readAudioSettings:&settings];settings.preferReceiverOverSpeaker=YES;[audio updateAudioSettings:&settings];
        dispatch_semaphore_signal(release);FinishDeactivation();
        Check(!audio.isRunning,@"A graph using obsolete preferences becomes running");
        FinishActivation(YES);Wait(^BOOL{return audio.isRunning;});
        Check(engineStarts==before+2 && !(session.options&AVAudioSessionCategoryOptionDefaultToSpeaker),@"A preference changed during graph construction is not reconciled");Cleanup(audio);
    }@finally{dispatch_semaphore_signal(release);}
    session=[MLTestSession new];audio=[test new];before=engineStarts;
    [audio start];Wait(^BOOL{return session.activation!=nil;});
    [audio readAudioSettings:&settings];settings.preferReceiverOverSpeaker=YES;[audio updateAudioSettings:&settings];
    FinishActivation(YES);FinishDeactivation();FinishActivation(YES);Wait(^BOOL{return audio.isRunning;});
    Check(engineStarts==before+1 && !(session.options&AVAudioSessionCategoryOptionDefaultToSpeaker),@"Settings changed during activation construct an obsolete graph");Cleanup(audio);
    Record(@"configuration changes during activation and graph construction settle on the latest route before publishing running");
}
static void RunTests(void) {
    results=[NSMutableArray array];
    legacy=getenv("ML_AUDIO_TEST_LEGACY")!=nullptr;
    Method sessionAPI=class_getInstanceMethod(MLAudio.class,NSSelectorFromString(@"usesAsynchronousSessionAPI"));
    IMP originalSessionAPI=method_setImplementation(sessionAPI,(IMP)TestAsynchronousSessionAPI);
    Method shared=class_getClassMethod(AVAudioSession.class,@selector(sharedInstance));
    IMP originalShared=method_setImplementation(shared,(IMP)TestSharedSession);
    Method permission=class_getInstanceMethod(object_getClass(AVAudioApplication.sharedInstance),@selector(recordPermission));
    IMP originalPermission=method_setImplementation(permission,(IMP)TestPermission);
    Method request=class_getClassMethod(AVAudioApplication.class,@selector(requestRecordPermissionWithCompletionHandler:));
    IMP originalRequest=method_setImplementation(request,(IMP)TestPermissionRequest);
    Class base=NSClassFromString(@"MLAudio");
    Class test=objc_allocateClassPair(base,"MLLifecycleTestAudio",0);
    Method engine=class_getInstanceMethod(base,@selector(startEngineWithSettings:));
    class_addMethod(test,@selector(startEngineWithSettings:),(IMP)TestEngineStart,method_getTypeEncoding(engine));
    objc_registerClassPair(test);
    @try {
        if(getenv("ML_AUDIO_TEST_ENGINE_ONLY")){NonBlockingEngineTests(test);ConfigurationReconciliationTests(test);}
        else {
        Check(AVAudioApplication.sharedInstance.recordPermission==AVAudioApplicationRecordPermissionGranted,@"Permission test shim failed");
        session=[MLTestSession new]; engineStarts=0;
        MLAudio *audio=[test new];
        [audio start]; [audio start]; [audio start];
        Wait(^BOOL { return session.activation!=nil; });
        Check(session.activationCount==1,@"Repeated start created overlapping activations");
        [audio stop]; FinishActivation(YES); FinishDeactivation();
        Wait(^BOOL { return !Flag(audio,@"_sessionTransition"); });
        Check(engineStarts==0 && !Flag(audio,@"_sessionActive"),@"A cancelled start reopened audio");
        Record(@"stop while activation is pending; duplicate starts coalesce");

        [audio start]; Wait(^BOOL { return session.activation!=nil; });
        [audio restart]; FinishActivation(YES); FinishDeactivation();
        Wait(^BOOL { return session.activation!=nil; });
        Check(engineStarts==0,@"Restart reused a stale activation");
        FinishActivation(YES); Wait(^BOOL{return (engineStarts==1) && ![audio isChangingEngine];}); Cleanup(audio);
        Record(@"restart waits for cancelled activation and deactivation");

        NSUInteger count=session.activationCount;
        [audio start]; FinishActivation(YES); Wait(^BOOL{return (engineStarts==2) && ![audio isChangingEngine];});
        [audio stop]; [audio start]; [audio start];
        Wait(^BOOL { return session.deactivation!=nil; });
        Check(session.activationCount==count+1,@"Started before deactivation completed");
        FinishDeactivation(); FinishActivation(YES); Wait(^BOOL{return (engineStarts==3) && ![audio isChangingEngine];}); Cleanup(audio);
        Record(@"start waits for pending deactivation");

        [audio start]; Wait(^BOOL { return session.activation!=nil; });
        Interrupt(audio,AVAudioSessionInterruptionTypeBegan,0);
        Wait(^BOOL { return Flag(audio,@"_interrupted"); });
        FinishActivation(YES); FinishDeactivation();
        Wait(^BOOL { return !Flag(audio,@"_sessionTransition"); });
        Check(engineStarts==3 && session.activation==nil,@"Audio restarted during an interruption");
        Interrupt(audio,AVAudioSessionInterruptionTypeEnded,AVAudioSessionInterruptionOptionShouldResume);
        FinishActivation(YES); Wait(^BOOL{return (engineStarts==4) && ![audio isChangingEngine];}); Cleanup(audio);
        Record(@"interruption blocks pending start and resumes only after it ends");

        [audio start]; Wait(^BOOL { return session.activation!=nil; });
        Interrupt(audio,AVAudioSessionInterruptionTypeBegan,0); Wait(^BOOL { return Flag(audio,@"_interrupted"); });
        FinishActivation(YES); FinishDeactivation(); Wait(^BOOL { return !Flag(audio,@"_sessionTransition"); });
        Interrupt(audio,AVAudioSessionInterruptionTypeEnded,0); Wait(^BOOL { return !Flag(audio,@"_interrupted"); });
        Check(Flag(audio,@"_wantRunning") && session.activation==nil,@"Automatic resume ignored system guidance or discarded capture intent");
        Cleanup(audio); Record(@"interruption without ShouldResume stays stopped");

        [audio start]; FinishActivation(NO); Wait(^BOOL { return !Flag(audio,@"_sessionTransition"); });
        Check(engineStarts==4,@"Failed activation started the engine");
        [audio start]; FinishActivation(YES); Wait(^BOOL{return (engineStarts==5) && ![audio isChangingEngine];}); Cleanup(audio);
        Record(@"activation failure permits a later retry");

        session.failConfiguration=YES; [audio start]; Wait(^BOOL { return !Flag(audio,@"_sessionTransition"); });
        Check(session.activation==nil && engineStarts==5,@"Configuration failure activated audio");
        session.failConfiguration=NO; Cleanup(audio); Record(@"configuration failure does not start audio");
        NSUInteger previous=session.activationCount;
        permissionValue=AVAudioApplicationRecordPermissionUndetermined;
        [audio start]; [audio start];
        Check(permissionRequests==1 && permissionCompletion!=nil,@"Repeated start duplicated the permission prompt");
        [audio stop]; permissionValue=AVAudioApplicationRecordPermissionGranted;
        void (^granted)(BOOL)=permissionCompletion; permissionCompletion=nil;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT,0),^{ granted(YES); });
        Wait(^BOOL { return !Flag(audio,@"_permissionRequested"); });
        Check(session.activationCount==previous,@"Late microphone permission restarted cancelled audio");
        [audio start]; FinishActivation(YES); Wait(^BOOL{return (engineStarts==6) && ![audio isChangingEngine];}); Cleanup(audio);
        Record(@"permission prompt coalesces and a late grant respects stop");

        [audio start]; FinishActivation(YES); Wait(^BOOL{return (engineStarts==7) && ![audio isChangingEngine];});
        [audio stop]; Wait(^BOOL { return session.deactivation!=nil; });
        void (^failed)(BOOL,NSError *)=session.deactivation; session.deactivation=nil;
        failed(NO,[NSError errorWithDomain:@"Test" code:2 userInfo:nil]);
        Wait(^BOOL { return !Flag(audio,@"_sessionTransition"); });
        Check(Flag(audio,@"_sessionActive") && session.activation==nil,@"Deactivation failure restarted audio");
        Record(@"deactivation failure remains stopped and can be retried");
        [audio start]; FinishActivation(NO); Wait(^BOOL { return !Flag(audio,@"_sessionTransition"); });
        Check(Flag(audio,@"_sessionActive") && engineStarts==7,@"Failed activation lost ownership of an unreleased session");
        Cleanup(audio); Record(@"activation failure after failed deactivation still releases the session on stop");
        NSUInteger baseline=engineStarts;
        [audio start]; FinishActivation(YES); Wait(^BOOL{return (engineStarts==baseline+1) && ![audio isChangingEngine];});
        MLTestEngine *stopped=[audio valueForKey:@"_engine"]; stopped.running=NO;
        NSUInteger resumed=engineResumes, activations=session.activationCount, deactivations=session.deactivationCount;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT,0), ^{
            for (int i=0;i<3;i++) [NSNotificationCenter.defaultCenter postNotificationName:AVAudioEngineConfigurationChangeNotification object:stopped];
        });
        Wait(^BOOL { return stopped.running && !Flag(audio,@"_engineRecoveryInFlight"); });
        Check(engineResumes==resumed+1 && session.activationCount==activations && session.deactivationCount==deactivations && engineStarts==baseline+1,@"Recovery recreated the graph or toggled the audio session");
        Record(@"configuration recovery resumes existing graph off main; duplicate events coalesce");

        NSDate *continuousDeadline=[NSDate dateWithTimeIntervalSinceNow:2];
        while (continuousDeadline.timeIntervalSinceNow>0) {
            [audio recoverStoppedEngine];
            [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.05]];
        }
        Check(engineResumes==resumed+1 && session.activationCount==activations && session.deactivationCount==deactivations,@"Healthy idle engine caused wakeups or session churn");
        Record(@"healthy idle engine does not cycle the session");

        for (NSUInteger attempt=0;attempt<2;attempt++) {
            stopped.running=NO; [audio recoverStoppedEngine];
            Wait(^BOOL { return stopped.running && !Flag(audio,@"_engineRecoveryInFlight"); });
        }
        stopped.running=NO; [audio recoverStoppedEngine];
        Check(engineResumes==resumed+3 && !Flag(audio,@"_engineRecoveryInFlight"),@"Repeated engine failures created an unlimited restart loop");
        Record(@"repeated successful starts followed by stops have a bounded recovery budget");

        [NSNotificationCenter.defaultCenter postNotificationName:AVAudioEngineConfigurationChangeNotification object:stopped];
        Cleanup(audio); activations=session.activationCount;
        [audio recoverStoppedEngine];
        Check(!Flag(audio,@"_wantRunning") && session.activationCount==activations,@"Late recovery reopened a disconnected microphone");
        Record(@"explicit stop cancels queued engine recovery");

        // Simulate a notification emitted while an old engine is being torn down.
        [audio start]; FinishActivation(YES); Wait(^BOOL{return (engineStarts==baseline+2) && ![audio isChangingEngine];});
        MLTestEngine *current=[audio valueForKey:@"_engine"];
        [NSNotificationCenter.defaultCenter postNotificationName:AVAudioEngineConfigurationChangeNotification object:stopped];
        NSDate *staleDeadline=[NSDate dateWithTimeIntervalSinceNow:.1];
        while (staleDeadline.timeIntervalSinceNow>0) [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
        Check([audio valueForKey:@"_engine"]==current && engineResumes==resumed+3,@"Old-engine notification disturbed the new engine");
        Cleanup(audio); Record(@"stale engine teardown notifications are ignored");
        __weak MLTestEngine *releasedEngine;
        @autoreleasepool {
            MLTestEngine *old=[MLTestEngine new]; releasedEngine=old;
            [NSNotificationCenter.defaultCenter postNotificationName:AVAudioEngineConfigurationChangeNotification object:old];
        }
        Check(releasedEngine==nil,@"Queued configuration callback retained an engine during teardown");
        Record(@"configuration callback does not retain a retiring engine");
        baseline=engineStarts; startupFailuresRemaining=1;
        [audio start]; FinishActivation(YES); Wait(^BOOL{return (engineStarts==baseline+1) && ![audio isChangingEngine];});
        Check(Flag(audio,@"_wantRunning") && [audio valueForKey:@"_engineRetryTimer"]!=nil,@"Transient input failure abandoned the connected microphone");
        FinishActivation(YES); Wait(^BOOL{return (engineStarts==baseline+2) && ![audio isChangingEngine];}); Cleanup(audio);
        Record(@"transient input format failure preserves capture intent and retries");

        baseline=engineStarts; startupFailuresRemaining=1;
        [audio start]; FinishActivation(YES); Wait(^BOOL{return (engineStarts==baseline+1) && ![audio isChangingEngine];}); Cleanup(audio);
        activations=session.activationCount;
        NSDate *retryDeadline=[NSDate dateWithTimeIntervalSinceNow:.7];
        while (retryDeadline.timeIntervalSinceNow>0) [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.02]];
        Check(engineStarts==baseline+1 && session.activationCount==activations && [audio valueForKey:@"_engineRetryTimer"]==nil,@"Disconnect did not cancel the input retry");
        Record(@"disconnect cancels a pending microphone startup retry");
        baseline=engineStarts;
        [audio start]; FinishActivation(YES); Wait(^BOOL{return (engineStarts==baseline+1) && ![audio isChangingEngine];});
        void (^interruptWithoutEnd)(void)=^{
            Interrupt(audio,AVAudioSessionInterruptionTypeBegan,0);
            Wait(^BOOL { return Flag(audio,@"_interrupted"); });
            FinishDeactivation(); Wait(^BOOL { return !Flag(audio,@"_sessionTransition"); });
        };
        interruptWithoutEnd();
        activations=session.activationCount;
        [audio resumeIfNeeded]; [audio resumeIfNeeded]; [audio resumeIfNeeded];
        FinishActivation(YES); Wait(^BOOL{return (engineStarts==baseline+2) && ![audio isChangingEngine];});
        Check(session.activationCount==activations+1 && !Flag(audio,@"_interrupted"),@"Foreground recovery duplicated activation or kept a stale interruption");
        Interrupt(audio,AVAudioSessionInterruptionTypeEnded,0);
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.05]];
        Check(Flag(audio,@"_wantRunning"),@"Late interruption end cancelled explicit recovery");
        Record(@"foreground recovery works without interruption end; duplicate requests and late end coalesce");

        interruptWithoutEnd();
        Interrupt(audio,AVAudioSessionInterruptionTypeEnded,0);
        Wait(^BOOL { return !Flag(audio,@"_interrupted"); });
        Check(Flag(audio,@"_wantRunning") && session.activation==nil,@"Nonresumable interruption discarded the next explicit capture action");
        [audio setLocalMuted:YES deafened:NO]; [audio setLocalMuted:NO deafened:NO];
        FinishActivation(YES); Wait(^BOOL{return (engineStarts==baseline+3) && ![audio isChangingEngine];});
        Record(@"unmute restores interrupted capture without reconnecting");

        interruptWithoutEnd(); [audio resumeIfNeeded]; FinishActivation(NO);
        Wait(^BOOL { return !Flag(audio,@"_sessionTransition"); });
        activations=session.activationCount;
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.1]];
        Check(session.activationCount==activations && engineStarts==baseline+3,@"Denied recovery started a retry loop or engine");
        audio.forceTransmit=YES; FinishActivation(YES); Wait(^BOOL{return (engineStarts==baseline+4) && ![audio isChangingEngine];});
        audio.forceTransmit=NO;
        Record(@"higher-priority audio can deny recovery; a later PTT press retries once");

        interruptWithoutEnd(); activations=session.activationCount;
        [audio setLocalMuted:YES deafened:NO]; [audio setLocalMuted:NO deafened:NO]; [audio stop];
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.1]];
        [audio resumeIfNeeded];
        Check(session.activationCount==activations && !Flag(audio,@"_wantRunning"),@"Queued user action reopened capture after disconnect");
        Record(@"disconnect cancels queued unmute and foreground recovery");
        CaptureTests();
        VoiceQualityTests();
        DeafenTests();
        CaptureHealthTests(test);
        ConnectedInterruptionTests(test);
        CaptureQueueTests();
        SpeakingIndicatorTests();
        NonBlockingEngineTests(test);
        ConfigurationReconciliationTests(test);
        MLVoiceIngressTests(^(NSString *name){Record(name);});
        }
        [results addObject:@"ALL TESTS PASSED"];
    } @catch (NSException *error) {
        [results addObject:[NSString stringWithFormat:@"FAIL %@: %@",error.name,error.reason]];
    } @finally {
        method_setImplementation(sessionAPI,originalSessionAPI);
        method_setImplementation(shared,originalShared);
        method_setImplementation(permission,originalPermission);
        method_setImplementation(request,originalRequest);
    }
    NSString *path=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"audio-lifecycle-results.txt"];
    [[[results componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"] writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}
__attribute__((constructor)) static void ScheduleTests(void) {
    dispatch_async(dispatch_get_main_queue(),^{
        // Run from the run loop, so Wait can deliver main-queue callbacks without reentering a GCD block.
        [NSTimer scheduledTimerWithTimeInterval:1 repeats:NO block:^(NSTimer *timer) { RunTests(); }];
    });
}
