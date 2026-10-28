// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUConnectionController.h"
#import "MUConnectionPresentation.h"
#import "MUApplicationDelegate.h"
#import "MUServerRootViewController.h"
#import "MUServerCertificateTrustViewController.h"
#import "MUCertificateController.h"
#import "MUCertificateChainBuilder.h"
#import "MUDatabase.h"
#import "MUFavouriteServer.h"

#import "MLClient.h"

NSNotificationName const MUConnectionStateDidChangeNotification=@"MUConnectionStateDidChangeNotification";

@interface MUConnectionController () <MLConnectionDelegate, MLServerModelDelegate, MUServerCertificateTrustViewControllerProtocol> {
    MLConnection               *_connection;
    MLServerModel              *_serverModel;
    MUServerRootViewController *_serverRoot;
    __weak UIViewController    *_parentViewController;
    MUConnectionPresentation *_presentation;
    __weak MUServerCertificateTrustViewController *_trustView;
    MUConnectionState _state;
    BOOL _joinedSession,_stateNotificationScheduled;
    UIAlertController          *_alertCtrl;

    UIAlertController          *_rejectAlertCtrl;

    NSString                   *_hostname;
    NSUInteger                 _port;
    NSString                   *_username;
    NSString                   *_password;
    NSString                   *_displayName;
    NSInteger                  _favouritePrimaryKey;
    BOOL                       _savePasswordOnJoin;
    NSUInteger                 _connectionAttempt;

}
- (void) establishConnection;
- (void) teardownConnection;
- (void) showConnectingView;
- (void) hideConnectingView;
- (void) hideConnectingViewWithCompletion:(void(^)(void))completion;
- (void)presentConnectionAlert:(UIAlertController *)alert forAttempt:(NSUInteger)attempt;
- (void)beginConnectionToHostname:(NSString *)hostname port:(NSUInteger)port username:(NSString *)username password:(NSString *)password displayName:(NSString *)displayName favouriteKey:(NSInteger)key parent:(UIViewController *)parent;
@end

@implementation MUConnectionController
- (instancetype)init {if((self=[super init]))_presentation=[MUConnectionPresentation new];return self;}
- (void)dealloc {
    [_serverModel removeDelegate:self];_connection.delegate=nil;
    MLConnection *connection=_connection;
    if(NSThread.isMainThread)[connection disconnect];
    else dispatch_async(dispatch_get_main_queue(),^{[connection disconnect];});
}
- (MUConnectionState)state {return _state;}
- (BOOL)hasActiveSession {return _state==MUConnectionStateConnected || _state==MUConnectionStateReconnecting;}
- (BOOL)hasPendingConnection {return _state==MUConnectionStateConnecting || _state==MUConnectionStateAuthenticating || _state==MUConnectionStateAwaitingCertificate;}
- (void)transitionToState:(MUConnectionState)state {
    NSAssert(NSThread.isMainThread,@"Connection state belongs to the main thread");
    if(_state==state)return;_state=state;
    if(_stateNotificationScheduled)return;_stateNotificationScheduled=YES;
    __weak MUConnectionController *weakSelf=self;
    dispatch_async(dispatch_get_main_queue(),^{
        MUConnectionController *owner=weakSelf;if(!owner)return;owner->_stateNotificationScheduled=NO;
        [NSNotificationCenter.defaultCenter postNotificationName:MUConnectionStateDidChangeNotification object:owner];
    });
}


+ (MUConnectionController *) sharedController {
    static MUConnectionController *nc;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        nc = [[MUConnectionController alloc] init];
    });
    return nc;
}

- (void) connectToHostname:(NSString *)hostName port:(NSUInteger)port withUsername:(NSString *)userName andPassword:(NSString *)password withParentViewController:(UIViewController *)parentViewController {
    [self beginConnectionToHostname:hostName port:port username:userName password:password displayName:nil favouriteKey:-1 parent:parentViewController];
}

- (void)connectToFavouriteServer:(MUFavouriteServer *)server withParentViewController:(UIViewController *)parentViewController {
    NSString *username = server.userName.length ? server.userName : [NSUserDefaults.standardUserDefaults stringForKey:@"DefaultUserName"];
    [self beginConnectionToHostname:server.hostName port:server.port username:username password:server.password displayName:server.displayName favouriteKey:server.primaryKey parent:parentViewController];
}

- (void)beginConnectionToHostname:(NSString *)hostname port:(NSUInteger)port username:(NSString *)username password:(NSString *)password displayName:(NSString *)displayName favouriteKey:(NSInteger)key parent:(UIViewController *)parent {
    [self disconnectFromServer];
    _presentation=[MUConnectionPresentation new];_presentation.presenter=parent;
    _hostname = [hostname copy];
    _port = port;
    _username = [username copy];
    _password = [password copy];
    _displayName = [displayName copy];
    _favouritePrimaryKey = key;
    _savePasswordOnJoin = NO;
    _rejectAlertCtrl = nil;
    _parentViewController = parent;
    [self establishConnection];
    [self showConnectingView];
}

- (BOOL) isConnected {
    return _state==MUConnectionStateConnected;
}

- (void)disconnectFromServer {
    NSAssert(NSThread.isMainThread,@"Connection state belongs to the main thread");
    ++_connectionAttempt;[_presentation invalidate];
    _alertCtrl=nil;_rejectAlertCtrl=nil;
    [self transitionToState:MUConnectionStateDisconnecting];
    [_serverRoot dismissViewControllerAnimated:YES completion:nil];
    [self teardownConnection];
    _savePasswordOnJoin=NO;_username=nil;_password=nil;_hostname=nil;_displayName=nil;_parentViewController=nil;
}
- (void)showTerminalErrorWithTitle:(NSString *)title message:(NSString *)message {
    UIViewController *presenter=_serverRoot.presentingViewController ?: _parentViewController;
    [self disconnectFromServer];_presentation.presenter=presenter;
    if(!message.length)return;
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK",nil) style:UIAlertActionStyleCancel handler:nil]];
    NSUInteger attempt=_connectionAttempt;__weak MUConnectionController *weakSelf=self;
    [_presentation presentAlert:alert whileCurrent:^BOOL{MUConnectionController *owner=weakSelf;return owner && owner->_connectionAttempt==attempt && owner.state==MUConnectionStateIdle;}];
}

- (void) showConnectingView {
    if(!_connection)return;
    if(_state!=MUConnectionStateAuthenticating)[self transitionToState:MUConnectionStateConnecting];
    NSUInteger attempt = _connectionAttempt;
    NSString *title = [NSString stringWithFormat:@"%@...", NSLocalizedString(@"Connecting", nil)];
    NSString *msg = [NSString stringWithFormat:
                     NSLocalizedString(@"Connecting to %@:%lu", @"Connecting to hostname:port"),
                     _hostname, (unsigned long)_port];
    
    _alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                     message:msg
                                              preferredStyle:UIAlertControllerStyleAlert];
    __weak MUConnectionController *weakSelf=self;
    [_alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            MUConnectionController *owner=weakSelf;
            if (!owner || attempt != owner->_connectionAttempt) return;
            [owner disconnectFromServer];
    }]];
    [self presentConnectionAlert:_alertCtrl forAttempt:_connectionAttempt];
    
}

- (void)presentConnectionAlert:(UIAlertController *)alert forAttempt:(NSUInteger)attempt {
    __weak MUConnectionController *weakSelf=self;
    [_presentation presentAlert:alert whileCurrent:^BOOL{
        MUConnectionController *owner=weakSelf;
        return owner && attempt==owner->_connectionAttempt && (alert==owner->_alertCtrl || alert==owner->_rejectAlertCtrl);
    }];
}
- (void)hideConnectingView {[self hideConnectingViewWithCompletion:nil];}
- (void)hideConnectingViewWithCompletion:(dispatch_block_t)completion {
    UIAlertController *connecting=_alertCtrl;_alertCtrl=nil;
    [_presentation dismissAlert:connecting completion:completion];
}

- (void) establishConnection {
    [self teardownConnection];
    _connectionAttempt++;_joinedSession=NO;
    [self transitionToState:MUConnectionStateConnecting];
    _connection = [[MLConnection alloc] init];
    [_connection setDelegate:self];
    [_connection setForceTCP:[[NSUserDefaults standardUserDefaults] boolForKey:@"NetworkForceTCP"]];
    
    _serverModel = [[MLServerModel alloc] initWithConnection:_connection];
    [_serverModel addDelegate:self];
    
    _serverRoot = [[MUServerRootViewController alloc] initWithConnection:_connection andServerModel:_serverModel];
    __weak MUConnectionController *weakSelf=self;
    __weak MLConnection *ownedConnection=_connection;
    _serverRoot.disconnectHandler=^(NSString *title,NSString *message){
        MUConnectionController *owner=weakSelf;
        if(!owner || owner->_connection!=ownedConnection || !ownedConnection)return;
        if(message.length)[owner showTerminalErrorWithTitle:title message:message];else [owner disconnectFromServer];
    };
    
    // Set the connection's client cert if one is set in the app's preferences...
    NSData *certPersistentId = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultCertificate"];
    if (certPersistentId != nil) {
        NSArray *certChain = [MUCertificateChainBuilder buildChainFromPersistentRef:certPersistentId];
        [_connection setCertificateChain:certChain];
    }
    
    [_connection connectToHost:_hostname port:_port];


}

- (void) teardownConnection {
    [_serverModel removeDelegate:self];
    _serverModel = nil;
    [_connection setDelegate:nil];
    [_connection disconnect];
    _connection = nil;
    _serverRoot = nil;_trustView=nil;
    
    // Reset app badge. The connection is no more.
    [MUApplicationDelegate setApplicationBadgeCount:0];
    
    _joinedSession=NO;[self transitionToState:MUConnectionStateIdle];
}
            

- (void)connectionOpened:(MLConnection *)connection {
    if(connection!=_connection || _state!=MUConnectionStateConnecting)return;
    [self transitionToState:MUConnectionStateAuthenticating];
    NSUInteger attempt=_connectionAttempt;NSString *username=[_username copy],*password=[_password copy];
    __weak MUConnectionController *weakSelf=self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        NSArray *tokens=[MUDatabase accessTokensForServerWithHostname:connection.hostname port:connection.port];
        dispatch_async(dispatch_get_main_queue(),^{
            MUConnectionController *owner=weakSelf;
            if(!owner || owner->_connection!=connection || owner->_connectionAttempt!=attempt || owner.state!=MUConnectionStateAuthenticating)return;
            [connection authenticateWithUsername:username password:password accessTokens:tokens];
        });
    });
}
- (void)connection:(MLConnection *)connection willReconnectAfterDelay:(NSTimeInterval)delay attempt:(NSUInteger)attempt {
    if(connection!=_connection || !_joinedSession)return;
    [self transitionToState:MUConnectionStateReconnecting];
    [(id<MLConnectionDelegate>)_serverRoot connection:connection willReconnectAfterDelay:delay attempt:attempt];
}
- (void)connectionDidRestoreSession:(MLConnection *)connection {
    if(connection!=_connection || !_joinedSession)return;
    [self transitionToState:MUConnectionStateConnected];
    [(id<MLConnectionDelegate>)_serverRoot connectionDidRestoreSession:connection];
}
- (void)connection:(MLConnection *)connection closedWithError:(NSError *)error {
    if(connection!=_connection)return;
    [self showTerminalErrorWithTitle:NSLocalizedString(@"Connection closed",nil) message:error.localizedDescription];
}
- (void)connection:(MLConnection *)connection unableToConnectWithError:(NSError *)error {
    if(connection!=_connection)return;
    [self showTerminalErrorWithTitle:NSLocalizedString(@"Unable to connect",nil) message:error.localizedDescription];
}

// The connection encountered an invalid SSL certificate chain.
- (void) connection:(MLConnection *)conn trustFailureInCertificateChain:(NSArray *)chain {
    if(conn!=_connection)return;
    [self transitionToState:MUConnectionStateAwaitingCertificate];
    NSUInteger attempt=_connectionAttempt;
    MLCertificate *certificate=conn.peerCertificates.firstObject;
    if(!certificate){[self showTerminalErrorWithTitle:NSLocalizedString(@"Unable to validate server certificate",nil) message:NSLocalizedString(@"Mumble was unable to validate the certificate chain of the server.",nil)];return;}
    __weak MUConnectionController *weakSelf=self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        NSString *storedDigest=[MUDatabase digestForServerWithHostname:conn.hostname port:conn.port];
        dispatch_async(dispatch_get_main_queue(),^{
            MUConnectionController *owner=weakSelf;
            if(owner && owner->_connection==conn && attempt==owner->_connectionAttempt && [certificate.certificate isEqual:conn.peerCertificates.firstObject.certificate])
                [owner showTrustDecisionForConnection:conn certificate:certificate storedDigest:storedDigest attempt:attempt];
        });
    });
}
- (void)showTrustDecisionForConnection:(MLConnection *)conn certificate:(MLCertificate *)cert storedDigest:(NSString *)storedDigest attempt:(NSUInteger)attempt {
    NSString *serverDigest=cert.hexDigest;
    __weak MUConnectionController *weakSelf=self;
    BOOL (^currentCertificate)(void)=^BOOL{
        MUConnectionController *owner=weakSelf;
        return owner && owner->_connection==conn && attempt==owner->_connectionAttempt && [cert.certificate isEqual:conn.peerCertificates.firstObject.certificate];
    };
    void (^cancelHandler)(UIAlertAction * _Nonnull action) = ^(UIAlertAction * _Nonnull action) {
        if(!currentCertificate())return;
        [weakSelf disconnectFromServer];
    };
    void (^ignoreHandler)(UIAlertAction * _Nonnull action) = ^(UIAlertAction * _Nonnull action) {
        if(!currentCertificate())return;
        // Ignore just reconnects to the server without
        // performing any verification on the certificate chain
        // the server presents us.
        [conn setIgnoreSSLVerification:YES];
        [conn reconnect];
        [weakSelf showConnectingView];
    };
    void (^trustHandler)(UIAlertAction * _Nonnull action) = ^(UIAlertAction * _Nonnull action) {
        if(!currentCertificate())return;
        NSString *digest=cert.hexDigest;NSString *hostname=[conn.hostname copy];NSUInteger port=conn.port;
        [conn setIgnoreSSLVerification:YES];[weakSelf showConnectingView];
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
            [MUDatabase storeDigest:digest forServerWithHostname:hostname port:port];
            dispatch_async(dispatch_get_main_queue(),^{if(currentCertificate())[conn reconnect];});
        });
    };
    void (^showCertsHandler)(UIAlertAction * _Nonnull action) = ^(UIAlertAction * _Nonnull action) {
        if(!currentCertificate())return;
        MUConnectionController *owner=weakSelf;if(!owner)return;
        MUServerCertificateTrustViewController *certTrustView = [[MUServerCertificateTrustViewController alloc] initWithCertificates:conn.peerCertificates];
        [certTrustView setDelegate:owner];
        UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:certTrustView];
        owner->_trustView=certTrustView;
        [owner->_presentation presentViewController:navCtrl whileCurrent:currentCertificate];
    };
    
    if (storedDigest) {
        if ([storedDigest isEqualToString:serverDigest]) {
            // Match
            [conn setIgnoreSSLVerification:YES];
            [weakSelf showConnectingView];
            [conn reconnect];
            return;
        } else {
            // Mismatch.  The server is using a new certificate, different from the one it previously
            // presented to us.
            NSString *title = NSLocalizedString(@"Certificate Mismatch", nil);
            NSString *msg = NSLocalizedString(@"The server presented a different certificate than the one stored for this server", nil);
            
            UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                                               message:msg
                                                                        preferredStyle:UIAlertControllerStyleAlert];
            
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:cancelHandler]];
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Ignore", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:ignoreHandler]];
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Trust New Certificate", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:trustHandler]];
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Show Certificates", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:showCertsHandler]];
            
            [self hideConnectingViewWithCompletion:^{
                MUConnectionController *owner=weakSelf;if(owner)[owner->_presentation presentAlert:alertCtrl whileCurrent:currentCertificate];
            }];
        }
    } else {
        // No certhash of this certificate in the database for this hostname-port combo.  Let the user decide
        // what to do.
        NSString *title = NSLocalizedString(@"Unable to validate server certificate", nil);
        NSString *msg = NSLocalizedString(@"Mumble was unable to validate the certificate chain of the server.", nil);
        
        UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                                           message:msg
                                                                    preferredStyle:UIAlertControllerStyleAlert];
        
        [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                       style:UIAlertActionStyleCancel
                                                     handler:cancelHandler]];
        [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Ignore", nil)
                                                       style:UIAlertActionStyleDefault
                                                     handler:ignoreHandler]];
        [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Trust Certificate", nil)
                                                       style:UIAlertActionStyleDefault
                                                     handler:trustHandler]];
        [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Show Certificates", nil)
                                                       style:UIAlertActionStyleDefault
                                                     handler:showCertsHandler]];
        
        [self hideConnectingViewWithCompletion:^{
            MUConnectionController *owner=weakSelf;if(owner)[owner->_presentation presentAlert:alertCtrl whileCurrent:currentCertificate];
        }];
    }
}

// The server rejected our connection.
- (UIAlertController *)passwordAlertForReason:(MLRejectReason)reason attempt:(NSUInteger)attempt {
    BOOL serverPassword = reason == MLRejectReasonWrongServerPassword;
    NSString *title = serverPassword ? (_password.length ? NSLocalizedString(@"Incorrect Password", nil) : NSLocalizedString(@"Password Required", nil)) : NSLocalizedString(@"Authentication Required", nil);
    NSString *message = serverPassword ? [NSString stringWithFormat:NSLocalizedString(@"Enter the server password to connect to %@.", nil), _hostname] : NSLocalizedString(@"Enter the password for this user, or check your certificate.", nil);
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.secureTextEntry = YES;
        field.textContentType = UITextContentTypePassword;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.placeholder = NSLocalizedString(@"Password", nil);
        [field addTarget:self action:@selector(rejectionPasswordChanged:) forControlEvents:UIControlEventEditingChanged];
    }];
    __weak MUConnectionController *weakSelf = self;
    __weak UIAlertController *weakAlert = alert;
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        MUConnectionController *controller = weakSelf;
        if (!controller || attempt != controller->_connectionAttempt) return;
        controller->_savePasswordOnJoin = NO;
        [controller disconnectFromServer];
    }]];
    for (NSNumber *save in @[@NO, @YES]) {
        UIAlertAction *connect = [UIAlertAction actionWithTitle:save.boolValue ? NSLocalizedString(@"Save and Connect", nil) : NSLocalizedString(@"Connect Once", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            MUConnectionController *controller = weakSelf;
            NSString *password = [weakAlert.textFields.firstObject.text copy];
            if (!controller || attempt != controller->_connectionAttempt || !password.length) return;
            controller->_password = password;
            controller->_savePasswordOnJoin = save.boolValue;
            controller->_rejectAlertCtrl = nil;
            [controller establishConnection];
            [controller showConnectingView];
        }];
        connect.enabled = NO;
        [alert addAction:connect];
    }
    return alert;
}

- (void)rejectionPasswordChanged:(UITextField *)field {
    if (field != _rejectAlertCtrl.textFields.firstObject) return;
    for (UIAlertAction *action in _rejectAlertCtrl.actions) {
        if (action.style != UIAlertActionStyleCancel) action.enabled = field.text.length > 0;
    }
}

- (void) connection:(MLConnection *)conn rejectedWithReason:(MLRejectReason)reason explanation:(NSString *)explanation {
    if (conn != _connection) return;
    if(_joinedSession){[self showTerminalErrorWithTitle:NSLocalizedString(@"Connection Rejected",nil) message:explanation.length ? explanation : NSLocalizedString(@"Authentication failed",nil)];return;}
    NSUInteger attempt = _connectionAttempt;
    _savePasswordOnJoin = NO;
    NSString *title = NSLocalizedString(@"Connection Rejected", nil);
    NSString *msg = nil;
    UIAlertController *alertCtrl = nil;
    
    __weak MUConnectionController *weakSelf=self;
    void (^cancelHandler)(UIAlertAction * _Nonnull action) = ^(UIAlertAction * _Nonnull action) {
        MUConnectionController *owner=weakSelf;if(!owner || attempt!=owner->_connectionAttempt)return;
        [owner disconnectFromServer];
    };
    void (^reconnectHandler)(UIAlertAction * _Nonnull action) = ^(UIAlertAction * _Nonnull action) {
        MUConnectionController *owner=weakSelf;if(!owner || attempt!=owner->_connectionAttempt)return;
        owner->_username=[owner->_rejectAlertCtrl.textFields.firstObject.text copy];owner->_rejectAlertCtrl=nil;
        [owner establishConnection];[owner showConnectingView];
    };
    void (^usernameConfigHandler)(UITextField * _Nonnull textField) = ^(UITextField * _Nonnull textField) {
        MUConnectionController *owner=weakSelf;[textField setText:owner ? owner->_username : nil];
    };
    [self teardownConnection];
    [self transitionToState:MUConnectionStateAwaitingCredentials];
    
    switch (reason) {
        case MLRejectReasonAuthenticatorFailure:
            msg = explanation.length ? explanation : NSLocalizedString(@"Authentication failed", nil);
            alertCtrl = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
            [alertCtrl addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleCancel handler:cancelHandler]];
            break;
        case MLRejectReasonNone:
            msg = NSLocalizedString(@"No reason", nil);
            
            alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                            message:msg
                                                     preferredStyle:UIAlertControllerStyleAlert];
            
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:cancelHandler]];
            break;
        case MLRejectReasonWrongVersion:
            msg = NSLocalizedString(@"Client/server version mismatch", nil);
            
            alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                            message:msg
                                                     preferredStyle:UIAlertControllerStyleAlert];
            
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:cancelHandler]];
            break;
        case MLRejectReasonInvalidUsername:
            msg = NSLocalizedString(@"Invalid username", nil);
            
            alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                            message:msg
                                                     preferredStyle:UIAlertControllerStyleAlert];
            
            [alertCtrl addTextFieldWithConfigurationHandler:usernameConfigHandler];
            
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:cancelHandler]];
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Reconnect", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:reconnectHandler]];
            break;
        case MLRejectReasonWrongUserPassword:
        case MLRejectReasonWrongServerPassword:
            alertCtrl = [self passwordAlertForReason:reason attempt:attempt];
            break;
        case MLRejectReasonUsernameInUse:
            msg = NSLocalizedString(@"Username already in use", nil);
            
            alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                            message:msg
                                                     preferredStyle:UIAlertControllerStyleAlert];
            
            [alertCtrl addTextFieldWithConfigurationHandler:usernameConfigHandler];
            
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:cancelHandler]];
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Reconnect", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:reconnectHandler]];
            break;
        case MLRejectReasonServerIsFull:
            msg = NSLocalizedString(@"Server is full", nil);
            
            alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                            message:msg
                                                     preferredStyle:UIAlertControllerStyleAlert];
            
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:cancelHandler]];
            break;
        case MLRejectReasonNoCertificate:
            msg = NSLocalizedString(@"A certificate is needed to connect to this server", nil);
            
            alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                            message:msg
                                                     preferredStyle:UIAlertControllerStyleAlert];
            
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:cancelHandler]];
            break;
    }

    _rejectAlertCtrl = alertCtrl;

    [self hideConnectingViewWithCompletion:^{
        [self presentConnectionAlert:alertCtrl forAttempt:attempt];
    }];
}

#pragma mark - MLServerModelDelegate

- (void)serverModel:(MLServerModel *)model joinedServerAsUser:(MLUser *)user {
    if(model!=_serverModel || _joinedSession || _connection.isRestoringSession)return;
    _joinedSession=YES;_connection.automaticReconnectEnabled=YES;
    [self transitionToState:MUConnectionStateConnected];
    BOOL save=_savePasswordOnJoin;NSInteger key=_favouritePrimaryKey;
    NSString *hostname=[_hostname copy],*password=[_password copy],*displayName=[_displayName copy],*username=[user.userName copy];NSUInteger port=_port;
    _savePasswordOnJoin=NO;_password=nil;_username=nil;_hostname=nil;_displayName=nil;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
        if(save && password.length){
            if(key>=0)[MUDatabase storePassword:password forFavouriteWithPrimaryKey:key];
            else [MUDatabase storeFavourite:[[MUFavouriteServer alloc]initWithDisplayName:hostname hostName:hostname port:port userName:username password:password]];
        }
        [MUDatabase storeUsername:username forServerWithHostname:hostname port:port];
        [MUDatabase recordRecentServerWithHostname:hostname port:port displayName:displayName username:username];
    });
    NSUInteger attempt=_connectionAttempt;MLConnection *connection=_connection;MUServerRootViewController *root=_serverRoot;__weak MUConnectionController *weakSelf=self;
    [self hideConnectingViewWithCompletion:^{
        MUConnectionController *owner=weakSelf;
        if(!owner || attempt!=owner->_connectionAttempt || owner->_connection!=connection || !owner.hasActiveSession)return;
        root.modalPresentationStyle=UIModalPresentationFullScreen;
        // A certificate prompt may still be dismissing while the replacement
        // Connecting alert has not appeared yet. Serialize the server page
        // through the same presenter instead of racing UIKit's old modal.
        [owner->_presentation presentViewController:root whileCurrent:^BOOL{
            MUConnectionController *current=weakSelf;
            return current && attempt==current->_connectionAttempt && current->_connection==connection && current.hasActiveSession;
        }];
        owner->_parentViewController=nil;
    }];
}

- (void) serverCertificateTrustViewControllerDidDismiss:(MUServerCertificateTrustViewController *)trustView {
    if(!_connection || _state!=MUConnectionStateAwaitingCertificate || trustView!=_trustView)return;
    _trustView=nil;[self showConnectingView];
    [_connection reconnect];
}

@end
