#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "MLClient.h"
#import "MUConnectionController.h"
#import "MUServerRootViewController.h"
#import "MUFavouriteServer.h"
@interface MUDatabase : NSObject
+ (NSArray<MUFavouriteServer *> *)recentServers;
+ (void)deleteRecentServer:(MUFavouriteServer *)server;
@end
@interface MUConnectionController (Checks) <MLConnectionDelegate,MLServerModelDelegate> @end
static NSUInteger authentications;
static NSUInteger fixtureConnects;
static __weak MLConnection *authenticatedConnection;
static void ConnectFixture(MLConnection *object,SEL command,NSString *hostname,NSUInteger port){
    ++fixtureConnects;
    [object setValue:hostname forKey:@"_hostname"];[object setValue:@(port) forKey:@"_port"];
    if([hostname isEqual:@"synchronous-lifecycle.invalid"])[object.delegate connection:object unableToConnectWithError:[NSError errorWithDomain:@"Fixture" code:1 userInfo:nil]];
}
static void AuthenticateFixture(id object,SEL command,NSString *username,NSString *password,NSArray *tokens){++authentications;authenticatedConnection=object;}
static void Check(BOOL value,NSString *reason){if(!value)@throw [NSException exceptionWithName:@"ConnectionLifecycleFailure" reason:reason userInfo:nil];}
static void Pump(double seconds){NSDate *until=[NSDate dateWithTimeIntervalSinceNow:seconds];while(until.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]];}
static void WaitUntil(BOOL (^condition)(void)){
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:4];
    while(!condition() && deadline.timeIntervalSinceNow>0)Pump(.01);
}
void MUConnectionLifecycleChecks(UIWindow *window,NSMutableArray<NSString *> *results){
    Method connect=class_getInstanceMethod(MLConnection.class,@selector(connectToHost:port:));IMP oldConnect=method_setImplementation(connect,(IMP)ConnectFixture);
    Method authenticate=class_getInstanceMethod(MLConnection.class,@selector(authenticateWithUsername:password:accessTokens:));IMP oldAuthenticate=method_setImplementation(authenticate,(IMP)AuthenticateFixture);
    MUConnectionController *controller=[MUConnectionController new];UIViewController *parent=[UIViewController new];
    UITabBarController *tabs=[UITabBarController new];
    tabs.viewControllers=@[[[UINavigationController alloc]initWithRootViewController:parent],[UIViewController new]];
    window.rootViewController=tabs;[window makeKeyAndVisible];Pump(.2);
    __block NSUInteger activeTransitions=0;
    id observer=[NSNotificationCenter.defaultCenter addObserverForName:MUConnectionStateDidChangeNotification object:controller queue:nil usingBlock:^(NSNotification *notification){Check(NSThread.isMainThread,@"Connection state changed off main");if(controller.hasActiveSession)++activeTransitions;}];
    @try{
        Check(![controller isKindOfClass:UIView.class] && controller.state==MUConnectionStateIdle,@"Connection manager still uses view lifetime or starts non-idle");
        [controller connectToHostname:@"first-lifecycle.invalid" port:64738 withUsername:@"Fixture" andPassword:nil withParentViewController:parent];
        MLConnection *first=[controller valueForKey:@"_connection"];
        Check(controller.state==MUConnectionStateConnecting && !controller.isConnected && !controller.hasActiveSession && controller.hasPendingConnection && activeTransitions==0,@"A created transport is treated as a joined audio session");
        authentications=0;[controller connectionOpened:first];
        Check(controller.state==MUConnectionStateAuthenticating && !controller.hasActiveSession,@"TLS open activates a conversation before server sync");
        [controller connectToHostname:@"second-lifecycle.invalid" port:64738 withUsername:@"Fixture" andPassword:nil withParentViewController:parent];
        MLConnection *second=[controller valueForKey:@"_connection"];Pump(.8);
        [controller connection:first closedWithError:[NSError errorWithDomain:@"Fixture" code:1 userInfo:nil]];
        [controller connection:first unableToConnectWithError:[NSError errorWithDomain:@"Fixture" code:2 userInfo:nil]];
        Check([controller valueForKey:@"_connection"]==second && controller.state==MUConnectionStateConnecting && authentications==0,@"A stale authentication completion/error changes the replacement session");
        [controller connectionOpened:second];[controller connectionOpened:second];Pump(.2);Check(authentications==1 && authenticatedConnection==second,@"Authentication is not scoped/coalesced to the current connection");
        MLServerModel *model=[controller valueForKey:@"_serverModel"];MLUser *user=[MLUser new];user.session=1;user.userName=@"Fixture";user.channel=model.rootChannel;
        [model setValue:user forKey:@"_connectedUser"];[controller serverModel:model joinedServerAsUser:user];
        [controller connection:second willReconnectAfterDelay:.5 attempt:1];Pump(.8);
        MUServerRootViewController *root=[controller valueForKey:@"_serverRoot"];
        Check(root.presentingViewController!=nil && controller.state==MUConnectionStateReconnecting,@"A reconnect during the initial presentation loses the server page");
        [controller connectionDidRestoreSession:second];
        Check(controller.state==MUConnectionStateConnected && controller.isConnected && controller.hasActiveSession && second.delegate==controller,@"Joined session transfers its event owner to a page");
        Check(root.presentingViewController!=nil,@"Joined session does not present its server page");
        [controller connection:second willReconnectAfterDelay:.5 attempt:1];
        Check(controller.state==MUConnectionStateReconnecting && !controller.isConnected && controller.hasActiveSession && second.delegate==controller,@"Recovery drops capture demand or changes event ownership");
        [controller serverModel:model joinedServerAsUser:user];Check([controller valueForKey:@"_serverRoot"]==root && controller.state==MUConnectionStateReconnecting,@"A repeated server-sync presents another page");
        [controller connectionDidRestoreSession:second];Check(controller.state==MUConnectionStateConnected && root.topViewController.navigationItem.prompt==nil,@"Restored session retains reconnect state");
        [controller disconnectFromServer];Pump(.6);Check(controller.state==MUConnectionStateIdle && !controller.hasActiveSession && second.delegate==nil,@"Explicit disconnect retains a joined session");
        [results addObject:@"PASS connection phases, joined-only audio demand, stale authentication/errors, stable delegate ownership and recovery transitions"];

        [controller connectToHostname:@"cancel-lifecycle.invalid" port:64738 withUsername:@"Fixture" andPassword:nil withParentViewController:parent];
        root.disconnectHandler(nil,nil);
        Check(controller.hasPendingConnection,@"A retiring server page can disconnect its replacement session");
        [controller disconnectFromServer];Pump(.8);
        Check(!parent.presentedViewController && controller.state==MUConnectionStateIdle,@"Cancelled connecting presentation reappears after its transition");
        [controller connectToHostname:@"error-lifecycle.invalid" port:64738 withUsername:@"Fixture" andPassword:nil withParentViewController:parent];
        MLConnection *failed=[controller valueForKey:@"_connection"];
        [controller connection:failed unableToConnectWithError:[NSError errorWithDomain:@"Fixture" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Old error"}]];
        [controller connectToHostname:@"current-lifecycle.invalid" port:64738 withUsername:@"Fixture" andPassword:nil withParentViewController:parent];Pump(1);
        UIAlertController *current=(id)parent.presentedViewController;
        Check([current isKindOfClass:UIAlertController.class] && ![current.message isEqual:@"Old error"] && controller.state==MUConnectionStateConnecting,@"An obsolete terminal error replaces the current connection UI");
        [results addObject:@"PASS connection presentation cancellation and suppression of obsolete terminal alerts"];
        [controller disconnectFromServer];Pump(.6);
        [controller connectToHostname:@"synchronous-lifecycle.invalid" port:0 withUsername:@"Fixture" andPassword:nil withParentViewController:parent];Pump(.7);
        Check(controller.state==MUConnectionStateIdle && !controller.hasPendingConnection && ![controller valueForKey:@"_alertCtrl"],@"A synchronous connection failure recreates the connecting state");
        [results addObject:@"PASS synchronous connection failure stays idle instead of reopening the connecting UI"];
        [controller disconnectFromServer];Pump(.6);
        MLCertificate *certificate=[MLCertificate selfSignedCertificateWithName:@"Lifecycle fixture" email:nil];
        for(NSUInteger viewer=0;viewer<2;++viewer){
            [controller connectToHostname:@"certificate-lifecycle.invalid" port:64738 withUsername:@"Fixture" andPassword:nil withParentViewController:parent];
            MLConnection *connection=[controller valueForKey:@"_connection"];
            [connection setValue:@[certificate] forKey:@"_peerCertificates"];
            [controller connection:connection trustFailureInCertificateChain:@[certificate]];
            WaitUntil(^BOOL{UIViewController *page=parent.presentedViewController;return [page isKindOfClass:UIAlertController.class] && ((UIAlertController *)page).actions.count>1 && !page.isBeingPresented;});
            UIAlertController *prompt=(id)parent.presentedViewController;
            Check([prompt isKindOfClass:UIAlertController.class] && controller.state==MUConnectionStateAwaitingCertificate,@"Certificate decision is not presented");
            if(viewer){
                void (^showCertificates)(UIAlertAction *)=[prompt.actions.lastObject valueForKey:@"handler"];
                Check(showCertificates!=nil,@"Certificate viewer action is missing");showCertificates(prompt.actions.lastObject);
                WaitUntil(^BOOL{return [parent.presentedViewController isKindOfClass:UINavigationController.class] && !parent.presentedViewController.isBeingPresented;});
                Check([parent.presentedViewController isKindOfClass:UINavigationController.class],@"Certificate viewer is not presented");
            }
            [controller disconnectFromServer];WaitUntil(^BOOL{return !parent.presentedViewController;});
            Check(!parent.presentedViewController && controller.state==MUConnectionStateIdle,[NSString stringWithFormat:@"Disconnect leaves certificate stage %lu on screen: %@, presenting=%d dismissing=%d",(unsigned long)viewer,parent.presentedViewController,parent.presentedViewController.isBeingPresented,parent.presentedViewController.isBeingDismissed]);
        }
        [results addObject:@"PASS cancellation dismisses both certificate decisions and certificate viewers"];
        for(NSUInteger storedTrust=0;storedTrust<2;++storedTrust){
            NSString *hostname=@"Trusted-Lifecycle.Invalid";
            if(storedTrust){
                WaitUntil(^BOOL{return [[MUDatabase recentServers].firstObject.hostName isEqualToString:@"trusted-lifecycle.invalid"];});
                hostname=[MUDatabase recentServers].firstObject.hostName;
                Check([hostname isEqualToString:@"trusted-lifecycle.invalid"],@"Recent does not preserve the canonical LAN endpoint");
            }
            [controller connectToHostname:hostname port:64738 withUsername:@"Fixture" andPassword:nil withParentViewController:parent];
            MLConnection *connection=[controller valueForKey:@"_connection"];
            [connection setValue:@[certificate] forKey:@"_peerCertificates"];
            NSUInteger before=fixtureConnects;
            [controller connection:connection trustFailureInCertificateChain:@[certificate]];
            if(!storedTrust){
                WaitUntil(^BOOL{UIViewController *page=parent.presentedViewController;return [page isKindOfClass:UIAlertController.class] && ((UIAlertController *)page).actions.count==4 && !page.isBeingPresented;});
                UIAlertController *prompt=(id)parent.presentedViewController;
                Check([prompt isKindOfClass:UIAlertController.class] && prompt.actions.count==4,@"Self-signed certificate decision is missing");
                void (^trust)(UIAlertAction *)=[prompt.actions[2] valueForKey:@"handler"];trust(prompt.actions[2]);
            }
            WaitUntil(^BOOL{return fixtureConnects>before;});
            Check(fixtureConnects>before && controller.state==MUConnectionStateConnecting,@"Trust does not start a new TLS attempt");
            // Server sync can arrive before the old certificate/Connecting
            // modal has finished its transition, especially on a LAN.
            MLServerModel *model=[controller valueForKey:@"_serverModel"];
            MLUser *user=[MLUser new];user.session=2;user.userName=@"Fixture";user.channel=model.rootChannel;[model setValue:user forKey:@"_connectedUser"];
            [controller serverModel:model joinedServerAsUser:user];
            MUServerRootViewController *root=[controller valueForKey:@"_serverRoot"];
            WaitUntil(^BOOL{return root.presentingViewController!=nil && !root.isBeingPresented;});
            Check(root.presentingViewController!=nil && controller.state==MUConnectionStateConnected,@"Fast self-signed server sync leaves Connecting/certificate UI covering the joined session");
            [controller disconnectFromServer];WaitUntil(^BOOL{return !parent.presentedViewController;});
        }
        [results addObject:@"PASS fast self-signed join, mixed-case LAN trust and canonical Recent reconnect without a second prompt"];
    }@finally{
        [controller disconnectFromServer];Pump(.5);[NSNotificationCenter.defaultCenter removeObserver:observer];
        method_setImplementation(connect,oldConnect);method_setImplementation(authenticate,oldAuthenticate);
        for(MUFavouriteServer *server in [MUDatabase recentServers])if([server.hostName hasSuffix:@"-lifecycle.invalid"])[MUDatabase deleteRecentServer:server];
        window.rootViewController=[UIViewController new];
    }
}
