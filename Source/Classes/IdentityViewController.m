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
#import "CertificateCell.h"
#import "CertificateViewController.h"
#import "CertificateCreationView.h"

#import <MumbleKit/MKCertificate.h>

static NSInteger IdentityViewControllerIdentityView = 0;
static NSInteger IdentityViewControllerCertificateView = 1;

@interface IdentityViewController (Private)
- (void) setCurrentView:(NSInteger)currentView;
- (void) animateDeleteRowsCount:(NSUInteger)count withRowAnimation:(UITableViewRowAnimation)rowAnimation;
- (void) animateInsertRowsCount:(NSUInteger)count withRowAnimation:(UITableViewRowAnimation)rowAnimation;
- (void) deleteIdentityForRow:(NSUInteger)row;
- (void) deleteCertificateForRow:(NSUInteger)row;
- (void) fetchCertificates;
- (void) viewChanged:(UISegmentedControl *)segmentedControl;
@end

@implementation IdentityViewController

#pragma mark -
#pragma mark Initialization

- (id) init {
	if (self = [super init]) {
		_currentView = -1;
	}
	return self;
}

- (void) dealloc {
	[super dealloc];
}

- (void) viewWillAppear:(BOOL)animated {
	if (_currentView == -1)
		[self setCurrentView:IdentityViewControllerIdentityView];

	UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	NSArray *segmentItems = [NSArray arrayWithObjects:
							 @"Identities",
							 @"Certificates",
							 nil];
	UISegmentedControl *segmentedControl = [[UISegmentedControl alloc] initWithItems:segmentItems];
	[segmentedControl setSegmentedControlStyle:UISegmentedControlStyleBar];
	[segmentedControl setSelectedSegmentIndex:_currentView];
	[segmentedControl addTarget:self action:@selector(viewChanged:) forControlEvents:UIControlEventValueChanged];
	UIBarButtonItem *barSegmented = [[UIBarButtonItem alloc] initWithCustomView:segmentedControl];
	[segmentedControl release];

	[self setToolbarItems:[NSArray arrayWithObjects:flexSpace, barSegmented, flexSpace, nil]];
	[self viewChanged:segmentedControl];

	[flexSpace release];
	[barSegmented release];

	[self.navigationController setToolbarHidden:NO animated:YES];
}

- (void) viewWillDisappear:(BOOL)animated {
	[_identities release];
	_identities = nil;

	[self.navigationController setToolbarHidden:YES animated:YES];
}

- (void) setCurrentView:(NSInteger)currentView {
	BOOL animate = (currentView != _currentView);

	[[self tableView] deselectRowAtIndexPath:[[self tableView] indexPathForSelectedRow] animated:YES];

	UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addButtonClicked:)];
	[self.navigationItem setRightBarButtonItem:addButton];
	[addButton release];

	// View changed to identity view
	if (currentView == IdentityViewControllerIdentityView) {
		self.navigationItem.title = @"Identities";

		NSUInteger deleteCount = [_certificateItems count];
		[_certificateItems release];
		_certificateItems = nil;
		if (animate)
			[self animateDeleteRowsCount:deleteCount withRowAnimation:UITableViewRowAnimationRight];

		_currentView = currentView;
		_identities = [[Database fetchAllIdentities] retain];
		if (animate)
			[self animateInsertRowsCount:[_identities count] withRowAnimation:UITableViewRowAnimationLeft];

	// View changed to certificate view
	} else if (currentView == IdentityViewControllerCertificateView) {
		self.navigationItem.title = @"Certificates";

		NSUInteger deleteCount = [_identities count];
		[_identities release];
		_identities = nil;
		if (animate)
			[self animateDeleteRowsCount:deleteCount withRowAnimation:UITableViewRowAnimationLeft];

		_currentView = currentView;
		[self fetchCertificates];
		if (animate)
			[self animateInsertRowsCount:[_certificateItems count] withRowAnimation:UITableViewRowAnimationRight];
	}

	if (!animate)
		[self.tableView reloadData];
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
- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (_currentView == IdentityViewControllerIdentityView) {
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

	} else if (_currentView == IdentityViewControllerCertificateView) {
		static NSString *CellIdentifier = @"CertificateCell";
		CertificateCell *cell = (CertificateCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
		if (cell == nil)
			cell = [CertificateCell loadFromNib];

		// Configure the cell...
		NSDictionary *dict = [_certificateItems objectAtIndex:[indexPath row]];
		MKCertificate *cert = [dict objectForKey:@"cert"];
		[cell setSubjectName:[cert commonName]];
		[cell setEmail:[cert emailAddress]];
		[cell setIssuerText:[cert issuerName]];
		[cell setExpiryText:[[cert notAfter] description]];
		[cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];

		return (UITableViewCell *) cell;
	}

	return nil;
}

- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
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
	Identity *ident = [_identities objectAtIndex:row];
	[Database deleteIdentity:ident];
	[ident release];
	[_identities removeObjectAtIndex:row];
}

- (void) deleteCertificateForRow:(NSUInteger)row {
	// Delete a certificate from the keychain
	NSDictionary *dict = [_certificateItems objectAtIndex:row];

	// This goes against what the documentation says for this fucntion, but Apple has stated that
	// this is the intended way to delete via a persistent ref through a rdar.
	NSDictionary *op = [NSDictionary dictionaryWithObjectsAndKeys:
							[dict objectForKey:@"persistentRef"], kSecValuePersistentRef,
						nil];
	OSStatus err = SecItemDelete((CFDictionaryRef)op);
	if (err == noErr) {
		[_certificateItems removeObjectAtIndex:row];
	}
}

#pragma mark -
#pragma mark Table view delegate

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (_currentView == IdentityViewControllerIdentityView) {
		Identity *ident = [_identities objectAtIndex:[indexPath row]];
		IdentityCreationViewController *identityEdit = [[IdentityCreationViewController alloc] initWithIdentity:ident];
		UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:identityEdit];
		[[self navigationController] presentModalViewController:navCtrl animated:YES];
		[navCtrl release];
		[identityEdit release];
	} else if (_currentView == IdentityViewControllerCertificateView) {
		NSDictionary *dict = [_certificateItems objectAtIndex:[indexPath row]];
		MKCertificate *cert = [dict objectForKey:@"cert"];
		CertificateViewController *certView = [[CertificateViewController alloc] initWithCertificate:cert];
		[[self navigationController] pushViewController:certView animated:YES];
		[certView release];
	}
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 85.0f;
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
		UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Add Certificate"
														   delegate:self
												  cancelButtonTitle:@"Cancel"
											 destructiveButtonTitle:nil
												  otherButtonTitles:@"Generate New Certificate",
																	@"Import From Disk",
								nil];
		[sheet showInView:[self tableView]];
		[sheet release];
	}
}

#pragma mark -
#pragma mark UIActionSheet delegate

- (void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)idx {
	if (idx == 0) { // Generate New Certificate
		UINavigationController *navCtrl = [[UINavigationController alloc] init];
		CertificateCreationView *certGen = [[CertificateCreationView alloc] init];
		[navCtrl pushViewController:certGen animated:NO];
		[certGen release];
		[self presentModalViewController:navCtrl animated:YES];
		[navCtrl release];
	} else if (idx == 1) { // Import From Disk
		NSLog(@"DiskImport");
	}
}

#pragma mark -
#pragma mark Misc.

- (void) fetchCertificates {
	NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
						   kSecClassIdentity,    kSecClass,
						   kCFBooleanTrue,       kSecReturnPersistentRef,
						   kSecMatchLimitAll,    kSecMatchLimit,
						   nil];
	NSArray *array = nil;
	OSStatus err = SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&array);
	if (err != noErr || array == nil) {
		[array release];
		return;
	}

	_certificateItems = [[NSMutableArray alloc] init];

	for (NSData *persistentRef in array) {
		query = [NSDictionary dictionaryWithObjectsAndKeys:
					persistentRef,      kSecValuePersistentRef,
					kCFBooleanTrue,     kSecReturnRef,
					kSecMatchLimitOne,  kSecMatchLimit,
				 nil];
		SecIdentityRef identity = NULL;
		if (SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&identity) == noErr && identity != NULL) {
			SecCertificateRef secCert;
			if (SecIdentityCopyCertificate(identity, &secCert) == noErr) {
				NSData *secData = (NSData *)SecCertificateCopyData(secCert);
				MKCertificate *cert = [MKCertificate certificateWithCertificate:secData privateKey:nil];
				[_certificateItems addObject:[NSDictionary dictionaryWithObjectsAndKeys:
											  cert, @"cert", persistentRef, @"persistentRef", nil]];
			}
		}
	}
}

@end
