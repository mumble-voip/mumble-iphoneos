#import "MLInternal.hpp"
#import <objc/runtime.h>
#include <atomic>
#include <cassert>
#include <memory>
#include <cstdio>
struct MLNetworkState;
@interface MLConnection (RecoveryTests)
- (void)transportFailed:(NSError *)error opened:(BOOL)opened retryable:(BOOL)retryable;
- (void)transportOpened;
- (void)beginAutomaticReconnect;
- (void)networkPathDidChangeSignature:(NSUInteger)signature available:(BOOL)available;
- (void)scheduleReconnectAfter:(NSTimeInterval)delay;
- (void)handleRejectedReason:(MLRejectReason)reason explanation:(NSString *)explanation;
- (void)handleUntrustedCertificates:(NSArray *)certificates;
@end
@interface MLRecoveryObserver : NSObject <MLConnectionDelegate>
@property(nonatomic) NSUInteger pending,restored,closed;
@end
@implementation MLRecoveryObserver
- (void)connection:(MLConnection *)connection willReconnectAfterDelay:(NSTimeInterval)delay attempt:(NSUInteger)attempt {assert(NSThread.isMainThread && attempt<=7 && delay<=15);self.pending++;}
- (void)connectionDidRestoreSession:(MLConnection *)connection {assert(!connection.isRestoringSession);self.restored++;}
- (void)connection:(MLConnection *)connection closedWithError:(NSError *)error {assert(error);self.closed++;}
@end
static std::atomic_uint runs;
static std::vector<MumbleTCP::UserState> userStates;
static std::vector<MumbleTCP::Authenticate> authentications;
static void NoMonitor(id object,SEL command){}
static void NoNetwork(id object,SEL command,std::shared_ptr<MLNetworkState> state,NSString *hostname,NSArray *identity,NSData *accepted){++runs;}
static void CaptureMessage(id object,SEL command,const google::protobuf::Message &message){
    if(message.GetTypeName()=="MumbleTCP.UserState")userStates.push_back(static_cast<const MumbleTCP::UserState &>(message));
    if(message.GetTypeName()=="MumbleTCP.Authenticate")authentications.push_back(static_cast<const MumbleTCP::Authenticate &>(message));
}
static void Pump(double interval){NSDate *until=[NSDate dateWithTimeIntervalSinceNow:interval];while(until.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]];}
static void Synchronize(MLServerModel *model,uint32_t session,bool muted){
    MumbleTCP::ChannelState channel;channel.set_channel_id(7);channel.set_parent(0);channel.set_name("Recovery");
    [model receiveType:7 data:MLData(mumble::tcp::Pack(channel).data())];
    MumbleTCP::UserState user;user.set_session(session);user.set_channel_id(muted?7:0);user.set_name("Recovery user");user.set_self_mute(muted);user.set_self_deaf(muted);
    [model receiveType:9 data:MLData(mumble::tcp::Pack(user).data())];
    MumbleTCP::ServerSync sync;sync.set_session(session);[model receiveType:5 data:MLData(mumble::tcp::Pack(sync).data())];
}
void MLReconnectPolicyTests(){@autoreleasepool{
    Method monitor=class_getInstanceMethod(MLConnection.class,NSSelectorFromString(@"startPathMonitoring"));IMP oldMonitor=method_setImplementation(monitor,(IMP)NoMonitor);
    Method run=class_getInstanceMethod(MLConnection.class,NSSelectorFromString(@"run:hostname:identity:accepted:"));IMP oldRun=method_setImplementation(run,(IMP)NoNetwork);
    Method send=class_getInstanceMethod(MLConnection.class,@selector(sendProto:));IMP oldSend=method_setImplementation(send,(IMP)CaptureMessage);
    MLConnection *connection=[MLConnection new];MLServerModel *model=[[MLServerModel alloc]initWithConnection:connection];MLRecoveryObserver *observer=[MLRecoveryObserver new];connection.delegate=observer;
    @try{
        runs=0;userStates.clear();authentications.clear();
        [connection connectToHost:@"recovery.invalid" port:64738];Pump(.05);
        [connection authenticateWithUsername:@"Fixture" password:@"Fixture password" accessTokens:@[@"Old token"]];
        [model setAccessTokens:@[@"Updated token"]];Synchronize(model,1,true);connection.automaticReconnectEnabled=YES;
        NSError *error=[NSError errorWithDomain:@"Fixture" code:1 userInfo:nil];
        [model setSelfMuted:YES andSelfDeafened:NO]; // Not acknowledged by the server yet.
        [connection networkPathDidChangeSignature:3 available:YES];
        [connection networkPathDidChangeSignature:5 available:YES];
        assert(connection.isRestoringSession && observer.pending==1 && !observer.closed);
        [model setSelfMuted:YES andSelfDeafened:YES]; // Updated while transport is unavailable.
        Pump(.65);assert(runs==2 && !model.connectedUser);
        [connection transportOpened];
        const auto &auth=authentications.back();assert(auth.username()=="Fixture" && auth.password()=="Fixture password" && auth.tokens(0)=="Updated token");
        Synchronize(model,42,false);
        assert(model.connectedUser.session==42 && model.connectedUser.isSelfMuted && model.connectedUser.isSelfDeafened);
        assert(!userStates.empty());const auto &restore=userStates.back();
        assert(restore.session()==42 && restore.channel_id()==7 && restore.self_mute() && restore.self_deaf());
        assert(observer.restored==1 && !connection.isRestoringSession);
        std::puts("PASS reconnect: network handoff, same model, changed session ID, latest mute intent and authentication tokens");
        [connection networkPathDidChangeSignature:0 available:NO];unsigned before=runs;
        Pump(.6);assert(runs==before && connection.isRestoringSession);
        [connection transportFailed:error opened:YES retryable:YES];
        [connection disconnect];Pump(.65);assert(runs==before && !connection.automaticReconnectEnabled);
        std::puts("PASS reconnect: explicit disconnect cancels scheduled retry and disables recovery");
        [connection connectToHost:@"recovery.invalid" port:64738];Synchronize(model,1,true);connection.automaticReconnectEnabled=YES;
        [connection beginAutomaticReconnect];[connection handleRejectedReason:MLRejectReasonWrongServerPassword explanation:@"Fixture rejection"];
        assert(observer.closed==1 && !connection.automaticReconnectEnabled && !connection.isRestoringSession);
        [connection connectToHost:@"recovery.invalid" port:64738];Synchronize(model,1,true);connection.automaticReconnectEnabled=YES;
        [connection beginAutomaticReconnect];[connection handleUntrustedCertificates:@[]];assert(observer.closed==2 && !connection.automaticReconnectEnabled);
        std::puts("PASS reconnect: authentication rejection and certificate validation stop retries");
        [connection connectToHost:@"recovery.invalid" port:64738];Synchronize(model,1,true);connection.automaticReconnectEnabled=YES;
        [connection beginAutomaticReconnect];[connection setValue:@6 forKey:@"_reconnectAttempt"];
        [connection scheduleReconnectAfter:.001];Pump(.1);assert(observer.closed==3 && !connection.automaticReconnectEnabled);
        std::puts("PASS reconnect: retry limit terminates recovery instead of looping indefinitely");
    }@finally{
        [connection disconnect];dispatch_sync((dispatch_queue_t)[connection valueForKey:@"_worker"],^{});
        method_setImplementation(monitor,oldMonitor);method_setImplementation(run,oldRun);method_setImplementation(send,oldSend);
    }
}}
