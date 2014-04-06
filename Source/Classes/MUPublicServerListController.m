// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUPublicServerList.h"
#import "MUPublicServerListController.h"
#import "MUCountryServerListController.h"
#import "MUTableViewHeaderLabel.h"
#import "MUImage.h"
#import "MUOperatingSystem.h"
#import "MUBackgroundView.h"

@interface MUPublicServerListController () {
    MUPublicServerList        *_serverList;
}
@end

@implementation MUPublicServerListController

- (id) init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        _serverList = [[MUPublicServerList alloc] init];
    }
    return self;
}

- (void) dealloc {
    [_serverList release];
    [super dealloc];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:YES];

    self.navigationItem.title = NSLocalizedString(@"Public Servers", nil);

    UINavigationBar *navBar = self.navigationController.navigationBar;
    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        navBar.tintColor = [UIColor whiteColor];
        navBar.translucent = NO;
        navBar.backgroundColor = [UIColor blackColor];
    }
    navBar.barStyle = UIBarStyleBlackOpaque;
    
    self.tableView.backgroundView = [MUBackgroundView backgroundView];
    
    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        self.tableView.separatorInset = UIEdgeInsetsZero;
    } else {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    }

    if (![_serverList isParsed]) {
        UIActivityIndicatorView *activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        UIBarButtonItem *barActivityIndicator = [[UIBarButtonItem alloc] initWithCustomView:activityIndicatorView];
        self.navigationItem.rightBarButtonItem = barActivityIndicator;
        [activityIndicatorView startAnimating];
        [barActivityIndicator release];
        [activityIndicatorView release];
    }
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:YES];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if ([_serverList isParsed]) {
            self.navigationItem.rightBarButtonItem = nil;
            return;
        }
        [_serverList parse];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.navigationItem.rightBarButtonItem = nil;
            [self.tableView reloadData];
        });
    });
}

#pragma mark -
#pragma mark UITableView data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return [_serverList numberOfContinents];
}

- (UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    return [MUTableViewHeaderLabel labelWithText:[_serverList continentNameAtIndex:section]];
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return [MUTableViewHeaderLabel defaultHeaderHeight];
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_serverList numberOfCountriesAtContinentIndex:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"countryItem"];
    if (!cell) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"countryItem"] autorelease];
    }

    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    NSDictionary *countryInfo = [_serverList countryAtIndexPath:indexPath];
    cell.textLabel.text = [countryInfo objectForKey:@"name"];
    NSInteger numServers = [[countryInfo objectForKey:@"servers"] count];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%li %@", (long int)numServers, numServers > 1 ? @"servers" : @"server"];
    cell.selectionStyle = UITableViewCellSelectionStyleGray;

    return cell;
}

#pragma mark -
#pragma mark UITableView delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *countryInfo = [_serverList countryAtIndexPath:indexPath];
    NSString *countryName = [countryInfo objectForKey:@"name"];
    NSArray *countryServers = [countryInfo objectForKey:@"servers"];

    MUCountryServerListController *countryController = [[MUCountryServerListController alloc] initWithName:countryName serverList:countryServers];
    [[self navigationController] pushViewController:countryController animated:YES];
    [countryController release];
}

@end
