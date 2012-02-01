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

#import "MUFavouriteServerListController.h"

#import "MUDatabase.h"
#import "MUFavouriteServer.h"
#import "MUFavouriteServerEditViewController.h"
#import "MUTableViewHeaderLabel.h"
#import "MUConnectionController.h"
#import "MUServerCell.h"

@interface MUFavouriteServerListController () <UIAlertViewDelegate> {
    NSMutableArray     *_favouriteServers;
    BOOL               _editMode;
    MUFavouriteServer  *_editedServer;
}
- (void) reloadFavourites;
- (void) deleteFavouriteAtIndexPath:(NSIndexPath *)indexPath;
@end

@implementation MUFavouriteServerListController

#pragma mark -
#pragma mark Initialization

- (id) init {
    if ((self = [super init])) {
        // ...
    }
    
    return self;
}

- (void) dealloc {
    [MUDatabase storeFavourites:_favouriteServers];
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

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [[self navigationItem] setTitle:@"Favourites"];
    
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addButtonClicked:)];
    [[self navigationItem] setRightBarButtonItem:addButton];
    [addButton release];

    [self reloadFavourites];
}

- (void) reloadFavourites {
    [_favouriteServers release];
    _favouriteServers = [[MUDatabase fetchAllFavourites] retain];
    [_favouriteServers sortUsingSelector:@selector(compare:)];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_favouriteServers count];
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MUFavouriteServer *favServ = [_favouriteServers objectAtIndex:[indexPath row]];
    MUServerCell *cell = (MUServerCell *)[tableView dequeueReusableCellWithIdentifier:[MUServerCell reuseIdentifier]];
    if (cell == nil) {
        cell = [[[MUServerCell alloc] init] autorelease];
    }
    [cell populateFromFavouriteServer:favServ];
    cell.selectionStyle = UITableViewCellSelectionStyleGray;
    return (UITableViewCell *) cell;
}

- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self deleteFavouriteAtIndexPath:indexPath];
    }
}

#pragma mark -
#pragma mark Table view delegate

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    MUFavouriteServer *favServ = [_favouriteServers objectAtIndex:[indexPath row]];
    BOOL pad = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
    UIView *cellView = [[self tableView] cellForRowAtIndexPath:indexPath];
    
    NSString *sheetTitle = pad ? nil : [favServ displayName];
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:sheetTitle delegate:self
                                              cancelButtonTitle:@"Cancel"
                                         destructiveButtonTitle:@"Delete"
                                              otherButtonTitles:@"Edit", @"Connect", nil];
    if (pad) {
        CGRect frame = cellView.frame;
        frame.origin.y = frame.origin.y - (frame.size.height/2);
        [sheet showFromRect:frame inView:self.tableView animated:YES];
    } else {
        [sheet showInView:cellView];
    }
    [sheet release];
}

- (void) deleteFavouriteAtIndexPath:(NSIndexPath *)indexPath {
    // Drop it from the database
    MUFavouriteServer *favServ = [_favouriteServers objectAtIndex:[indexPath row]];
    [MUDatabase deleteFavourite:favServ];
    
    // And remove it from our locally sorted array
    [_favouriteServers removeObjectAtIndex:[indexPath row]];
    [[self tableView] deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
    [[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
}

- (void) actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
    NSIndexPath *indexPath = [[self tableView] indexPathForSelectedRow];
    
    MUFavouriteServer *favServ = [_favouriteServers objectAtIndex:[indexPath row]];
    
    // Delete
    if (index == 0) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Delete Favourite" message:@"Are you sure you want to delete this favourite server?" delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
        [alertView show];
        [alertView release];
    // Connect
    } else if (index == 2) {
        NSString *userName = [favServ userName];
        if (userName == nil) {
            userName = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultUserName"];
        }
        
        MUConnectionController *connCtrlr = [MUConnectionController sharedController];
        [connCtrlr connetToHostname:[favServ hostName]
                               port:[favServ port]
                            withUsername:userName
                        andPassword:[favServ password]
           withParentViewController:self];
        [[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
    // Edit
    } else if (index == 1) {
        [self presentEditDialogForFavourite:favServ];
    // Cancel
    } else if (index == 3) {
        [[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
    }
}

#pragma mark -
#pragma mark UIAlertViewDelegate

- (void) alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    NSIndexPath *selectedRow = [[self tableView] indexPathForSelectedRow];
    if (buttonIndex == 0) {
        // ...
    } else if (buttonIndex == 1) {
        [self deleteFavouriteAtIndexPath:selectedRow];
    }

    [[self tableView] deselectRowAtIndexPath:selectedRow animated:YES];
}

#pragma mark -
#pragma Modal edit dialog

- (void) presentNewFavouriteDialog {
    UINavigationController *modalNav = [[UINavigationController alloc] init];
    
    MUFavouriteServerEditViewController *editView = [[MUFavouriteServerEditViewController alloc] init];
    
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

- (void) presentEditDialogForFavourite:(MUFavouriteServer *)favServ {
    UINavigationController *modalNav = [[UINavigationController alloc] init];
    
    MUFavouriteServerEditViewController *editView = [[MUFavouriteServerEditViewController alloc] initInEditMode:YES withContentOfFavouriteServer:favServ];
    
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

// Called when someone clicks 'Done' in a FavouriteServerEditViewController.
- (void) doneButtonClicked:(id)sender {
    MUFavouriteServerEditViewController *editView = sender;
    MUFavouriteServer *newServer = [editView copyFavouriteFromContent];
    [MUDatabase storeFavourite:newServer];
    [newServer release];

    [self reloadFavourites];
    [self.tableView reloadData];
}

@end
