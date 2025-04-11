// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUCountryServerListController.h"

#import "MUDatabase.h"
#import "MUFavouriteServer.h"
#import "MUFavouriteServerListController.h"
#import "MUFavouriteServerEditViewController.h"
#import "MUServerRootViewController.h"
#import "MUConnectionController.h"
#import "MUServerCell.h"
#import "MUColor.h"
#import "MUOperatingSystem.h"

@interface MUCountryServerListController () <UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource> {
    UITableView    *_tableView;
    NSArray        *_visibleServers;
    NSArray        *_countryServers;
    NSString       *_countryName;
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

- (void) viewDidLoad {    
    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height) style:UITableViewStylePlain];
    [_tableView setDataSource:self];
    [_tableView setDelegate:self];
    [_tableView setAutoresizingMask:UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth];
    [self.view addSubview:_tableView];
    
    [self resetSearch];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.navigationItem.titleView = nil;
    self.navigationItem.title = _countryName;
    self.navigationItem.hidesBackButton = NO;
    
    UINavigationBar *navBar = self.navigationController.navigationBar;
    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        navBar.tintColor = [UIColor whiteColor];
        navBar.translucent = NO;
        navBar.backgroundColor = [UIColor blackColor];
    }
    navBar.barStyle = UIBarStyleBlackOpaque;

    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        _tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        _tableView.separatorInset = UIEdgeInsetsZero;
    }

    UIBarButtonItem *searchButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(searchButtonClicked:)];
    self.navigationItem.rightBarButtonItem = searchButton;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
    return [_visibleServers count];
}

- (void) tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *serverItem = [_visibleServers objectAtIndex:[indexPath row]];
    if ([[serverItem objectForKey:@"ca"] integerValue] > 0) {
        cell.backgroundColor = [MUColor verifiedCertificateChainColor];
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
    cell.selectionStyle = UITableViewCellSelectionStyleGray;

    return (UITableViewCell *) cell;
}

#pragma mark -
#pragma mark Selection

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *serverItem = [_visibleServers objectAtIndex:[indexPath row]];

    UIAlertController *sheetCtrl = [UIAlertController alertControllerWithTitle:[serverItem objectForKey:@"name"]
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];

    [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                   style:UIAlertActionStyleCancel
                                                 handler: ^(UIAlertAction * _Nonnull action) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }]];
    
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
            [connCtrlr connetToHostname:[serverItem objectForKey:@"ip"]
                                   port:[[serverItem objectForKey:@"port"] intValue]
                           withUsername:[[[alertCtrl textFields] firstObject] text]
                            andPassword:nil
               withParentViewController:self];
        }]];

        [self presentViewController:alertCtrl animated:YES completion:nil];
    }]];
    
    [self presentViewController:sheetCtrl animated:YES completion:^() {
        [[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
    }];
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

- (void) performSearchForTerm:(NSString *)searchTerm {        
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *results = [[NSMutableArray alloc] initWithCapacity:[_countryServers count]];
        for (NSDictionary *serverItem in _countryServers) {
            if ([(NSString *)[serverItem objectForKey:@"name"] rangeOfString:searchTerm options:NSCaseInsensitiveSearch].location != NSNotFound ||
                    [(NSString *)[serverItem objectForKey:@"ip"] rangeOfString:searchTerm options:NSCaseInsensitiveSearch].location != NSNotFound) {
                [results addObject:serverItem];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            _visibleServers = results;
            [self.tableView reloadData]; 
        });
    });
}

#pragma mark -
#pragma mark Search Bar Delegate Methods

- (void) searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    NSString *searchText = searchBar.text;
    [self performSearchForTerm:searchText];
    [searchBar resignFirstResponder];
}

- (void) searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if([searchText length] == 0){
        [self resetSearch];
        [self.tableView reloadData];
        return;
    }
    [self performSearchForTerm:searchText];
}

#pragma mark -
#pragma mark UIKeyboard notifications

- (void) keyboardWillShow:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    
    NSValue *val = [userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    NSTimeInterval t;
    [val getValue:&t];
    
    val = [userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey];
    UIViewAnimationCurve c;
    [val getValue:&c];
    
    val = [userInfo objectForKey:UIKeyboardFrameEndUserInfoKey];
    CGRect r;
    [val getValue:&r];
    r = [self.view convertRect:r fromView:nil];
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:t];
    [UIView setAnimationCurve:c];
    _tableView.contentInset = UIEdgeInsetsMake(0.0f, 0.0f, r.size.height, 0.0f);
    _tableView.scrollIndicatorInsets = _tableView.contentInset;
    [UIView commitAnimations];
}

- (void) keyboardWillHide:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    
    NSValue *val = [userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    NSTimeInterval t;
    [val getValue:&t];
    
    val = [userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey];
    UIViewAnimationCurve c;
    [val getValue:&c];
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:t];
    [UIView setAnimationCurve:c];
    _tableView.contentInset = UIEdgeInsetsZero;
    _tableView.scrollIndicatorInsets = UIEdgeInsetsZero;
    [UIView commitAnimations];
}

#pragma mark -
#pragma mark Actions

- (void) searchButtonClicked:(id)sender {
    self.navigationItem.hidesBackButton = YES;
    
    UIBarButtonItem *cancelSearchButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelSearchButtonClicked:)];
    self.navigationItem.rightBarButtonItem = cancelSearchButton;
    
    UISearchBar *searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
    searchBar.delegate = self;
    searchBar.barStyle = UIBarStyleBlack;
    [searchBar sizeToFit];
    self.navigationItem.titleView = searchBar;

    [searchBar becomeFirstResponder];
}

- (void) cancelSearchButtonClicked:(id)sender {
    [self resetSearch];
    [self.tableView reloadData];
    
    UIBarButtonItem *searchButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(searchButtonClicked:)];
    self.navigationItem.rightBarButtonItem = searchButton;
    
    self.navigationItem.hidesBackButton = NO;
    self.navigationItem.titleView = nil;
    [self.navigationItem setTitle:_countryName];
}

@end

