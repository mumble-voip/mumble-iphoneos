// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUConnectionController.h"
#import "MUServerRootViewController.h"
#import "MUServerCertificateTrustViewController.h"
#import "MUCertificateController.h"
#import "MUCertificateChainBuilder.h"
#import "MUDatabase.h"
#import "MUHorizontalFlipTransitionDelegate.h"

#import <MumbleKit/MKConnection.h>
#import <MumbleKit/MKServerModel.h>
#import <MumbleKit/MKCertificate.h>

NSString *MUConnectionOpenedNotification = @"MUConnectionOpenedNotification";
NSString *MUConnectionClosedNotification = @"MUConnectionClosedNotification";

@interface MUConnectionController () <MKConnectionDelegate, MKServerModelDelegate, MUServerCertificateTrustViewControllerProtocol> {
    MKConnection               *_connection;
    MKServerModel              *_serverModel;
    MUServerRootViewController *_serverRoot;
    UIViewController           *_parentViewController;
    UIAlertController          *_alertCtrl;
    NSTimer                    *_timer;
    int                        _numDots;

    UIAlertController          *_rejectAlertCtrl;
    MKRejectReason             _rejectReason;

    NSString                   *_hostname;
    NSUInteger                 _port;
    NSString                   *_username;
    NSString                   *_password;

    id                         _transitioningDelegate;
}
- (void) establishConnection;
- (void) teardownConnection;
- (void) showConnectingView;
- (void) hideConnectingView;
- (void) hideConnectingViewWithCompletion:(void(^)(void))completion;
@end

@implementation MUConnectionController

+ (MUConnectionController *) sharedController {
    static MUConnectionController *nc;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        nc = [[MUConnectionController alloc] init];
    });
    return nc;
}

- (id) init {
    if ((self = [super init])) {
        if (@available(iOS 7, *)) {
            _transitioningDelegate = [[MUHorizontalFlipTransitionDelegate alloc] init];
        }
    }
    return self;
}

- (void) connetToHostname:(NSString *)hostName port:(NSUInteger)port withUsername:(NSString *)userName andPassword:(NSString *)password withParentViewController:(UIViewController *)parentViewController {
    _hostname = hostName;
    _port = port;
    _username = userName;
    _password = password;
    
    _parentViewController = parentViewController;
    
    [self showConnectingView];
    [self establishConnection];
}

- (BOOL) isConnected {
    return _connection != nil;
}

- (void) disconnectFromServer {
    [_serverRoot dismissViewControllerAnimated:YES completion:nil];
    [self teardownConnection];
}

- (void) showConnectingView {
    NSString *title = [NSString stringWithFormat:@"%@...", NSLocalizedString(@"Connecting", nil)];
    NSString *msg = [NSString stringWithFormat:
                     NSLocalizedString(@"Connecting to %@:%lu", @"Connecting to hostname:port"),
                     _hostname, (unsigned long)_port];
    
    _alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                     message:msg
                                              preferredStyle:UIAlertControllerStyleAlert];
    [_alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            [self teardownConnection];
    }]];
    [_parentViewController presentViewController:_alertCtrl animated:YES completion:nil];
    
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.2f target:self selector:@selector(updateTitle) userInfo:nil repeats:YES];
}

- (void) hideConnectingView {
    [self hideConnectingViewWithCompletion:nil];
}

- (void) hideConnectingViewWithCompletion:(void (^)(void))completion {
    [_timer invalidate];
    _timer = nil;

    if (_alertCtrl != nil) {
        [_parentViewController dismissViewControllerAnimated:YES completion:completion];
        _alertCtrl = nil;
    }
}

- (void) establishConnection {
    _connection = [[MKConnection alloc] init];
    [_connection setDelegate:self];
    [_connection setForceTCP:[[NSUserDefaults standardUserDefaults] boolForKey:@"NetworkForceTCP"]];
    
    _serverModel = [[MKServerModel alloc] initWithConnection:_connection];
    [_serverModel addDelegate:self];
    
    _serverRoot = [[MUServerRootViewController alloc] initWithConnection:_connection andServerModel:_serverModel];
    
    // Set the connection's client cert if one is set in the app's preferences...
    NSData *certPersistentId = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultCertificate"];
    if (certPersistentId != nil) {
        NSArray *certChain = [MUCertificateChainBuilder buildChainFromPersistentRef:certPersistentId];
        [_connection setCertificateChain:certChain];
    }
    
    [_connection connectToHost:_hostname port:_port];

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:MUConnectionOpenedNotification object:nil];
    });
}

- (void) teardownConnection {
    [_serverModel removeDelegate:self];
    _serverModel = nil;
    [_connection setDelegate:nil];
    [_connection disconnect];
    _connection = nil;
    [_timer invalidate];
    _serverRoot = nil;
    
    // Reset app badge. The connection is no more.
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:MUConnectionClosedNotification object:nil];
    });
}
            
- (void) updateTitle {
    ++_numDots;
    if (_numDots > 3)
        _numDots = 0;

    NSString *dots = @"   ";
    if (_numDots == 1) { dots = @".  "; }
    if (_numDots == 2) { dots = @".. "; }
    if (_numDots == 3) { dots = @"..."; }
    
    [_alertCtrl setTitle:[NSString stringWithFormat:@"%@%@", NSLocalizedString(@"Connecting", nil), dots]];
}

#pragma mark - MKConnectionDelegate

- (void) connectionOpened:(MKConnection *)conn {
    NSArray *tokens = [MUDatabase accessTokensForServerWithHostname:[conn hostname] port:[conn port]];
    [conn authenticateWithUsername:_username password:_password accessTokens:tokens];
}

- (void) connection:(MKConnection *)conn closedWithError:(NSError *)err {
    [self hideConnectingView];
    if (err) {
        UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Connection closed", nil)
                                                                           message:[err localizedDescription]
                                                                    preferredStyle:UIAlertControllerStyleAlert];
        
        [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                       style:UIAlertActionStyleCancel
                                                     handler:nil]];
        
        [_parentViewController presentViewController:alertCtrl animated:YES completion:nil];
        
        [self teardownConnection];
    }
}

- (void) connection:(MKConnection*)conn unableToConnectWithError:(NSError *)err {
    [self hideConnectingView];

    NSString *msg = [err localizedDescription];

    // errSSLClosedAbort: "connection closed via error".
    //
    // This is the error we get when users hit a global ban on the server.
    // Ideally, we'd provide better descriptions for more of these errors,
    // but when using NSStream's TLS support, the NSErrors we get are simply
    // OSStatus codes in an NSError wrapper without a useful description.
    //
    // In the future, MumbleKit should probably wrap the SecureTransport range of
    // OSStatus codes to improve this situation, but this will do for now.
    if ([[err domain] isEqualToString:NSOSStatusErrorDomain] && [err code] == -9806) {
        msg = NSLocalizedString(@"The TLS connection was closed due to an error.\n\n"
                                @"The server might be temporarily rejecting your connection because you have "
                                @"attempted to connect too many times in a row.", nil);
    }
    
    UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Unable to connect", nil)
                                                                       message:msg
                                                                preferredStyle:UIAlertControllerStyleAlert];
    
    [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                   style:UIAlertActionStyleCancel
                                                 handler:nil]];
    
    [_parentViewController presentViewController:alertCtrl animated:YES completion:nil];
    
    [self teardownConnection];
}

// The connection encountered an invalid SSL certificate chain.
- (void) connection:(MKConnection *)conn trustFailureInCertificateChain:(NSArray *)chain {
    // Check the database whether the user trusts the leaf certificate of this server.
    NSString *storedDigest = [MUDatabase digestForServerWithHostname:[conn hostname] port:[conn port]];
    MKCertificate *cert = [[conn peerCertificates] firstObject];
    NSString *serverDigest = [cert hexDigest];
    
    void (^cancelHandler)(UIAlertAction * _Nonnull action) = ^(UIAlertAction * _Nonnull action) {
        // Tear down the connection.
        [self teardownConnection];
    };
    void (^ignoreHandler)(UIAlertAction * _Nonnull action) = ^(UIAlertAction * _Nonnull action) {
        // Ignore just reconnects to the server without
        // performing any verification on the certificate chain
        // the server presents us.
        [self->_connection setIgnoreSSLVerification:YES];
        [self->_connection reconnect];
        [self showConnectingView];
    };
    void (^trustHandler)(UIAlertAction * _Nonnull action) = ^(UIAlertAction * _Nonnull action) {
        // Store the cert hash of the leaf certificate.  We then ignore certificate
        // verification errors from this host as long as it keeps on presenting us
        // the same certificate it always has.
        MKCertificate *cert = [[self->_connection peerCertificates] objectAtIndex:0];
        NSString *digest = [cert hexDigest];
        [MUDatabase storeDigest:digest forServerWithHostname:[self->_connection hostname] port:[self->_connection port]];
        [self->_connection setIgnoreSSLVerification:YES];
        [self->_connection reconnect];
        [self showConnectingView];
    };
    void (^showCertsHandler)(UIAlertAction * _Nonnull action) = ^(UIAlertAction * _Nonnull action) {
        MUServerCertificateTrustViewController *certTrustView = [[MUServerCertificateTrustViewController alloc] initWithCertificates:[self->_connection peerCertificates]];
        [certTrustView setDelegate:self];
        UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:certTrustView];
        [self->_parentViewController presentViewController:navCtrl animated:YES completion:nil];
    };
    
    if (storedDigest) {
        if ([storedDigest isEqualToString:serverDigest]) {
            // Match
            [conn setIgnoreSSLVerification:YES];
            [conn reconnect];
            return;
        } else {
            // Mismatch.  The server is using a new certificate, different from the one it previously
            // presented to us.
            [self hideConnectingView];
            
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
            
            [_parentViewController presentViewController:alertCtrl animated:YES completion:nil];
        }
    } else {
        // No certhash of this certificate in the database for this hostname-port combo.  Let the user decide
        // what to do.
        [self hideConnectingView];
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
        
        [_parentViewController presentViewController:alertCtrl animated:YES completion:nil];
    }
}

// The server rejected our connection.
- (void) connection:(MKConnection *)conn rejectedWithReason:(MKRejectReason)reason explanation:(NSString *)explanation {
    NSString *title = NSLocalizedString(@"Connection Rejected", nil);
    NSString *msg = nil;
    UIAlertController *alertCtrl = nil;
    
    void (^cancelHandler)(UIAlertAction * _Nonnull action) = ^(UIAlertAction * _Nonnull action) {
        if (self->_rejectReason == MKRejectReasonInvalidUsername || self->_rejectReason == MKRejectReasonUsernameInUse) {
            UITextField *textField = [[self->_rejectAlertCtrl textFields] firstObject];
            self->_username = [[textField text] copy];
        } else if (self->_rejectReason == MKRejectReasonWrongServerPassword || self->_rejectReason == MKRejectReasonWrongUserPassword) {
            UITextField *textField = [[self->_rejectAlertCtrl textFields] firstObject];
            self->_password = [[textField text] copy];
        }
        
        // Rejection handler has already handled the teardown for us.
    };
    void (^reconnectHandler)(UIAlertAction * _Nonnull action) = ^(UIAlertAction * _Nonnull action) {
        if (self->_rejectReason == MKRejectReasonInvalidUsername || self->_rejectReason == MKRejectReasonUsernameInUse) {
            UITextField *textField = [[self->_rejectAlertCtrl textFields] firstObject];
            self->_username = [[textField text] copy];
        } else if (self->_rejectReason == MKRejectReasonWrongServerPassword || self->_rejectReason == MKRejectReasonWrongUserPassword) {
            UITextField *textField = [[self->_rejectAlertCtrl textFields] firstObject];
            self->_password = [[textField text] copy];
        }
        
        [self establishConnection];
        [self showConnectingView];
    };
    void (^usernameConfigHandler)(UITextField * _Nonnull textField) = ^(UITextField * _Nonnull textField) {
        [textField setText:self->_username];
    };
    void (^passwordConfigHandler)(UITextField * _Nonnull textField) = ^(UITextField * _Nonnull textField) {
        [textField setSecureTextEntry:YES];
        [textField setText:self->_password];
    };
    
    [self hideConnectingView];
    [self teardownConnection];
    
    switch (reason) {
        case MKRejectReasonNone:
            msg = NSLocalizedString(@"No reason", nil);
            
            alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                            message:msg
                                                     preferredStyle:UIAlertControllerStyleAlert];
            
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:cancelHandler]];
            break;
        case MKRejectReasonWrongVersion:
            msg = @"Client/server version mismatch";
            
            alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                            message:msg
                                                     preferredStyle:UIAlertControllerStyleAlert];
            
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:cancelHandler]];
            break;
        case MKRejectReasonInvalidUsername:
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
        case MKRejectReasonWrongUserPassword:
            msg = NSLocalizedString(@"Wrong certificate or password for existing user", nil);
            
            alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                            message:msg
                                                     preferredStyle:UIAlertControllerStyleAlert];
            
            [alertCtrl addTextFieldWithConfigurationHandler:passwordConfigHandler];
            
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:cancelHandler]];
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Reconnect", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:reconnectHandler]];
            break;
        case MKRejectReasonWrongServerPassword:
            msg = NSLocalizedString(@"Wrong server password", nil);
            
            alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                            message:msg
                                                     preferredStyle:UIAlertControllerStyleAlert];
            
            [alertCtrl addTextFieldWithConfigurationHandler:passwordConfigHandler];
            
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:cancelHandler]];
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Reconnect", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:reconnectHandler]];
            break;
        case MKRejectReasonUsernameInUse:
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
        case MKRejectReasonServerIsFull:
            msg = NSLocalizedString(@"Server is full", nil);
            
            alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                            message:msg
                                                     preferredStyle:UIAlertControllerStyleAlert];
            
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:cancelHandler]];
            break;
        case MKRejectReasonNoCertificate:
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
    _rejectReason = reason;

    [_parentViewController presentViewController:alertCtrl animated:YES completion:nil];
}

#pragma mark - MKServerModelDelegate

- (void) serverModel:(MKServerModel *)model joinedServerAsUser:(MKUser *)user {
    [MUDatabase storeUsername:[user userName] forServerWithHostname:[model hostname] port:[model port]];

    [self hideConnectingViewWithCompletion:^{
        [self->_serverRoot takeOwnershipOfConnectionDelegate];

        self->_username = nil;
        self->_hostname = nil;
        self->_password = nil;

        [[self->_parentViewController navigationController] presentViewController:self->_serverRoot animated:YES completion:nil];
        self->_parentViewController = nil;
    }];
}

- (void) serverCertificateTrustViewControllerDidDismiss:(MUServerCertificateTrustViewController *)trustView {
    [self showConnectingView];
    [_connection reconnect];
}

@end
