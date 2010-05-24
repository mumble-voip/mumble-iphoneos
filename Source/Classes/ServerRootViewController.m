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

#import "ServerRootViewController.h"
#import "ChannelViewController.h"
#import "LogViewController.h"
#import "UserViewController.h"

@implementation ServerRootViewController

- (id) initWithHostname:(NSString *)host port:(NSUInteger)port {
	self = [super init];
	if (! self)
		return nil;

	_connection = [[MKConnection alloc] init];
	[_connection setDelegate:self];

	_model = [[MKServerModel alloc] initWithConnection:_connection];
	[_model addDelegate:self];

	[_connection connectToHost:host port:port];

	return self;
}

- (void) dealloc {
	[super dealloc];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark MKConnection Delegate

//
// The connection encountered an invalid SSL certificate chain. For now, we will show this dialog
// each time, as iPhoneOS 3.{1,2}.X doesn't allow for trusting certificates on an app-to-app basis.
//
- (void) connection:(MKConnection *)conn trustFailureInCertificateChain:(NSArray *)chain {
	NSString *title = @"Unable to validate server certificate";
	NSString *msg = @"Mumble was unable to validate the certificate chain of the server.";

	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:msg delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:nil];
	[alert addButtonWithTitle:@"OK"];
	[alert show];
	[alert release];
}

//
// The server rejected our connection.
//
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

//
// An SSL connection has been opened to the server.  We should authenticate ourselves.
//
- (void) connectionOpened:(MKConnection *)conn {
	[conn authenticateWithUsername:@"MumbleiPhoneUser" password:nil];
}

#pragma mark MKServerModel Delegate

//
// We've successfuly joined the server.
//
- (void) serverModel:(MKServerModel *)server joinedServerAsUser:(MKUser *)user {
	NSLog(@"joinedServerAsUser:");

	//
	// Channel view
	//
	ChannelViewController *channelView = [[ChannelViewController alloc] initWithChannel:[server rootChannel] serverModel:server];
	UINavigationController *channelNavController = [[UINavigationController alloc] initWithRootViewController:channelView];
	[channelView release];
	UITabBarItem *channelBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemHistory tag:0];
	[channelNavController setTabBarItem:channelBarItem];
	[channelBarItem release];

	//
	// Log view
	//
	LogViewController *logView = [[LogViewController alloc] initWithServerModel:_model];
	UINavigationController *logNavController = [[UINavigationController alloc] initWithRootViewController:logView];
	[logView release];
	UITabBarItem *logBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemRecents tag:1];
	[logNavController setTabBarItem:logBarItem];
	[logBarItem release];

	//
	// User view
	//
	UserViewController *userView = [[UserViewController alloc] initWithServerModel:_model];
	UINavigationController *userNavController = [[UINavigationController alloc] initWithRootViewController:userView];
	[userView release];
	UITabBarItem *userBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemContacts tag:2];
	[userNavController setTabBarItem:userBarItem];
	[userBarItem release];

	[self setViewControllers:[NSArray arrayWithObjects:channelNavController, userNavController, logNavController, nil]];

	[channelNavController release];
	[logNavController release];
	[userNavController release];
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


@end
