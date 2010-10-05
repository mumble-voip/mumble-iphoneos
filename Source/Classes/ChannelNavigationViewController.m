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

#import "ChannelNavigationViewController.h"


#pragma mark -
#pragma mark ChannelNavigationItem

@interface ChannelNavigationItem : NSObject {
	id         _object;
	NSInteger  _indentLevel;
}

+ (ChannelNavigationItem *) navigationItemWithObject:(id)obj indentLevel:(NSInteger)indentLevel;
- (id) initWithObject:(id)obj indentLevel:(NSInteger)indentLevel;
- (void) dealloc;
- (id) object;
- (NSInteger) indentLevel;

@end

@implementation ChannelNavigationItem

+ (ChannelNavigationItem *) navigationItemWithObject:(id)obj indentLevel:(NSInteger)indentLevel {
	return [[[ChannelNavigationItem alloc] initWithObject:obj indentLevel:indentLevel] autorelease];
}

- (id) initWithObject:(id)obj indentLevel:(NSInteger)indentLevel {
	if (self = [super init]) {
		_object = obj;
		_indentLevel = indentLevel;
	}
	return self;
}

- (void) dealloc {
	[super dealloc];
}

- (id) object {
	return _object;
}

- (NSInteger) indentLevel {
	return _indentLevel;
}

@end

#pragma mark -
#pragma mark ChannelNavigationViewController

@interface ChannelNavigationViewController (Private)
- (void) rebuildModelArrayFromChannel:(MKChannel *)channel;
- (void) addChannelTreeToModel:(MKChannel *)channel indentLevel:(NSInteger)indentLevel;
@end

@implementation ChannelNavigationViewController

#pragma mark -
#pragma mark Initialization and lifecycle

- (id) initWithServerModel:(MKServerModel *)serverModel {
	if (self = [super initWithStyle:UITableViewStylePlain]) {
		_serverModel = serverModel;
		[_serverModel addDelegate:self];
	}
	return self;
}

- (void) dealloc {
	[_serverModel removeDelegate:self];
	[super dealloc];
}

- (void) viewWillAppear:(BOOL)animated {
	UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(doneButtonClicked:)];
	self.navigationItem.rightBarButtonItem = doneButton;
	[doneButton release];
	
	self.navigationItem.title = @"Server View";
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	
	[self rebuildModelArrayFromChannel:[_serverModel rootChannel]];
}

- (void) rebuildModelArrayFromChannel:(MKChannel *)channel {
	[_modelItems release];
	_modelItems = [[NSMutableArray alloc] init];
	
	[_userIndexMap release];
	_userIndexMap = [[NSMutableDictionary alloc] init];

	[_channelIndexMap release];
	_channelIndexMap = [[NSMutableDictionary alloc] init];

	[self addChannelTreeToModel:channel indentLevel:0];
	[self.tableView reloadData];
}

- (void) addChannelTreeToModel:(MKChannel *)channel indentLevel:(NSInteger)indentLevel {	
	[_channelIndexMap setObject:[NSNumber numberWithInt:[_modelItems count]] forKey:[NSNumber numberWithInt:[channel channelId]]];
	[_modelItems addObject:[ChannelNavigationItem navigationItemWithObject:channel indentLevel:indentLevel]];

	for (MKUser *user in [channel users]) {
		[_userIndexMap setObject:[NSNumber numberWithInt:[_modelItems count]] forKey:[NSNumber numberWithInt:[user session]]];
		[_modelItems addObject:[ChannelNavigationItem navigationItemWithObject:user indentLevel:indentLevel+1]];
	}
	for (MKChannel *chan in [channel channels]) {
		[self addChannelTreeToModel:chan indentLevel:indentLevel+1];
	}
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_modelItems count];
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"ChannelNavigationCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }

	ChannelNavigationItem *navItem = [_modelItems objectAtIndex:[indexPath row]];
	id object = [navItem object];

	MKUser *connectedUser = [_serverModel connectedUser];

	cell.textLabel.font = [UIFont systemFontOfSize:14];
	if ([object class] == [MKChannel class]) {
		MKChannel *chan = object;
		cell.imageView.image = [UIImage imageNamed:@"channel"];
		cell.textLabel.text = [chan channelName];
		if (chan == [connectedUser channel])
			cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
	} else if ([object class] == [MKUser class]) {
		MKUser *user = object;
		cell.imageView.image = [UIImage imageNamed:@"talking_off"];
		cell.textLabel.text = [user userName];
		if (user == connectedUser)
			cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
	}

	cell.indentationLevel = [navItem indentLevel];

    return cell;
}

#pragma mark -
#pragma mark Table view delegate

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	ChannelNavigationItem *navItem = [_modelItems objectAtIndex:[indexPath row]];
	id object = [navItem object];
	if ([object class] == [MKChannel class]) {
		[_serverModel joinChannel:object];
	}

	[self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 28.0f;
}

#pragma mark -
#pragma mark Actions

- (void) doneButtonClicked:(id)sender {
	[self dismissModalViewControllerAnimated:YES];
}

#pragma mark -
#pragma mark MumbleKit notifications'n'stuff

- (void) serverModel:(MKServerModel *)model joinedServerAsUser:(MKUser *)user {
}

- (void) serverModel:(MKServerModel *)model userJoined:(MKUser *)user {
}

- (void) serverModel:(MKServerModel *)model userLeft:(MKUser *)user {
	[self rebuildModelArrayFromChannel:[model rootChannel]];
}

- (void) serverModel:(MKServerModel *)model userTalkStateChanged:(MKUser *)user {
	NSLog(@"userTalkStateChanged!!");
	NSInteger userIndex = [[_userIndexMap objectForKey:[NSNumber numberWithInt:[user session]]] integerValue];
	NSLog(@"userIndex = %i", userIndex);

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

	cell.imageView.image = [UIImage imageNamed:talkImageName];
}

- (void) serverModel:(MKServerModel *)model channelAdded:(MKChannel *)channel {
	[self rebuildModelArrayFromChannel:[model rootChannel]];
}

- (void) serverModel:(MKServerModel *)model channelRemoved:(MKChannel *)channel {
	[self rebuildModelArrayFromChannel:[model rootChannel]];
}

- (void) serverModel:(MKServerModel *)model userMoved:(MKUser *)user toChannel:(MKChannel *)chan byUser:(MKUser *)mover {
	[self rebuildModelArrayFromChannel:[model rootChannel]];
}

@end

