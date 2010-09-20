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

#import "IdentityPickerViewController.h"
#import "Identity.h"
#import "Database.h"

@implementation IdentityPickerViewController

#pragma mark -
#pragma mark Initialization

- (id) initWithIdentity:(Identity *)identity {
	self = [super initWithStyle:UITableViewStyleGrouped];

	if (self != nil) {
		_identities = [[Database fetchAllIdentities] retain];
		_selectedPrimaryKey = [identity primaryKey];
	}

	return self;
}

- (void) dealloc {
	[_identities release];
	[super dealloc];
}

- (void) viewWillAppear:(BOOL)animated {
	[self setTitle:@"Choose..."];
}

#pragma mark -
#pragma mark Delegate

- (id<IdentityPickerViewControllerDelegate>) delegate {
	return _delegate;
}

- (void) setDelegate:(id<IdentityPickerViewControllerDelegate>)delegate {
	_delegate = delegate;
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_identities count] + 1;
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSUInteger row = [indexPath row];

	// The 'none' choice.
	if (row == 0) {
		NSString *NoneIdentifier = @"NoneButton";
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:NoneIdentifier];
		if (!cell) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewStyleGrouped reuseIdentifier:NoneIdentifier];
		}
		[[cell textLabel] setText:@"None"];
		[[cell detailTextLabel] setText:nil];
		if (_selectedPrimaryKey != -1) {
			[cell setAccessoryType:UITableViewCellAccessoryNone];
		} else {
			[cell setAccessoryType:UITableViewCellAccessoryCheckmark];
			_selectedRow = row;
		}
		return cell;
	}

	NSString *CellIdentifier = @"IdentityPickerCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewStyleGrouped reuseIdentifier:CellIdentifier];
	}

	Identity *ident = [_identities objectAtIndex:row-1];
	[[cell textLabel] setText:[ident userName]];
	[[cell imageView] setImage:[ident avatar]];

	if (_selectedPrimaryKey == [ident primaryKey]) {
		[cell setAccessoryType:UITableViewCellAccessoryCheckmark];
		_selectedRow = row;
	} else {
		[cell setAccessoryType:UITableViewCellAccessoryNone];
	}

	return (UITableViewCell *) cell;
}

#pragma mark -
#pragma mark Table view delegate

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NSUInteger row = [indexPath row];

	if (row != _selectedRow) {
		UITableViewCell *cell = [[self tableView] cellForRowAtIndexPath:[NSIndexPath indexPathForRow:_selectedRow inSection:0]];
		[cell setAccessoryType:UITableViewCellAccessoryNone];

		cell = [[self tableView] cellForRowAtIndexPath:indexPath];
		[cell setAccessoryType:UITableViewCellAccessoryCheckmark];
		_selectedRow = row;

		Identity *ident = row > 0 ? [_identities objectAtIndex:row-1] : nil;
		_selectedPrimaryKey = ident ? [ident primaryKey] : -1;
		if ([(id)_delegate respondsToSelector:@selector(identityPickerViewController:didSelectIdentity:)]) {
			[_delegate identityPickerViewController:self didSelectIdentity:ident];
		}
	}

	[[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 44.0f;
}

@end

