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

#import "PublicServerListController.h"
#import "CountryServerListController.h"

@implementation PublicServerListController

- (id) init {
	self = [super initWithNibName:@"PublicServerListController" bundle:nil];
	if (self == nil)
		return nil;

	publicServerList = [[PublicServerList alloc] init];
	[publicServerList setDelegate:self];
	[publicServerList load];

	// Add UIActivityIndicator
	activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
	[activityIndicator startAnimating];
	UIBarButtonItem *rightButton = [[UIBarButtonItem alloc] initWithCustomView:activityIndicator];
	self.navigationItem.rightBarButtonItem = rightButton;

	return self;
}

- (void) dealloc {
    [super dealloc];
	[publicServerList release];
	[activityIndicator release];
}


- (void)viewDidLoad {
	[super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
	self.navigationItem.title = @"Public Servers";
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
}

 // Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
}

- (void)viewDidUnload {

}

/* Public Server List delegate. */

- (void) serverListReady: (PublicServerList *)publicList {
	loadCompleted = YES;
	[[self tableView] reloadData];
	[activityIndicator stopAnimating];
}

/* Table view methods. */

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {

	if (!loadCompleted)
		return 0;

	return [publicServerList numberOfContinents];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return [publicServerList continentNameAtIndex:section];
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

	if (!loadCompleted)
		return 0;

	return [publicServerList numberOfCountriesAtContinentIndex:section];
}

// Space it a little.
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50.0;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"countryItem"];
	if (!cell) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"countryItem"] autorelease];
	}

	// Set up a disclosure accessory on our cells.
	[cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
	NSDictionary *countryInfo = [publicServerList countryAtIndexPath:indexPath];
	cell.textLabel.text = [countryInfo objectForKey:@"name"];
	NSInteger numServers = [[countryInfo objectForKey:@"servers"] count];
	cell.detailTextLabel.text = [NSString stringWithFormat:@"%i %@", numServers, numServers > 1 ? @"servers" : @"server"];

	return cell;
}

// Row selected.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {


	NSDictionary *countryInfo = [publicServerList countryAtIndexPath:indexPath];
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
