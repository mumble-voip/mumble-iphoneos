// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MULanServerListController.h"
#import "MUServerRootViewController.h"
#import "MUFavouriteServer.h"
#import "MUFavouriteServerEditViewController.h"
#import "MUServerCell.h"
#import "MUDatabase.h"
#import "MUFavouriteServerListController.h"
#import "MUConnectionController.h"
#import "MUColor.h"
#import "MUBackgroundView.h"

static NSInteger NetServiceAlphabeticalSort(id arg1, id arg2, void *reverse) {
    if (reverse) {
        return [[arg1 name] compare:[arg2 name]];
    } else {
        return [[arg2 name] compare:[arg1 name]];
    }
} 

@interface MULanServerListController () <NSNetServiceBrowserDelegate, NSNetServiceDelegate> {
    NSNetServiceBrowser  *_browser;
    NSMutableArray       *_netServices;
}
- (void) presentAddAsFavouriteDialogForServer:(NSNetService *)netService;
@end

@implementation MULanServerListController

#pragma mark -
#pragma mark Initialization

- (id) init {
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        _browser = [[NSNetServiceBrowser alloc] init];
        [_browser setDelegate:self];
        [_browser scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];

        _netServices = [[NSMutableArray alloc] init];
    }
    return self;
}

#pragma mark -

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:YES];
    [[self navigationItem] setTitle:NSLocalizedString(@"LAN Servers", nil)];
    
    if (@available(iOS 11.0, *)) {
        self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    }
    
    if (!self.refreshControl) {
        UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
        [refresh addTarget:self action:@selector(refreshServerList:) forControlEvents:UIControlEventValueChanged];
        self.refreshControl = refresh;
    }
}

- (void) refreshServerList:(UIRefreshControl *)sender {
    [_browser stop];
    [_netServices removeAllObjects];
    [self.tableView reloadData];
    [_browser searchForServicesOfType:@"_mumble._tcp" inDomain:@"local."];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [sender endRefreshing];
        [self updateEmptyState];
    });
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:YES];
    [_browser searchForServicesOfType:@"_mumble._tcp" inDomain:@"local."];
    [self updateEmptyState];
}

- (void) updateEmptyState {
    if ([_netServices count] == 0) {
        UIView *emptyView = [[UIView alloc] initWithFrame:self.tableView.bounds];
        
        UIImageView *iconView = [[UIImageView alloc] init];
        if (@available(iOS 13.0, *)) {
            iconView.image = [UIImage systemImageNamed:@"wifi.exclamationmark"
                              withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:48 weight:UIImageSymbolWeightLight]];
            iconView.tintColor = [UIColor tertiaryLabelColor];
        }
        iconView.translatesAutoresizingMaskIntoConstraints = NO;
        [emptyView addSubview:iconView];
        
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.text = NSLocalizedString(@"No Servers Found", nil);
        titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
        titleLabel.textColor = [MUColor secondaryTextColor];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [emptyView addSubview:titleLabel];
        
        UILabel *detailLabel = [[UILabel alloc] init];
        detailLabel.text = NSLocalizedString(@"Make sure a Mumble server is running on the same Wi-Fi network.", nil);
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
#pragma mark NSNetServiceBrowser delegate

- (void) netServiceBrowser:(NSNetServiceBrowser *)browser didFindService:(NSNetService *)netService moreComing:(BOOL)moreServices {    
    [_netServices addObject:netService];
    [_netServices sortUsingFunction:NetServiceAlphabeticalSort context:nil];
    NSInteger newIndex = [_netServices indexOfObject:netService];
    [[self tableView] insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:newIndex inSection:0]] withRowAnimation:UITableViewRowAnimationFade];

    [netService scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [netService setDelegate:self];
    [netService resolveWithTimeout:10.0f];
    [self updateEmptyState];
}

- (void) netServiceBrowser:(NSNetServiceBrowser *)browser didRemoveService:(NSNetService *)netService moreComing:(BOOL)moreServices {
    NSInteger curIndex = [_netServices indexOfObject:netService];
    [_netServices removeObjectAtIndex:curIndex];
    [[self tableView] deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:curIndex inSection:0]] withRowAnimation:UITableViewRowAnimationFade];

    [netService removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [self updateEmptyState];
}

#pragma mark -
#pragma mark NSNetService delegate

- (void) netServiceDidResolveAddress:(NSNetService *)netService {
    NSInteger index = [_netServices indexOfObject:netService];
    if (index >= 0) {
        [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:index inSection:0]] withRowAnimation:UITableViewRowAnimationFade];
    }
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_netServices count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSNetService *netService = [_netServices objectAtIndex:[indexPath row]];
    MUServerCell *cell = (MUServerCell *)[tableView dequeueReusableCellWithIdentifier:[MUServerCell reuseIdentifier]];
    if (cell == nil) {
        cell = [[MUServerCell alloc] init];
    }
    [cell populateFromDisplayName:[netService name] hostName:[netService hostName] port:[NSString stringWithFormat:@"%li", (long)[netService port]]];
    cell.selectionStyle = UITableViewCellSelectionStyleGray;
    return (UITableViewCell *) cell;
}

#pragma mark -
#pragma mark Selection

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSNetService *netService = [_netServices objectAtIndex:[indexPath row]];
    // Server not yet resolved
    if ([netService hostName] == nil) {
        [[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    UIAlertController* sheetCtrl = [UIAlertController alertControllerWithTitle:[netService name]
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
    
    [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                   style:UIAlertActionStyleCancel
                                                 handler:^(UIAlertAction * _Nonnull action) {
        [[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
    }]];
    [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Add as favourite", nil)
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * _Nonnull action) {
        [self presentAddAsFavouriteDialogForServer:netService];
    }]];
    [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Connect", nil)
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * _Nonnull action) {
        NSString *title = NSLocalizedString(@"Username", nil);
        NSString *msg = NSLocalizedString(@"Please enter the username you wish to use on this server", nil);
        
        UIAlertController* alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                                           message:msg
                                                                    preferredStyle:UIAlertControllerStyleAlert];
        [alertCtrl addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            [textField setText:[MUDatabase usernameForServerWithHostname:[netService hostName] port:[netService port]]];
        }];
        
        [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                       style:UIAlertActionStyleCancel
                                                     handler:^(UIAlertAction * _Nonnull action) {
            [[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
        }]];
        [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Connect", nil)
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * _Nonnull action) {
            MUConnectionController *connCtrlr = [MUConnectionController sharedController];
            [connCtrlr connetToHostname:[netService hostName]
                                   port:[netService port]
                           withUsername:[[[alertCtrl textFields] objectAtIndex:0] text]
                            andPassword:nil
               withParentViewController:self];
            
            [[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
        }]];
        
        [self presentViewController:alertCtrl animated:YES completion:nil];
    }]];
    
    [self presentViewController:sheetCtrl animated:YES completion:nil];
}

- (void) presentAddAsFavouriteDialogForServer:(NSNetService *)netService {
    MUFavouriteServer *favServ = [[MUFavouriteServer alloc] init];
    [favServ setDisplayName:[netService name]];
    [favServ setHostName:[netService hostName]];
    [favServ setPort:[netService port]];
    [favServ setUserName:[MUDatabase usernameForServerWithHostname:[netService hostName] port:[netService port]]];
    
    UINavigationController *modalNav = [[UINavigationController alloc] init];
    MUFavouriteServerEditViewController *editView = [[MUFavouriteServerEditViewController alloc] initInEditMode:NO withContentOfFavouriteServer:favServ];
    
    [editView setTarget:self];
    [editView setDoneAction:@selector(doneButtonClicked:)];
    [modalNav pushViewController:editView animated:NO];
    
    [[self navigationController] presentViewController:modalNav animated:YES completion:nil];
}

- (void) doneButtonClicked:(id)sender {
    MUFavouriteServerEditViewController *editView = (MUFavouriteServerEditViewController *)sender;
    MUFavouriteServer *favServ = [editView copyFavouriteFromContent];
    [MUDatabase storeFavourite:favServ];
    
    MUFavouriteServerListController *favController = [[MUFavouriteServerListController alloc] init];
    UINavigationController *navCtrl = [self navigationController];
    [navCtrl popToRootViewControllerAnimated:NO];
    [navCtrl pushViewController:favController animated:YES];
}

@end

