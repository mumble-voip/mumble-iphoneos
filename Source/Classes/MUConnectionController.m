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

    NSString                   *_saved_hostname;
    NSUInteger                 _saved_port;
    NSString                   *_saved_username;
    NSString                   *_saved_password;

    id                         _transitioningDelegate;
}
- (void) establishConnection;
- (void) teardownConnection;
- (void) showConnectingView;
- (void) hideConnectingViewWithCompletion:(void(^)(void))completion;

- (void) teardownAfterShowingErrorWithTimeout:(NSError*) err;
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

- (void) connectToHostname:(NSString *)hostName port:(NSUInteger)port withUsername:(NSString *)userName andPassword:(NSString *)password withParentViewController:(UIViewController *)parentViewController {
    _hostname = hostName;
    _port = port;
    _username = userName;
    _password = password;

    _saved_hostname = hostName;
    _saved_port = port;
    _saved_username = userName;
    _saved_password = password;

    _parentViewController = parentViewController;
    
    [_connection setDelegate:self];
    
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

- (void) dismissServerRootWithCompletion:(void (^)(void))completion {
    if (!self->_serverRoot) {
        completion();
        return;
    }
    
    if (!self->_serverRoot.viewLoaded || !self->_serverRoot.view.window) {
        completion();
        return;
    }
    
    [self->_serverRoot dismissViewControllerAnimated:YES completion:completion];
}

- (void) teardownAfterShowingErrorWithTimeout:(NSError*) err {
    UIViewController* parentView = [[UIApplication sharedApplication] keyWindow].rootViewController;

    [self dismissServerRootWithCompletion:^{
        [self hideConnectingViewWithCompletion:^{
            NSString *errMsg = [err localizedDescription];
            
            if ([[err domain] isEqualToString:NSOSStatusErrorDomain] && [err code] == -9806) {
                errMsg = NSLocalizedString(@"The TLS connection was closed due to an error.\n\n"
                                           @"The server might be temporarily rejecting your connection because you have "
                                           @"attempted to connect too many times in a row.", nil);
            }
            
            NSString *title = [NSString stringWithFormat:@"%@...", NSLocalizedString(@"Error", @"Oops, something is wrong...")];
            NSString *msg = [NSString stringWithFormat:
                             NSLocalizedString(@"Connecting to %@:%lu\n\n%@", @"Connecting to hostname:port"),
                             _saved_hostname, (unsigned long)_saved_port, errMsg];
            
            UIAlertController* alertCtrl = [UIAlertController           alertControllerWithTitle:title
                                                                        message:msg
                                                                        preferredStyle:UIAlertControllerStyleAlert];
            
            __block NSTimer* timer = nil;
            
            UIAlertAction* retryAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Retry", @"Retry") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [timer invalidate];
                [parentView dismissViewControllerAnimated:YES completion:^{
                    [self->_serverRoot dismissViewControllerAnimated:YES completion:nil];
                    [self teardownConnection];
                    
                    [self connectToHostname:_saved_hostname port:_saved_port withUsername:_saved_username andPassword:_saved_password withParentViewController:_parentViewController];
                }];
            }];
            
            UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Close", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                
                self->_saved_hostname = nil;
                self->_saved_password = nil;
                self->_saved_username = nil;
                self->_saved_port = 0;
                
                [parentView dismissViewControllerAnimated:YES completion:^{
                    [timer invalidate];
                    [parentView removeFromParentViewController];
                    
                    [self->_serverRoot dismissViewControllerAnimated:YES completion:nil];
                    [self teardownConnection];
                }];
            }];
            
            [alertCtrl addAction: retryAction];
            [alertCtrl addAction: cancelAction];
            
            [parentView presentViewController:alertCtrl animated:YES completion:nil];

            long MAX_SECONDS = 10 + 1;

            NSString* newTitle = [NSString stringWithFormat:NSLocalizedString(@"Retry (%ld)", "Retry (%@)"), (long)MAX_SECONDS];
            [retryAction setValue:newTitle forKey:@"title"];

            NSDate* startTime = [NSDate now];
            timer = [NSTimer scheduledTimerWithTimeInterval:0.2f repeats:YES block:^(NSTimer * _Nonnull timer) {
                NSTimeInterval interval = [[NSDate now] timeIntervalSinceDate:startTime];
                        
                NSInteger seconds = floor(MAX_SECONDS - interval);
                
                NSString* newTitle = [NSString stringWithFormat:NSLocalizedString(@"Retry (%ld)", "Retry (%@)"), (long)seconds];
                        
                if (seconds <= 0) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [parentView dismissViewControllerAnimated:YES completion:^{
                            [timer invalidate];
                            [parentView removeFromParentViewController];
                            
                            [self->_serverRoot dismissViewControllerAnimated:YES completion:nil];
                            [self teardownConnection];

                            [self connectToHostname:_saved_hostname port:_saved_port withUsername:_saved_username andPassword:_saved_password withParentViewController:_parentViewController];
                        }];
                    });
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [retryAction setValue:newTitle forKey:@"title"];
                    });
                }
            }];
        }];
    }];
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

- (void) hideConnectingViewWithCompletion:(void (^)(void))completion {
    [_timer invalidate];
    _timer = nil;

    if (_alertCtrl != nil) {
        [_parentViewController dismissViewControllerAnimated:YES completion:completion];
        _alertCtrl = nil;
    } else {
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
    // This should not be executed
    [self hideConnectingViewWithCompletion:^{
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
    }];
}

- (void) connection:(MKConnection*)conn unableToConnectWithError:(NSError *)err {
    // Will be handled by [MUIServerRootViewController unableToConnectWithError]
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
            [self hideConnectingViewWithCompletion:^{
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
            }];
        }
    } else {
        // No certhash of this certificate in the database for this hostname-port combo.  Let the user decide
        // what to do.
        [self hideConnectingViewWithCompletion:^{
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
            
            [self->_parentViewController presentViewController:alertCtrl animated:YES completion:nil];
        }];
    }
}

// The server rejected our connection.
- (void) connection:(MKConnection *)conn rejectedWithReason:(MKRejectReason)reason explanation:(NSString *)explanation {
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
    
    [self hideConnectingViewWithCompletion:^{
        NSString *title = NSLocalizedString(@"Connection Rejected", nil);
        NSString *msg = nil;
        UIAlertController *alertCtrl = nil;

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

        self->_rejectAlertCtrl = alertCtrl;
        self->_rejectReason = reason;

        [self->_parentViewController presentViewController:alertCtrl animated:YES completion:nil];
    }];
}

#pragma mark - MKServerModelDelegate

- (void) serverModel:(MKServerModel *)model joinedServerAsUser:(MKUser *)user {
    [MUDatabase storeUsername:[user userName] forServerWithHostname:[model hostname] port:[model port]];

    MUConnectionController* this = self;
    
    [this hideConnectingViewWithCompletion:^{
        [this->_serverRoot takeOwnershipOfConnectionDelegate];

        this->_username = nil;
        this->_hostname = nil;
        this->_password = nil;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            this->_serverRoot.modalPresentationStyle = UIModalPresentationFullScreen;
            [[this->_parentViewController navigationController] presentViewController:self->_serverRoot animated:YES completion:nil];
            //self->_parentViewController = nil;
        });
    }];
}

- (void) serverCertificateTrustViewControllerDidDismiss:(MUServerCertificateTrustViewController *)trustView {
    [self showConnectingView];
    [_connection reconnect];
}

@end
