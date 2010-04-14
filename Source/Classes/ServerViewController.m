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
#import "Version.h"

#import <MumbleKit/MKUser.h>
#import <MumbleKit/MKConnection.h>
#include <MumbleKit/celt/celt.h>

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
	[connection setMessageHandler:self];
	[connection connectToHost:serverHostName port:serverPortNumber];

	model = [[MKServerModel alloc] init];

	serverSyncReceived = NO;

	return self;
}

- (void) dealloc {
    [super dealloc];
}

#pragma mark

- (void) viewDidLoad {
	[super viewDidLoad];

	self.navigationItem.title = @"Connecting...";
	UIBarButtonItem *disconnectButton = [[[UIBarButtonItem alloc] initWithTitle:@"Disconnect" style:UIBarButtonItemStyleBordered target:self action:@selector(disconnectClicked:)] autorelease];
	[[self navigationItem] setLeftBarButtonItem:disconnectButton];
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

	/* Get CELT bitstream version. */
	celt_int32 bitstream;
	CELTMode *mode = celt_mode_create(48000, 100, NULL);
	celt_mode_info(mode, CELT_GET_BITSTREAM_VERSION, &bitstream);
	celt_mode_destroy(mode);

	NSLog(@"CELT bitstream = 0x%x", bitstream);

	NSData *data;
	MPVersion_Builder *version = [MPVersion builder];
	UIDevice *dev = [UIDevice currentDevice];
	[version setVersion: [Version hex]];
	[version setRelease: [Version string]];
	[version setOs: [dev systemName]];
	[version setOsVersion: [dev systemVersion]];
	data = [[version build] data];
	[connection sendMessageWithType:VersionMessage data:data];

	MPAuthenticate_Builder *authenticate = [MPAuthenticate builder];
	[authenticate setUsername:@"Tukoff43"];
	[authenticate addCeltVersions:bitstream];
	data = [[authenticate build] data];
	[connection sendMessageWithType:AuthenticateMessage data:data];
}

#pragma mark MKMessageHandler methods

/*
 * Version message.
 *
 * Sent from the server to us on connect.
 */
-(void)handleVersionMessage: (MPVersion *)msg {
	NSLog(@"ServerViewController: Recieved Version message..");

	if ([msg hasVersion])
		NSLog(@"Version = 0x%x", [msg version]);
	if ([msg hasRelease])
		NSLog(@"Release = %@", [msg release]);
	if ([msg hasOs])
		NSLog(@"OS = %@", [msg os]);
	if ([ msg hasOsVersion])
		NSLog(@"OSVersion = %@", [msg osVersion]);
}

/*
 * CryptSetup...
 * bleh...
 */
-(void) handleCryptSetupMessage:(MPCryptSetup *)setup {
	NSLog(@"ServerViewController: Received CryptSetup packet...");
}

/*
 * CodecVersion message...
 *
 * Used to tell us which version of CELT to use.
 */
-(void) handleCodecVersionMessage:(MPCodecVersion *)codec {
	NSLog(@"ServerViewController: Received CodecVersion message");

	if ([codec hasAlpha])
		NSLog(@"alpha = 0x%x", [codec alpha]);
	if ([codec hasBeta])
		NSLog(@"beta = 0x%x", [codec beta]);
	if ([codec hasPreferAlpha])
		NSLog(@"preferAlpha = %i", [codec preferAlpha]);
}

- (void) handleUserStateMessage:(MPUserState *)msg {
	NSLog(@"ServerViewController: Recieved UserState message");
	BOOL newUser = NO;

	if (![msg hasSession]) {
		return;
	}

	NSUInteger session = [msg session];
	MKUser *user = [model userWithSession:session];
	if (user == nil) {
		if ([msg hasName]) {
			NSLog(@"Adding user....!");
			user = [model addUserWithSession:session name:[msg name]];
			if (serverSyncReceived == YES)
				[[self tableView] reloadData];
		} else {
			return;
		}
	}

	if ([msg hasUserId]) {
		[model setIdForUser:user to:[msg userId]];
	}

	if ([msg hasHash]) {
		[model setHashForUser:user to:[msg hash]];
		/* Check if user is a friend? */
	}

	if (newUser) {
		NSLog(@"%@ connected.", [user userName]);
	}

	if ([msg hasChannelId]) {
		MKChannel *chan = [model channelWithId:[msg channelId]];
		if (chan == nil) {
			NSLog(@"ServerViewController: UserState with invalid channelId.");
		}

		MKChannel *oldChan = [user channel];
		if (chan != oldChan) {
			[model moveUser:user toChannel:chan];
			NSLog(@"Moved user '%@' to channel '%@'", [user userName], [chan channelName]);
		}
	}

	if ([msg hasName]) {
		[model renameUser:user to:[msg name]];
	}

	if ([msg hasTexture]) {
		NSLog(@"ServerViewController: User has texture.. Discarding.");
	}

	if ([msg hasComment]) {
		NSLog(@"ServerViewControler: User has comment... Discarding.");
	}

	[[self tableView] reloadData];
}

/*
 * A user leaving the server.
 */
- (void) handleUserRemoveMessage:(MPUserRemove *)msg {
	NSLog(@"ServerViewController: Recieved UserRemove message");
	[model removeUser:[model userWithSession:[msg session]]];
	[[self tableView] reloadData];
}

- (void) handleChannelStateMessage:(MPChannelState *)msg {
	NSLog(@"ServerViewController: Received ChannelState message");

	if (![msg hasChannelId]) {
		NSLog(@"ServerViewController: ChannelState without channelId.");
		return;
	}

	MKChannel *chan = [model channelWithId:[msg channelId]];
	MKChannel *parent = [msg hasParent] ? [model channelWithId:[msg parent]] : NULL;

	if (!chan) {
		if ([msg hasParent] && [msg hasName]) {
			NSLog(@"Adding new channel....");
			chan = [model addChannelWithId:[msg channelId] name:[msg name] parent:parent];
			if ([msg hasTemporary]) {
				[chan setTemporary:[msg temporary]];
			}
		} else {
			return;
		}
	}

	if (parent) {
		NSLog(@"Moving %@ to %@", [chan channelName], [parent channelName]);
		[model moveChannel:chan toChannel:parent];
	}

	if ([msg hasName]) {
		[model renameChannel:chan to:[msg name]];
	}

	if ([msg hasDescription]) {
		[model setCommentForChannel:chan to:[msg description]];
	}

	if ([msg hasPosition]) {
		[model repositionChannel:chan to:[msg position]];
	}

	/*
	 * Handle links.
	 */

	if (serverSyncReceived == YES) {
		[[self tableView] reloadData];
	}
}

- (void) handleChannelRemoveMessage:(MPChannelRemove *)msg {
	NSLog(@"ServerViewController: ChannelRemove message");

	if (! [msg hasChannelId]) {
		NSLog(@"ServerViewController: ChannelRemove without channelId.");
		return;
	}

	MKChannel *chan = [model channelWithId:[msg channelId]];
	if (chan && [chan channelId] != 0) {
		[model removeChannel:chan];
		if (serverSyncReceived == YES) {
			[[self tableView] reloadData];
		}
	}
}

- (void) handleServerSyncMessage:(MPServerSync *)msg {
	NSLog(@"ServerViewController: Recieved ServerSync message");
	if (![msg hasSession]) {
		NSLog(@"ServerViewController: Invalid ServerSync recieved.");
		return;
	}

	NSLog(@"ServerSync: Our session=%u", [msg session]);
	currentChannel = [model rootChannel];
	serverSyncReceived = YES;
	[[self tableView] reloadData];

	self.navigationItem.title = [[model rootChannel] channelName];
	[[self navigationController] setToolbarHidden:NO animated:YES];
}

- (void) handlePermissionQueryMessage:(MPPermissionQuery *)perm {
}

#pragma mark Table View methods

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

