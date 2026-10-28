// Deterministic backend integration tests. No external server or microphone is used.
#import "MLInternal.hpp"
#include "MLVoiceCrypt.hpp"
#include "MLTransportTiming.hpp"
#include <mumble/Cert.hpp>
#include <mumble/Opus.hpp>
#include <mumble/PacketDataStream.hpp>
#include <openssl/ssl.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>
#include <thread>
#include <atomic>
#include <cassert>
#include <cerrno>
#include <cmath>
#include <cstdio>
#include <poll.h>

using namespace mumble;
static std::atomic<int> receivedVoice{0}, receivedTalkStop{0};
static bool completed=false;
// Substitute the hardware audio layer while testing its actual wire/Opus boundary.
@implementation MLAudio
+ (instancetype)sharedAudio { static MLAudio *audio=[self new]; return audio; }
- (BOOL)isRunning { return NO; }
- (void)start {}
- (void)resumeIfNeeded {}
- (void)stop {}
- (void)restart {}
- (void)readAudioSettings:(MLAudioSettings *)settings { *settings={}; }
- (void)updateAudioSettings:(MLAudioSettings *)settings {}
- (BOOL)echoCancellationAvailable { return NO; }
- (float)speechProbablity { return 0; }
- (float)peakCleanMic { return 0; }
- (void)beginMetering {}
- (void)endMetering {}
- (NSDictionary *)copyAudioOutputMixerDebugInfo { return @{}; }
- (void)setMainConnectionForAudio:(MLConnection *)connection {}
- (void)setUserLocalMuted:(BOOL)muted session:(NSUInteger)session connection:(MLConnection *)connection {}
- (void)setLocalMuted:(BOOL)muted deafened:(BOOL)deafened {}
- (void)setBandwidthLimit:(uint32_t)bandwidth {}
- (void)receiveOpus:(NSData *)data session:(NSUInteger)session sequence:(uint64_t)sequence terminator:(BOOL)terminator {
    assert(session==2);
    if (data.length) {
        Opus::Decoder decoder(1); assert(decoder.init()==Code::Success);
        float samples[5760]; auto result=decoder(samples,MLBytes(data)); assert(result.size()==960);
    } else assert(terminator);
    ++receivedVoice;
}
- (void)receiveOpus:(NSData *)data session:(NSUInteger)session sequence:(uint64_t)sequence terminator:(BOOL)terminator fromConnection:(MLConnection *)connection {
    assert(connection);
    [self receiveOpus:data session:session sequence:sequence terminator:terminator];
}
@end

static bool readExact(SSL *ssl, void *buffer, size_t size) {
    auto bytes=static_cast<uint8_t *>(buffer);
    while (size) { int count=SSL_read(ssl,bytes,(int)size); if (count<=0) return false; bytes+=count; size-=(size_t)count; }
    return true;
}
static std::pair<uint16_t,Buf> readPacket(SSL *ssl, const char *stage) {
    tcp::NetHeader header;
    bool received=readExact(ssl,&header,sizeof(header));
    if (!received) fprintf(stderr,"TLS packet header missing during %s (errno %d)\n",stage,errno);
    assert(received);
    Buf data(Endian::toHost(header.size)); assert(data.size()<8*1024*1024);
    assert(readExact(ssl,data.data(),data.size())); return {Endian::toHost(header.type),std::move(data)};
}
static void sendPacket(SSL *ssl, BufViewConst bytes, bool fragmented=false) {
    if (fragmented) { assert(SSL_write(ssl,bytes.data(),2)==2); std::this_thread::sleep_for(std::chrono::milliseconds(50)); bytes=bytes.subspan(2); }
    while (!bytes.empty()) { int written=SSL_write(ssl,bytes.data(),(int)bytes.size()); assert(written>0); bytes=bytes.subspan((size_t)written); }
}
static void sendProto(SSL *ssl, const google::protobuf::Message &message, bool fragmented=false) { sendPacket(ssl,tcp::Pack(message).buf(),fragmented); }

@interface MLTestDelegate : NSObject <MLConnectionDelegate,MLServerModelDelegate,MLServerPingerDelegate>
@property(nonatomic) int trustFailures, opened, joined, texts, moved, pings;
@property(nonatomic,strong) MLServerModel *model;
@property(nonatomic,weak) MLConnection *connection;
@property(nonatomic,strong) NSData *fixtureOpus;
@property(nonatomic,strong) NSDate *speechStarted;
@property(nonatomic) BOOL delayAuthentication;
@end
@implementation MLTestDelegate
- (void)connection:(MLConnection *)connection trustFailureInCertificateChain:(NSArray *)chain {
    assert(chain.count && !connection.peerCertificateChainTrusted && !connection.connected);
    ++_trustFailures;
    if (_trustFailures==1) { [connection setIgnoreSSLVerification:YES]; [connection reconnect]; }
    else { assert(_trustFailures==2); completed=true; [connection disconnect]; }
}
- (void)connectionOpened:(MLConnection *)connection {
    ++_opened;
    void (^authenticate)(void)=^{ [connection authenticateWithUsername:@"Test User" password:@"fixture password" accessTokens:@[@"fixture token"]]; };
    // Let TLS 1.3 session tickets reach the worker before credentials are
    // queued. A readable TLS socket must not block pending outgoing work
    // while the server is waiting for authentication.
    if (_delayAuthentication) dispatch_after(dispatch_time(DISPATCH_TIME_NOW,250*NSEC_PER_MSEC),dispatch_get_main_queue(),authenticate);
    else authenticate();
}
- (void)connection:(MLConnection *)connection unableToConnectWithError:(NSError *)error { NSLog(@"Unexpected failure: %@",error); assert(false); }
- (void)connection:(MLConnection *)connection closedWithError:(NSError *)error { NSLog(@"Unexpected close: %@",error); assert(false); }
- (void)serverModel:(MLServerModel *)model joinedServerAsUser:(MLUser *)user {
    ++_joined; assert(user.session==1 && user.isSelfMuted);
    [model joinChannel:[model channelWithId:7]];
    [model sendTextMessage:[MLTextMessage messageWithPlainText:@"hello & world"] toChannel:[model channelWithId:7]];
    [self.connection sendOpus:self.fixtureOpus sequence:4 terminator:NO];
}
- (void)serverModel:(MLServerModel *)model userMoved:(MLUser *)user toChannel:(MLChannel *)channel fromChannel:(MLChannel *)previous byUser:(MLUser *)actor {
    if (model.connectedUser==user && previous && channel.channelId==7) { ++_moved; assert(user.isSelfMuted && [user.userName isEqual:@"Test User"]); }
}
- (void)serverModel:(MLServerModel *)model textMessageReceived:(MLTextMessage *)message fromUser:(MLUser *)user {
    ++_texts; assert(message.plainTextString.length==70000 && user.session==2);
}
- (void)serverModel:(MLServerModel *)model userTalkStateChanged:(MLUser *)user {
    assert(NSThread.isMainThread && user.session==2);
    if (user.talkState==MLTalkStateTalking) self.speechStarted=NSDate.date;
    else { assert(user.talkState==MLTalkStatePassive && -self.speechStarted.timeIntervalSinceNow>=.3); ++receivedTalkStop; }
}
- (void)serverPingerResult:(MLServerPingerResult *)result { ++_pings; assert(result->cur_users==3 && result->max_users==10 && result->ping>=0 && result->ping<5); }
@end

static void cryptoTests() {
    Buf key(16,std::byte{0x39}), first(16), second(16,std::byte{0x2});
    MLVoiceCrypt sender,receiver; assert(sender.setup(key,first,second)); assert(receiver.setup(key,second,first));
    Buf original(64,std::byte{0x45}); std::vector<Buf> packets;
    for (int i=0;i<300;++i) packets.push_back(sender.encrypt(original));
    for (int i=0;i<250;++i) assert(receiver.decrypt(packets[i])==original);
    assert(receiver.decrypt(packets[251])==original); assert(receiver.decrypt(packets[250])==original);
    assert(receiver.decrypt(packets[250]).empty());
    auto corrupt=packets[252]; corrupt[1]^=std::byte{1}; assert(receiver.decrypt(corrupt).empty());
    assert(receiver.decrypt(packets[252])==original);
    for (int i=253;i<300;++i) assert(receiver.decrypt(packets[i])==original);
    assert(!sender.setup(Buf(15),first,second));
    CryptOCB2 cipher; cipher.setKey(key); cipher.setNonce(first); Buf small(1),tag(17);
    assert(!cipher.encrypt(small,original,{})); assert(!cipher.decrypt(small,original,{})); assert(!cipher.decrypt(original,original,tag));
    printf("PASS: OCB nonce rollover, loss/reordering, replay, tamper and buffer bounds\n");
}
static void certificateTests() {
    MLCertificate *identity=[MLCertificate selfSignedCertificateWithName:@"Test User" email:@"test@example.com"];
    assert(identity.hasCertificate && identity.hasPrivateKey && [identity isSignedBy:identity] && [identity isValidOnDate:NSDate.date]);
    assert(std::abs(identity.notBefore.timeIntervalSinceNow+60)<3);
    assert([identity.commonName isEqual:@"Test User"] && [identity.emailAddress isEqual:@"test@example.com"]);
    NSData *exported=[identity exportPKCS12WithPassword:@"fixture"];
    MLCertificate *imported=[MLCertificate certificateWithPKCS12:exported password:@"fixture"];
    assert(imported.hasPrivateKey && [identity.certificate isEqual:imported.certificate]);
    assert(![MLCertificate certificateWithPKCS12:exported password:@"wrong"]);
    assert(identity.hexDigest.length==40 && [identity hexDigestOfKind:@"sha256"].length==64);
    auto keyData=MLBytes(identity.privateKey); auto bytes=reinterpret_cast<const unsigned char *>(keyData.data());
    EVP_PKEY *key=d2i_AutoPrivateKey(nullptr,&bytes,(long)keyData.size());
    assert(EVP_PKEY_get_bits(key)==2048); EVP_PKEY_free(key);
    Cert certificate(MLBytes(identity.certificate)); assert(X509_get_signature_nid(static_cast<X509 *>(certificate.handle()))==NID_sha256WithRSAEncryption);
    printf("PASS: RSA-2048/SHA-256 identity, PKCS12 roundtrip and incorrect password\n");
}
static SSL_CTX *serverContext(MLCertificate *identity) {
    SSL_CTX *context=SSL_CTX_new(TLS_server_method()); assert(context);
    Cert certificate(MLBytes(identity.certificate)); auto bytes=static_cast<const unsigned char *>(identity.privateKey.bytes);
    EVP_PKEY *key=d2i_AutoPrivateKey(nullptr,&bytes,(long)identity.privateKey.length);
    assert(SSL_CTX_use_certificate(context,static_cast<X509 *>(certificate.handle()))==1 && SSL_CTX_use_PrivateKey(context,key)==1);
    EVP_PKEY_free(key); return context;
}
static NSArray *nativeIdentity(bool legacy) {
    MLCertificate *certificate=[MLCertificate selfSignedCertificateWithName:@"Test User" email:nil];
    if (legacy) {
        Cert parsed(MLBytes(certificate.certificate));
        auto bytes=static_cast<const unsigned char *>(certificate.privateKey.bytes);
        EVP_PKEY *key=d2i_AutoPrivateKey(nullptr,&bytes,(long)certificate.privateKey.length);
        assert(X509_sign(static_cast<X509 *>(parsed.handle()),key,EVP_sha1())>0);
        certificate=[MLCertificate certificateWithCertificate:MLData(parsed.der()) privateKey:certificate.privateKey];
        EVP_PKEY_free(key);
    }
    NSString *password=NSUUID.UUID.UUIDString;
    NSData *bundle=[certificate exportPKCS12WithPassword:password];
    NSDictionary *options=@{(__bridge NSString *)kSecImportExportPassphrase:password, (__bridge NSString *)kSecImportToMemoryOnly:@YES};
    CFArrayRef imported=nullptr;
    OSStatus result=SecPKCS12Import((__bridge CFDataRef)bundle,(__bridge CFDictionaryRef)options,&imported);
    if (result!=errSecSuccess) NSLog(@"Native identity import failed: %d",(int)result);
    assert(result==errSecSuccess && imported);
    NSArray *items=CFBridgingRelease(imported);
    id identity=items.firstObject[(__bridge NSString *)kSecImportItemIdentity]; assert(identity);
    return @[identity];
}
static int runTransport(bool modern) { @autoreleasepool {
    completed=false; receivedVoice=0; receivedTalkStop=0;
    cryptoTests(); certificateTests();
    MLTextMessage *text=[MLTextMessage messageWithPlainText:@"a < b & c\nd"];
    assert([text.HTMLString isEqual:@"a &lt; b &amp; c<br/>d"]);
    auto converted=[MLTextMessage messageWithHTML:@"<p>Hello<br/>world<img src='data:image/png;base64,YQ=='/><a href='https://example.com'>link</a></p>"];
    assert(converted.embeddedImages.count==1 && converted.embeddedLinks.count==1);
    int listener=socket(AF_INET,SOCK_STREAM,0); assert(listener>=0);
    sockaddr_in address{}; address.sin_family=AF_INET; address.sin_addr.s_addr=htonl(INADDR_LOOPBACK);
    assert(!bind(listener,(sockaddr *)&address,sizeof(address)) && !listen(listener,3));
    socklen_t length=sizeof(address); getsockname(listener,(sockaddr *)&address,&length); uint16_t port=ntohs(address.sin_port);
    int probe=socket(AF_INET,SOCK_DGRAM,0); assert(!bind(probe,(sockaddr *)&address,sizeof(address)));
    timeval timeout{5,0}; setsockopt(probe,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof(timeout));
    MLTestDelegate *delegate=[MLTestDelegate new];
    delegate.delayAuthentication=modern;
    MLConnection *connection=[MLConnection new]; connection.delegate=delegate; connection.forceTCP=modern;
    connection.certificateChain=nativeIdentity(!modern);
    MLServerModel *model=[[MLServerModel alloc] initWithConnection:connection]; [model addDelegate:delegate];
    delegate.model=model;
    delegate.connection=connection;
    Opus::Encoder fixtureEncoder(1); assert(fixtureEncoder.init()==Code::Success);
    float fixtureSamples[960]; for (int i=0;i<960;++i) fixtureSamples[i]=.1f*sinf(i*.1f);
    Buf fixtureBuffer(4096); delegate.fixtureOpus=MLData(fixtureEncoder(fixtureBuffer,Opus::FloatViewConst(fixtureSamples,960)));
    MLServerPinger *pinger=[[MLServerPinger alloc] initWithHostname:@"127.0.0.1" port:[NSString stringWithFormat:@"%u",port]]; pinger.delegate=delegate;
    MLCertificate *first=[MLCertificate selfSignedCertificateWithName:@"Fixture A" email:nil];
    MLCertificate *rotated=[MLCertificate selfSignedCertificateWithName:@"Fixture B" email:nil];
    std::thread pingServer([=](){
        legacy::udp::Ping packet{}; sockaddr_storage sender{}; socklen_t size=sizeof(sender);
        assert(recvfrom(probe,&packet,sizeof(packet),0,(sockaddr *)&sender,&size)==12);
        packet.versionBlob=Endian::toNetwork((uint32_t)0x10500); packet.sessions=Endian::toNetwork((uint32_t)3); packet.maxSessions=Endian::toNetwork((uint32_t)10); packet.maxBandwidth=Endian::toNetwork((uint32_t)72000);
        assert(sendto(probe,&packet,sizeof(packet),0,(sockaddr *)&sender,size)==sizeof(packet)); close(probe);
    });
    std::thread server([=](){ @autoreleasepool {
        for (int attempt=0;attempt<3;++attempt) {
            int fd=accept(listener,nullptr,nullptr); assert(fd>=0); int one=1; setsockopt(fd,SOL_SOCKET,SO_NOSIGPIPE,&one,sizeof(one));
            setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof(timeout));
            SSL_CTX *context=serverContext(attempt==2?rotated:first);
            if (modern) {
                SSL_CTX_set_min_proto_version(context,TLS1_3_VERSION);
                SSL_CTX_set_num_tickets(context,2);
            }
            SSL_CTX_set_verify(context,SSL_VERIFY_PEER|SSL_VERIFY_FAIL_IF_NO_PEER_CERT,[](int,X509_STORE_CTX *) { return 1; });
            SSL *ssl=SSL_new(context); SSL_set_fd(ssl,fd); assert(SSL_accept(ssl)==1);
            Cert client(SSL_get1_peer_certificate(ssl)); assert(client && client.subjectAttributes().at("CN")=="Test User");
            assert(std::string(SSL_get_servername(ssl,TLSEXT_NAMETYPE_host_name))=="127.0.0.1");
            if (attempt!=1) { uint8_t byte; assert(SSL_read(ssl,&byte,1)<=0); }
            else {
                auto version=readPacket(ssl,"version"); assert(version.first==0);
                auto auth=readPacket(ssl,"authentication"); assert(auth.first==2); MumbleTCP::Authenticate parsed;
                assert(parsed.ParseFromArray(auth.second.data(),(int)auth.second.size()) && parsed.username()=="Test User" && parsed.opus() && parsed.tokens_size()==1);
                MumbleTCP::Version ver; ver.set_version_v2(Version(1,modern?5:4,0).blob64()); sendProto(ssl,ver);
                MumbleTCP::ChannelState channel; channel.set_channel_id(0); channel.set_name("Root"); sendProto(ssl,channel);
                channel.set_channel_id(7); channel.set_parent(0); channel.set_name("Room"); sendProto(ssl,channel);
                MumbleTCP::UserState user; user.set_session(1); user.set_name("Test User"); user.set_channel_id(0); user.set_self_mute(true); sendProto(ssl,user);
                user.Clear(); user.set_session(2); user.set_name("Peer"); user.set_channel_id(7); sendProto(ssl,user);
                MumbleTCP::ServerSync sync; sync.set_session(1); sync.set_welcome_text("Welcome"); sendProto(ssl,sync);
                auto join=readPacket(ssl,"channel join"); assert(join.first==9); MumbleTCP::UserState move; assert(move.ParseFromArray(join.second.data(),(int)join.second.size()) && move.channel_id()==7);
                move.Clear(); move.set_session(1); move.set_channel_id(7); sendProto(ssl,move,true);
                auto outgoingText=readPacket(ssl,"text message"); assert(outgoingText.first==11); MumbleTCP::TextMessage sent; assert(sent.ParseFromArray(outgoingText.second.data(),(int)outgoingText.second.size()) && sent.message()=="hello &amp; world" && sent.channel_id(0)==7);
                auto outgoingVoice=readPacket(ssl,"outgoing voice"); assert(outgoingVoice.first==1 && !outgoingVoice.second.empty());
                if (modern) {
                    udp::NetHeader header; header.type=std::to_integer<uint8_t>(outgoingVoice.second[0]);
                    udp::Pack packet(header,(uint32_t)outgoingVoice.second.size()-1); std::copy(outgoingVoice.second.begin()+1,outgoingVoice.second.end(),packet.data().begin());
                    udp::Message::Audio audio; assert(packet(audio) && audio.direction==udp::Message::Audio::ClientToServer && audio.frameNumber==4 && !audio.opusData.empty());
                } else {
                    assert(outgoingVoice.second[0]==std::byte{128}); PacketDataStream stream(BufView(outgoingVoice.second).subspan(1));
                    uint64_t sequence=0,size=0; stream >> sequence >> size; assert(stream && sequence==4 && size==delegate.fixtureOpus.length);
                }
                MumbleTCP::TextMessage large; large.set_actor(2); large.set_message(std::string(70000,'a')); sendProto(ssl,large,true);
                Opus::Encoder encoder(1); assert(encoder.init()==Code::Success); float samples[960]; for (int i=0;i<960;++i) samples[i]=.1f*sinf(i*.1f);
                Buf encoded(4096); auto opus=encoder(encoded,Opus::FloatViewConst(samples,960)); assert(!opus.empty());
                udp::Message::Audio audio; audio.direction=udp::Message::Audio::ServerToClient; audio.context=0; audio.senderSession=2; audio.frameNumber=0; audio.opusData.assign(opus.begin(),opus.end());
                auto voice=[&]() {
                    if (modern) { tcp::Message::UDPTunnel tunnel; tunnel.pack=udp::Pack(audio); sendPacket(ssl,tcp::Pack(tunnel).buf()); }
                    else {
                        Buf plain(audio.opusData.size()+32); plain[0]=std::byte{128}; PacketDataStream stream(BufView(plain).subspan(1));
                        stream << (uint64_t)2 << audio.frameNumber << (uint64_t)(audio.opusData.size() | (audio.isTerminator?8192:0));
                        auto used=stream.data().size(); std::copy(audio.opusData.begin(),audio.opusData.end(),plain.begin()+1+(long)used); plain.resize(1+used+audio.opusData.size());
                        tcp::NetHeader header{Endian::toNetwork((uint16_t)1),Endian::toNetwork((uint32_t)plain.size())}; tcp::Pack packet(header); std::copy(plain.begin(),plain.end(),packet.data().begin()); sendPacket(ssl,packet.buf());
                    }
                };
                voice(); audio.opusData.clear(); audio.frameNumber=2; audio.isTerminator=true; voice();
                // Wait until the main thread observes every callback before reconnecting.
                while (receivedVoice<2 || receivedTalkStop<1) std::this_thread::sleep_for(std::chrono::milliseconds(10));
                // Outgoing work must wake an otherwise idle transport immediately.
                std::this_thread::sleep_for(std::chrono::milliseconds(80));
                auto wakeStarted=std::chrono::steady_clock::now();
                dispatch_async(dispatch_get_main_queue(), ^{ [model sendTextMessage:[MLTextMessage messageWithPlainText:@"idle wake"] toChannel:[model channelWithId:7]]; });
                auto idleText=readPacket(ssl,"idle transport wake");
                assert(idleText.first==11 && sent.ParseFromArray(idleText.second.data(),(int)idleText.second.size()) && sent.message()=="idle wake");
                assert(std::chrono::steady_clock::now()-wakeStarted<std::chrono::milliseconds(250));
                if (modern) {
                    // Echo two real keepalives across a quiet interval; the connection must remain usable.
                    // The first ping can also use the quiet interval if the
                    // active-voice window expires before the worker wakes.
                    // Allow 15 seconds plus scheduling headroom for both pings.
                    timeval keepaliveTimeout{20,0}; setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&keepaliveTimeout,sizeof(keepaliveTimeout));
                    auto firstPing=readPacket(ssl,"first quiet keepalive"); MumbleTCP::Ping keepalive;
                    assert(firstPing.first==3 && keepalive.ParseFromArray(firstPing.second.data(),(int)firstPing.second.size()));
                    sendProto(ssl,keepalive);
                    auto firstPingAt=std::chrono::steady_clock::now();
                    auto secondPing=readPacket(ssl,"second quiet keepalive");
                    auto interval=std::chrono::steady_clock::now()-firstPingAt;
                    assert(secondPing.first==3 && interval>=std::chrono::seconds(14) && interval<std::chrono::seconds(18));
                    assert(keepalive.ParseFromArray(secondPing.second.data(),(int)secondPing.second.size())); sendProto(ssl,keepalive);
                    printf("PASS: quiet TLS connection survives two keepalives with a 15-second interval\n");
                }
                dispatch_async(dispatch_get_main_queue(), ^{ assert(delegate.texts==1 && delegate.moved==1); [connection reconnect]; });
                uint8_t byte; SSL_read(ssl,&byte,1);
            }
            SSL_free(ssl); SSL_CTX_free(context); close(fd);
        }
        close(listener);
    } });
    [connection connectToHost:@"127.0.0.1" port:port];
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:40];
    while ((!completed || !delegate.pings) && deadline.timeIntervalSinceNow>0) [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
    assert(completed && delegate.trustFailures==2 && delegate.opened==1 && delegate.joined==1 && receivedVoice==2 && receivedTalkStop==1 && delegate.pings>0);
    server.join(); pingServer.join();
    [connection disconnect]; pinger=nil;
    printf("PASS: certificate gating/pinning/rotation, SNI, auth, channel deltas, fragmented TCP, >64KiB messages, UDP server probe, %s Opus send/receive and TCP fallback\n",modern?"modern":"legacy");
    return 0;
} }
// Real loopback TLS exercises recovery without replacing transport methods.
static std::atomic<int> recoveryJoins,recoveryRestores,recoveryErrors;
@interface MLRecoveryTransportConnection : MLConnection @end
@implementation MLRecoveryTransportConnection
- (void)startPathMonitoring {} // Loopback does not depend on the host's default route.
@end
@interface MLRecoveryTransportDelegate : NSObject <MLConnectionDelegate,MLServerModelDelegate>
@property(nonatomic) NSUInteger trustPrompts,opens;
@property(nonatomic,weak) MLConnection *connection;
@end
@implementation MLRecoveryTransportDelegate
- (void)connection:(MLConnection *)connection trustFailureInCertificateChain:(NSArray *)chain {
    assert(++_trustPrompts==1);[connection setIgnoreSSLVerification:YES];[connection reconnect];
}
- (void)connectionOpened:(MLConnection *)connection {
    ++_opens;[connection authenticateWithUsername:@"Recovery fixture" password:@"Fixture password" accessTokens:@[@"Fixture token"]];
}
- (void)serverModel:(MLServerModel *)model joinedServerAsUser:(MLUser *)user {
    assert(user.isSelfMuted && user.isSelfDeafened);if(!self.connection.isRestoringSession)self.connection.automaticReconnectEnabled=YES;++recoveryJoins;
}
- (void)connectionDidRestoreSession:(MLConnection *)connection {++recoveryRestores;}
- (void)connection:(MLConnection *)connection closedWithError:(NSError *)error {assert(error && !connection.automaticReconnectEnabled);++recoveryErrors;}
- (void)connection:(MLConnection *)connection unableToConnectWithError:(NSError *)error {assert(false);}
@end
static void recoveryTransportTest(int terminal){@autoreleasepool{
    recoveryJoins=0;recoveryRestores=0;recoveryErrors=0;
    MLCertificate *identity=[MLCertificate selfSignedCertificateWithName:@"Recovery fixture" email:nil];
    MLCertificate *changed=[MLCertificate selfSignedCertificateWithName:@"Rotated fixture" email:nil];
    int listener=socket(AF_INET,SOCK_STREAM,0);assert(listener>=0);
    sockaddr_in address{};address.sin_family=AF_INET;address.sin_addr.s_addr=htonl(INADDR_LOOPBACK);
    assert(!bind(listener,(sockaddr *)&address,sizeof(address)) && !listen(listener,4));
    socklen_t length=sizeof(address);assert(!getsockname(listener,(sockaddr *)&address,&length));
    MLConnection *connection=[MLRecoveryTransportConnection new];
    MLServerModel *model=[[MLServerModel alloc]initWithConnection:connection];
    MLRecoveryTransportDelegate *delegate=[MLRecoveryTransportDelegate new];delegate.connection=connection;connection.delegate=delegate;[model addDelegate:delegate];
    std::thread server([&](){@autoreleasepool{
        int attempts=terminal==0 ? 4 : 3;
        for(int i=0;i<attempts;i++){
            pollfd pending{listener,POLLIN,0};assert(poll(&pending,1,10000)>0);
            int fd=accept(listener,nullptr,nullptr);assert(fd>=0);timeval timeout{5,0};setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof(timeout));
            SSL_CTX *context=serverContext(i==3 ? changed : identity);SSL *ssl=SSL_new(context);SSL_set_fd(ssl,fd);assert(SSL_accept(ssl)==1);
            if(i==0 || i==3){unsigned char byte;assert(SSL_read(ssl,&byte,1)<=0);}
            else{
                assert(readPacket(ssl,"recovery client version").first==0);
                MumbleTCP::Version version;version.set_version_v1(0x10500);sendProto(ssl,version);
                auto authPacket=readPacket(ssl,"recovery authentication");MumbleTCP::Authenticate auth;
                assert(authPacket.first==2 && auth.ParseFromArray(authPacket.second.data(),(int)authPacket.second.size()));
                assert(auth.username()=="Recovery fixture" && auth.password()=="Fixture password" && auth.tokens_size()==1 && auth.tokens(0)=="Fixture token");
                if(i==2 && terminal==2){
                    MumbleTCP::Reject reject;reject.set_type(MumbleTCP::Reject::WrongServerPW);reject.set_reason("Fixture authentication rejected");sendProto(ssl,reject);
                    unsigned char byte;assert(SSL_read(ssl,&byte,1)<=0);
                }else{
                    MumbleTCP::ChannelState channel;channel.set_channel_id(7);channel.set_parent(0);channel.set_name("Recovery");sendProto(ssl,channel);
                    MumbleTCP::UserState user;user.set_session(i==1?1:42);user.set_channel_id(i==1?7:0);user.set_name("Recovery fixture");user.set_self_mute(i==1);user.set_self_deaf(i==1);sendProto(ssl,user);
                    MumbleTCP::ServerSync sync;sync.set_session(user.session());sendProto(ssl,sync);
                    if(i==1){
                        auto until=std::chrono::steady_clock::now()+std::chrono::seconds(3);
                        while(recoveryJoins<1 && std::chrono::steady_clock::now()<until)std::this_thread::sleep_for(std::chrono::milliseconds(5));assert(recoveryJoins==1);
                    }else{
                        auto statePacket=readPacket(ssl,"restored channel and mute state");MumbleTCP::UserState restored;
                        assert(statePacket.first==9 && restored.ParseFromArray(statePacket.second.data(),(int)statePacket.second.size()));
                        assert(restored.session()==42 && restored.channel_id()==7 && restored.self_mute() && restored.self_deaf());sendProto(ssl,restored);
                        auto until=std::chrono::steady_clock::now()+std::chrono::seconds(3);
                        while(recoveryRestores<1 && std::chrono::steady_clock::now()<until)std::this_thread::sleep_for(std::chrono::milliseconds(5));assert(recoveryRestores==1);
                        if(terminal==1){MumbleTCP::UserRemove removed;removed.set_session(42);removed.set_actor(99);removed.set_reason("Fixture kick");sendProto(ssl,removed);unsigned char byte;assert(SSL_read(ssl,&byte,1)<=0);}
                    }
                }
            }
            SSL_shutdown(ssl);SSL_free(ssl);SSL_CTX_free(context);close(fd);
        }close(listener);
    }});
    [connection connectToHost:@"127.0.0.1" port:ntohs(address.sin_port)];
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:15];
    while(!recoveryErrors && deadline.timeIntervalSinceNow>0){
        if(recoveryJoins && !connection.automaticReconnectEnabled && !connection.isRestoringSession)connection.automaticReconnectEnabled=YES;
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]];
    }
    assert(recoveryErrors==1 && !connection.automaticReconnectEnabled && delegate.trustPrompts==1 && delegate.opens==1);
    assert(recoveryJoins==(terminal==2?1:2) && recoveryRestores==(terminal==2?0:1));
    server.join();[connection disconnect];
    printf("PASS real TLS recovery: cached authentication, session/channel/mute restoration; %s stops retries\n",terminal==0?"certificate rotation":terminal==1?"server kick":"authentication rejection");
}}
static void waitForIndicators(NSTimeInterval seconds) {
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:seconds];
    while (deadline.timeIntervalSinceNow>0) [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
}
static bool waitForTalkState(MLUser *user, MLTalkState state) {
    // NSTimer delivery can be coalesced or delayed by a busy hosted runner.
    // Observe the real state with a deadline instead of assuming 50ms scheduling slack.
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:2];
    while (user.talkState!=state && deadline.timeIntervalSinceNow>0)
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
    return user.talkState==state;
}
static void talkIndicatorTests(bool delayedRunLoop=false) { @autoreleasepool {
    MLServerModel *model=[[MLServerModel alloc] initWithConnection:nil];
    MumbleTCP::UserState state; state.set_session(2); state.set_name("Peer"); state.set_channel_id(0);
    [model receiveType:(uint16_t)tcp::Message::Type::UserState data:MLData(tcp::Pack(state).data())];
    MLUser *peer=[model userWithSession:2]; assert(peer);
    // The only audio packet can also be the final packet of a brief utterance.
    [model receivedVoiceForSession:2 talkState:MLTalkStateTalking hasAudio:YES terminator:YES];
    assert(peer.talkState==MLTalkStateTalking); waitForIndicators(.15); assert(peer.talkState==MLTalkStateTalking);
    if (delayedRunLoop) {
        // Delay main-queue work across the timer's deadline, as CI load can do.
        dispatch_async(dispatch_get_main_queue(), ^{ [NSThread sleepForTimeInterval:.4]; });
    }
    assert(waitForTalkState(peer,MLTalkStatePassive));
    [model receivedVoiceForSession:2 talkState:MLTalkStateWhispering hasAudio:YES terminator:NO];
    waitForIndicators(.5);
    [model receivedVoiceForSession:2 talkState:MLTalkStateShouting hasAudio:YES terminator:NO];
    waitForIndicators(.4); assert(peer.talkState==MLTalkStateShouting);
    assert(waitForTalkState(peer,MLTalkStatePassive));
    [model receivedVoiceForSession:2 talkState:MLTalkStateTalking hasAudio:YES terminator:NO];
    [model reset]; waitForIndicators(.9); assert([model userWithSession:2]==nil);
    printf("PASS: brief speech visible, active speech refresh, lost terminator timeout and reset cancellation\n");
} }
static void imageMessageConfigTests() {
    MLServerModel *model=[[MLServerModel alloc] initWithConnection:nil];
    assert(model.allowsHTMLMessages && model.maximumImageMessageLength==131072);
    MumbleTCP::ServerConfig config; config.set_allow_html(false); config.set_image_message_length(4096);
    [model receiveType:(uint16_t)tcp::Message::Type::ServerConfig data:MLData(tcp::Pack(config).data())];
    assert(!model.allowsHTMLMessages && model.maximumImageMessageLength==4096);
    config.Clear(); config.set_allow_html(true);
    [model receiveType:(uint16_t)tcp::Message::Type::ServerConfig data:MLData(tcp::Pack(config).data())];
    assert(model.allowsHTMLMessages && model.maximumImageMessageLength==4096);
    [model receiveType:(uint16_t)tcp::Message::Type::ServerConfig data:[NSData dataWithBytes:"\377" length:1]];
    assert(model.allowsHTMLMessages && model.maximumImageMessageLength==4096);
    [model reset];
    assert(model.allowsHTMLMessages && model.maximumImageMessageLength==131072);
    printf("PASS: image message limits, HTML policy, partial updates, malformed config and reconnect defaults\n");
}
static void keepaliveTimingTests() {
    using namespace std::chrono;
    auto now=steady_clock::time_point(seconds(100));
    assert(MLKeepaliveInterval(false,now,{})==seconds(5));
    assert(MLKeepaliveInterval(true,now,{})==seconds(15));
    assert(MLKeepaliveInterval(true,now,now)==seconds(5));
    assert(MLKeepaliveInterval(true,now,now-seconds(4))==seconds(5));
    assert(MLKeepaliveInterval(true,now,now-seconds(5))==seconds(15));
    assert(MLKeepaliveInterval(true,now,now-seconds(60))==seconds(15));
    printf("PASS: authentication and active voice retain fast keepalive; quiet connection uses 15 seconds\n");
}
void MLReconnectPolicyTests();
int main(int argc, const char *argv[]) {
    if(argc==2 && !strcmp(argv[1],"--reconnect-transport")){for(int terminal=0;terminal<3;++terminal)recoveryTransportTest(terminal);return 0;}
    if(argc==2 && !strcmp(argv[1],"--reconnect-policy")){MLReconnectPolicyTests();return 0;}
    if (argc==2 && !strcmp(argv[1],"--delayed-talk-indicators")) { talkIndicatorTests(true); return 0; }
    keepaliveTimingTests(); imageMessageConfigTests(); talkIndicatorTests(); runTransport(false); runTransport(true); return 0;
}
