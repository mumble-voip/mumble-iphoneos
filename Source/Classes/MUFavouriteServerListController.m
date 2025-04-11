// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUFavouriteServerListController.h"

#import "MUDatabase.h"
#import "MUFavouriteServer.h"
#import "MUFavouriteServerEditViewController.h"
#import "MUTableViewHeaderLabel.h"
#import "MUConnectionController.h"
#import "MUServerCell.h"
#import "MUOperatingSystem.h"
#import "MUBackgroundView.h"

@interface MUFavouriteServerListController () {
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

    [[self navigationItem] setTitle:NSLocalizedString(@"Favourite Servers", nil)];
    
    UINavigationBar *navBar = self.navigationController.navigationBar;
    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        navBar.tintColor = [UIColor whiteColor];
        navBar.translucent = NO;
        navBar.backgroundColor = [UIColor blackColor];
    }
    navBar.barStyle = UIBarStyleBlackOpaque;
    
    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        self.tableView.separatorInset = UIEdgeInsetsZero;
    }
    
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addButtonClicked:)];
    [[self navigationItem] setRightBarButtonItem:addButton];

    [self reloadFavourites];
}

- (void) reloadFavourites {
    _favouriteServers = [MUDatabase fetchAllFavourites];
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
        cell = [[MUServerCell alloc] init];
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
    
    UIAlertController* sheetCtrl = [UIAlertController alertControllerWithTitle:sheetTitle
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
    
    [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                   style:UIAlertActionStyleCancel
                                                 handler:^(UIAlertAction * _Nonnull action) {
        [[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
    }]];
    
    [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Delete", nil)
                                                   style:UIAlertActionStyleDestructive
                                                 handler:^(UIAlertAction * _Nonnull action) {
        NSString *title = NSLocalizedString(@"Delete Favourite", nil);
        NSString *msg = NSLocalizedString(@"Are you sure you want to delete this favourite server?", nil);
        UIAlertController* alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                                           message:msg
                                                                    preferredStyle:UIAlertControllerStyleAlert];
        
        [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"No", nil)
                                                       style:UIAlertActionStyleCancel
                                                     handler:nil]];
        [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", nil)
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * _Nonnull action) {
            [self deleteFavouriteAtIndexPath:indexPath];
        }]];

        [self presentViewController:alertCtrl animated:YES completion:nil];
        [[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
    }]];
    [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Edit", nil)
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * _Nonnull action) {
        [self presentEditDialogForFavourite:favServ];
        [[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
    }]];
    
    [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Connect", nil)
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * _Nonnull action) {
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
    }]];
    
    [self presentViewController:sheetCtrl animated:YES completion:nil];
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
    
    modalNav.modalPresentationStyle = UIModalPresentationFormSheet;
    [[self navigationController] presentViewController:modalNav animated:YES completion:nil];
}

- (void) presentEditDialogForFavourite:(MUFavouriteServer *)favServ {
    UINavigationController *modalNav = [[UINavigationController alloc] init];
    
    MUFavouriteServerEditViewController *editView = [[MUFavouriteServerEditViewController alloc] initInEditMode:YES withContentOfFavouriteServer:favServ];
    
    _editMode = YES;
    _editedServer = favServ;
    
    [editView setTarget:self];
    [editView setDoneAction:@selector(doneButtonClicked:)];
    [modalNav pushViewController:editView animated:NO];
    
    modalNav.modalPresentationStyle = UIModalPresentationFormSheet;
    [[self navigationController]presentViewController:modalNav animated:YES completion:nil];
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

    [self reloadFavourites];
    [self.tableView reloadData];
}

@end
