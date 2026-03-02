// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUConnectionController.h"
#import "MUServerRootViewController.h"
#import "MUServerCertificateTrustViewController.h"
#import "MUCertificateController.h"
#import "MUCertificateChainBuilder.h"
#import "MUDatabase.h"
#import "MUFavouriteServer.h"
#import "MUHorizontalFlipTransitionDelegate.h"
#import "MUApplicationDelegate.h"
#import "MUServerPlaceholderViewController.h"

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
    [self teardownConnection];
    
    // Reset the Server tab back to the placeholder
    MUApplicationDelegate *appDelegate = (MUApplicationDelegate *)[[UIApplication sharedApplication] delegate];
    UITabBarController *tabBar = [appDelegate tabBarController];
    
    MUServerPlaceholderViewController *placeholder = [[MUServerPlaceholderViewController alloc] init];
    UINavigationController *serverNav = [[UINavigationController alloc] initWithRootViewController:placeholder];
    serverNav.toolbarHidden = YES;
    if (@available(iOS 13.0, *)) {
        serverNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Server", nil)
                                                            image:[UIImage systemImageNamed:@"server.rack"]
                                                              tag:1];
    } else {
        serverNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Server", nil) image:nil tag:1];
    }
    
    NSMutableArray *vcs = [tabBar.viewControllers mutableCopy];
    [vcs replaceObjectAtIndex:1 withObject:serverNav];
    tabBar.viewControllers = vcs;
    
    // Switch to Home tab
    tabBar.selectedIndex = 0;
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
        _alertCtrl = nil;
        [_parentViewController dismissViewControllerAnimated:YES completion:completion];
    } else if (completion) {
        completion();
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
    if (err) {
        UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Connection closed", nil)
                                                                           message:[err localizedDescription]
                                                                    preferredStyle:UIAlertControllerStyleAlert];
        
        [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                       style:UIAlertActionStyleCancel
                                                     handler:nil]];
        
        [self hideConnectingViewWithCompletion:^{
            [self->_parentViewController presentViewController:alertCtrl animated:YES completion:nil];
        }];
        
        [self teardownConnection];
    } else {
        [self hideConnectingView];
    }
}

- (void) connection:(MKConnection*)conn unableToConnectWithError:(NSError *)err {
    NSString *title = NSLocalizedString(@"Connection Failed", nil);
    NSString *msg = [err localizedDescription];

    if ([[err domain] isEqualToString:NSOSStatusErrorDomain] && [err code] == -9806) {
        msg = NSLocalizedString(@"The secure connection was interrupted.\n\n"
                                @"This usually means the server is temporarily blocking your connection. "
                                @"Wait a moment and try again.", nil);
    } else if ([[err domain] isEqualToString:NSPOSIXErrorDomain] && [err code] == 61) {
        msg = NSLocalizedString(@"Could not reach the server. Check that the address and port are correct, "
                                @"and that the server is online.", nil);
    } else if ([[err domain] isEqualToString:NSPOSIXErrorDomain] && [err code] == 60) {
        msg = NSLocalizedString(@"The connection timed out. Check your internet connection and the server address.", nil);
    }
    
    UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                                       message:msg
                                                                preferredStyle:UIAlertControllerStyleAlert];
    
    [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                   style:UIAlertActionStyleCancel
                                                 handler:nil]];
    
    [self hideConnectingViewWithCompletion:^{
        [self->_parentViewController presentViewController:alertCtrl animated:YES completion:nil];
    }];
    
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
                [self->_parentViewController presentViewController:alertCtrl animated:YES completion:nil];
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
            [self->_parentViewController presentViewController:alertCtrl animated:YES completion:nil];
        }];
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
    
    [self teardownConnection];
    
    switch (reason) {
        case MKRejectReasonNone:
            msg = NSLocalizedString(@"The server rejected the connection without a specific reason. Please try again later.", nil);
            
            alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                            message:msg
                                                     preferredStyle:UIAlertControllerStyleAlert];
            
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:cancelHandler]];
            break;
        case MKRejectReasonWrongVersion:
            msg = NSLocalizedString(@"This server requires a different version of Mumble. Please update the app and try again.", nil);
            
            alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                            message:msg
                                                     preferredStyle:UIAlertControllerStyleAlert];
            
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:cancelHandler]];
            break;
        case MKRejectReasonInvalidUsername:
            title = NSLocalizedString(@"Invalid Username", nil);
            msg = NSLocalizedString(@"The username you entered is not allowed on this server. Please choose a different one.", nil);
            
            alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                            message:msg
                                                     preferredStyle:UIAlertControllerStyleAlert];
            
            [alertCtrl addTextFieldWithConfigurationHandler:usernameConfigHandler];
            
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:cancelHandler]];
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:reconnectHandler]];
            break;
        case MKRejectReasonWrongUserPassword:
            title = NSLocalizedString(@"Authentication Failed", nil);
            msg = NSLocalizedString(@"The password is incorrect, or this username is registered with a different certificate. Please check your password and try again.", nil);
            
            alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                            message:msg
                                                     preferredStyle:UIAlertControllerStyleAlert];
            
            [alertCtrl addTextFieldWithConfigurationHandler:passwordConfigHandler];
            
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:cancelHandler]];
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:reconnectHandler]];
            break;
        case MKRejectReasonWrongServerPassword:
            title = NSLocalizedString(@"Server Password Required", nil);
            msg = NSLocalizedString(@"This server is password-protected. Please enter the correct password to connect.", nil);
            
            alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                            message:msg
                                                     preferredStyle:UIAlertControllerStyleAlert];
            
            [alertCtrl addTextFieldWithConfigurationHandler:passwordConfigHandler];
            
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:cancelHandler]];
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:reconnectHandler]];
            break;
        case MKRejectReasonUsernameInUse:
            title = NSLocalizedString(@"Username Taken", nil);
            msg = NSLocalizedString(@"Someone is already using that name on this server. Please choose a different username.", nil);
            
            alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                            message:msg
                                                     preferredStyle:UIAlertControllerStyleAlert];
            
            [alertCtrl addTextFieldWithConfigurationHandler:usernameConfigHandler];
            
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:cancelHandler]];
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:reconnectHandler]];
            break;
        case MKRejectReasonServerIsFull:
            title = NSLocalizedString(@"Server Full", nil);
            msg = NSLocalizedString(@"This server has reached its maximum number of users. Please try again later.", nil);
            
            alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                            message:msg
                                                     preferredStyle:UIAlertControllerStyleAlert];
            
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:cancelHandler]];
            break;
        case MKRejectReasonNoCertificate:
            title = NSLocalizedString(@"Certificate Required", nil);
            msg = NSLocalizedString(@"This server requires a client certificate to connect. Go to Preferences > Certificate to create or import one.", nil);
            
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

    [self hideConnectingViewWithCompletion:^{
        [self->_parentViewController presentViewController:alertCtrl animated:YES completion:nil];
    }];
}

#pragma mark - MKServerModelDelegate

- (void) serverModel:(MKServerModel *)model joinedServerAsUser:(MKUser *)user {
    [MUDatabase storeUsername:[user userName] forServerWithHostname:[model hostname] port:[model port]];

    // Record in connection history
    [MUDatabase storeRecentConnectionWithHostname:[model hostname] port:[model port] username:[user userName]];

    // Auto-save to favourites if not already saved
    [self autoSaveToFavouritesWithHostname:[model hostname] port:[model port] username:[user userName]];

    // Haptic feedback on successful connection
    if (@available(iOS 10.0, *)) {
        UINotificationFeedbackGenerator *feedback = [[UINotificationFeedbackGenerator alloc] init];
        [feedback notificationOccurred:UINotificationFeedbackTypeSuccess];
    }

    [self hideConnectingViewWithCompletion:^{
        [self->_serverRoot takeOwnershipOfConnectionDelegate];

        self->_username = nil;
        self->_hostname = nil;
        self->_password = nil;
        
        // Switch to Server tab with the connected server view
        MUApplicationDelegate *appDelegate = (MUApplicationDelegate *)[[UIApplication sharedApplication] delegate];
        UITabBarController *tabBar = [appDelegate tabBarController];
        
        // Preserve the tab bar item
        if (@available(iOS 13.0, *)) {
            self->_serverRoot.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Server", nil)
                                                                        image:[UIImage systemImageNamed:@"server.rack"]
                                                                          tag:1];
        } else {
            self->_serverRoot.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Server", nil) image:nil tag:1];
        }
        
        NSMutableArray *vcs = [tabBar.viewControllers mutableCopy];
        [vcs replaceObjectAtIndex:1 withObject:self->_serverRoot];
        tabBar.viewControllers = vcs;
        tabBar.selectedIndex = 1;
        
        self->_parentViewController = nil;
    }];
}

- (void) autoSaveToFavouritesWithHostname:(NSString *)hostname port:(NSInteger)port username:(NSString *)username {
    NSMutableArray *favourites = [MUDatabase fetchAllFavourites];
    for (MUFavouriteServer *fav in favourites) {
        if ([[fav hostName] isEqualToString:hostname] && [fav port] == (NSUInteger)port) {
            return; // Already saved
        }
    }
    
    MUFavouriteServer *newFav = [[MUFavouriteServer alloc] init];
    [newFav setDisplayName:hostname];
    [newFav setHostName:hostname];
    [newFav setPort:port];
    [newFav setUserName:username];
    [MUDatabase storeFavourite:newFav];
}

- (void) serverCertificateTrustViewControllerDidDismiss:(MUServerCertificateTrustViewController *)trustView {
    [self showConnectingView];
    [_connection reconnect];
}

@end
