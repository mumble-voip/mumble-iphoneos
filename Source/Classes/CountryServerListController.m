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

#import "Database.h"
#import "FavouriteServer.h"
#import "FavouriteServerListController.h"
#import "FavouriteServerEditViewController.h"

@implementation CountryServerListController

- (id) initWithName:(NSString *)country serverList:(NSArray *)servers {
	self = [super initWithNibName:@"CountryServerListController" bundle:nil];
	if (self == nil)
		return nil;

	_countryServers = [servers retain];
	_countryName = [[country copy] retain];

	return self;
}

- (void) dealloc {
    [super dealloc];

	[_countryName release];
	[_countryServers release];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	[[self navigationItem] setTitle:_countryName];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark -
#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_countryServers count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *reuseIdentifier = @"PublicServer";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier] autorelease];
    }

	// fixme(mkrautz): Implement a ServerCell?
	NSDictionary *serverItem = [_countryServers objectAtIndex:[indexPath row]];
	cell.textLabel.text = [serverItem objectForKey:@"name"];
	cell.detailTextLabel.text = [NSString stringWithFormat:@"%@:%@", [serverItem objectForKey:@"ip"], [serverItem objectForKey:@"port"]];

    return cell;
}

#pragma mark -
#pragma mark Selection

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *serverItem = [_countryServers objectAtIndex:[indexPath row]];

	UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:[serverItem objectForKey:@"name"] delegate:self
											cancelButtonTitle:@"Cancel"
											destructiveButtonTitle:nil
											otherButtonTitles:@"Connect", @"Add as favourite", nil];
	[sheet showInView:[self tableView]];
	[sheet release];
}

- (void) actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
	NSIndexPath *indexPath = [[self tableView] indexPathForSelectedRow];
	[[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
	
	NSDictionary *serverItem = [_countryServers objectAtIndex:[indexPath row]];

	// Connect
	if (index == 0) {
		NSLog(@"Connect...");

	// Add as favourite
	} else if (index == 1) {
		[self presentAddAsFavouriteDialogForServer:serverItem];
	}
}

- (void) presentAddAsFavouriteDialogForServer:(NSDictionary *)serverItem {
	FavouriteServer *favServ = [[FavouriteServer alloc] init];
	[favServ setDisplayName:[serverItem objectForKey:@"name"]];
	[favServ setHostName:[serverItem objectForKey:@"ip"]];
	[favServ setPort:[[serverItem objectForKey:@"port"] intValue]];

	UINavigationController *modalNav = [[UINavigationController alloc] init];
	FavouriteServerEditViewController *editView = [[FavouriteServerEditViewController alloc] initInEditMode:NO withContentOfFavouriteServer:favServ];

	[editView setTarget:self];
	[editView setDoneAction:@selector(doneButtonClicked:)];
	[modalNav pushViewController:editView animated:NO];
	[editView release];

	[[self navigationController] presentModalViewController:modalNav animated:YES];

	[modalNav release];
	[favServ release];
}

- (void) doneButtonClicked:(id)sender {
	FavouriteServerEditViewController *editView = (FavouriteServerEditViewController *)sender;
	FavouriteServer *favServ = [editView copyFavouriteFromContent];
	[Database saveFavourite:favServ];
	[favServ release];

	FavouriteServerListController *favController = [[FavouriteServerListController alloc] init];
	UINavigationController *navCtrl = [self navigationController];
	[navCtrl popToRootViewControllerAnimated:NO];
	[navCtrl pushViewController:favController animated:YES];
	[favController release];
}


@end

