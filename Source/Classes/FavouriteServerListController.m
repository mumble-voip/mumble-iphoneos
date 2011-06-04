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

#import "FavouriteServerListController.h"

#import "Database.h"
#import "FavouriteServer.h"
#import "FavouriteServerEditViewController.h"

#import "ServerConnectionViewController.h"
#import "ServerRootViewController.h"
#import "ServerRootViewControllerPad.h"
#import "ServerCell.h"

@implementation FavouriteServerListController

#pragma mark -
#pragma mark Initialization

- (id) init {
	if ((self = [super init])) {
		[[self navigationItem] setTitle:@"Favourites"];
        
		UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addButtonClicked:)];
		[[self navigationItem] setRightBarButtonItem:addButton];
		[addButton release];
        
		_favouriteServers = [[Database fetchAllFavourites] retain];
		[_favouriteServers sortUsingSelector:@selector(compare:)];
	}
    
	return self;
}

- (void) dealloc {
	[Database storeFavourites:_favouriteServers];
	[_favouriteServers release];
    
	[super dealloc];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	// On iPad, we support all interface orientations.
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		return YES;
	}
    
	return toInterfaceOrientation == UIInterfaceOrientationPortrait;
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_favouriteServers count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    FavouriteServer *favServ = [_favouriteServers objectAtIndex:[indexPath row]];
    ServerCell *cell = (ServerCell *)[tableView dequeueReusableCellWithIdentifier:[ServerCell reuseIdentifier]];
    if (cell == nil) {
        cell = [[[ServerCell alloc] init] autorelease];
    }
    [cell populateFromFavouriteServer:favServ];
    return (UITableViewCell *) cell;
}

- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		NSUInteger row = [indexPath row];
        
		// Drop it from the database
		FavouriteServer *favServ = [_favouriteServers objectAtIndex:row];
		[Database deleteFavourite:favServ];
        
		// And remove it from our locally sorted array
		[_favouriteServers removeObjectAtIndex:[indexPath row]];
		[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
    }
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	FavouriteServer *favServ = [_favouriteServers objectAtIndex:[indexPath row]];
	BOOL pad = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
	UIView *cellView = [[self tableView] cellForRowAtIndexPath:indexPath];
    
	NSString *sheetTitle = pad ? nil : [favServ displayName];
	UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:sheetTitle delegate:self
                                              cancelButtonTitle:@"Cancel"
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:@"Connect", @"Edit", nil];
	if (pad) {
		CGRect frame = cellView.frame;
		frame.origin.y = frame.origin.y - (frame.size.height/2);
		[sheet showFromRect:frame inView:self.tableView animated:YES];
	} else {
		[sheet showInView:cellView];
	}
	[sheet release];
}

- (void) actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
	NSIndexPath *indexPath = [[self tableView] indexPathForSelectedRow];
	[[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
    
	FavouriteServer *favServ = [_favouriteServers objectAtIndex:[indexPath row]];
    
	// Connect
	if (index == 0) {
        ServerRootViewController *serverRoot = [[ServerRootViewController alloc] initWithHostname:[favServ hostName]
		    																				 port:[favServ port]
			     																		 username:[favServ userName]
				    																	 password:[favServ password]];
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] != UIUserInterfaceIdiomPad) {
			[serverRoot setModalTransitionStyle:UIModalTransitionStyleFlipHorizontal];
        }
        
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:serverRoot];
		[[self navigationController] presentModalViewController:nav animated:YES];
		[serverRoot release];
		[nav release];
        
        // Edit
	} else if (index == 1) {
		[self presentEditDialogForFavourite:favServ];
	}
}

#pragma mark -
#pragma Modal edit dialog

- (void) presentNewFavouriteDialog {
	UINavigationController *modalNav = [[UINavigationController alloc] init];
    
	FavouriteServerEditViewController *editView = [[FavouriteServerEditViewController alloc] init];
    
	_editMode = NO;
	_editedServer = nil;
    
	[editView setTarget:self];
	[editView setDoneAction:@selector(doneButtonClicked:)];
	[modalNav pushViewController:editView animated:NO];
	[editView release];
    
	modalNav.modalPresentationStyle = UIModalPresentationFormSheet;
	[[self navigationController] presentModalViewController:modalNav animated:YES];
	[modalNav release];
}

- (void) presentEditDialogForFavourite:(FavouriteServer *)favServ {
	UINavigationController *modalNav = [[UINavigationController alloc] init];
    
	FavouriteServerEditViewController *editView = [[FavouriteServerEditViewController alloc] initInEditMode:YES withContentOfFavouriteServer:favServ];
    
	_editMode = YES;
	_editedServer = favServ;
    
	[editView setTarget:self];
	[editView setDoneAction:@selector(doneButtonClicked:)];
	[modalNav pushViewController:editView animated:NO];
	[editView release];
    
	modalNav.modalPresentationStyle = UIModalPresentationFormSheet;
	[[self navigationController] presentModalViewController:modalNav animated:YES];
	[modalNav release];
}

#pragma mark -
#pragma mark Add button target

//
// Action for someone clicking the '+' button on the Favourite Server listing.
//
- (void) addButtonClicked:(id)sender {
	[self presentNewFavouriteDialog];
}

#pragma mark -
#pragma mark Done button target (from Edit View)

//
// We get called here when someone clicks 'Done' in a FavouriteServerEditViewController.
//
- (void) doneButtonClicked:(id)sender {
	FavouriteServerEditViewController *editView = sender;
    
	if (_editMode)
		[_favouriteServers removeObject:_editedServer];
    
	FavouriteServer *newServer = [editView copyFavouriteFromContent];
	[_favouriteServers addObject:newServer];
	[newServer release];
    
	[Database storeFavourite:newServer];
	[_favouriteServers sortUsingSelector:@selector(compare:)];
    [[self tableView] reloadData];
}

@end
