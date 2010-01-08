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
#import "User.h"

#include <celt.h>

@implementation ServerViewController

- (id) initWithHostname:(NSString *)host port:(NSUInteger)port {
	self = [super initWithNibName:@"ServerViewController" bundle:nil];
	if (self == nil)
		return nil;

	serverHostName = host;
	serverPortNumber = port;

	connection = [[Connection alloc] init];
	[connection setDelegate:self];
	[connection connectToHost:serverHostName port:serverPortNumber];
	[[[UIApplication sharedApplication] delegate] setConnection:connection];

	return self;
}

- (void)dealloc {
    [super dealloc];
}

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

-(void) alertView:(UIAlertView *)alert didDismissWithButtonIndex:(NSInteger)buttonIndex {
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
- (void) connectionOpened:(Connection *)conn {
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
-(void)handleVersionMessage: (MPVersion *)version {
	NSLog(@"ServerViewController: Recieved Version message..");
#if 0
	if (version.hasVersion)
		NSLog(@"Version = 0x%x", version.version);
	if (version.hasRelease)
		NSLog(@"Release = %@", version.release);
	if (version.hasOs)
		NSLog(@"OS = %@", version.os);
	if (version.hasOsVersion)
		NSLog(@"OSVersion = %@", version.osVersion);
#endif
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

-(void) handleChannelStateMesage:(MPChannelState *)state {
	NSLog(@"ServerViewController: Received ChannelState message");
	//if ([state hasChannelId])
	//	NSLog(@"channelId = 0x%x", [state channelId]);
	//if ([state hasParent])
	//	NSLog(@"parentId = 0x%x", [state parent]);
	//if ([state hasName])
	//	NSLog(@"name = %@", [state name]);
	// fixme(mkrautz): How to check for repeated field availability in objc protobuf?
	//if ([state hasLinks]) {
	//	NSArray *links = [state linksList];
	//	for (i = 0; i < [links count]; i++) {
	//		NSLog(@"links[%i] = %i", i, [links objectAtIndex:i]);
	//	}
	//}
}

-(void) handleUserStateMessage:(MPUserState *)state {
	NSLog(@"ServerViewController: Recieved UserState message");

	UInt32 session = 0;
	UInt32 actor = 0;
	UInt32 userId = 0;
	UInt32 channelId = 0;
	BOOL mute, deaf, selfMute, selfDeaf;
	MUMBLE_UNUSED NSData *texture = nil;
	NSString *name = nil;
	MUMBLE_UNUSED NSString *pluginContext = nil;
	MUMBLE_UNUSED NSString *pluginIdentity = nil;
	MUMBLE_UNUSED NSString *comment = nil;
	MUMBLE_UNUSED NSString *hash = nil;

	if ([state hasSession]) {
		session = [state session];
		NSLog(@"  session = 0x%x", session);
	}
	if ([state hasActor]) {
		actor = [state actor];
		NSLog(@"  actor = 0x%x", actor);
	}
	if ([state hasName]) {
		name = [[[state name] copy] autorelease];
		NSLog(@"  name = %@", name);
	}
	if ([state hasUserId]) {
		userId = [state userId];
		NSLog(@"  userId = 0x%x", userId);
	}
	if ([state hasChannelId]) {
		channelId = [state channelId];
		NSLog(@"  channelId = 0x%x", channelId);
	}
	if ([state hasMute]) {
		mute = [state mute];
		NSLog(@"  mute = %i", mute);
	}
	if ([state hasDeaf]) {
		deaf = [state deaf];
		NSLog(@"  deaf = %i", deaf);
	}
	if ([state hasSelfMute]) {
		selfMute = [state selfMute];
		NSLog(@"  selfMute = %i", selfMute);
	}
	if ([state hasSelfDeaf]) {
		selfDeaf = [state selfDeaf];
		NSLog(@"  selfDeaf = %i", selfDeaf);
	}

	/*NSData *texture = [state texture];
	NSString *pluginContext = [state pluginContext];
	NSString *pluginIdentity = [state pluginIdentity];
	NSString *comment = [state comment];
	NSString *hash = [state hash];*/


	User *user = nil;

	if (! session) {
		NSLog(@"ServerViewController: Somthing has gone horribly wrong. No session in UserState packet.");
	}

	user = [User lookupBySession:session];
	if (! user && name) {
		user = [User addUserWithSession:session];
		[user setName:name];
		NSLog(@"ServerViewController: Added user for session=%u (%@)...", session, name);
	} else {
		NSLog(@"ServerViewController: No user created, but no name in packet.");
		return;
	}
}

-(void) handleServerSyncMessage:(MPServerSync *)sync {
	NSLog(@"ServerViewController: Recieved ServerSync message");
}

-(void) handlePermissionQueryMessage:(MPPermissionQuery *)perm {
}

/*
- (void)viewDidLoad {
    [super viewDidLoad];

    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}
*/

/*
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}
*/
/*
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}
*/
/*
- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
}
*/
/*
- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
}
*/

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];

	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    static NSString *CellIdentifier = @"serverViewCell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
	cell.indentationWidth = 15.0f;
	NSUInteger rowNumber = [indexPath indexAtPosition:1];

	if (rowNumber == 0) {
		cell.textLabel.text = @"Root";
		UIImage *image = [PDFImageLoader imageFromPDF:@"channel"];
		NSLog(@"rootImage =%p", image);
		cell.imageView.image = image;
		cell.indentationLevel = 0;
	} else if (rowNumber == 1) {
		cell.textLabel.text = @"User";
		UIImage *image = [PDFImageLoader imageFromPDF:@"talking_off"];
		NSLog(@"userImage=%p", image);
		cell.imageView.image = image;
		cell.indentationLevel = 1;
	}

    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Navigation logic may go here. Create and push another view controller.
	// AnotherViewController *anotherViewController = [[AnotherViewController alloc] initWithNibName:@"AnotherView" bundle:nil];
	// [self.navigationController pushViewController:anotherViewController];
	// [anotherViewController release];
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {

    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
    }
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }
}
*/


/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/


/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

@end

