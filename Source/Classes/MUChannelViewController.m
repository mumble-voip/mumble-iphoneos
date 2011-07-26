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

#import "MUChannelViewController.h"

@implementation MUChannelViewController

- (id) initWithChannel:(MKChannel *)channel serverModel:(MKServerModel *)model {
	self = [super initWithNibName:@"ChannelViewController" bundle:nil];
	if (! self)
		return nil;

	_channel = channel;
	_model = model;

	return self;
}

- (void) dealloc {
	[super dealloc];
}

#pragma mark -

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void) viewWillAppear:(BOOL)flag {
	[[self navigationItem] setTitle:[_channel channelName]];

	UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneButtonClicked:)];
	[[self navigationItem] setRightBarButtonItem:doneButton];
	[doneButton release];
}

- (void) viewDidAppear:(BOOL)animated {
 }

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

#pragma mark Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
	return 3;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == ChannelViewSectionSubChannels) {
		return [[_channel channels] count];
	} else if (section == ChannelViewSectionUsers) {
		return [[_channel users] count];
	} else if (section == ChannelViewSectionActions) {
		return 1;
	}

	return 0;
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == ChannelViewSectionSubChannels) {
		return @"Subchannels";
	} else if (section == ChannelViewSectionUsers) {
		return @"Users";
	} else if (section == ChannelViewSectionActions) {
		return @"Actions";
	}

	return nil;
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"channelViewCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }

	ChannelViewSection section = [indexPath indexAtPosition:0];
	NSUInteger row = [indexPath indexAtPosition:1];

	if (section == ChannelViewSectionSubChannels) {
		MKChannel *childChannel = [[_channel channels] objectAtIndex:row];
		cell.imageView.image = [UIImage imageNamed:@"channel"];
		cell.textLabel.text = [childChannel channelName];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	} else if (section == ChannelViewSectionUsers) {
		MKUser *channelUser = [[_channel users] objectAtIndex:row];
		cell.imageView.image = [UIImage imageNamed:@"talking_off"];
		cell.textLabel.text = [channelUser userName];
		cell.accessoryType = UITableViewCellAccessoryNone;
	} else if (section == ChannelViewSectionActions) {
		// Join Channel
		if (row == 0) {
			cell.textLabel.text = @"Join Channel";
		}
	}

    return cell;
}

#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	ChannelViewSection section = [indexPath indexAtPosition:0];
	NSUInteger row = [indexPath indexAtPosition:1];

	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if (section == ChannelViewSectionSubChannels) {
		MKChannel *childChannel = [[_channel channels] objectAtIndex:row];
		MUChannelViewController *channelView = [[MUChannelViewController alloc] initWithChannel:childChannel serverModel:_model];
		[self.navigationController pushViewController:channelView animated:YES];
		[channelView release];
	} else if (section == ChannelViewSectionActions) {
		if (row == ChannelViewActionJoinChannel) {
			[_model joinChannel:_channel];
			[[self navigationController] dismissModalViewControllerAnimated:YES];
		}
	}
}

#pragma mark -
#pragma mark Target/actions

- (void) doneButtonClicked:(id)button {
	[[self navigationController] dismissModalViewControllerAnimated:YES];
}

@end
