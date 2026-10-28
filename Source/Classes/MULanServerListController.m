// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MULanServerListController.h"
#import "MUInterface.h"
#import "MUServerRootViewController.h"
#import "MUFavouriteServer.h"
#import "MUFavouriteServerEditViewController.h"
#import "MUServerCell.h"
#import "MUDatabase.h"
#import "MUFavouriteServerListController.h"
#import "MUConnectionController.h"

static NSInteger NetServiceAlphabeticalSort(id arg1, id arg2, void *reverse) {
    return [[arg1 name] localizedStandardCompare:[arg2 name]];
} 

@interface MULanServerListController () <NSNetServiceBrowserDelegate, NSNetServiceDelegate> {
    NSNetServiceBrowser  *_browser;
    NSMutableArray       *_netServices;
    BOOL _browsing, _discoveryFailed;
    __weak UIViewController *_actionPresenter;
}
- (void)presentAddAsFavouriteDialogForServer:(NSNetService *)netService fromViewController:(UIViewController *)parent;
@end

@implementation MULanServerListController

#pragma mark -
#pragma mark Initialization

- (id) init {
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        _netServices = [[NSMutableArray alloc] init];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(appEnteredBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(appBecameActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

#pragma mark -

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[self navigationItem] setTitle:NSLocalizedString(@"LAN Servers", nil)];
    
    {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    }
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self startDiscovery];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopDiscovery];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [_browser stop];
    _browser.delegate = nil;
    [_browser removeFromRunLoop:NSRunLoop.mainRunLoop forMode:NSDefaultRunLoopMode];
    for (NSNetService *service in _netServices) {
        service.delegate = nil;
        [service stop];
        [service removeFromRunLoop:NSRunLoop.mainRunLoop forMode:NSDefaultRunLoopMode];
    }
}

- (NSArray<NSNetService *> *)discoveredServers { return [_netServices copy]; }
- (BOOL)discoveryFailed { return _discoveryFailed; }
- (void)appEnteredBackground:(NSNotification *)notification { [self stopDiscovery]; }
- (void)appBecameActive:(NSNotification *)notification {
    if (self.isViewLoaded && self.view.window) [self startDiscovery];
}

- (void)notifyServersChanged {
    if (self.isViewLoaded && self.view.window) [self.tableView reloadData];
    if (self.serversChangedHandler) self.serversChangedHandler();
}

- (void)startDiscovery {
    if (_browsing) return;
    _browsing = YES;
    _discoveryFailed = NO;
    _browser = [NSNetServiceBrowser new];
    _browser.delegate = self;
    [_browser scheduleInRunLoop:NSRunLoop.mainRunLoop forMode:NSDefaultRunLoopMode];
    [_netServices removeAllObjects];
    [self notifyServersChanged];
    [_browser searchForServicesOfType:@"_mumble._tcp" inDomain:@"local."];
}

- (void)stopDiscovery {
    _browsing = NO;
    [_browser stop];
    _browser.delegate = nil;
    [_browser removeFromRunLoop:NSRunLoop.mainRunLoop forMode:NSDefaultRunLoopMode];
    _browser = nil;
    for (NSNetService *service in _netServices) {
        service.delegate = nil;
        [service stop];
        [service removeFromRunLoop:NSRunLoop.mainRunLoop forMode:NSDefaultRunLoopMode];
    }
    [_netServices removeAllObjects];
}

#pragma mark -
#pragma mark NSNetServiceBrowser delegate

- (void) netServiceBrowser:(NSNetServiceBrowser *)browser didFindService:(NSNetService *)netService moreComing:(BOOL)moreServices {    
    if (!_browsing || browser != _browser || [_netServices containsObject:netService]) return;
    [_netServices addObject:netService];
    [_netServices sortUsingFunction:NetServiceAlphabeticalSort context:nil];

    [netService scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [netService setDelegate:self];
    [netService resolveWithTimeout:10.0f];
    if (!moreServices) [self notifyServersChanged];
}

- (void) netServiceBrowser:(NSNetServiceBrowser *)browser didRemoveService:(NSNetService *)netService moreComing:(BOOL)moreServices {
    if (!_browsing || browser != _browser || ![_netServices containsObject:netService]) return;
    [_netServices removeObject:netService];
    netService.delegate = nil;
    [netService stop];
    [netService removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    if (!moreServices) [self notifyServersChanged];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didNotSearch:(NSDictionary<NSString *, NSNumber *> *)errorDict {
    if (!_browsing || browser != _browser) return;
    [self stopDiscovery];
    _discoveryFailed = YES;
    [self notifyServersChanged];
}

#pragma mark -
#pragma mark NSNetService delegate

- (void) netServiceDidResolveAddress:(NSNetService *)netService {
    if (_browsing && [_netServices containsObject:netService]) [self notifyServersChanged];
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
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return (UITableViewCell *) cell;
}

#pragma mark -
#pragma mark Selection

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSNetService *netService = [_netServices objectAtIndex:[indexPath row]];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self presentActionsForServer:netService fromViewController:self sourceView:[tableView cellForRowAtIndexPath:indexPath]];
}

- (void)presentActionsForServer:(NSNetService *)netService fromViewController:(UIViewController *)parent sourceView:(UIView *)sourceView {
    // Server not yet resolved
    if ([netService hostName] == nil) {
        return;
    }
    
    UIAlertController* sheetCtrl = [UIAlertController alertControllerWithTitle:[netService name]
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
    
    [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                   style:UIAlertActionStyleCancel
                                                 handler:nil]];
    [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Add as favourite", nil)
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * _Nonnull action) {
        [self presentAddAsFavouriteDialogForServer:netService fromViewController:parent];
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
                                                     handler:nil]];
        [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Connect", nil)
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * _Nonnull action) {
            MUConnectionController *connCtrlr = [MUConnectionController sharedController];
            [connCtrlr connectToHostname:[netService hostName]
                                   port:[netService port]
                           withUsername:[[[alertCtrl textFields] objectAtIndex:0] text]
                            andPassword:nil
               withParentViewController:parent];
        }]];
        
        [parent presentViewController:alertCtrl animated:YES completion:nil];
    }]];
    
    MUConfigureServerActionSheet(sheetCtrl, sourceView ?: parent.view);
    [parent presentViewController:sheetCtrl animated:YES completion:nil];
}

- (void)presentAddAsFavouriteDialogForServer:(NSNetService *)netService fromViewController:(UIViewController *)parent {
    _actionPresenter = parent;
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
    
    [parent presentViewController:modalNav animated:YES completion:nil];
}

- (void) doneButtonClicked:(id)sender {
    MUFavouriteServerEditViewController *editView = (MUFavouriteServerEditViewController *)sender;
    MUFavouriteServer *favServ = [editView copyFavouriteFromContent];
    [MUDatabase storeFavourite:favServ];
    
    MUFavouriteServerListController *favController = [[MUFavouriteServerListController alloc] init];
    UINavigationController *navCtrl = (_actionPresenter ?: self).navigationController;
    [navCtrl popToRootViewControllerAnimated:NO];
    [navCtrl pushViewController:favController animated:YES];
}

@end

