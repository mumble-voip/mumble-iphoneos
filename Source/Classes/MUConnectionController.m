/* Copyright (C) 2009-2011 Mikkel Krautz <mikkel@krautz.dk>

   All rights reserved.

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions
   are met:

   - Redistributions of source code must retain the above copyright notice,
     this list of conditions and the following disclaimer.
   - Redistributions in binary form must reproduce the above copyright notice,
     this list of conditions and the following disclaimer in the documentation
     and/or other materials provided with the distribution.
   - Neither the name of the Mumble Developers nor the names of its
     contributors may be used to endorse or promote products derived from this
     software without specific prior written permission.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
   ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
   A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR
   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "MUConnectionController.h"
#import "MUServerRootViewController.h"
#import "MUServerCertificateTrustViewController.h"
#import "MUCertificateController.h"
#import "MUCertificateChainBuilder.h"
#import "MUDatabase.h"

#import <MumbleKit/MKConnection.h>
#import <MumbleKit/MKServerModel.h>
#import <MumbleKit/MKCertificate.h>

@interface MUConnectionController () <MKConnectionDelegate, MKServerModelDelegate, MUServerCertificateTrustViewControllerProtocol> {
    MKConnection               *_connection;
    MKServerModel              *_serverModel;
    MUServerRootViewController *_serverRoot;
    UIViewController           *_parentViewController;
    UIAlertView                *_alertView;
    NSTimer                    *_timer;
    int                        _numDots;

    UIAlertView                *_rejectAlertView;
    MKRejectReason             _rejectReason;

    NSString                   *_hostname;
    NSUInteger                 _port;
    NSString                   *_username;
    NSString                   *_password;
}
- (void) establishConnection;
- (void) teardownConnection;
- (void) showConnectingView;
- (void) hideConnectingView;
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
        // ...
    }
    return self;
}

- (void) dealloc {
    [super dealloc];
}

- (void) connetToHostname:(NSString *)hostName port:(NSUInteger)port withUsername:(NSString *)userName andPassword:(NSString *)password withParentViewController:(UIViewController *)parentViewController {
    _hostname = [hostName retain];
    _port = port;
    _username = [userName retain];
    _password = [password retain];
    
    [self showConnectingView];
    [self establishConnection];
    
    _parentViewController = [parentViewController retain];
}

- (BOOL) isConnected {
    return _connection != nil;
}

- (void) disconnectFromServer {
    [_serverRoot dismissModalViewControllerAnimated:YES];
    [self teardownConnection];
}

- (void) showConnectingView {
    NSString *title = [NSString stringWithFormat:@"%@...", NSLocalizedString(@"Connecting", nil)];
    NSString *msg = [NSString stringWithFormat:
                        NSLocalizedString(@"Connecting to %@:%u", @"Connecting to hostname:port"),
                            _hostname, _port];
    
    _alertView = [[UIAlertView alloc] initWithTitle:title
                                            message:msg
                                           delegate:self
                                  cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                  otherButtonTitles:nil];
    [_alertView show];
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.2f target:self selector:@selector(updateTitle) userInfo:nil repeats:YES];
}

- (void) hideConnectingView {
    [_alertView dismissWithClickedButtonIndex:1 animated:NO];
    [_alertView release];
    _alertView = nil;
    [_timer invalidate];
    _timer = nil;
}
    
- (void) establishConnection {
    _connection = [[MKConnection alloc] init];
    [_connection setDelegate:self];
    
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
}

- (void) teardownConnection {
    [_serverModel removeDelegate:self];
    [_serverModel release];
    _serverModel = nil;
    [_connection setDelegate:nil];
    [_connection disconnect];
    [_connection release]; 
    _connection = nil;
    [_timer invalidate];
    [_serverRoot release];
    _serverRoot = nil;
}
            
- (void) updateTitle {
    ++_numDots;
    if (_numDots > 3)
        _numDots = 0;

    NSString *dots = @"   ";
    if (_numDots == 1) { dots = @".  "; }
    if (_numDots == 2) { dots = @".. "; }
    if (_numDots == 3) { dots = @"..."; }
    
    [_alertView setTitle:[NSString stringWithFormat:@"%@%@", NSLocalizedString(@"Connecting", nil), dots]];
}

#pragma mark - MKConnectionDelegate

- (void) connectionOpened:(MKConnection *)conn {
    NSArray *tokens = [MUDatabase accessTokensForServerWithHostname:[conn hostname] port:[conn port]];
    [conn authenticateWithUsername:_username password:_password accessTokens:tokens];
}

- (void) connection:(MKConnection *)conn closedWithError:(NSError *)err {
    [self hideConnectingView];
    if (err) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Connection closed", nil)
                                                            message:[err localizedDescription]
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                  otherButtonTitles:nil];
        [alertView show];
        [alertView release];
        [self teardownConnection];
    }
}

- (void) connection:(MKConnection*)conn unableToConnectWithError:(NSError *)err {
    [self hideConnectingView];
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Unable to connect", nil)
                                                        message:[err localizedDescription]
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                              otherButtonTitles:nil];
    [alertView show];
    [alertView release];
    [self teardownConnection];
}

// The connection encountered an invalid SSL certificate chain.
- (void) connection:(MKConnection *)conn trustFailureInCertificateChain:(NSArray *)chain {
    // Check the database whether the user trusts the leaf certificate of this server.
    NSString *storedDigest = [MUDatabase digestForServerWithHostname:[conn hostname] port:[conn port]];
    MKCertificate *cert = [[conn peerCertificates] objectAtIndex:0];
    NSString *serverDigest = [cert hexDigest];
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
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                            message:msg
                                                           delegate:self
                                                  cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                  otherButtonTitles:nil];
            [alert addButtonWithTitle:NSLocalizedString(@"Ignore", nil)];
            [alert addButtonWithTitle:NSLocalizedString(@"Trust New Certificate", nil)];
            [alert addButtonWithTitle:NSLocalizedString(@"Show Certificates", nil)];
            [alert show];
            [alert release];
        }
    } else {
        // No certhash of this certificate in the database for this hostname-port combo.  Let the user decide
        // what to do.
        [self hideConnectingView];
        NSString *title = NSLocalizedString(@"Unable to validate server certificate", nil);
        NSString *msg = NSLocalizedString(@"Mumble was unable to validate the certificate chain of the server.", nil);
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                        message:msg
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                              otherButtonTitles:nil];
        [alert addButtonWithTitle:NSLocalizedString(@"Ignore", nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"Trust Certificate", nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"Show Certificates", nil)];
        [alert show];
        [alert release];
    }
}

// The server rejected our connection.
- (void) connection:(MKConnection *)conn rejectedWithReason:(MKRejectReason)reason explanation:(NSString *)explanation {
    NSString *title = NSLocalizedString(@"Connection Rejected", nil);
    NSString *msg = nil;
    UIAlertView *alert = nil;
    
    [self hideConnectingView];
    [self teardownConnection];
    
    switch (reason) {
        case MKRejectReasonNone:
            msg = NSLocalizedString(@"No reason", nil);
            alert = [[UIAlertView alloc] initWithTitle:title
                                               message:msg
                                              delegate:nil
                                     cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                     otherButtonTitles:nil];
            break;
        case MKRejectReasonWrongVersion:
            msg = @"Client/server version mismatch";
            alert = [[UIAlertView alloc] initWithTitle:title
                                               message:msg
                                              delegate:nil
                                     cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                     otherButtonTitles:nil];

            break;
        case MKRejectReasonInvalidUsername:
            msg = NSLocalizedString(@"Invalid username", nil);
            alert = [[UIAlertView alloc] initWithTitle:title
                                               message:msg
                                              delegate:self
                                     cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                     otherButtonTitles:NSLocalizedString(@"Reconnect", nil), nil];
            [alert setAlertViewStyle:UIAlertViewStylePlainTextInput];
            [[alert textFieldAtIndex:0] setText:_username];
            break;
        case MKRejectReasonWrongUserPassword:
            msg = NSLocalizedString(@"Wrong certificate or password for existing user", nil);
            alert = [[UIAlertView alloc] initWithTitle:title
                                               message:msg
                                              delegate:self
                                     cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                     otherButtonTitles:NSLocalizedString(@"Reconnect", nil), nil];
            [alert setAlertViewStyle:UIAlertViewStyleSecureTextInput];
            [[alert textFieldAtIndex:0] setText:_password];
            break;
        case MKRejectReasonWrongServerPassword:
            msg = NSLocalizedString(@"Wrong server password", nil);
            alert = [[UIAlertView alloc] initWithTitle:title
                                               message:msg
                                              delegate:self
                                     cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                     otherButtonTitles:NSLocalizedString(@"Reconnect", nil), nil];
            [alert setAlertViewStyle:UIAlertViewStyleSecureTextInput];
            [[alert textFieldAtIndex:0] setText:_password];
            break;
        case MKRejectReasonUsernameInUse:
            msg = NSLocalizedString(@"Username already in use", nil);
            alert = [[UIAlertView alloc] initWithTitle:title
                                               message:msg
                                              delegate:self
                                     cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                     otherButtonTitles:NSLocalizedString(@"Reconnect", nil), nil];
            [alert setAlertViewStyle:UIAlertViewStylePlainTextInput];
            [[alert textFieldAtIndex:0] setText:_username];
            break;
        case MKRejectReasonServerIsFull:
            msg = NSLocalizedString(@"Server is full", nil);
            alert = [[UIAlertView alloc] initWithTitle:title
                                               message:msg
                                              delegate:nil
                                     cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                     otherButtonTitles:nil];
            break;
        case MKRejectReasonNoCertificate:
            msg = NSLocalizedString(@"A certificate is needed to connect to this server", nil);
            alert = [[UIAlertView alloc] initWithTitle:title
                                               message:msg
                                              delegate:nil
                                     cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                     otherButtonTitles:nil];
            break;
    }

    _rejectAlertView = alert;
    _rejectReason = reason;

    [alert show];
    [alert release];
}

#pragma mark - MKServerModelDelegate

- (void) serverModel:(MKServerModel *)model joinedServerAsUser:(MKUser *)user {
    [MUDatabase storeUsername:[user userName] forServerWithHostname:[model hostname] port:[model port]];

    [self hideConnectingView];

    [_serverRoot takeOwnershipOfConnectionDelegate];

    [_username release];
    _username = nil;
    [_hostname release];
    _hostname = nil;
    [_password release];
    _password = nil;

    if ([[UIDevice currentDevice] userInterfaceIdiom] != UIUserInterfaceIdiomPad) {
        [_serverRoot setModalTransitionStyle:UIModalTransitionStyleFlipHorizontal];
    }

    [_parentViewController presentModalViewController:_serverRoot animated:YES];
    [_parentViewController release];
    _parentViewController = nil;
}

#pragma mark - UIAlertView delegate

- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    // Actions for the outermost UIAlertView
    if (alertView == _alertView) {
        if (buttonIndex == 0) {
            [self teardownConnection];
        } else if (buttonIndex == 1) {
            // ... nope.
        }
        return;
    }
    
    // Actions for the rejection UIAlertView
    if (alertView == _rejectAlertView) {
        if (_rejectReason == MKRejectReasonInvalidUsername || _rejectReason == MKRejectReasonUsernameInUse) {
            [_username release];
            UITextField *textField = [_rejectAlertView textFieldAtIndex:0];
            _username = [[textField text] copy];
        } else if (_rejectReason == MKRejectReasonWrongServerPassword || _rejectReason == MKRejectReasonWrongUserPassword) {
            [_password release];
            UITextField *textField = [_rejectAlertView textFieldAtIndex:0];
            _password = [[textField text] copy];
        }

        if (buttonIndex == 0) {
            // Rejection handler has already handled the teardown for us.
        } else if (buttonIndex == 1) {
            [self establishConnection];
            [self showConnectingView];
        }
        return;
    }
    
    // Actions that follow are for the certificate trust alert view
    
    // Cancel
    if (buttonIndex == 0) {
        // Tear down the connection.
        [self teardownConnection];
        
    // Ignore
    } else if (buttonIndex == 1) {
        // Ignore just reconnects to the server without
        // performing any verification on the certificate chain
        // the server presents us.
        [_connection setIgnoreSSLVerification:YES];
        [_connection reconnect];
        [self showConnectingView];
        
    // Trust
    } else if (buttonIndex == 2) {
        // Store the cert hash of the leaf certificate.  We then ignore certificate
        // verification errors from this host as long as it keeps on presenting us
        // the same certificate it always has.
        MKCertificate *cert = [[_connection peerCertificates] objectAtIndex:0];
        NSString *digest = [cert hexDigest];
        [MUDatabase storeDigest:digest forServerWithHostname:[_connection hostname] port:[_connection port]];
        [_connection setIgnoreSSLVerification:YES];
        [_connection reconnect];
        [self showConnectingView];
        
    // Show certificates
    } else if (buttonIndex == 3) {
        MUServerCertificateTrustViewController *certTrustView = [[MUServerCertificateTrustViewController alloc] initWithCertificates:[_connection peerCertificates]];
        [certTrustView setDelegate:self];
        UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:certTrustView];
        [certTrustView release];
        [_parentViewController presentModalViewController:navCtrl animated:YES];
        [navCtrl release];
    }
}

- (void) serverCertificateTrustViewControllerDidDismiss:(MUServerCertificateTrustViewController *)trustView {
    [self showConnectingView];
    [_connection reconnect];
}

@end
