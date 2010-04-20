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
#import "PDFImageLoader.h"

@implementation ChannelViewController

#pragma mark -

- (id) initWithChannel:(MKChannel *)channel {
	self = [super initWithNibName:@"ChannelViewController" bundle:nil];
	if (! self)
		return nil;

	_channel = channel;

	// fixme(mkrautz): Move this to ChannelPickerController.
	UITabBarItem *tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemHistory tag:0];
	[self setTabBarItem:tabBarItem];
	[tabBarItem release];

	return self;
}

- (void) dealloc {
	return [super dealloc];
}

#pragma mark -

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void) viewDidLoad {
	[super viewDidLoad];
}

- (void)viewDidUnload {
	[super viewDidUnload];
}

- (void) viewWillAppear:(BOOL)flag {
}

- (void) viewDidAppear:(BOOL)animated {
	self.navigationItem.title = [[_channel channelName] copy];
	UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	UIBarButtonItem *joinChannel = [[UIBarButtonItem alloc] initWithTitle:@"Join Channel" style:UIBarButtonItemStyleBordered target:nil action:nil];

	[self.navigationController setToolbarHidden:NO animated:NO];
	[self.navigationController.toolbar setItems:[NSArray arrayWithObjects: flexSpace, joinChannel, flexSpace, nil] animated:NO];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

#pragma mark Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
	if ([[_channel subchannels] count] > 0) {
		return 2;
	} else {
		return 0;
	}
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == ChannelViewSectionSubChannels) {
		return [[_channel subchannels] count];
	} else if (section == ChannelViewSectionUsers) {
		return [[_channel users] count];
	}

	return 0;
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == ChannelViewSectionSubChannels) {
		return @"Subchannels";
	} else if (section == ChannelViewSectionUsers) {
		return @"Users";
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
		MKChannel *childChannel = [[_channel subchannels] objectAtIndex:row];
		cell.imageView.image = [PDFImageLoader imageFromPDF:@"channel"];
		cell.textLabel.text = [childChannel channelName];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	} else if (section == ChannelViewSectionUsers) {
		MKUser *channelUser = [[_channel users] objectAtIndex:row];
		cell.imageView.image = [PDFImageLoader imageFromPDF:@"talking_off"];
		cell.textLabel.text = [channelUser userName];
		cell.accessoryType = UITableViewCellAccessoryNone;
	}

    return cell;
}

#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	ChannelViewSection section = [indexPath indexAtPosition:0];
	NSUInteger row = [indexPath indexAtPosition:1];

	if (section == ChannelViewSectionSubChannels) {
		MKChannel *childChannel = [[_channel subchannels] objectAtIndex:row];
		ChannelViewController *channelView = [[ChannelViewController alloc] initWithChannel:childChannel];
		[self.navigationController pushViewController:channelView animated:YES];
		[channelView release];
	}
}

@end
