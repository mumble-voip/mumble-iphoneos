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

#import "PublicServerList.h"
#import "PublicServerListController.h"
#import "CountryServerListController.h"

@implementation PublicServerListController

- (id) init {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		_serverList = [[PublicServerList alloc] init];
		[_serverList setDelegate:self];
		[_serverList load];
	}
	return self;
}

- (void) dealloc {
	[_serverList release];
	[super dealloc];
}

- (void) viewWillAppear:(BOOL)animated {
	self.navigationItem.title = @"Public Servers";

	if (![_serverList loadCompleted]) {
		_activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
		[_activityIndicator startAnimating];
		UIBarButtonItem *rightButton = [[UIBarButtonItem alloc] initWithCustomView:_activityIndicator];
		self.navigationItem.rightBarButtonItem = rightButton;
		[_activityIndicator release];
	}
}


#pragma mark
#pragma mark PublicServerList delegate

- (void) publicServerListDidLoad:(PublicServerList *)publicList {
	[[self tableView] reloadData];
	[_activityIndicator stopAnimating];
}

- (void) publicServerListFailedLoading:(NSError *)error {
}

#pragma mark -
#pragma mark UITableView data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
	if (![_serverList loadCompleted])
		return 0;
	return [_serverList numberOfContinents];
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return [_serverList continentNameAtIndex:section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (![_serverList loadCompleted])
		return 0;
	return [_serverList numberOfCountriesAtContinentIndex:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"countryItem"];
	if (!cell) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"countryItem"] autorelease];
	}

	[cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
	NSDictionary *countryInfo = [_serverList countryAtIndexPath:indexPath];
	cell.textLabel.text = [countryInfo objectForKey:@"name"];
	NSInteger numServers = [[countryInfo objectForKey:@"servers"] count];
	cell.detailTextLabel.text = [NSString stringWithFormat:@"%i %@", numServers, numServers > 1 ? @"servers" : @"server"];

	return cell;
}

#pragma mark -
#pragma mark UITableView delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *countryInfo = [_serverList countryAtIndexPath:indexPath];
	NSString *countryName = [countryInfo objectForKey:@"name"];
	NSArray *countryServers = [countryInfo objectForKey:@"servers"];

	CountryServerListController *countryController = [[CountryServerListController alloc] initWithName:countryName serverList:countryServers];
	[[self navigationController] pushViewController:countryController animated:YES];
	[countryController release];

	// fixme(mkrautz): The feedback from this isn't visible. It'd be nice if
	// we were able to visually show the 'last' selected country when going back to the
	// list of countries.
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
