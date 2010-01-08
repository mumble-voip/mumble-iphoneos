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

#import "CountryServerListController.h"

@implementation CountryServerListController

- (id) initWithName:(NSString *)country serverList:(NSArray *)servers {
	self = [super initWithNibName:@"CountryServerListController" bundle:nil];
	if (self == nil)
		return nil;

	countryServers = [servers retain];
	countryName = [[country copy] retain];

	// Toolbar items
	UIBarButtonItem *connectItem = [[[UIBarButtonItem alloc] initWithTitle:@"Connect" style:UIBarButtonItemStyleDone target:self action:@selector(connectClicked:)] autorelease];
	UIBarButtonItem *moreInfoItem = [[[UIBarButtonItem alloc] initWithTitle:@"More Info" style:UIBarButtonItemStyleBordered	target:self action:@selector(moreInfoClicked:)] autorelease];
	UIBarButtonItem *addFavItem = [[[UIBarButtonItem alloc] initWithTitle:@"Add as Favourite" style:UIBarButtonItemStyleBordered target:self action:@selector(addFavClicked:)] autorelease];

	[self setToolbarItems:[NSArray arrayWithObjects:moreInfoItem, addFavItem, connectItem, nil] animated:NO];

	return self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

	self.navigationItem.title = countryName;
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];

	// Hide our toolbar.
	[[self navigationController] setToolbarHidden:YES animated:YES];
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
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

/*
 * Table View methods.
 */

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [countryServers count];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"countryServer"];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"countryServer"] autorelease];
    }

	// fixme(mkrautz): Implement a ServerCell.
	NSDictionary *serverItem = [countryServers objectAtIndex:[indexPath indexAtPosition:1]];
	cell.textLabel.text = [serverItem objectForKey:@"name"];
	cell.detailTextLabel.text = [NSString stringWithFormat:@"%@:%@", [serverItem objectForKey:@"ip"], [serverItem objectForKey:@"port"]];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[[self navigationController] setToolbarHidden:NO animated:YES];
}

/*
 * Toolbar actions.
 */
- (void)connectClicked:(id)sender {
	MUMBLE_UNUSED NSIndexPath *indexPath = [[self tableView] indexPathForSelectedRow];
}

- (void)moreInfoClicked:(id)sender {
	MUMBLE_UNUSED NSIndexPath *indexPath = [[self tableView] indexPathForSelectedRow];
}

- (void)addFavClicked:(id)sender {
	MUMBLE_UNUSED NSIndexPath *indexPath = [[self tableView] indexPathForSelectedRow];
}

- (void)dealloc {
    [super dealloc];
	[countryName release];
	[countryServers release];
}

@end

