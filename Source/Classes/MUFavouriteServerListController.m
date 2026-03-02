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
#import "MUColor.h"
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

- (BOOL) shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask) supportedInterfaceOrientations {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        return UIInterfaceOrientationMaskAll;
    }
    return UIInterfaceOrientationMaskPortrait;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [[self navigationItem] setTitle:NSLocalizedString(@"Favourite Servers", nil)];
    
    if (@available(iOS 11.0, *)) {
        self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    }
    
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addButtonClicked:)];
    [[self navigationItem] setRightBarButtonItem:addButton];

    [self reloadFavourites];
}

- (void) reloadFavourites {
    _favouriteServers = [MUDatabase fetchAllFavourites];
    [_favouriteServers sortUsingSelector:@selector(compare:)];
    [self updateEmptyState];
}

- (void) updateEmptyState {
    if ([_favouriteServers count] == 0) {
        UIView *emptyView = [[UIView alloc] initWithFrame:self.tableView.bounds];
        
        UIImageView *iconView = [[UIImageView alloc] init];
        if (@available(iOS 13.0, *)) {
            iconView.image = [UIImage systemImageNamed:@"star"
                              withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:48 weight:UIImageSymbolWeightLight]];
            iconView.tintColor = [UIColor tertiaryLabelColor];
        }
        iconView.translatesAutoresizingMaskIntoConstraints = NO;
        [emptyView addSubview:iconView];
        
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.text = NSLocalizedString(@"No Favourite Servers", nil);
        titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
        titleLabel.textColor = [MUColor secondaryTextColor];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [emptyView addSubview:titleLabel];
        
        UILabel *detailLabel = [[UILabel alloc] init];
        detailLabel.text = NSLocalizedString(@"Tap + to add a server, or browse public servers.\nServers you connect to are saved automatically.", nil);
        detailLabel.font = [UIFont systemFontOfSize:15];
        detailLabel.textColor = [MUColor tertiaryTextColor];
        detailLabel.textAlignment = NSTextAlignmentCenter;
        detailLabel.numberOfLines = 0;
        detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [emptyView addSubview:detailLabel];
        
        [NSLayoutConstraint activateConstraints:@[
            [iconView.centerXAnchor constraintEqualToAnchor:emptyView.centerXAnchor],
            [iconView.centerYAnchor constraintEqualToAnchor:emptyView.centerYAnchor constant:-60],
            
            [titleLabel.topAnchor constraintEqualToAnchor:iconView.bottomAnchor constant:16],
            [titleLabel.leadingAnchor constraintEqualToAnchor:emptyView.leadingAnchor constant:32],
            [titleLabel.trailingAnchor constraintEqualToAnchor:emptyView.trailingAnchor constant:-32],
            
            [detailLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8],
            [detailLabel.leadingAnchor constraintEqualToAnchor:emptyView.leadingAnchor constant:32],
            [detailLabel.trailingAnchor constraintEqualToAnchor:emptyView.trailingAnchor constant:-32],
        ]];
        
        self.tableView.backgroundView = emptyView;
    } else {
        self.tableView.backgroundView = nil;
    }
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
    
    // Swipe hint accessory
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightRegular];
        UIImageView *hintView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"line.3.horizontal" withConfiguration:config]];
        hintView.tintColor = [UIColor tertiaryLabelColor];
        cell.accessoryView = hintView;
    }
    
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
    // Direct connect on tap
    MUFavouriteServer *favServ = [_favouriteServers objectAtIndex:[indexPath row]];
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
}

- (void) deleteFavouriteAtIndexPath:(NSIndexPath *)indexPath {
    // Drop it from the database
    MUFavouriteServer *favServ = [_favouriteServers objectAtIndex:[indexPath row]];
    [MUDatabase deleteFavourite:favServ];
    
    // And remove it from our locally sorted array
    [_favouriteServers removeObjectAtIndex:[indexPath row]];
    [[self tableView] deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
    [[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
    [self updateEmptyState];
}

- (UISwipeActionsConfiguration *) tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    MUFavouriteServer *favServ = [_favouriteServers objectAtIndex:[indexPath row]];
    
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                               title:NSLocalizedString(@"Delete", nil)
                                                                             handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [self deleteFavouriteAtIndexPath:indexPath];
        completionHandler(YES);
    }];
    if (@available(iOS 13.0, *)) {
        deleteAction.image = [UIImage systemImageNamed:@"trash"];
    }
    
    UIContextualAction *editAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                             title:NSLocalizedString(@"Edit", nil)
                                                                           handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [self presentEditDialogForFavourite:favServ];
        completionHandler(YES);
    }];
    editAction.backgroundColor = [UIColor systemBlueColor];
    if (@available(iOS 13.0, *)) {
        editAction.image = [UIImage systemImageNamed:@"pencil"];
    }
    
    return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction, editAction]];
}

- (UISwipeActionsConfiguration *) tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    MUFavouriteServer *favServ = [_favouriteServers objectAtIndex:[indexPath row]];
    
    UIContextualAction *connectAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                                title:NSLocalizedString(@"Connect", nil)
                                                                              handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
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
        completionHandler(YES);
    }];
    connectAction.backgroundColor = [UIColor systemGreenColor];
    if (@available(iOS 13.0, *)) {
        connectAction.image = [UIImage systemImageNamed:@"bolt.fill"];
    }
    
    return [UISwipeActionsConfiguration configurationWithActions:@[connectAction]];
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
