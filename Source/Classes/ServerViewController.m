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

#import "ServerViewController.h"
#import "PDFImageLoader.h"
#import "Version.h"

#import <MumbleKit/MKUser.h>
#include <celt.h>

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
	[connection connectToHost:serverHostName port:serverPortNumber];

	model = [[MKServerModel alloc] init];
	return self;
}

- (void)dealloc {
    [super dealloc];
}


- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];

	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}

#pragma mark Connection delegate methods

/*
 * invalidSslCertificateChain.
 */
- (void) invalidSslCertificateChain:(NSArray *)certificateChain {

	NSString *title = @"Unable to validate server certificate";
	NSString *msg = @"Mumble was unable to validate the certificate chain of the server.";

	[connection setForceAllowedCertificates:certificateChain];

	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:msg delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:nil];
	[alert addButtonWithTitle:@"OK"];
	[alert show];
	[alert release];
}

- (void) alertView:(UIAlertView *)alert didDismissWithButtonIndex:(NSInteger)buttonIndex {
	/* ok clicked. */
	if (buttonIndex == 1) {
		[connection reconnect];
	} else {
		[connection setForceAllowedCertificates:nil];
	}
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
	[authenticate setUsername:@"iPhoneOS-user"];
	[authenticate addCeltVersions:bitstream];
	data = [[authenticate build] data];
	[connection sendMessageWithType:AuthenticateMessage data:data];
}

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

- (void) handleUserRemoveMessage:(MPUserRemove *)msg {
	NSLog(@"ServerViewController: Recieved UserRemove message");
}

- (void) handleChannelStateMessage:(MPChannelState *)msg {
	NSLog(@"ServerViewController: Received ChannelState message");
	BOOL updateModel = NO;

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
			updateModel = YES;
		} else {
			return;
		}
	}

	if (parent) {
		NSLog(@"Moving %@ to %@", [chan channelName], [parent channelName]);
		[model moveChannel:chan toChannel:parent];
		updateModel = YES;
	}

	if ([msg hasName]) {
		[model renameChannel:chan to:[msg name]];
		updateModel = YES;
	}

	if ([msg hasDescription]) {
		[model setCommentForChannel:chan to:[msg description]];
		updateModel = YES;
	}

	if ([msg hasPosition]) {
		[model repositionChannel:chan to:[msg position]];
		updateModel = YES;
	}
	
	/*
	 * Handle links.
	 */

	if (serverSyncReceived == YES && updateModel == YES) {
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
	
	[[self tableView] reloadData];
	NSLog(@"reloadedData...");
}

- (void) handlePermissionQueryMessage:(MPPermissionQuery *)perm {
}

#pragma mark Table View methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger numRows = [model count];
	NSLog(@"ServerViewController: numRows = %i", numRows);
	return numRows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    static NSString *CellIdentifier = @"serverViewCell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
	
	id object = [model objectAtIndex:[indexPath indexAtPosition:1]];
	if ([object class] == [MKChannel class]) {
		MKChannel *c = (MKChannel *)object;
		cell.imageView.image = [PDFImageLoader imageFromPDF:@"channel"];
		cell.textLabel.text = [c channelName];
	} else if ([object class] == [MKUser class]) {
		MKUser *u = (MKUser *)object;
		cell.imageView.image = [PDFImageLoader imageFromPDF:@"talking_off"];
		cell.textLabel.text = [u userName];
	}

	cell.indentationWidth = 6.0f;
	cell.indentationLevel = [object treeDepth];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
}

@end

