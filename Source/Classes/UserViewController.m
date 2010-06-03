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

#import "UserViewController.h"
#import "PDFImageLoader.h"

@implementation UserViewController


#pragma mark -
#pragma mark Initialization

- (id) initWithServerModel:(MKServerModel *)model {
	self = [super init];
	if (self == nil)
		return nil;

	_model = model;
	_currentChannel = [[_model connectedUser] channel];
	_channelUsers = [[[[_model connectedUser] channel] users] mutableCopy];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userTalkStateChanged:) name:@"MKUserTalkStateChanged" object:nil];
	[_model addDelegate:self];

	return self;
}

- (void) dealloc {
    [super dealloc];

	[_model removeDelegate:self];
}

#pragma Server model handlers

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
	NSUInteger userIndex = [_channelUsers indexOfObject:user];
	if (userIndex != NSNotFound) {
		[_channelUsers removeObjectAtIndex:userIndex];
		[[self tableView] deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:userIndex inSection:0]]
								withRowAnimation:UITableViewRowAnimationRight];
	}
}

//
// A user moved channel
//
- (void) serverModel:(MKServerModel *)server userMoved:(MKUser *)user toChannel:(MKChannel *)chan byUser:(MKUser *)mover {
	// Did the user join this channel?
	if (chan == _currentChannel) {
		NSLog(@"user joined us!");
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
}

- (void) userTalkStateChanged:(NSNotification *)notification {
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


#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_channelUsers count];
}

// Customize the appearance of table view cells.
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
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
}
@end

