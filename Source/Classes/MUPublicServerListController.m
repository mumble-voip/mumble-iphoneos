// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUPublicServerList.h"
#import "MUPublicServerListController.h"
#import "MUCountryServerListController.h"
#import "MUTableViewHeaderLabel.h"
#import "MUImage.h"
#import "MUBackgroundView.h"

@interface MUPublicServerListController () <UISearchResultsUpdating> {
    MUPublicServerList        *_serverList;
    UISearchController        *_searchController;
    NSString                  *_searchText;
}
@end

@implementation MUPublicServerListController

- (id) init {
    UITableViewStyle style;
    if (@available(iOS 13.0, *)) {
        style = UITableViewStyleInsetGrouped;
    } else {
        style = UITableViewStyleGrouped;
    }
    if ((self = [super initWithStyle:style])) {
        _serverList = [[MUPublicServerList alloc] init];
    }
    return self;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:YES];

    self.navigationItem.title = NSLocalizedString(@"Public Servers", nil);
    
    self.tableView.backgroundView = [MUBackgroundView backgroundView];
    
    if (@available(iOS 11.0, *)) {
        self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
        
        if (!_searchController) {
            _searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
            _searchController.searchResultsUpdater = self;
            _searchController.obscuresBackgroundDuringPresentation = NO;
            _searchController.searchBar.placeholder = NSLocalizedString(@"Search countries...", nil);
            self.navigationItem.searchController = _searchController;
            self.definesPresentationContext = YES;
        }
    }

    if (![_serverList isParsed]) {
        UIActivityIndicatorViewStyle indicatorStyle;
        if (@available(iOS 13.0, *)) {
            indicatorStyle = UIActivityIndicatorViewStyleMedium;
        } else {
            indicatorStyle = UIActivityIndicatorViewStyleWhite;
        }
        UIActivityIndicatorView *activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:indicatorStyle];
        UIBarButtonItem *barActivityIndicator = [[UIBarButtonItem alloc] initWithCustomView:activityIndicatorView];
        self.navigationItem.rightBarButtonItem = barActivityIndicator;
        [activityIndicatorView startAnimating];
    }
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:YES];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if ([self->_serverList isParsed]) {
            self.navigationItem.rightBarButtonItem = nil;
            return;
        }
        [self->_serverList parse];
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
    if ([self isSearchActive]) {
        return [[self filteredCountriesForSection:section] count];
    }
    return [_serverList numberOfCountriesAtContinentIndex:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"countryItem"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"countryItem"];
    }

    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    NSDictionary *countryInfo;
    if ([self isSearchActive]) {
        NSArray *filtered = [self filteredCountriesForSection:indexPath.section];
        countryInfo = [filtered objectAtIndex:indexPath.row];
    } else {
        countryInfo = [_serverList countryAtIndexPath:indexPath];
    }
    cell.textLabel.text = [countryInfo objectForKey:@"name"];
    NSInteger numServers = [[countryInfo objectForKey:@"servers"] count];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%li %@", (long int)numServers, numServers > 1 ? @"servers" : @"server"];
    cell.selectionStyle = UITableViewCellSelectionStyleGray;

    return cell;
}

#pragma mark -
#pragma mark UITableView delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *countryInfo;
    if (_searchText && [_searchText length] > 0) {
        NSArray *filtered = [self filteredCountriesForSection:indexPath.section];
        countryInfo = [filtered objectAtIndex:indexPath.row];
    } else {
        countryInfo = [_serverList countryAtIndexPath:indexPath];
    }
    NSString *countryName = [countryInfo objectForKey:@"name"];
    NSArray *countryServers = [countryInfo objectForKey:@"servers"];

    MUCountryServerListController *countryController = [[MUCountryServerListController alloc] initWithName:countryName serverList:countryServers];
    [[self navigationController] pushViewController:countryController animated:YES];
}

#pragma mark - Search

- (void) updateSearchResultsForSearchController:(UISearchController *)searchController {
    _searchText = searchController.searchBar.text;
    [self.tableView reloadData];
}

- (BOOL) isSearchActive {
    return _searchText && [_searchText length] > 0;
}

- (NSArray *) filteredCountriesForSection:(NSInteger)section {
    if (![self isSearchActive]) return nil;
    
    NSMutableArray *results = [[NSMutableArray alloc] init];
    NSInteger numCountries = [_serverList numberOfCountriesAtContinentIndex:section];
    for (NSInteger i = 0; i < numCountries; i++) {
        NSDictionary *countryInfo = [_serverList countryAtIndexPath:[NSIndexPath indexPathForRow:i inSection:section]];
        NSString *name = [countryInfo objectForKey:@"name"];
        if ([name rangeOfString:_searchText options:NSCaseInsensitiveSearch].location != NSNotFound) {
            [results addObject:countryInfo];
        }
    }
    return results;
}

@end
