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

#import "MULanServerListController.h"
#import "MUServerRootViewController.h"
#import "MUFavouriteServer.h"
#import "MUFavouriteServerEditViewController.h"
#import "MUServerCell.h"
#import "MUDatabase.h"
#import "MUFavouriteServerListController.h"
#import "MUConnectionController.h"

static NSInteger NetServiceAlphabeticalSort(id arg1, id arg2, void *reverse) {
    if (reverse) {
        return [[arg1 name] compare:[arg2 name]];
    } else {
        return [[arg2 name] compare:[arg1 name]];
    }
} 

@interface MULanServerListController () <NSNetServiceBrowserDelegate, NSNetServiceDelegate, UIActionSheetDelegate, UIAlertViewDelegate> {
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

- (void) dealloc {
    [_browser release];
    [_netServices release];
    [super dealloc];
}

#pragma mark -

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:YES];
    [[self navigationItem] setTitle:@"LAN Servers"];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:YES];
    [_browser searchForServicesOfType:@"_mumble._tcp" inDomain:@"local."];
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
}

- (void) netServiceBrowser:(NSNetServiceBrowser *)browser didRemoveService:(NSNetService *)netService moreComing:(BOOL)moreServices {
    NSInteger curIndex = [_netServices indexOfObject:netService];
    [_netServices removeObjectAtIndex:curIndex];
    [[self tableView] deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:curIndex inSection:0]] withRowAnimation:UITableViewRowAnimationFade];

    [netService removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
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
        cell = [[[MUServerCell alloc] init] autorelease];
    }
    [cell populateFromDisplayName:[netService name] hostName:[netService hostName] port:[NSString stringWithFormat:@"%li", [netService port]]];
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
    
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:[netService name] delegate:self
                                              cancelButtonTitle:@"Cancel"
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:@"Add as favourite", @"Connect", nil];
    [sheet setActionSheetStyle:UIActionSheetStyleBlackOpaque];
    [sheet showInView:[self tableView]];
    [sheet release];
}

- (void) actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
    NSIndexPath *indexPath = [[self tableView] indexPathForSelectedRow];
    NSNetService *netService = [_netServices objectAtIndex:[indexPath row]];
    
    // Connect
    if (index == 1) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Username"
                                                        message:@"Please enter the username you wish to use on this server"
                                                       delegate:self
                                              cancelButtonTitle:@"Cancel"
                                              otherButtonTitles:@"Connect", nil];
        [alert setAlertViewStyle:UIAlertViewStylePlainTextInput];
        [[alert textFieldAtIndex:0] setText:[MUDatabase usernameForServerWithHostname:[netService hostName] port:[netService port]]];
        [alert show];
        [alert release];

    // Add as favourite
    } else if (index == 0) {
        [self presentAddAsFavouriteDialogForServer:netService];
    // Cancel
    } else if (index == 2) {
        [[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
    }
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
    NSNetService *netService = [_netServices objectAtIndex:[indexPath row]];

    if (buttonIndex == 1) {
        MUConnectionController *connCtrlr = [MUConnectionController sharedController];
        [connCtrlr connetToHostname:[netService hostName]
                               port:[netService port]
                       withUsername:[[alertView textFieldAtIndex:0] text]
                        andPassword:nil
           withParentViewController:self];
    }

    [[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
}

@end

