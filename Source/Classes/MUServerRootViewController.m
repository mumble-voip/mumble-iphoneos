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

#import "MUServerRootViewController.h"
#import "MUServerViewController.h"
#import "MUChannelViewController.h"
#import "MUConnectionViewController.h"
#import "MUServerCertificateTrustViewController.h"
#import "MUDatabase.h"

#import <MumbleKit/MKConnection.h>
#import <MumbleKit/MKServerModel.h>
#import <MumbleKit/MKCertificate.h>

@interface MUServerRootViewController () <MKConnectionDelegate, MKServerModelDelegate> {
    MKConnection                *_connection;
    MKServerModel               *_model;

    NSString                    *_hostname;
    NSUInteger                  _port;
    NSString                    *_username;
    NSString                    *_password;
    
    NSInteger                   _segmentIndex;
    UISegmentedControl          *_segmentedControl;

    MUServerViewController      *_serverView;
    MUChannelViewController     *_channelView;
    MUConnectionViewController  *_connectionView;
}
@end

@implementation MUServerRootViewController

- (id) initWithHostname:(NSString *)host port:(NSUInteger)port username:(NSString *)username password:(NSString *)password {
    if ([self init]) {
        _hostname = [host retain];
        _port = port;
        _username = [username retain];
        _password = [password retain];
    }
    return self;
}

- (void) dealloc {
    [_hostname release];
    [_username release];
    [_password release];

    [_model release];
    [_connection disconnect];
    [_connection release];

    [super dealloc];
}

- (void) didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void) establishConnection {
    _connection = [[MKConnection alloc] init];
    [_connection setDelegate:self];

    _model = [[MKServerModel alloc] initWithConnection:_connection];
    [_model addDelegate:self];

    // Set the connection's client cert if one is set in the app's preferences...
    NSData *certPersistentId = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultCertificate"];
    if (certPersistentId != nil) {
        // Try to fetch our given identity's SecIdentityRef by its persistent reference.
        // If we're able to fetch it, set it as the connection's client certificate.
        SecIdentityRef secIdentity = NULL;
        NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
                               certPersistentId,		kSecValuePersistentRef,
                               kCFBooleanTrue,			kSecReturnRef,
                               kSecMatchLimitOne,		kSecMatchLimit,
                               nil];
        if (SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&secIdentity) == noErr && secIdentity != NULL) {
            [_connection setClientIdentity:secIdentity];
            CFRelease(secIdentity);
        }
    }

    [_connection connectToHost:_hostname port:_port];
}

#pragma mark - View lifecycle

- (void) viewDidUnload {
    [super viewDidUnload];
}

- (void) viewWillAppear:(BOOL)animated {
    [self establishConnection];

    _serverView = [[MUServerViewController alloc] initWithServerModel:_model];
    _channelView = [[MUChannelViewController alloc] initWithServerModel:_model];
    _connectionView = [[MUConnectionViewController alloc] initWithServerModel:_model];
    
    _segmentedControl = [[UISegmentedControl alloc] initWithItems:
                            [NSArray arrayWithObjects:@"Server", @"Channel", @"Connection", nil]];

    _segmentIndex = 0;

    _segmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
    _segmentedControl.selectedSegmentIndex = _segmentIndex;
    [_segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];

    _serverView.navigationItem.titleView = _segmentedControl;

    [self setViewControllers:[NSArray arrayWithObject:_serverView] animated:NO];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void) segmentChanged:(id)sender {
    if (_segmentedControl.selectedSegmentIndex == 0) {
        _serverView.navigationItem.titleView = _segmentedControl;
        [self setViewControllers:[NSArray arrayWithObject:_serverView] animated:NO]; 
    } else if (_segmentedControl.selectedSegmentIndex == 1) {
        _channelView.navigationItem.titleView = _segmentedControl;
        [self setViewControllers:[NSArray arrayWithObject:_channelView] animated:NO];
    } else if (_segmentedControl.selectedSegmentIndex == 2) {
        _connectionView.navigationItem.titleView = _segmentedControl;
        [self setViewControllers:[NSArray arrayWithObject:_connectionView] animated:NO];
    }
}

#pragma mark - MKConnection delegate



- (void) connectionOpened:(MKConnection *)conn {
    [conn authenticateWithUsername:_username password:_password];
}

- (void) connectionClosed:(MKConnection *)conn {
    NSLog(@"MUServerRootViewController: Connection closed.");
}

// The connection encountered an invalid SSL certificate chain.
- (void) connection:(MKConnection *)conn trustFailureInCertificateChain:(NSArray *)chain {
	// Check the database whether the user trusts the leaf certificate of this server.
	NSString *storedDigest = [MUDatabase digestForServerWithHostname:[conn hostname] port:[conn port]];
	NSString *serverDigest = [[[conn peerCertificates] objectAtIndex:0] hexDigest];
	if (storedDigest) {
		// Match?
		if ([storedDigest isEqualToString:serverDigest]) {
			[conn setIgnoreSSLVerification:YES];
			[conn reconnect];
			return;
            
            // Mismatch.  The server is using a new certificate, different from the one it previously
            // presented to us.
		} else {
			NSString *title = @"Certificate Mismatch";
			NSString *msg = @"The server presented a different certificate than the one stored for this server";
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:msg delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:nil];
			[alert addButtonWithTitle:@"Ignore"];
			[alert addButtonWithTitle:@"Trust New Certificate"];
			[alert addButtonWithTitle:@"Show Certificates"];
			[alert show];
			[alert release];
		}
        
        // No certhash of this certificate in the database for this hostname-port combo.  Let the user decide
        // what to do.
	} else {
		NSString *title = @"Unable to validate server certificate";
		NSString *msg = @"Mumble was unable to validate the certificate chain of the server.";
        
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:msg delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:nil];
		[alert addButtonWithTitle:@"Ignore"];
		[alert addButtonWithTitle:@"Trust Certificate"];
		[alert addButtonWithTitle:@"Show Certificates"];
		[alert show];
		[alert release];
	}
}

// The server rejected our connection.
- (void) connection:(MKConnection *)conn rejectedWithReason:(MKRejectReason)reason explanation:(NSString *)explanation {
	NSString *title = @"Connection Rejected";
	NSString *msg = nil;
    
	switch (reason) {
		case MKRejectReasonNone:
			msg = @"No reason";
			break;
		case MKRejectReasonWrongVersion:
			msg = @"Version mismatch between client and server.";
			break;
		case MKRejectReasonInvalidUsername:
			msg = @"Invalid username";
			break;
		case MKRejectReasonWrongUserPassword:
			msg = @"Wrong user password";
			break;
		case MKRejectReasonWrongServerPassword:
			msg = @"Wrong server password";
			break;
		case MKRejectReasonUsernameInUse:
			msg = @"Username already in use";
			break;
		case MKRejectReasonServerIsFull:
			msg = @"Server is full";
			break;
		case MKRejectReasonNoCertificate:
			msg = @"A certificate is needed to connect to this server";
			break;
	}
    
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
	[alert release];
    
    [self.navigationController dismissModalViewControllerAnimated:YES];
}

#pragma mark - MKServerModel delegate

- (void) serverModel:(MKServerModel *)model joinedServerAsUser:(MKUser *)user {
    NSLog(@"JoinedServerAsUser!");
}

#pragma mark - UIAlertView delegate

- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	// Cancel
	if (buttonIndex == 0) {
		// Tear down the connection.
		[_connection disconnect];
        
    // Ignore
	} else if (buttonIndex == 1) {
		// Ignore just reconnects to the server without
		// performing any verification on the certificate chain
		// the server presents us.
		[_connection setIgnoreSSLVerification:YES];
		[_connection reconnect];
        
    // Trust
	} else if (buttonIndex == 2) {
		// Store the cert hash of the leaf certificate.  We then ignore certificate
		// verification errors from this host as long as it keeps on presenting us
		// the same certificate it always has.
		NSString *digest = [[[_connection peerCertificates] objectAtIndex:0] hexDigest];
		[MUDatabase storeDigest:digest forServerWithHostname:[_connection hostname] port:[_connection port]];
		[_connection setIgnoreSSLVerification:YES];
		[_connection reconnect];
        
    // Show certificates
	} else if (buttonIndex == 3) {
		MUServerCertificateTrustViewController *certTrustView = [[MUServerCertificateTrustViewController alloc] initWithConnection:_connection];
		UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:certTrustView];
		[certTrustView release];
		[self presentModalViewController:navCtrl animated:YES];
		[navCtrl release];
	}
}

@end
