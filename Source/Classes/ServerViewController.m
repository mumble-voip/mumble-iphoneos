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

#import "ChannelViewController.h"
#import "ServerViewController.h"
#import "PDFImageLoader.h"

#import <MumbleKit/MKUser.h>
#import <MumbleKit/MKConnection.h>

@implementation ServerViewController

#pragma mark UITableViewController methods

- (id) initWithHostname:(NSString *)host port:(NSUInteger)port {
	self = [super initWithNibName:@"ServerViewController" bundle:nil];
	if (self == nil)
		return nil;

	serverHostName = host;
	serverPortNumber = port;

	connection = [[MKConnection alloc] init];
	[connection setDelegate:self];

	model = [[MKServerModel alloc] initWithConnection:connection];
	[model addDelegate:self];

	[connection connectToHost:serverHostName port:serverPortNumber];

	return self;
}

- (void) dealloc {
	[model removeDelegate:self];
	[model release];

	[connection closeStreams];
	[connection release];

	[super dealloc];
}

#pragma mark

- (void) viewDidLoad {
	[super viewDidLoad];
	self.navigationItem.title = @"Connecting...";
	[self.navigationItem setHidesBackButton:YES animated:YES];
}

#pragma mark

- (void) alertView:(UIAlertView *)alert didDismissWithButtonIndex:(NSInteger)buttonIndex {
	/* OK clicked. */
	if (buttonIndex == 1) {
		/* For now, simply ignore the SSL verification. */
		[connection setIgnoreSSLVerification:YES];
		[connection reconnect];
	}
}

#pragma mark Actions

- (void) disconnectClicked:(id)sender {
	// Disconnect from the server.
	[connection closeStreams];
}

#pragma mark MKConnection delegate methods

- (void) connection:(MKConnection *)conn trustFailureInCertificateChain:(NSArray *)chain {
	NSString *title = @"Unable to validate server certificate";
	NSString *msg = @"Mumble was unable to validate the certificate chain of the server.";

	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:msg delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:nil];
	[alert addButtonWithTitle:@"OK"];
	[alert show];
	[alert release];
}

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
}

/*
 * connectionOpened:
 *
 * Called when the connection is ready for use. We
 * use this to send our Version and Authenticate messages.
 */
- (void) connectionOpened:(MKConnection *)conn {
	/* OK. We're connected. */
	NSLog(@"ServerViewController: connectionOpened");

	[conn authenticateWithUsername:@"MumbleiPhoneUser" password:nil];
}

///////////////////////////////////////////////////////////////////
#pragma mark MKServerModel delegate methods
///////////////////////////////////////////////////////////////////

//
// We've successfuly joined the server.
//
- (void) serverModel:(MKServerModel *)server joinedServerAsUser:(MKUser *)user {
	NSLog(@"ServerViewController: joinedServerAsUser:");

/*
	self.navigationItem.title = [[server rootChannel] channelName];

	UIBarButtonItem *disconnectButton = [[[UIBarButtonItem alloc] initWithTitle:@"Disconnect" style:UIBarButtonItemStyleBordered target:self action:@selector(disconnectClicked:)] autorelease];
	[[self navigationItem] setLeftBarButtonItem:disconnectButton];*/

	ChannelViewController *channelView = [[ChannelViewController alloc] initWithChannel:[model rootChannel]];
	[[[[UIApplication sharedApplication] delegate] window] addSubview:channelView.view];

	NSLog(@"switched active window.");
}

//
// A user joined the server.
//
- (void) serverModel:(MKServerModel *)server userJoined:(MKUser *)user {
	NSLog(@"ServerViewController: userJoined.");
}

//
// A user left the server.
//
- (void) serverModel:(MKServerModel *)server userLeft:(MKUser *)user {
	NSLog(@"ServerViewController: userLeft.");
}

//
// A channel was added.
//
- (void) serverModel:(MKServerModel *)server channelAdded:(MKChannel *)channel {
	NSLog(@"ServerViewController: channelAdded.");
}

//
// A channel was removed.
//
- (void) serverModel:(MKServerModel *)server channelRemoved:(MKChannel *)channel {
	NSLog(@"ServerViewController: channelRemoved.");
}


///////////////////////////////////////////////////////////////////
#pragma mark Table View methods
///////////////////////////////////////////////////////////////////

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == ServerViewSectionActions) {
		return @"Actions";
	}

	return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == ServerViewSectionActions) {
		// Only show 'channels' for now.
		return 1;
	}

	return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *CellIdentifier = @"serverViewCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }

	ServerViewSection section = [indexPath indexAtPosition:0];
	NSUInteger row = [indexPath indexAtPosition:1];

	if (section == ServerViewSectionActions) {
		if (row == ServerViewActionsChannels) {
			cell.textLabel.text = @"Channels";
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
	}

    return cell;

}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	ServerViewSection section = [indexPath indexAtPosition:0];
	NSUInteger row = [indexPath indexAtPosition:1];

	if (section == ServerViewSectionActions) {
		if (row == ServerViewActionsChannels) {
			ChannelViewController *channelView = [[ChannelViewController alloc] initWithChannel:[model rootChannel]];
			[self.navigationController pushViewController:channelView animated:YES];
			[channelView release];
		}
	}
}

@end

