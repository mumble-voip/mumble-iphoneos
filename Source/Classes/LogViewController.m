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

#import "LogViewController.h"
#import "LogEntry.h"

@implementation LogViewController

- (id) initWithServerModel:(MKServerModel *)serverModel {
	self = [super init];
	if (self == nil)
		return nil;

	_serverModel = serverModel;
	[_serverModel addDelegate:self];

	_logEntries = [[NSMutableArray alloc] init];
	_dateFormatter = [[NSDateFormatter alloc] init];

	[_dateFormatter setTimeStyle:NSDateFormatterLongStyle];

	return self;
}

- (void) dealloc {
	[super dealloc];

	[_serverModel removeDelegate:self];
	[_logEntries release];
}

- (void) didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
}

#pragma mark -

- (void) viewWillAppear:(BOOL)animated {
	self.navigationItem.title = @"Log";
}

#pragma mark -

//
// A user joined the server.
//
- (void) serverModel:(MKServerModel *)server userJoined:(MKUser *)user {
	LogEntry *entry = [[LogEntry alloc] initWithText:@"User Joined"];
	[_logEntries addObject:entry];
	[entry release];

	[self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:UITableViewRowAnimationTop];
}

//
// A user left the server.
//
- (void) serverModel:(MKServerModel *)server userLeft:(MKUser *)user {
	LogEntry *entry = [[LogEntry alloc] initWithText:@"User Left"];
	[_logEntries addObject:entry];
	[entry release];

	[self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:UITableViewRowAnimationTop];
}

#pragma mark Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}


- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_logEntries count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    static NSString *CellIdentifier = @"logCell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
    }

	// Ascending
	NSUInteger idx = 0;
	if (_logEntries.count > 0) {
		idx = (_logEntries.count - 1) - indexPath.row;
	}

	LogEntry *entry = [_logEntries objectAtIndex:idx];

	cell.textLabel.text = [entry text];
	cell.detailTextLabel.text = [_dateFormatter stringFromDate:[entry date]];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
}

@end

