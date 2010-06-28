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

#import "IdentityViewController.h"
#import "IdentityCreationViewController.h"
#import "Database.h"
#import "Identity.h"

static NSUInteger IdentityViewControllerIdentityView = 0;
static NSUInteger IdentityViewControllerCertificateView = 1;

@interface IdentityViewController (Private)
- (void) setCurrentView:(NSUInteger)currentView;
- (void) animateDeleteRowsCount:(NSUInteger)count withRowAnimation:(UITableViewRowAnimation)rowAnimation;
- (void) animateInsertRowsCount:(NSUInteger)count withRowAnimation:(UITableViewRowAnimation)rowAnimation;
- (void) deleteIdentityForRow:(NSUInteger)row;
- (void) deleteCertificateForRow:(NSUInteger)row;
- (void) fetchCertificates;
@end

@implementation IdentityViewController

#pragma mark -
#pragma mark Initialization

- (id) init {
	self = [super init];
	if (self == nil)
		return nil;

	return self;
}

- (void) dealloc {
	[super dealloc];
}

- (void) viewWillAppear:(BOOL)animated {
	[self setCurrentView:IdentityViewControllerIdentityView];
	[self.navigationController setToolbarHidden:NO animated:NO];
}

- (void) viewDidAppear:(BOOL)animated {
	UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	NSArray *segmentItems = [NSArray arrayWithObjects:
							 @"Identities",
							 @"Certificates",
							 nil];
	UISegmentedControl *segmentedControl = [[UISegmentedControl alloc] initWithItems:segmentItems];
	[segmentedControl setSegmentedControlStyle:UISegmentedControlStyleBar];
	[segmentedControl setSelectedSegmentIndex:0];
	[segmentedControl addTarget:self action:@selector(viewChanged:) forControlEvents:UIControlEventValueChanged];
	UIBarButtonItem *barSegmented = [[UIBarButtonItem alloc] initWithCustomView:segmentedControl];
	[segmentedControl release];

	[self.navigationController.toolbar setItems:[NSArray arrayWithObjects:flexSpace, barSegmented, flexSpace, nil]];

	[flexSpace release];
	[barSegmented release];
}

- (void) viewWillDisappear:(BOOL)animated {
	[_identities release];
	_identities = nil;
}

- (void) viewDidDisappear:(BOOL)animated {
	[self.navigationController setToolbarHidden:YES animated:NO];
}

- (void) setCurrentView:(NSUInteger)currentView {
	// No change in view, the view just re-appeared.
	if (currentView == _currentView) {
		[self.tableView reloadData];

	// View changed to identity view
	} else if (currentView == IdentityViewControllerIdentityView) {
		self.navigationItem.title = @"Identities";
		UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addButtonClicked:)];
		[self.navigationItem setRightBarButtonItem:addButton];
		[addButton release];

		NSUInteger deleteCount = [_certificateItems count];
		[_certificateItems release];
		_certificateItems = nil;
		[self animateDeleteRowsCount:deleteCount withRowAnimation:UITableViewRowAnimationRight];

		_currentView = currentView;
		_identities = [[Database identities] retain];
		[self animateInsertRowsCount:[_identities count] withRowAnimation:UITableViewRowAnimationLeft];

	// View changed to certificate view
	} else if (currentView == IdentityViewControllerCertificateView) {
		self.navigationItem.title = @"Certificates";
		[self.navigationItem setRightBarButtonItem:nil];

		NSUInteger deleteCount = [_identities count];
		[_identities release];
		_identities = nil;
		[self animateDeleteRowsCount:deleteCount withRowAnimation:UITableViewRowAnimationLeft];

		_currentView = currentView;
		[self fetchCertificates];
		[self animateInsertRowsCount:[_certificateItems count] withRowAnimation:UITableViewRowAnimationRight];
	}
}

- (void) animateDeleteRowsCount:(NSUInteger)count withRowAnimation:(UITableViewRowAnimation)rowAnimation {
	NSMutableArray *operation = [[NSMutableArray alloc] init];
	NSUInteger i;
	for (i = 0; i < count; i++) {
		[operation addObject:[NSIndexPath indexPathForRow:i inSection:0]];
	}
	[self.tableView deleteRowsAtIndexPaths:operation withRowAnimation:rowAnimation];
	[operation release];
}

- (void) animateInsertRowsCount:(NSUInteger)count withRowAnimation:(UITableViewRowAnimation)rowAnimation {
	NSMutableArray *operation = [[NSMutableArray alloc] init];
	NSUInteger i;
	for (i = 0; i < count; i++) {
		[operation addObject:[NSIndexPath indexPathForRow:i inSection:0]];
	}
	[self.tableView insertRowsAtIndexPaths:operation withRowAnimation:rowAnimation];
	[operation release];
}

- (void) viewChanged:(UISegmentedControl *)segmentedControl {
	[self setCurrentView:[segmentedControl selectedSegmentIndex]];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (_currentView == IdentityViewControllerIdentityView) {
		return [_identities count];
	} else if (_currentView == IdentityViewControllerCertificateView) {
		return [_certificateItems count];
	}

	return 0;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

	if (_currentView == IdentityViewControllerIdentityView) {
		static NSString *CellIdentifier = @"IdentityCell";
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
		if (cell == nil) {
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
		}

		Identity *ident = [_identities objectAtIndex:[indexPath row]];
		cell.textLabel.text = ident.userName;

		return cell;
	} else if (_currentView == IdentityViewControllerCertificateView) {
		static NSString *CellIdentifier = @"CertificateCell";
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
		if (cell == nil) {
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
		}

		// Configure the cell...
		NSDictionary *dict = [_certificateItems objectAtIndex:[indexPath row]];
		cell.textLabel.text = [dict objectForKey:kSecAttrLabel];
		return cell;
	}

	return nil;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
		if (_currentView == IdentityViewControllerIdentityView) {
			[self deleteIdentityForRow:[indexPath row]];
			[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationLeft];
		} else if (_currentView == IdentityViewControllerCertificateView) {
			[self deleteCertificateForRow:[indexPath row]];
			[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationRight];
		}
	}
}

- (void) deleteIdentityForRow:(NSUInteger)row {
	NSLog(@"IdentityViewController: deleteIdentityForRow not implemented.");
}

- (void) deleteCertificateForRow:(NSUInteger)row {
	// Delete a certificate from the keychain
	NSDictionary *dict = [_certificateItems objectAtIndex:row];
	NSLog(@"Attempting to delete %@", [dict objectForKey:kSecAttrLabel]);

	NSData *persis = [dict objectForKey:kSecValuePersistentRef];
	NSLog(@"class = %@", NSStringFromClass([persis class]));
	NSDictionary *op = [NSDictionary dictionaryWithObjectsAndKeys:
						kSecClassIdentity, kSecClass,
						//[NSArray arrayWithObject:persis],            kSecMatchItemList,
						[dict objectForKey:kSecAttrDescription], kSecAttrDescription,
						nil];
	NSLog(@"persistentRef = %@", [dict objectForKey:kSecValuePersistentRef]);
	OSStatus err = SecItemDelete((CFDictionaryRef)op);
	if (err == noErr) {
		[_certificateItems removeObjectAtIndex:row];
	} else {
		NSLog(@"CertificateViewController: Failed to SecItemDelete identity. err=%i", (int)err);
	}
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
}

#pragma mark -
#pragma mark Target/actions

- (void) addButtonClicked:(UIBarButtonItem *)addButton {
	if (_currentView == IdentityViewControllerIdentityView) {
		IdentityCreationViewController *create = [[IdentityCreationViewController alloc] init];
		UINavigationController *navCtrl = [[UINavigationController alloc] init];
		[navCtrl pushViewController:create animated:NO];
		[create release];
		[[self navigationController] presentModalViewController:navCtrl animated:YES];
		[navCtrl release];
	} else if (_currentView == IdentityViewControllerCertificateView) {
		NSLog(@"IdentityViewController: Add view for Certificate View not implemented.");
	}
}

#pragma mark -
#pragma mark

- (void) fetchCertificates {
	NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
						   kSecClassIdentity,    kSecClass,
						   kCFBooleanTrue,       kSecReturnRef,
						   kCFBooleanTrue,       kSecReturnAttributes,
						   kCFBooleanTrue,       kSecReturnPersistentRef,
						   kSecMatchLimitAll,    kSecMatchLimit,
						   nil];
	CFTypeRef result = NULL;
	OSStatus err = SecItemCopyMatching((CFDictionaryRef)query, &result);
	if (err == noErr) {
		if (result != NULL) {
			NSArray *items = (NSArray *)result;
			_certificateItems = [items mutableCopy];
			[items release];
		}
	}
#if 1
	if (_certificateItems) {
		[_certificateItems enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			// Assume obj is a dictionary
			NSDictionary *dict = (NSDictionary *)obj;
			NSLog(@"%p", dict);
			[dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
				NSLog(@"key = %@", key);
				NSLog(@"val class = %@", NSStringFromClass([obj class]));
			}];
			NSLog(@"Label: %@", [dict objectForKey:kSecAttrLabel]);
			NSLog(@"Issuer: %@", [dict objectForKey:kSecAttrIssuer]);
			NSLog(@"Subject: %@", [dict objectForKey:kSecAttrSubject]);
			NSLog(@"%@ %@", kSecReturnPersistentRef, kSecReturnRef);
			NSLog(@"Persistent: %@", [dict objectForKey:kSecValuePersistentRef]);
			//NSLog(@"Data: %@", [dict objectForKey:@"certdata"]);
			NSLog(@"---");
		}];
	}
#endif
}

@end
