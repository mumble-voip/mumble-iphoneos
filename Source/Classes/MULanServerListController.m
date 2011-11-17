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

static NSInteger NetServiceAlphabeticalSort(id arg1, id arg2, void *reverse) {
    if (reverse) {
        return [[arg1 name] compare:[arg2 name]];
    } else {
        return [[arg2 name] compare:[arg1 name]];
    }
} 

@interface MULanServerListController () <NSNetServiceBrowserDelegate> {
    NSNetServiceBrowser  *_browser;
    NSMutableArray       *_netServices;
}
@end

@implementation MULanServerListController

#pragma mark -
#pragma mark Initialization

- (id) init {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self == nil)
        return nil;

    _browser = [[NSNetServiceBrowser alloc] init];
    [_browser setDelegate:self];
    [_browser scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];

    _netServices = [[NSMutableArray alloc] init];

    return self;
}

- (void) dealloc {
    [_browser release];
    [_netServices release];
    [super dealloc];
}

#pragma mark -

- (void) viewWillAppear:(BOOL)animated {
    [[self navigationItem] setTitle:@"LAN Servers"];
}

- (void) viewDidAppear:(BOOL)animated {
    [_browser searchForServicesOfType:@"_mumble._tcp" inDomain:@"local."];
}

#pragma mark -
#pragma mark NSNetServiceBrowser delegate

- (void) netServiceBrowser:(NSNetServiceBrowser *)browser didFindService:(NSNetService *)netService moreComing:(BOOL)moreServices {    
    [_netServices addObject:netService];
    [_netServices sortUsingFunction:NetServiceAlphabeticalSort context:nil];
    NSInteger newIndex = [_netServices indexOfObject:netService];
    [[self tableView] insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:newIndex inSection:0]] withRowAnimation:UITableViewRowAnimationLeft];
}

- (void) netServiceBrowser:(NSNetServiceBrowser *)browser didRemoveService:(NSNetService *)netService moreComing:(BOOL)moreServices {
    NSInteger curIndex = [_netServices indexOfObject:netService];
    [_netServices removeObjectAtIndex:curIndex];
    [[self tableView] deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:curIndex inSection:0]] withRowAnimation:UITableViewRowAnimationRight];

}

#pragma mark -
#pragma mark NSNetServiceDelegate

- (void) netServiceDidResolveAddress:(NSNetService *)netService {
    // We should resolve before we can connect..
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
    static NSString *CellIdentifier = @"LanServerCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
    NSNetService *netService = [_netServices objectAtIndex:[indexPath row]];
    cell.textLabel.text = [netService name];
    
    return cell;
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"Selected");
}

@end

