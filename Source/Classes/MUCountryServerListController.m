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

#import "MUCountryServerListController.h"

#import "MUDatabase.h"
#import "MUFavouriteServer.h"
#import "MUFavouriteServerListController.h"
#import "MUFavouriteServerEditViewController.h"
#import "MUServerRootViewController.h"
#import "MUConnectionController.h"
#import "MUServerCell.h"
#import "MUColor.h"

@interface MUCountryServerListController () <UIAlertViewDelegate, UISearchBarDelegate> {
    NSMutableArray   *_visibleCountryServers;
    NSArray   *_countryServers;
    NSString  *_countryName;
}
@end

@implementation MUCountryServerListController

- (id) initWithName:(NSString *)country serverList:(NSArray *)servers {
    self = [super init];
    if (self == nil)
        return nil;

    _countryServers = [servers retain];
    _visibleCountryServers = [servers mutableCopy];
    _countryName = [[country copy] retain];

    UISearchBar *searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
    searchBar.delegate = self;
    searchBar.barStyle = UIBarStyleBlackOpaque;
    [searchBar sizeToFit];
	[self.view addSubview:searchBar];
	[searchBar release];
    
    return self;
}

- (void) dealloc {
    [_countryName release];
    [_countryServers release];
    [_visibleCountryServers release];
    
    [super dealloc];
}

- (void) viewDidLoad{
    [self resetSearch];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[self navigationItem] setTitle:_countryName];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
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
    return [_visibleCountryServers count];
}

- (void) tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *serverItem = [_visibleCountryServers objectAtIndex:[indexPath row]];
    if ([[serverItem objectForKey:@"ca"] integerValue] > 0) {
        cell.backgroundColor = [MUColor verifiedCertificateChainColor];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MUServerCell *cell = (MUServerCell *) [tableView dequeueReusableCellWithIdentifier:[MUServerCell reuseIdentifier]];
    if (cell == nil) {
        cell = [[[MUServerCell alloc] init] autorelease];
    }
    
    NSDictionary *serverItem = [_visibleCountryServers objectAtIndex:[indexPath row]];
    [cell populateFromDisplayName:[serverItem objectForKey:@"name"]
                         hostName:[serverItem objectForKey:@"ip"]
                             port:[serverItem objectForKey:@"port"]];
    cell.selectionStyle = UITableViewCellSelectionStyleGray;

    return (UITableViewCell *) cell;
}

#pragma mark -
#pragma mark Selection

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *serverItem = [_visibleCountryServers objectAtIndex:[indexPath row]];

    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:[serverItem objectForKey:@"name"]
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:NSLocalizedString(@"Add as favourite", nil),
                                                                NSLocalizedString(@"Connect", nil), nil];
    [sheet setActionSheetStyle:UIActionSheetStyleBlackOpaque];
    [sheet showInView:[self tableView]];
    [sheet release];
}

- (void) actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
    NSIndexPath *indexPath = [[self tableView] indexPathForSelectedRow];
    NSDictionary *serverItem = [_visibleCountryServers objectAtIndex:[indexPath row]];

    // Connect
    if (index == 1) {
        NSString *title = NSLocalizedString(@"Username", nil);
        NSString *msg = NSLocalizedString(@"Please enter the username you wish to use on this server", nil);
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                        message:msg
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                              otherButtonTitles:NSLocalizedString(@"Connect", nil), nil];
        [alert setAlertViewStyle:UIAlertViewStylePlainTextInput];
        [[alert textFieldAtIndex:0] setText:[MUDatabase usernameForServerWithHostname:[serverItem objectForKey:@"ip"] port:[[serverItem objectForKey:@"port"] intValue]]];
        [alert show];
        [alert release];

    // Add as favourite
    } else if (index == 0) {
        [self presentAddAsFavouriteDialogForServer:serverItem];
    // Cancel
    } else if (index == 2) {
        [[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
    }
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
    [editView release];

    [[self navigationController] presentModalViewController:modalNav animated:YES];

    [modalNav release];
    [favServ release];
}

- (void) doneButtonClicked:(id)sender {
    MUFavouriteServerEditViewController *editView = (MUFavouriteServerEditViewController *)sender;
    MUFavouriteServer *favServ = [editView copyFavouriteFromContent];
    [MUDatabase storeFavourite:favServ];
    [favServ release];

    MUFavouriteServerListController *favController = [[MUFavouriteServerListController alloc] init];
    UINavigationController *navCtrl = [self navigationController];
    [navCtrl popToRootViewControllerAnimated:NO];
    [navCtrl pushViewController:favController animated:YES];
    [favController release];
}

- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    NSIndexPath *indexPath = [[self tableView] indexPathForSelectedRow];
    NSDictionary *serverItem = [_visibleCountryServers objectAtIndex:[indexPath row]];
    
    if (buttonIndex == 1) {
        MUConnectionController *connCtrlr = [MUConnectionController sharedController];
        [connCtrlr connetToHostname:[serverItem objectForKey:@"ip"]
                               port:[[serverItem objectForKey:@"port"] intValue]
                       withUsername:[[alertView textFieldAtIndex:0] text]
                        andPassword:nil
           withParentViewController:self];
    }

    [[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark -
#pragma mark SearchBar methods

- (void) resetSearch{
    NSMutableArray *array = [_countryServers mutableCopy];
    NSMutableArray *old = _visibleCountryServers;
    
    _visibleCountryServers = array;
    [old release];
}

- (void) handleSearchForTerm:(NSString *)searchTerm {
    NSMutableArray *toRemove = [[NSMutableArray alloc] init];
    [self resetSearch];
    
    for(NSDictionary *serverItem in _visibleCountryServers) {
        if( [(NSString *)[serverItem objectForKey:@"name"] rangeOfString:searchTerm options:NSCaseInsensitiveSearch].location == NSNotFound
           && [(NSString *)[serverItem objectForKey:@"ip"] rangeOfString:searchTerm options:NSCaseInsensitiveSearch].location == NSNotFound)
        {
            [toRemove addObject:serverItem];
        }
    }
    [_visibleCountryServers removeObjectsInArray:toRemove];
    [toRemove release];
    [self.tableView reloadData];
}

#pragma mark -
#pragma mark Search Bar Delegate Methods
- (void) searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    NSString *searchText = searchBar.text;
    [self handleSearchForTerm:searchText];
    [searchBar resignFirstResponder];
}

- (void) searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if([searchText length] == 0){
        [self resetSearch];
        [self.tableView reloadData];
        return;
    }
    [self handleSearchForTerm:searchText];
}

- (void) searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.text = @"";
    [self resetSearch];
    [self.tableView reloadData];
    [searchBar resignFirstResponder];
}

@end

