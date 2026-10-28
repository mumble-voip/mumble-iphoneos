#import <Network/Network.h>
#import "MLInternal.hpp"
#include "MLVoiceCrypt.hpp"
#include "MLTransportTiming.hpp"
#include <mumble/Connection.hpp>
#include <mumble/Lib.hpp>
#include <mumble/PacketDataStream.hpp>
#include <openssl/evp.h>
#include <openssl/err.h>
#include <netdb.h>
#include <poll.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/socket.h>
#include <atomic>
#include <mutex>
#include <deque>
#include <chrono>
#include <unordered_map>

using namespace mumble;
using MLClock=std::chrono::steady_clock;
struct MLVoiceFrame { Buf data; uint64_t sequence; bool terminator; };
struct MLVoiceActivity { MLTalkState state=MLTalkStatePassive; bool hasAudio=false, terminator=false; };
struct MLNetworkState {
    std::atomic_bool halt{false};
    std::mutex mutex;
    int socket=-1;
    std::deque<Buf> outgoing;
    std::deque<MLVoiceFrame> voice;
    std::unordered_map<NSUInteger,MLVoiceActivity> pendingVoiceActivity;
    bool voiceActivityScheduled=false;
    NSData *__strong expectedCertificate=nil;
    int wakeReader=-1, wakeWriter=-1;
    MLNetworkState() {
        int pair[2];
        if (socketpair(AF_UNIX,SOCK_STREAM,0,pair)==0) {
            wakeReader=pair[0]; wakeWriter=pair[1];
            for (int fd:pair) {
                fcntl(fd,F_SETFL,fcntl(fd,F_GETFL,0)|O_NONBLOCK);
                int one=1; setsockopt(fd,SOL_SOCKET,SO_NOSIGPIPE,&one,sizeof(one));
            }
        }
    }
    ~MLNetworkState() { if (wakeReader>=0) close(wakeReader); if (wakeWriter>=0) close(wakeWriter); }
    void wake() { if (wakeWriter>=0) { char byte=0; send(wakeWriter,&byte,1,0); } }
    void drainWake() { char bytes[256]; while (recv(wakeReader,bytes,sizeof(bytes),0)>0) {} }
    void cancel() {
        halt=true; std::lock_guard guard(mutex);
        if (socket>=0) shutdown(socket,SHUT_RDWR);
        wake();
    }
};
static NSError *MLNetworkError(NSString *text, NSInteger code) {
    return [NSError errorWithDomain:@"Mumble.LibMumble" code:code userInfo:@{NSLocalizedDescriptionKey:text ?: @"Connection failed"}];
}
static bool MLWait(int fd, short events, MLNetworkState &state, int milliseconds) {
    const auto deadline=MLClock::now()+std::chrono::milliseconds(milliseconds);
    while (!state.halt && MLClock::now()<deadline) {
        pollfd target{fd,events,0}; int result=poll(&target,1,100);
        if (result>0) return !(target.revents & (POLLERR|POLLNVAL)) && (target.revents & events);
        if (result<0 && errno!=EINTR) return false;
    }
    return false;
}
static int MLConnect(NSString *hostname, NSUInteger port, MLNetworkState &state, sockaddr_storage &remote, socklen_t &length) {
    addrinfo hints{}; hints.ai_socktype=SOCK_STREAM; hints.ai_family=AF_UNSPEC;
    addrinfo *addresses=nullptr; std::string service=std::to_string(port);
    if (getaddrinfo(hostname.UTF8String,service.c_str(),&hints,&addresses)) return -1;
    int connected=-1;
    for (auto address=addresses; address && !state.halt; address=address->ai_next) {
        int fd=socket(address->ai_family,SOCK_STREAM,IPPROTO_TCP); if (fd<0) continue;
        int one=1; setsockopt(fd,SOL_SOCKET,SO_NOSIGPIPE,&one,sizeof(one));
        fcntl(fd,F_SETFL,fcntl(fd,F_GETFL,0)|O_NONBLOCK);
        { std::lock_guard guard(state.mutex); if (state.halt) { close(fd); break; } state.socket=fd; }
        int result=connect(fd,address->ai_addr,(socklen_t)address->ai_addrlen);
        bool ok=result==0 || (errno==EINPROGRESS && MLWait(fd,POLLOUT,state,8000));
        int error=0; socklen_t errorSize=sizeof(error);
        ok=ok && getsockopt(fd,SOL_SOCKET,SO_ERROR,&error,&errorSize)==0 && error==0;
        if (ok && !state.halt) { memcpy(&remote,address->ai_addr,address->ai_addrlen); length=(socklen_t)address->ai_addrlen; connected=fd; break; }
        { std::lock_guard guard(state.mutex); state.socket=-1; close(fd); }
    }
    freeaddrinfo(addresses); return connected;
}
static bool MLSetIdentity(Connection &connection, NSArray *identities) {
    if (!identities.count) return true;
    Cert::Chain chain; NSData *privateData=nil;
    for (id item in identities) {
        SecCertificateRef certificate=nullptr;
        if (CFGetTypeID((__bridge CFTypeRef)item)==SecIdentityGetTypeID()) {
            SecIdentityRef identity=(__bridge SecIdentityRef)item; SecKeyRef key=nullptr;
            SecIdentityCopyCertificate(identity,&certificate);
            if (SecIdentityCopyPrivateKey(identity,&key)==errSecSuccess) {
                privateData=CFBridgingRelease(SecKeyCopyExternalRepresentation(key,nullptr)); CFRelease(key);
            }
        } else if (CFGetTypeID((__bridge CFTypeRef)item)==SecCertificateGetTypeID()) {
            certificate=(SecCertificateRef)CFRetain((__bridge CFTypeRef)item);
        }
        if (certificate) { NSData *data=CFBridgingRelease(SecCertificateCopyData(certificate)); chain.emplace_back(MLBytes(data)); CFRelease(certificate); }
    }
    if (chain.empty() || !privateData.length) return false;
    auto bytes=static_cast<const unsigned char *>(privateData.bytes);
    EVP_PKEY *raw=d2i_AutoPrivateKey(nullptr,&bytes,(long)privateData.length);
    Key key(raw); return key && connection.setCert(chain,key);
}

@implementation MLConnection {
    std::shared_ptr<MLNetworkState> _state;
    dispatch_queue_t _worker;
    NSString *_hostname;
    NSUInteger _port;
    BOOL _connected, _peerCertificateChainTrusted;
    BOOL _automaticReconnectEnabled, _restoringSession, _hasJoinedSession;
    NSString *_authenticationUsername, *_authenticationPassword;
    NSArray *_authenticationTokens;
    NSNumber *_resumeChannel;
    BOOL _resumeMuted, _resumeDeafened, _desiredMuted, _desiredDeafened, _hasDesiredMuteState;
    NSUInteger _reconnectAttempt, _reconnectGeneration, _pathSignature;
    NSTimeInterval _reconnectStarted;
    BOOL _hasPathSignature, _networkUnavailable;
    NSTimer *_reconnectTimer;
    nw_path_monitor_t _pathMonitor;
    NSArray<MLCertificate *> *_peerCertificates;
    NSData *_acceptedCertificate, *_sessionCertificate;
    NSString *_serverVersion, *_serverRelease, *_serverOSName, *_serverOSVersion;
}
- (instancetype)init {
    if ((self=[super init])) { _worker=dispatch_queue_create("info.mumble.libmumble.transport",DISPATCH_QUEUE_SERIAL); lib::init(); }
    return self;
}
- (void)dealloc { [_reconnectTimer invalidate];if(_pathMonitor)nw_path_monitor_cancel(_pathMonitor);if (_state) _state->cancel(); lib::deinit(); }
- (NSString *)hostname { return _hostname; }
- (NSUInteger)port { return _port; }
- (BOOL)connected { return _connected; }
- (NSArray *)peerCertificates { return _peerCertificates; }
- (BOOL)peerCertificateChainTrusted { return _peerCertificateChainTrusted; }
- (NSString *)serverVersion { return _serverVersion; }
- (NSString *)serverRelease { return _serverRelease; }
- (NSString *)serverOSName { return _serverOSName; }
- (NSString *)serverOSVersion { return _serverOSVersion; }
- (std::shared_ptr<MLNetworkState>)networkState { @synchronized(self) { return _state; } }
- (void)deliver:(const std::shared_ptr<MLNetworkState> &)state block:(void (^)(void))block {
    // A block captures C++ reference parameters by reference. Own the state
    // until delivery, including after the network worker has returned.
    auto ownedState=state;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self networkState]==ownedState && !ownedState->halt) block();
    });
}
- (BOOL)automaticReconnectEnabled {return _automaticReconnectEnabled;}
- (BOOL)isRestoringSession {return _restoringSession;}
- (void)setAutomaticReconnectEnabled:(BOOL)enabled {
    NSAssert(NSThread.isMainThread,@"Reconnect state belongs to the main thread");
    _automaticReconnectEnabled=enabled;
    if(!enabled){
        ++_reconnectGeneration;[_reconnectTimer invalidate];_reconnectTimer=nil;
        if(_pathMonitor){nw_path_monitor_cancel(_pathMonitor);_pathMonitor=nil;}
        _hasPathSignature=NO;return;
    }
    [self startPathMonitoring];
}
- (void)startPathMonitoring {
    if(_pathMonitor)return;
    _pathMonitor=nw_path_monitor_create();__weak MLConnection *weakSelf=self;
    nw_path_monitor_set_queue(_pathMonitor,dispatch_get_main_queue());
    nw_path_monitor_set_update_handler(_pathMonitor,^(nw_path_t path){
        MLConnection *owner=weakSelf;if(!owner || !owner->_automaticReconnectEnabled)return;
        NSUInteger signature=nw_path_get_status(path)==nw_path_status_satisfied ? 1 : 0;
        owner->_networkUnavailable=signature==0;
        if(nw_path_uses_interface_type(path,nw_interface_type_wifi))signature|=2;
        if(nw_path_uses_interface_type(path,nw_interface_type_cellular))signature|=4;
        if(nw_path_uses_interface_type(path,nw_interface_type_wired))signature|=8;
        [owner networkPathDidChangeSignature:signature available:!owner->_networkUnavailable];
    });nw_path_monitor_start(_pathMonitor);
}
- (void)networkPathDidChangeSignature:(NSUInteger)signature available:(BOOL)available {
    if(!_automaticReconnectEnabled)return;
    BOOL changed=_hasPathSignature && signature!=_pathSignature;
    _pathSignature=signature;_hasPathSignature=YES;_networkUnavailable=!available;
    if(_hasJoinedSession && (changed || !available)){
        if(_restoringSession){if(available)[self scheduleReconnectAfter:.15];}
        else [self beginAutomaticReconnect];
    }
}
- (void)disconnectTransport {
    auto state=[self networkState];if(state)state->cancel();_connected=NO;
    [[MLAudio sharedAudio]setMainConnectionForAudio:nil];
}
- (void)disconnect {
    self.automaticReconnectEnabled=NO;_restoringSession=NO;_hasJoinedSession=NO;
    _authenticationUsername=nil;_authenticationPassword=nil;_authenticationTokens=nil;
    _hasDesiredMuteState=NO;_resumeChannel=nil;_sessionCertificate=nil;[self disconnectTransport];
}
- (void)beginAutomaticReconnect {
    if(!_automaticReconnectEnabled || !_hasJoinedSession || _restoringSession)return;
    MLUser *user=self.model.connectedUser;
    _resumeChannel=user.channel ? @(user.channel.channelId) : nil;
    _resumeMuted=_hasDesiredMuteState ? _desiredMuted : user.isSelfMuted;_resumeDeafened=_hasDesiredMuteState ? _desiredDeafened : user.isSelfDeafened;
    _restoringSession=YES;_reconnectAttempt=0;_reconnectStarted=NSProcessInfo.processInfo.systemUptime;
    [MLAudio.sharedAudio setForceTransmit:NO];[MLAudio.sharedAudio setLocalMuted:YES deafened:YES];
    [self disconnectTransport];[self scheduleReconnectAfter:.5];
}
- (void)scheduleReconnectAfter:(NSTimeInterval)delay {
    if(!_automaticReconnectEnabled || !_restoringSession)return;
    [_reconnectTimer invalidate];NSUInteger generation=++_reconnectGeneration;
    if([self.delegate respondsToSelector:@selector(connection:willReconnectAfterDelay:attempt:)])
        [self.delegate connection:self willReconnectAfterDelay:delay attempt:_reconnectAttempt+1];
    __weak MLConnection *weakSelf=self;
    _reconnectTimer=[NSTimer timerWithTimeInterval:delay repeats:NO block:^(NSTimer *timer){
        MLConnection *owner=weakSelf;if(!owner || generation!=owner->_reconnectGeneration || !owner->_automaticReconnectEnabled)return;
        owner->_reconnectTimer=nil;
        if(owner->_reconnectAttempt>=6 || NSProcessInfo.processInfo.systemUptime-owner->_reconnectStarted>180){
            [owner finishReconnectWithError:MLNetworkError(NSLocalizedString(@"The server could not be reached",nil),(NSInteger)Code::Reach)];return;
        }
        if(owner->_networkUnavailable){[owner scheduleReconnectAfter:15];return;}
        ++owner->_reconnectAttempt;[owner openTransportToHost:owner->_hostname port:owner->_port];
    }];_reconnectTimer.tolerance=MIN(.25,delay*.1);[NSRunLoop.mainRunLoop addTimer:_reconnectTimer forMode:NSRunLoopCommonModes];
}
- (void)finishReconnectWithError:(NSError *)error {
    self.automaticReconnectEnabled=NO;_restoringSession=NO;_hasJoinedSession=NO;
    _authenticationUsername=nil;_authenticationPassword=nil;_authenticationTokens=nil;
    [self disconnectTransport];
    if([self.delegate respondsToSelector:@selector(connection:closedWithError:)])[self.delegate connection:self closedWithError:error];
}
- (void)transportFailed:(NSError *)error opened:(BOOL)opened retryable:(BOOL)retryable {
    _connected=NO;
    if(retryable && _automaticReconnectEnabled && _hasJoinedSession){
        if(!_restoringSession)[self beginAutomaticReconnect];
        else [self scheduleReconnectAfter:MIN(15,pow(2.0,MIN(_reconnectAttempt,4ul)))];
        return;
    }
    if(_restoringSession){[self finishReconnectWithError:error];return;}
    if(opened){if([self.delegate respondsToSelector:@selector(connection:closedWithError:)])[self.delegate connection:self closedWithError:error];}
    else if([self.delegate respondsToSelector:@selector(connection:unableToConnectWithError:)])[self.delegate connection:self unableToConnectWithError:error];
}
- (void)rememberSelfMuted:(BOOL)muted deafened:(BOOL)deafened {
    _hasDesiredMuteState=YES;_desiredMuted=muted || deafened;_desiredDeafened=deafened;
    if(_restoringSession){_resumeMuted=_desiredMuted;_resumeDeafened=_desiredDeafened;}
}
- (void)restoreSessionForUser:(MLUser *)user {
    if(!_restoringSession){_hasJoinedSession=YES;_sessionCertificate=[_peerCertificates.firstObject.certificate copy];[self rememberSelfMuted:user.isSelfMuted deafened:user.isSelfDeafened];return;}
    user.selfMuted=_resumeMuted || _resumeDeafened;user.selfDeafened=_resumeDeafened;
    MumbleTCP::UserState state;state.set_session((uint32_t)user.session);state.set_self_mute(user.isSelfMuted);state.set_self_deaf(user.isSelfDeafened);
    if(_resumeChannel && [self.model channelWithId:_resumeChannel.unsignedIntegerValue])state.set_channel_id(_resumeChannel.unsignedIntValue);
    [self sendProto:state];
}
- (void)didRestoreSession {
    if(!_restoringSession)return;
    _restoringSession=NO;_reconnectAttempt=0;_hasJoinedSession=YES;
    [_reconnectTimer invalidate];_reconnectTimer=nil;++_reconnectGeneration;
    if([self.delegate respondsToSelector:@selector(connectionDidRestoreSession:)])[self.delegate connectionDidRestoreSession:self];
}
- (void)queueReceivedVoice:(NSData *)data session:(NSUInteger)session sequence:(uint64_t)sequence talkState:(MLTalkState)talk terminator:(BOOL)terminator state:(const std::shared_ptr<MLNetworkState> &)state {
    if (state->halt || [self networkState]!=state) return;
    [[MLAudio sharedAudio] receiveOpus:data session:session sequence:sequence terminator:terminator fromConnection:self];
    {
        std::lock_guard guard(state->mutex);
        if (state->pendingVoiceActivity.size()>=1024 && !state->pendingVoiceActivity.contains(session)) return;
        auto &activity=state->pendingVoiceActivity[session];
        activity.state=talk; activity.hasAudio=activity.hasAudio || data.length>0; activity.terminator=terminator;
        if (state->voiceActivityScheduled) return;
        state->voiceActivityScheduled=true;
    }
    auto ownedState=state;
    // Speaking indicators may wait for UIKit. Encoded voice never does. Keep
    // short speech/terminators when coalescing several packets from one user.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,50*NSEC_PER_MSEC),dispatch_get_main_queue(), ^{
        std::unordered_map<NSUInteger,MLVoiceActivity> activity;
        { std::lock_guard guard(ownedState->mutex);
          activity.swap(ownedState->pendingVoiceActivity); ownedState->voiceActivityScheduled=false; }
        if ([self networkState]!=ownedState || ownedState->halt) return;
        for (const auto &[session,frame]:activity) [self.model receivedVoiceForSession:session talkState:frame.state hasAudio:frame.hasAudio terminator:frame.terminator];
    });
}
- (void)connectToHost:(NSString *)hostname port:(NSUInteger)port {
    [self disconnect];
    [self openTransportToHost:hostname port:port];
}
- (void)openTransportToHost:(NSString *)hostname port:(NSUInteger)port {
    [self disconnectTransport];
    if (![_hostname isEqual:hostname] || _port!=port) _acceptedCertificate=nil;
    _hostname=[hostname copy]; _port=port; _peerCertificates=@[]; _peerCertificateChainTrusted=NO;
    [self.model reset];
    if (!hostname.length || !port || port>UINT16_MAX) {
        if ([self.delegate respondsToSelector:@selector(connection:unableToConnectWithError:)])
            [self.delegate connection:self unableToConnectWithError:MLNetworkError(NSLocalizedString(@"Invalid server address or port", nil),(NSInteger)Code::Invalid)];
        return;
    }
    auto state=std::make_shared<MLNetworkState>();state->expectedCertificate=_restoringSession ? [_sessionCertificate copy] : nil;
    @synchronized(self) { _state=state; }
    NSArray *identity=[self.certificateChain copy]; NSData *accepted=[_acceptedCertificate copy];
    dispatch_async(_worker, ^{ @autoreleasepool { [self run:state hostname:hostname identity:identity accepted:accepted]; } });
}
- (void)reconnect { [self connectToHost:_hostname port:_port]; }
- (void)setIgnoreSSLVerification:(BOOL)ignore {
    // Acceptance is bound to the certificate actually shown in the confirmation UI.
    _acceptedCertificate=ignore ? [[_peerCertificates.firstObject certificate] copy] : nil;
}
- (void)sendProto:(const google::protobuf::Message &)message {
    tcp::Pack packet(message); auto state=[self networkState]; if (!state || state->halt) return;
    std::lock_guard guard(state->mutex); state->outgoing.emplace_back(packet.buf().begin(),packet.buf().end());
    state->wake();
}
- (void)transportOpened {
    _connected=YES;
    if(_restoringSession)[self authenticateWithUsername:_authenticationUsername password:_authenticationPassword accessTokens:_authenticationTokens];
    else if([self.delegate respondsToSelector:@selector(connectionOpened:)])[self.delegate connectionOpened:self];
}
- (void)handleRejectedReason:(MLRejectReason)reason explanation:(NSString *)explanation {
    if(_restoringSession){[self finishReconnectWithError:MLNetworkError(explanation.length ? explanation : NSLocalizedString(@"Connection Rejected",nil),(NSInteger)reason)];return;}
    if([self.delegate respondsToSelector:@selector(connection:rejectedWithReason:explanation:)])[self.delegate connection:self rejectedWithReason:reason explanation:explanation];
}
- (void)handleUntrustedCertificates:(NSArray *)peer {
    if(_restoringSession){[self finishReconnectWithError:MLNetworkError(NSLocalizedString(@"Unable to validate server certificate",nil),(NSInteger)Code::Invalid)];return;}
    if([self.delegate respondsToSelector:@selector(connection:trustFailureInCertificateChain:)])[self.delegate connection:self trustFailureInCertificateChain:peer];
}
- (void)authenticateWithUsername:(NSString *)username password:(NSString *)password accessTokens:(NSArray *)tokens {
    _authenticationUsername=[username copy];_authenticationPassword=[password copy];_authenticationTokens=[tokens copy];
    MumbleTCP::Authenticate message; message.set_username(MLUTF8(username)); message.set_password(MLUTF8(password)); message.set_opus(true);
    for (NSString *token in tokens) message.add_tokens(MLUTF8(token)); [self sendProto:message];
}
- (void)updateAccessTokens:(NSArray *)tokens {
    _authenticationTokens=[tokens copy];MumbleTCP::Authenticate message;
    for(NSString *token in tokens)message.add_tokens(MLUTF8(token));[self sendProto:message];
}
- (void)sendOpus:(NSData *)data sequence:(uint64_t)sequence terminator:(BOOL)terminator {
    auto state=[self networkState]; if (!state || state->halt) return;
    auto bytes=MLBytes(data); std::lock_guard guard(state->mutex);
    // Drop stale voice instead of growing latency when a connection stalls.
    if (state->voice.size()>=50) state->voice.pop_front();
    state->voice.push_back({Buf(bytes.begin(),bytes.end()),sequence,(bool)terminator});
    state->wake();
}
- (void)run:(std::shared_ptr<MLNetworkState>)state hostname:(NSString *)hostname identity:(NSArray *)identity accepted:(NSData *)accepted {
    if(state->halt)return;
    sockaddr_storage remote{}; socklen_t remoteLength=0;
    int fd=MLConnect(hostname,self.port,*state,remote,remoteLength);
    if (fd<0) {
        [self deliver:state block:^{ [self transportFailed:MLNetworkError(NSLocalizedString(@"The server could not be reached",nil),(NSInteger)Code::Reach) opened:NO retryable:YES]; }]; return;
    }
    auto connection=std::make_unique<Connection>(fd,false);
    auto cleanup=[&]() { std::lock_guard guard(state->mutex); state->socket=-1; connection.reset(); };
    if (!*connection || !MLSetIdentity(*connection,identity) || !connection->setServerName(MLUTF8(hostname))) {
        cleanup(); [self deliver:state block:^{ [self transportFailed:MLNetworkError(NSLocalizedString(@"Unable to load the client identity or initialize TLS",nil),(NSInteger)Code::Init) opened:NO retryable:NO]; }]; return;
    }
    bool modernVoice=false, synchronized=false, rejected=false;
    uint32_t ownSession=UINT32_MAX;
    MLVoiceCrypt crypt;
    int udp=-1;
    MLClock::time_point lastUDP{}, lastPacket=MLClock::now(), lastPing=MLClock::now(), lastResync{}, lastVoice{};
    Code failure=Code::Success;
    auto write=[&](const google::protobuf::Message &message) { return connection->write(tcp::Pack(message).buf(),true,[&](){ return state->halt.load(); }); };
    auto receiveVoice=[&](Buf packet) {
        if (packet.empty()) return;
        if (modernVoice) {
            udp::NetHeader header; header.type=std::to_integer<uint8_t>(packet[0]); udp::Pack wire(header,(uint32_t)packet.size()-1);
            std::copy(packet.begin()+1,packet.end(),wire.data().begin());
            if (udp::Message::type(wire)==udp::Message::Type::Ping) { lastUDP=MLClock::now(); return; }
            udp::Message::Audio audio;
            if (!wire(audio) || audio.direction!=udp::Message::Audio::ServerToClient || !audio.senderSession || audio.opusData.size()>8192) return;
            NSData *opus=MLData(audio.opusData); auto session=*audio.senderSession; auto sequence=audio.frameNumber; BOOL end=audio.isTerminator;
            if (opus.length) lastVoice=MLClock::now();
            MLTalkState talk=audio.context==1?MLTalkStateShouting:audio.context==2?MLTalkStateWhispering:MLTalkStateTalking;
            [self queueReceivedVoice:opus session:session sequence:sequence talkState:talk terminator:end state:state];
        } else {
            uint8_t type=std::to_integer<uint8_t>(packet[0])>>5;
            if (type==1) { lastUDP=MLClock::now(); return; } // Legacy encrypted ping.
            if (type!=4 || packet.size()<2) return;
            PacketDataStream stream(BufView(packet).subspan(1)); uint64_t session=0, sequence=0, size=0;
            stream >> session >> sequence >> size;
            bool end=size & (1<<13); size &= 0x1fff;
            if (!stream || size>stream.seek().size() || session>UINT32_MAX) return;
            NSData *opus=MLData(stream.seek().first((size_t)size));
            if (opus.length) lastVoice=MLClock::now();
            uint8_t context=std::to_integer<uint8_t>(packet[0]) & 31;
            MLTalkState talk=context==1?MLTalkStateShouting:context==2?MLTalkStateWhispering:MLTalkStateTalking;
            [self queueReceivedVoice:opus session:(NSUInteger)session sequence:sequence talkState:talk terminator:end state:state];
        }
    };
    Connection::Feedback feedback;
    feedback.timeout=[](){ return 1000; }; feedback.timeouts=[](){ return 10; };
    feedback.opened=[](){}; feedback.closed=[&](){ failure=Code::Disconnect; };
    feedback.failed=[&](Code code){ failure=code; };
    feedback.pack=[&](tcp::Pack &packet) {
        lastPacket=MLClock::now(); uint16_t type=Endian::toHost(packet.header().type); NSData *data=MLData(packet.data());
        switch (static_cast<tcp::Message::Type>(type)) {
            case tcp::Message::Type::Version: {
                MumbleTCP::Version version; if (!version.ParseFromArray(data.bytes,(int)data.length)) break;
                Version number=version.has_version_v2() ? Version(version.version_v2()) : Version(version.version_v1());
                modernVoice=number.major>1 || (number.major==1 && number.minor>=5);
                NSString *text=[NSString stringWithFormat:@"%u.%u.%u",number.major,number.minor,number.patch];
                NSString *release=MLString(version.release()), *os=MLString(version.os()), *osVersion=MLString(version.os_version());
                [self deliver:state block:^{ self->_serverVersion=text; self->_serverRelease=release; self->_serverOSName=os; self->_serverOSVersion=osVersion; }]; break;
            }
            case tcp::Message::Type::Reject: {
                MumbleTCP::Reject message; if (!message.ParseFromArray(data.bytes,(int)data.length)) break;
                rejected=true; MLRejectReason reason=(MLRejectReason)message.type(); NSString *explanation=MLString(message.reason());
                [self deliver:state block:^{[self handleRejectedReason:reason explanation:explanation];}]; break;
            }
            case tcp::Message::Type::CryptSetup: {
                MumbleTCP::CryptSetup message; if (!message.ParseFromArray(data.bytes,(int)data.length)) break;
                auto view=[](const std::string &value)->BufViewConst { return {reinterpret_cast<const std::byte *>(value.data()),value.size()}; };
                if (message.key().size()==16 && message.client_nonce().size()==16 && message.server_nonce().size()==16) crypt.setup(view(message.key()),view(message.client_nonce()),view(message.server_nonce()));
                else if (message.server_nonce().size()==16) { crypt.resync(view(message.server_nonce())); lastUDP={}; }
                else if (!message.has_key() && !message.has_server_nonce() && crypt.valid) {
                    MumbleTCP::CryptSetup reply; reply.set_client_nonce(crypt.sendNonce.data(),crypt.sendNonce.size()); write(reply);
                }
                break;
            }
            case tcp::Message::Type::UDPTunnel: { receiveVoice(Buf(packet.data().begin(),packet.data().end())); break; }
            case tcp::Message::Type::UserRemove: {
                MumbleTCP::UserRemove message;
                if(message.ParseFromArray(data.bytes,(int)data.length) && message.session()==ownSession){
                    rejected=true;[self deliver:state block:^{
                        self.automaticReconnectEnabled=NO;self->_restoringSession=NO;self->_hasJoinedSession=NO;
                        [self.model receiveType:type data:data];
                        if(!state->halt)[self finishReconnectWithError:MLNetworkError(MLString(message.reason()).length ? MLString(message.reason()) : NSLocalizedString(@"Connection closed",nil),(NSInteger)Code::Disconnect)];
                    }];
                }else [self deliver:state block:^{[self.model receiveType:type data:data];}];
                break;
            }
            case tcp::Message::Type::CodecVersion: {
                MumbleTCP::CodecVersion message;
                if (message.ParseFromArray(data.bytes,(int)data.length) && !message.opus()) failure=Code::Unsupport;
                break;
            }
            case tcp::Message::Type::ServerSync: {
                MumbleTCP::ServerSync message;
                if (message.ParseFromArray(data.bytes,(int)data.length)) {
                    synchronized=true;ownSession=message.session();uint32_t bandwidth=message.max_bandwidth();
                    [self deliver:state block:^{ [[MLAudio sharedAudio] setBandwidthLimit:bandwidth]; }];
                }
                [[fallthrough]];
            }
            default: [self deliver:state block:^{ [self.model receiveType:type data:data]; }]; break;
        }
    };
    Code handshake=(*connection)(feedback,[&](){ return state->halt.load(); });
    if (handshake!=Code::Success) {
        // SSL teardown may clear the thread-local error queue. Record the
        // reason first, without logging the endpoint, identity or credentials.
        if (!state->halt && handshake!=Code::Cancel) {
            unsigned long tlsCode=ERR_peek_last_error();
            char reason[256]{};
            if(tlsCode)ERR_error_string_n(tlsCode,reason,sizeof(reason));
            NSLog(@"TLS handshake failed: transport=%d, OpenSSL=%s",(int)handshake,tlsCode ? reason : "no queued TLS error");
        }
        cleanup(); [self deliver:state block:^{ [self transportFailed:MLNetworkError(NSLocalizedString(@"TLS negotiation failed",nil),(NSInteger)handshake) opened:NO retryable:YES]; }]; return;
    }
    NSMutableArray *peer=[NSMutableArray array], *systemCertificates=[NSMutableArray array];
    for (auto &certificate:connection->peerCert()) {
        NSData *der=MLData(certificate.der()); MLCertificate *item=[MLCertificate certificateWithCertificate:der privateKey:nil];
        SecCertificateRef native=SecCertificateCreateWithData(nullptr,(__bridge CFDataRef)der);
        if (item) [peer addObject:item]; if (native) [systemCertificates addObject:CFBridgingRelease(native)];
    }
    SecPolicyRef policy=SecPolicyCreateSSL(true,(__bridge CFStringRef)hostname); SecTrustRef trust=nullptr;
    BOOL trusted=systemCertificates.count && SecTrustCreateWithCertificates((__bridge CFArrayRef)systemCertificates,policy,&trust)==errSecSuccess && SecTrustEvaluateWithError(trust,nullptr);
    if (trust) CFRelease(trust); CFRelease(policy);
    BOOL acceptedLeaf=accepted.length && [accepted isEqualToData:[peer.firstObject certificate]];
    [self deliver:state block:^{ self->_peerCertificates=[peer copy]; self->_peerCertificateChainTrusted=trusted; }];
    if(state->expectedCertificate.length && ![state->expectedCertificate isEqualToData:[(MLCertificate *)peer.firstObject certificate]]){
        cleanup();[self deliver:state block:^{[self finishReconnectWithError:MLNetworkError(NSLocalizedString(@"The server certificate changed. Reconnect manually to review it.",nil),(NSInteger)Code::Invalid)];}];return;
    }
    if (!trusted && !acceptedLeaf) {
        cleanup(); [self deliver:state block:^{[self handleUntrustedCertificates:peer];}]; return;
    }
    MumbleTCP::Version version; version.set_version_v1(lib::version().blob32()); version.set_version_v2(lib::version().blob64());
    version.set_release(MLUTF8(MLVersion.sharedVersion.releaseString)); version.set_os("iOS");
    failure=write(version);
    [self deliver:state block:^{[self transportOpened];}];
    udp=socket(remote.ss_family,SOCK_DGRAM,IPPROTO_UDP);
    if (udp>=0) { fcntl(udp,F_SETFL,fcntl(udp,F_GETFL,0)|O_NONBLOCK); if (connect(udp,(sockaddr *)&remote,remoteLength)) { close(udp); udp=-1; } }
    auto sendVoice=[&](BufViewConst plain) {
        bool available=udp>=0 && crypt.valid && !self.forceTCP && MLClock::now()-lastUDP<std::chrono::seconds(10);
        if (available) { auto packet=crypt.encrypt(plain); if (!packet.empty() && send(udp,packet.data(),packet.size(),0)==(ssize_t)packet.size()) return; }
        tcp::NetHeader header{Endian::toNetwork((uint16_t)tcp::Message::Type::UDPTunnel),Endian::toNetwork((uint32_t)plain.size())};
        tcp::Pack packet(header); std::copy(plain.begin(),plain.end(),packet.data().begin());
        auto code=connection->write(packet.buf(),true,[&](){ return state->halt.load(); }); if (code!=Code::Success) failure=code;
    };
    std::deque<Buf> outgoing; std::deque<MLVoiceFrame> frames;
    while (!state->halt && !rejected && failure==Code::Success) {
        @autoreleasepool {
            { std::lock_guard guard(state->mutex); outgoing.swap(state->outgoing); frames.swap(state->voice); }
            for (auto &packet:outgoing) { failure=connection->write(packet,true,[&](){ return state->halt.load(); }); if (failure!=Code::Success) break; }
            if (synchronized) for (auto &frame:frames) {
                if (!frame.data.empty()) lastVoice=MLClock::now();
                if (modernVoice) {
                    udp::Message::Audio audio; audio.direction=udp::Message::Audio::ClientToServer; audio.target=0; audio.frameNumber=frame.sequence; audio.opusData=std::move(frame.data); audio.isTerminator=frame.terminator;
                    udp::Pack packet(audio); sendVoice(packet.buf());
                } else {
                    Buf packet(frame.data.size()+32); packet[0]=std::byte{4<<5}; PacketDataStream stream(BufView(packet).subspan(1));
                    stream << frame.sequence << (uint64_t)(frame.data.size() | (frame.terminator?(1<<13):0));
                    auto used=stream.data().size(); std::copy(frame.data.begin(),frame.data.end(),packet.begin()+1+(long)used);
                    packet.resize(1+used+frame.data.size()); sendVoice(packet);
                }
            }
            outgoing.clear(); frames.clear();
            auto now=MLClock::now();
            auto pingInterval=MLKeepaliveInterval(synchronized,now,lastVoice);
            if (now-lastPing>=pingInterval) {
                MumbleTCP::Ping ping; ping.set_timestamp((uint64_t)std::chrono::duration_cast<std::chrono::microseconds>(now.time_since_epoch()).count());
                ping.set_good(crypt.good); ping.set_late(crypt.latePackets); ping.set_lost(crypt.lost); failure=write(ping);
                if (udp>=0 && crypt.valid && !self.forceTCP) {
                    Buf plain;
                    if (modernVoice) { udp::Message::Ping udpPing; udp::Pack packet(udpPing); plain.assign(packet.buf().begin(),packet.buf().end()); }
                    else { plain.resize(16); plain[0]=std::byte{1<<5}; PacketDataStream stream(BufView(plain).subspan(1)); stream << ping.timestamp(); plain.resize(1+stream.data().size()); }
                    auto packet=crypt.encrypt(plain); if (!packet.empty()) send(udp,packet.data(),packet.size(),0);
                }
                lastPing=now;
            }
            if (now-lastPacket>std::chrono::seconds(30)) { failure=Code::Timeout; break; }
            // Sleep until socket activity, an outgoing packet, cancellation, or the next keepalive.
            auto nextWake=std::min(lastPing+pingInterval,lastPacket+std::chrono::seconds(30));
            int timeout=(int)std::max<int64_t>(1,std::chrono::duration_cast<std::chrono::milliseconds>(nextWake-MLClock::now()).count());
            if (state->wakeReader<0) timeout=std::min(timeout,20);
            pollfd sockets[3]={{fd,POLLIN,0},{udp,POLLIN,0},{state->wakeReader,POLLIN,0}};
            int ready=poll(sockets,3,timeout);
            if (ready<0 && errno!=EINTR) { failure=Code::Failure; break; }
            if (sockets[2].revents&POLLIN) state->drainWake();
            // TLS control records can make the socket readable without an
            // application packet. Never block the worker here: authentication
            // and other queued writes must still be serviced through wakeReader.
            if (sockets[0].revents&POLLIN) { auto code=connection->process(false,[&](){ return state->halt.load(); }); if (code!=Code::Success && code!=Code::Busy) failure=code; }
            else if (sockets[0].revents&(POLLHUP|POLLERR|POLLNVAL)) { failure=Code::Disconnect; break; }
            if (udp>=0 && sockets[1].revents&POLLIN) {
                std::array<std::byte,65536> bytes;
                ssize_t size=recv(udp,bytes.data(),bytes.size(),0);
                if (size>4) {
                    auto plain=crypt.decrypt({bytes.data(),(size_t)size});
                    auto receivedAt=MLClock::now();
                    if (!plain.empty()) { lastUDP=receivedAt; receiveVoice(std::move(plain)); }
                    else if (crypt.valid && receivedAt-lastResync>std::chrono::seconds(5)) { MumbleTCP::CryptSetup request; write(request); lastResync=receivedAt; }
                }
            }
        }
    }
    if (udp>=0) close(udp); cleanup();
    if (!rejected) [self deliver:state block:^{
        self->_connected=NO; [[MLAudio sharedAudio] setMainConnectionForAudio:nil];
        NSString *description=failure==Code::Unsupport ? NSLocalizedString(@"The server does not support Opus audio.", nil) : NSLocalizedString(@"The connection was interrupted", nil);
        NSError *error=MLNetworkError(description,(NSInteger)failure);
        [self transportFailed:error opened:YES retryable:failure!=Code::Unsupport];
    }];
}
@end
