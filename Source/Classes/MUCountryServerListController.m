// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUCountryServerListController.h"
#import "MUInterface.h"

#import "MUDatabase.h"
#import "MUFavouriteServer.h"
#import "MUFavouriteServerListController.h"
#import "MUFavouriteServerEditViewController.h"
#import "MUServerRootViewController.h"
#import "MUConnectionController.h"
#import "MUServerCell.h"

@interface MUCountryServerListController () <UISearchResultsUpdating, UITableViewDelegate, UITableViewDataSource> {
    UITableView    *_tableView;
    NSArray        *_visibleServers;
    NSArray        *_countryServers;
    NSString       *_countryName;
    UISearchController *_searchController;
    NSUInteger _searchGeneration;
}
@end

@implementation MUCountryServerListController

- (id) initWithName:(NSString *)country serverList:(NSArray *)servers {
    self = [super init];
    if (self == nil)
        return nil;
    
    _countryServers = servers;
    _visibleServers = [servers mutableCopy];
    _countryName = [country copy];
    
    return self;
}

- (UITableView *) tableView {
    return _tableView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.dataSource = self; _tableView.delegate = self;
    _tableView.rowHeight = UITableViewAutomaticDimension; _tableView.estimatedRowHeight = 64;
    _tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_tableView];
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor], [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor], [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboardFrameWillChange:) name:UIKeyboardWillChangeFrameNotification object:nil];
    _searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    _searchController.searchResultsUpdater = self;
    _searchController.obscuresBackgroundDuringPresentation = NO;
    self.navigationItem.searchController = _searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.definesPresentationContext = YES;
    [self resetSearch];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.title = _countryName;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)keyboardFrameWillChange:(NSNotification *)notification {
    CGRect frame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect local = [self.view convertRect:frame fromView:nil];
    CGFloat overlap = CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(local);
    if (overlap < 0 || overlap >= CGRectGetHeight(self.view.bounds)) overlap = 0;
    UIEdgeInsets insets = _tableView.contentInset;
    if (fabs(insets.bottom - overlap) < 0.5) return;
    insets.bottom = overlap;
    _tableView.contentInset = insets;
    _tableView.scrollIndicatorInsets = insets;
}

#pragma mark -
#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_visibleServers count];
}

- (void) tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *serverItem = [_visibleServers objectAtIndex:[indexPath row]];
    BOOL verified = [[serverItem objectForKey:@"ca"] integerValue] > 0;
    if ([cell isKindOfClass:[MUServerCell class]]) {
        [(MUServerCell *)cell setShowsVerifiedCertificate:verified];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MUServerCell *cell = (MUServerCell *) [tableView dequeueReusableCellWithIdentifier:[MUServerCell reuseIdentifier]];
    if (cell == nil) {
        cell = [[MUServerCell alloc] init];
    }
    
    NSDictionary *serverItem = [_visibleServers objectAtIndex:[indexPath row]];
    [cell populateFromDisplayName:[serverItem objectForKey:@"name"]
                         hostName:[serverItem objectForKey:@"ip"]
                             port:[serverItem objectForKey:@"port"]];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;

    return (UITableViewCell *) cell;
}

#pragma mark -
#pragma mark Selection

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *serverItem = [_visibleServers objectAtIndex:[indexPath row]];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    UIAlertController *sheetCtrl = [UIAlertController alertControllerWithTitle:[serverItem objectForKey:@"name"]
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
    MUConfigureServerActionSheet(sheetCtrl, [tableView cellForRowAtIndexPath:indexPath] ?: self.view);

    [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                   style:UIAlertActionStyleCancel
                                                 handler:nil]];
    
    [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Add as favourite", nil)
                                                   style:UIAlertActionStyleDefault
                                                 handler: ^(UIAlertAction * _Nonnull action) {
        [self presentAddAsFavouriteDialogForServer:serverItem];
    }]];

    [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Connect", nil)
                                                   style:UIAlertActionStyleDefault
                                                 handler: ^(UIAlertAction * _Nonnull action) {
        NSString *title = NSLocalizedString(@"Username", nil);
        NSString *msg = NSLocalizedString(@"Please enter the username you wish to use on this server", nil);

        UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                                           message:msg
                                                                    preferredStyle:UIAlertControllerStyleAlert];
        
        [alertCtrl addTextFieldWithConfigurationHandler:^(UITextField* textField) {
            [textField setText:[MUDatabase usernameForServerWithHostname:[serverItem objectForKey:@"ip"]
                                                                    port:[[serverItem objectForKey:@"port"] intValue]]];
        }];
        
        [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                       style:UIAlertActionStyleCancel
                                                     handler: nil]];
        [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Connect", nil)
                                                       style:UIAlertActionStyleDefault
                                                     handler: ^(UIAlertAction * _Nonnull action) {
            MUConnectionController *connCtrlr = [MUConnectionController sharedController];
            [connCtrlr connectToHostname:[serverItem objectForKey:@"ip"]
                                   port:[[serverItem objectForKey:@"port"] intValue]
                           withUsername:[[[alertCtrl textFields] firstObject] text]
                            andPassword:nil
               withParentViewController:self];
        }]];

        [self presentViewController:alertCtrl animated:YES completion:nil];
    }]];
    
    [self presentViewController:sheetCtrl animated:YES completion:nil];
}

- (void) presentAddAsFavouriteDialogForServer:(NSDictionary *)serverItem {
    MUFavouriteServer *favServ = [[MUFavouriteServer alloc] init];
    [favServ setDisplayName:[serverItem objectForKey:@"name"]];
    [favServ setHostName:[serverItem objectForKey:@"ip"]];
    [favServ setPort:[[serverItem objectForKey:@"port"] intValue]];
    [favServ setUserName:[MUDatabase usernameForServerWithHostname:[serverItem objectForKey:@"ip"] port:[[serverItem objectForKey:@"port"] intValue]]];

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

#pragma mark -
#pragma mark SearchBar methods

- (void) resetSearch {
    _visibleServers = _countryServers;
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *term = [searchController.searchBar.text copy] ?: @"";
    NSUInteger generation = ++_searchGeneration;
    NSArray *servers = _countryServers;
    __weak MUCountryServerListController *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableArray *matches = [NSMutableArray array];
        for (NSDictionary *server in servers)
            if (!term.length || [server[@"name"] rangeOfString:term options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location != NSNotFound || [server[@"ip"] rangeOfString:term options:NSCaseInsensitiveSearch].location != NSNotFound)
                [matches addObject:server];
        dispatch_async(dispatch_get_main_queue(), ^{
            MUCountryServerListController *controller = weakSelf;
            if (!controller || generation != controller->_searchGeneration) return;
            controller->_visibleServers = matches;
            [controller.tableView reloadData];
        });
    });
}
@end
