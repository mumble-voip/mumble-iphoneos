#import "MUInterface.h"
// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUPublicServerList.h"
#import "MUPublicServerListController.h"
#import "MUCountryServerListController.h"
#import "MUImage.h"

@interface MUPublicServerListController () {
    MUPublicServerList        *_serverList;
}
@end

@implementation MUPublicServerListController

- (id) init {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        _serverList = [[MUPublicServerList alloc] init];
    }
    return self;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:YES];

    self.navigationItem.title = NSLocalizedString(@"Public Servers", nil);
    
    self.tableView.backgroundView = nil;
    
    {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverListDidUpdate:) name:MUPublicServerListDidUpdateNotification object:nil];

    if (![_serverList isParsed]) {
        UIActivityIndicatorView *activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        UIBarButtonItem *barActivityIndicator = [[UIBarButtonItem alloc] initWithCustomView:activityIndicatorView];
        self.navigationItem.rightBarButtonItem = barActivityIndicator;
        [activityIndicatorView startAnimating];
    }
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if ([self isMovingFromParentViewController] || [self isBeingDismissed]) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:MUPublicServerListDidUpdateNotification object:nil];
    }
}

- (void) reloadServerList {
    if (![_serverList isParsed]) {
        [_serverList parse];
    }
    self.navigationItem.rightBarButtonItem = nil;
    [self.tableView reloadData];
}

- (void) serverListDidUpdate:(NSNotification *)notification {
    [_serverList invalidate];
    [self reloadServerList];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:YES];
    [self reloadServerList];
}

#pragma mark -
#pragma mark UITableView data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return [_serverList numberOfContinents];
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [_serverList continentNameAtIndex:section];
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_serverList numberOfCountriesAtContinentIndex:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"countryItem"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"countryItem"];
        MUConfigureStandardCell(cell);
    }

    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    NSDictionary *countryInfo = [_serverList countryAtIndexPath:indexPath];
    cell.textLabel.text = [countryInfo objectForKey:@"name"];
    NSInteger numServers = [[countryInfo objectForKey:@"servers"] count];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%li %@", (long int)numServers, numServers > 1 ? @"servers" : @"server"];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;

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
}

@end
