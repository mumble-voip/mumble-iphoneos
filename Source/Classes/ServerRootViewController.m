/* Copyright (C) 2009-2010 Mikkel Krautz <mikkel@krautz.dk>

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

#import <MumbleKit/MKAudio.h>
#import <MumbleKit/MKCertificate.h>
#import <MumbleKit/MKConnection.h>

#import "MumbleApplication.h"
#import "MumbleApplicationDelegate.h"
#import "Database.h"

#import "ServerRootViewController.h"
#import "ServerConnectionViewController.h"
#import "ChannelViewController.h"
#import "LogViewController.h"
#import "UserViewController.h"
#import "PDFImageLoader.h"
#import "CertificateViewController.h"

@interface ServerRootViewController (Private)
- (void) togglePushToTalk;
@end

@implementation ServerRootViewController

- (id) initWithHostname:(NSString *)host port:(NSUInteger)port identity:(Identity *)identity password:(NSString *)password {
	self = [super init];
	if (! self)
		return nil;

	_hostname = [host copy];
	_port = port;

	_identity = [identity retain];
	_password = [password copy];

	_connection = [[MKConnection alloc] init];
	[_connection setDelegate:self];

	_model = [[MKServerModel alloc] initWithConnection:_connection];
	[_model addDelegate:self];

	// Try to fetch our given identity's SecIdentityRef by its persistent reference.
	// If we're able to fetch it, set it as the connection's client certificate.
	SecIdentityRef secIdentity = NULL;
	NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
								[identity persistent],	kSecValuePersistentRef,
								kCFBooleanTrue,			kSecReturnRef,
								kSecMatchLimitOne,		kSecMatchLimit,
							nil];
	if (SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&secIdentity) == noErr && secIdentity != NULL) {
		[_connection setClientIdentity:secIdentity];
		CFRelease(secIdentity);
	}

	[_connection connectToHost:host port:port];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userTalkStateChanged:) name:@"MKUserTalkStateChanged" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selfStartedTransmit:) name:@"MKAudioTransmitStarted" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selfStoppedTransmit:) name:@"MKAudioTransmitStopped" object:nil];

	return self;
}

- (void) dealloc {
	[_hostname release];
	[_identity release];
	[_password release];
	[_model release];
	[_connection release];

	[super dealloc];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void) viewWillAppear:(BOOL)animated {
	// Title
	if (_currentChannel == nil)
		[[self navigationItem] setTitle:@"Connecting..."];
	else
		[[self navigationItem] setTitle:[_currentChannel channelName]];

	// Top bar
	UIBarButtonItem *disconnectButton = [[UIBarButtonItem alloc] initWithTitle:@"Disconnect" style:UIBarButtonItemStyleBordered target:self action:@selector(disconnectClicked:)];
	[[self navigationItem] setLeftBarButtonItem:disconnectButton];
	[disconnectButton release];

	UIBarButtonItem *infoItem = [[UIBarButtonItem alloc] initWithTitle:@"Certs" style:UIBarButtonItemStyleBordered target:self action:@selector(infoClicked:)];
	[[self navigationItem] setRightBarButtonItem:infoItem];
	[infoItem release];

	// Toolbar
	UIBarButtonItem *channelsButton = [[UIBarButtonItem alloc] initWithTitle:@"Channels" style:UIBarButtonItemStyleBordered target:self action:@selector(channelsButtonClicked:)];
	UIBarButtonItem *pttButton = [[UIBarButtonItem alloc] initWithTitle:@"PushToTalk" style:UIBarButtonItemStyleBordered target:self action:@selector(pushToTalkClicked:)];
	UIBarButtonItem *usersButton = [[UIBarButtonItem alloc] initWithTitle:@"Users" style:UIBarButtonItemStyleBordered target:self action:@selector(usersButtonClicked:)];
	UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	[self setToolbarItems:[NSArray arrayWithObjects:channelsButton, flexSpace, pttButton, flexSpace, usersButton, nil]];
	[channelsButton release];
	[pttButton release];
	[usersButton release];
	[flexSpace release];

#ifdef USE_CONNECTION_ANIMATION
	// Show the ServerConnectionViewController when we're trying to establish a
	// connection to a server.
	if (![_connection connected]) {
		_progressController = [[ServerConnectionViewController alloc] init];
		_progressController.view.frame = [[UIScreen mainScreen] applicationFrame];
		_progressController.view.hidden = YES;

		UIWindow *window = [[MumbleApp delegate] window];
		[window addSubview:_progressController.view];

		[UIView beginAnimations:nil context:NULL];
		_progressController.view.hidden = NO;
		[UIView setAnimationDuration:0.6f];
		[UIView setAnimationBeginsFromCurrentState:YES];
		[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight forView:window cache:YES];
		[UIView commitAnimations];

		[MumbleApp setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
	}
#endif

	[[self navigationController] setToolbarHidden:NO];
}

- (void) viewDidAppear:(BOOL)animated {
}

#pragma mark MKConnection Delegate

// The connection encountered an invalid SSL certificate chain.
- (void) connection:(MKConnection *)conn trustFailureInCertificateChain:(NSArray *)chain {
	// Check the database whether the user trusts the leaf certificate of this server.
	NSString *storedDigest = [Database digestForServerWithHostname:_hostname port:_port];
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

	[[self navigationController] dismissModalViewControllerAnimated:YES];
}

// Connection established...
- (void) connectionOpened:(MKConnection *)conn {
	[conn authenticateWithUsername:[_identity userName] password:_password];
}

// Connection closed...
- (void) connectionClosed:(MKConnection *)conn {
	NSLog(@"ServerRootViewController: Connection closed");
}

#pragma mark MKServerModel Delegate

// We've successfuly joined the server.
- (void) serverModel:(MKServerModel *)server joinedServerAsUser:(MKUser *)user {
	_currentChannel = [[_model connectedUser] channel];
	_channelUsers = [[[[_model connectedUser] channel] users] mutableCopy];

#ifdef USE_CONNECTION_ANIMATION
	[MumbleApp setStatusBarStyle:UIStatusBarStyleDefault animated:YES];

	[UIView animateWithDuration:0.4f animations:^{
		_progressController.view.alpha = 0.0f;
	} completion:^(BOOL finished){
		[_progressController.view removeFromSuperview];
		[_progressController release];
		_progressController = nil;
	}];
#endif

	[[self navigationItem] setTitle:[_currentChannel channelName]];
	[[self tableView] reloadData];
}

// A user joined the server.
- (void) serverModel:(MKServerModel *)server userJoined:(MKUser *)user {
	NSLog(@"ServerViewController: userJoined.");
}

// A user left the server.
- (void) serverModel:(MKServerModel *)server userLeft:(MKUser *)user {
	if (_currentChannel == nil)
		return;

	NSUInteger userIndex = [_channelUsers indexOfObject:user];
	if (userIndex != NSNotFound) {
		[_channelUsers removeObjectAtIndex:userIndex];
		[[self tableView] deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:userIndex inSection:0]]
								withRowAnimation:UITableViewRowAnimationRight];
	}
}

// A user moved channel
- (void) serverModel:(MKServerModel *)server userMoved:(MKUser *)user toChannel:(MKChannel *)chan byUser:(MKUser *)mover {
	if (_currentChannel == nil)
		return;

	// Was this ourselves, or someone else?
	if (user != [server connectedUser]) {
		// Did the user join this channel?
		if (chan == _currentChannel) {
			[_channelUsers addObject:user];
			NSUInteger userIndex = [_channelUsers indexOfObject:user];
			[[self tableView] insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:userIndex inSection:0]]
									withRowAnimation:UITableViewRowAnimationLeft];
		// Or did he leave it?
		} else {
			NSUInteger userIndex = [_channelUsers indexOfObject:user];
			if (userIndex != NSNotFound) {
				[_channelUsers removeObjectAtIndex:userIndex];
				[[self tableView] deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:userIndex inSection:0]]
										withRowAnimation:UITableViewRowAnimationRight];
			}
		}

	// We were moved. We need to redo the array holding the users of the
	// current channel.
	} else {
		NSUInteger numUsers = [_channelUsers count];
		[_channelUsers release];
		_channelUsers = nil;

		NSMutableArray *array = [[NSMutableArray alloc] init];
		for (NSUInteger i = 0; i < numUsers; i++) {
			[array addObject:[NSIndexPath indexPathForRow:i inSection:0]];
		}
		[[self tableView] deleteRowsAtIndexPaths:array withRowAnimation:UITableViewRowAnimationRight];

		_currentChannel = chan;
		_channelUsers = [[chan users] mutableCopy];

		[array removeAllObjects];
		numUsers = [_channelUsers count];
		for (NSUInteger i = 0; i < numUsers; i++) {
			[array addObject:[NSIndexPath indexPathForRow:i inSection:0]];
		}
		[[self tableView] insertRowsAtIndexPaths:array withRowAnimation:UITableViewRowAnimationLeft];
		[array release];

		// Update the title to match our new channel.
		[[self navigationItem] setTitle:[_currentChannel channelName]];
	}
}

// A channel was added.
- (void) serverModel:(MKServerModel *)server channelAdded:(MKChannel *)channel {
	NSLog(@"ServerViewController: channelAdded.");
}

// A channel was removed.
- (void) serverModel:(MKServerModel *)server channelRemoved:(MKChannel *)channel {
	NSLog(@"ServerViewController: channelRemoved.");
}

// User talk state changed
- (void) userTalkStateChanged:(NSNotification *)notification {
	if (_currentChannel == nil)
		return;
	
	MKUser *user = [notification object];
	NSUInteger userIndex = [_channelUsers indexOfObject:user];
	
	if (userIndex == NSNotFound)
		return;
	
	UITableViewCell *cell = [[self tableView] cellForRowAtIndexPath:[NSIndexPath indexPathForRow:userIndex inSection:0]];
	
	MKTalkState talkState = [user talkState];
	NSString *talkImageName = nil;
	if (talkState == MKTalkStatePassive)
		talkImageName = @"talking_off";
	else if (talkState == MKTalkStateTalking)
		talkImageName = @"talking_on";
	else if (talkState == MKTalkStateWhispering)
		talkImageName = @"talking_whisper";
	else if (talkState == MKTalkStateShouting)
		talkImageName = @"talking_alt";
	
	UIImageView *imageView = [cell imageView];
	UIImage *image = [PDFImageLoader imageFromPDF:talkImageName];
	[imageView setImage:image];
}

// We stopped transmitting
- (void) selfStoppedTransmit:(NSNotification *)notification {
	MKUser *user = [_model connectedUser];
	NSUInteger userIndex = [_channelUsers indexOfObject:user];

	if (userIndex == NSNotFound)
		return;

	UITableViewCell *cell = [[self tableView] cellForRowAtIndexPath:[NSIndexPath indexPathForRow:userIndex inSection:0]];
	UIImageView *imageView = [cell imageView];
	UIImage *image = [PDFImageLoader imageFromPDF:@"talking_off"];
	[imageView setImage:image];
}

// We started transmitting
- (void) selfStartedTransmit:(NSNotification *)notification {
	MKUser *user = [_model connectedUser];
	NSUInteger userIndex = [_channelUsers indexOfObject:user];

	if (userIndex == NSNotFound)
		return;

	UITableViewCell *cell = [[self tableView] cellForRowAtIndexPath:[NSIndexPath indexPathForRow:userIndex inSection:0]];
	UIImageView *imageView = [cell imageView];
	UIImage *image = [PDFImageLoader imageFromPDF:@"talking_on"];
	[imageView setImage:image];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_channelUsers count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }

	NSUInteger row = [indexPath row];
	MKUser *user = [_channelUsers objectAtIndex:row];

	cell.textLabel.text = [user userName];

	MKTalkState talkState = [user talkState];
	NSString *talkImageName = nil;
	if (talkState == MKTalkStatePassive)
		talkImageName = @"talking_off";
	else if (talkState == MKTalkStateTalking)
		talkImageName = @"talking_on";
	else if (talkState == MKTalkStateWhispering)
		talkImageName = @"talking_whisper";
	else if (talkState == MKTalkStateShouting)
		talkImageName = @"talking_alt";
	cell.imageView.image = [PDFImageLoader imageFromPDF:talkImageName];
	
    return cell;
}

#pragma mark -
#pragma mark UITableView delegate

#if 0
- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
}
#endif

#pragma mark -
#pragma mark UIAlertView delegate

- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	// Cancel
	if (buttonIndex == 0) {
		// Tear down the connection.
		[_connection disconnect];
		return;

	// Ignore
	} else if (buttonIndex == 1) {
		// Ignore just reconnects to the server without
		// performing any verification on the certificate chain
		// the server presents us.

	// Trust
	} else if (buttonIndex == 2) {
		// Store the cert hash of the leaf certificate.  We then ignore certificate
		// verification errors from this host as long as it keeps on presenting us
		// the same certificate it always has.
		NSString *digest = [[[_connection peerCertificates] objectAtIndex:0] hexDigest];
		[Database storeDigest:digest forServerWithHostname:_hostname port:_port];
	}

	[_connection setIgnoreSSLVerification:YES];
	[_connection reconnect];
}

#pragma mark -
#pragma mark Target/actions

// Disconnect from the server
- (void) disconnectClicked:(id)sender {
	[_connection disconnect];
	[[self navigationController] dismissModalViewControllerAnimated:YES];
}

// Info (certs) button clicke
- (void) infoClicked:(id)sender {
	NSArray *certs = [_connection peerCertificates];
	CertificateViewController *certView = [[CertificateViewController alloc] initWithCertificate:[certs objectAtIndex:0]];
	[[self navigationController] pushViewController:certView animated:YES];
	[certView release];
}

// Push-to-Talk button
- (void) pushToTalkClicked:(id)sender {
	[self togglePushToTalk];
}

// Channel picker
- (void) channelsButtonClicked:(id)sender {
	ChannelViewController *channelView = [[ChannelViewController alloc] initWithChannel:[_model rootChannel] serverModel:_model];
	UINavigationController *navCtrl = [[UINavigationController alloc] init];

	[navCtrl pushViewController:channelView animated:NO];
	[[self navigationController] presentModalViewController:navCtrl animated:YES];

	[navCtrl release];
	[channelView release];
}

// User picker
- (void) usersButtonClicked:(id)sender {
	NSLog(@"users");
}

- (void) togglePushToTalk {
	_pttState = !_pttState;
	MKAudio *audio = [MKAudio sharedAudio];
	[audio setForceTransmit:_pttState];
}

@end
