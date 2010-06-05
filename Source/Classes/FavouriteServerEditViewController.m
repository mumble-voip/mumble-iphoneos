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

#import "FavouriteServerEditViewController.h"

#import "Database.h"
#import "FavouriteServer.h"
#import "TableViewTextFieldCell.h"

@implementation FavouriteServerEditViewController

#pragma mark -
#pragma mark Initialization

- (id) initInEditMode:(BOOL)editMode withContentOfFavouriteServer:(FavouriteServer *)favServ {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self == nil)
		return nil;

	_editMode = editMode;
	_initialFavouriteContent = favServ;
	[_initialFavouriteContent retain];

	_favourite = [[FavouriteServer alloc] init];

	return self;
}

- (id) init {
	return [self initInEditMode:NO withContentOfFavouriteServer:nil];
}

- (void) dealloc {
	[_initialFavouriteContent release];
	[_favourite release];
	[super dealloc];
}

#pragma mark -
#pragma mark View lifecycle

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	
	// View title
	if (!_editMode) {
		[[self navigationItem] setTitle:@"New Favourite"];
	} else {
		[[self navigationItem] setTitle:@"Edit Favourite"];
	}
	
	// Cancel button
	UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(cancelClicked:)]; 
	[[self navigationItem] setLeftBarButtonItem:cancelButton];
	[cancelButton release];
	
	// Done
	UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(doneClicked:)];
	[[self navigationItem] setRightBarButtonItem:doneButton];
	[doneButton release];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 2;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	// Mumble Server
	if (section == 0) {
		return 3;
	// Identity
	} else if (section == 1) {
		return 2;
	}

	return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == 0) {
		return @"Mumble Server";
	} else if (section == 1) {
		return @"Identity";
	}

	return @"Default";
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {	
    static NSString *CellIdentifier = @"FavouriteServerEditCell";
	TableViewTextFieldCell *cell = (TableViewTextFieldCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (cell == nil) {
		cell = [[[TableViewTextFieldCell alloc] initWithReuseIdentifier:CellIdentifier] autorelease];
    }
	
	[cell setTarget:self];

	NSUInteger section = [indexPath section];
	NSUInteger row = [indexPath row];

	// Mumble Server
	if (section == 0) {
		if (row == 0) {
			[cell setLabel:@"Description"];
			[cell setPlaceholder:@"Mumble Server of Doom"];
			[cell setAutocapitalizationType:UITextAutocapitalizationTypeWords];
			[cell setValueChangedAction:@selector(descriptionChanged:)];
		} else if (row == 1) {
			[cell setLabel:@"Address"];
			[cell setPlaceholder:@"mumble.example.com"];
			[cell setAutocapitalizationType:UITextAutocapitalizationTypeNone];
			[cell setKeyboardType:UIKeyboardTypeURL];
			[cell setValueChangedAction:@selector(hostnameChanged:)];
		} else if (row == 2) {
			[cell setLabel:@"Port"];
			[cell setPlaceholder:@"64738"];
			[cell setKeyboardType:UIKeyboardTypeNumberPad];
			[cell setValueChangedAction:@selector(portChanged:)];
		}
	// Identity
	} else if (section == 1) {
		if (row == 0) {
			[cell setLabel:@"Username"];
			[cell setPlaceholder:@"luser"];
			[cell setAutocapitalizationType:UITextAutocapitalizationTypeNone];
			[cell setValueChangedAction:@selector(usernameChanged:)];
		} else if (row == 1) {
			[cell setLabel:@"Password"];
			[cell setPlaceholder:@"Optional"];
			[cell setSecureTextEntry:YES];
			[cell setValueChangedAction:@selector(passwordChanged:)];
		}
	}

    return cell;
}

#pragma mark -
#pragma mark TableViewTextFieldCell actions

- (void) descriptionChanged:(id)sender {
	TableViewTextFieldCell *cell = (TableViewTextFieldCell *)sender;
	[_favourite setDisplayName:[cell textValue]];
}

- (void) hostnameChanged:(id)sender {
	TableViewTextFieldCell *cell = (TableViewTextFieldCell *)sender;
	[_favourite setHostName:[cell textValue]];
}

- (void) portChanged:(id)sender {
	TableViewTextFieldCell *cell = (TableViewTextFieldCell *)sender;
	[_favourite setPort:(NSUInteger)[[cell textValue] intValue]];
}

- (void) usernameChanged:(id)sender {
	TableViewTextFieldCell *cell = (TableViewTextFieldCell *)sender;
	[_favourite setUserName:[cell textValue]];
}

- (void) passwordChanged:(id)sender {
	// We should store passwords in keychain.
}

#pragma mark -
#pragma mark UIBarButton actions

- (void) cancelClicked:(id)sender {
	[[self navigationController] dismissModalViewControllerAnimated:YES];
}

- (void) doneClicked:(id)sender {
	[[self navigationController] dismissModalViewControllerAnimated:YES];
	if ([_target respondsToSelector:_doneAction]) {
		[_target performSelector:_doneAction withObject:self];
	}
}

#pragma mark -
#pragma mark Data accessors

- (FavouriteServer *) copyFavouriteFromContent {
	return [_favourite copy];
}

#pragma mark -
#pragma mark Target/actions

- (void) setTarget:(id)target {
	_target = target;
}

- (id) target {
	return _target;
}

- (void) setDoneAction:(SEL)action {
	_doneAction = action;
}

- (SEL) doneAction {
	return _doneAction;
}

@end