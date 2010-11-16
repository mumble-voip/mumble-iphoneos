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

#import "IdentityPreferencesViewController.h"
#import "Identity.h"
#import "IdentityCreationViewController.h"
#import "Database.h"


@interface IdentityPreferencesViewController (Private)
- (void) deleteIdentityForRow:(NSUInteger)row;
@end


@implementation IdentityPreferencesViewController

#pragma mark -
#pragma mark Initialization

- (id) init {
	if (self = [super init]) {
	}
	return self;
}

- (void) dealloc {
	[_identities release];
	[super dealloc];
}

- (void) viewWillAppear:(BOOL)animated {
	self.navigationItem.title = @"Identities";

	[[self tableView] deselectRowAtIndexPath:[[self tableView] indexPathForSelectedRow] animated:YES];	

	[_identities release];
	_identities = [[Database fetchAllIdentities] retain];

	[self.tableView reloadData];

	UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addButtonClicked:)];
	[self.navigationItem setRightBarButtonItem:addButton];
	[addButton release];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_identities count];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"IdentityCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
	}
	
	Identity *ident = [_identities objectAtIndex:[indexPath row]];
	cell.textLabel.text = ident.userName;
	
	if (ident.avatar != nil) {
		cell.imageView.image = ident.avatar;
	} else {
		cell.imageView.image = [UIImage imageNamed:@"DefaultAvatar"];
	}
	
	[cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
	return cell;
}

- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	[self deleteIdentityForRow:[indexPath row]];
	[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationLeft];
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    Identity *ident = [_identities objectAtIndex:[indexPath row]];
	IdentityCreationViewController *identityEdit = [[IdentityCreationViewController alloc] initWithIdentity:ident];
	UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:identityEdit];
	[[self navigationController] presentModalViewController:navCtrl animated:YES];
	[navCtrl release];
	[identityEdit release];
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 85.0f;
}

#pragma mark -
#pragma mark Actions

- (void) addButtonClicked:(UIBarButtonItem *)addButton {
	IdentityCreationViewController *create = [[IdentityCreationViewController alloc] init];
	UINavigationController *navCtrl = [[UINavigationController alloc] init];
	[navCtrl pushViewController:create animated:NO];
	[create release];
	[[self navigationController] presentModalViewController:navCtrl animated:YES];
	[navCtrl release];
}

#pragma mark -
#pragma mark Utils

- (void) deleteIdentityForRow:(NSUInteger)row {
	Identity *ident = [_identities objectAtIndex:row];
	[Database deleteIdentity:ident];
	[ident release];
	[_identities removeObjectAtIndex:row];
}

@end

