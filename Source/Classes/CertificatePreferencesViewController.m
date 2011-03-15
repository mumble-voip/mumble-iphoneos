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

#import "CertificatePreferencesViewController.h"
#import "CertificateCell.h"
#import "CertificateCreationView.h"
#import "CertificateViewController.h"

#import <MumbleKit/MKCertificate.h>


@interface CertificatePreferencesViewController (Private)
- (void) fetchCertificates;
- (void) deleteCertificateForRow:(NSUInteger)row;
@end


@implementation CertificatePreferencesViewController

#pragma mark -
#pragma mark Initialization

- (id) init {
	if (self = [super init]) {
		_picker = NO;
		[self setContentSizeForViewInPopover:CGSizeMake(320, 480)];
	}
	return self;
}

- (id) initAsPicker {
	if (self = [self init]) {
		_picker = YES;
	}
	return self;
}

- (void) dealloc {
	[_certificateItems release];
	[super dealloc];
}

#pragma mark -
#pragma mark View lifecycle

- (void) viewWillAppear:(BOOL)animated {
	if (_picker) {
		self.navigationItem.title = @"Pick Certificate";
	} else {
		self.navigationItem.title = @"Certificates";
	}

	[[self tableView] deselectRowAtIndexPath:[[self tableView] indexPathForSelectedRow] animated:YES];

	[self fetchCertificates];
	[self.tableView reloadData];
	
	if (!_picker) {
		UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addButtonClicked:)];
		[self.navigationItem setRightBarButtonItem:addButton];
		[addButton release];
	}
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_certificateItems count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
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

	if (!_picker) {
		[cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
	} else {
		[cell setAccessoryType:UITableViewCellAccessoryNone];
		NSData *persistentRef = [dict objectForKey:@"persistentRef"];
		NSData *curPersistentRef = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultCertificate"];
		if ([persistentRef isEqualToData:curPersistentRef]) {
			[cell setAccessoryType:UITableViewCellAccessoryCheckmark];
			_selectedIndex = [indexPath row];
		}
	}
	
	return (UITableViewCell *) cell;
}


#pragma mark -
#pragma mark Table view delegate
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (!_picker)
		return UITableViewCellEditingStyleDelete;
	else
		return UITableViewCellEditingStyleNone;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *dict = [_certificateItems objectAtIndex:[indexPath row]];

	// If we're in picker mode, simply set the certificate key NSUserDefaults to the persistentRef of this cert.
	if (_picker) {
		NSData *persistentRef = [dict objectForKey:@"persistentRef"];
		[[NSUserDefaults standardUserDefaults] setObject:persistentRef forKey:@"DefaultCertificate"];

		UITableViewCell *prevCell = [[self tableView] cellForRowAtIndexPath:[NSIndexPath indexPathForRow:_selectedIndex inSection:0]];
		UITableViewCell *curCell = [[self tableView] cellForRowAtIndexPath:indexPath];
		prevCell.accessoryType = UITableViewCellAccessoryNone;
		curCell.accessoryType = UITableViewCellAccessoryCheckmark;

		_selectedIndex = [indexPath row];

		[[self tableView] deselectRowAtIndexPath:indexPath animated:YES];

	// If not, show the detailed view.
	} else {
		MKCertificate *cert = [dict objectForKey:@"cert"];
		CertificateViewController *certView = [[CertificateViewController alloc] initWithCertificate:cert];
		[[self navigationController] pushViewController:certView animated:YES];
		[certView release];
	}
}

- (void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
		[self deleteCertificateForRow:[indexPath row]];
		[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationRight];
	}
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 85.0f;
}

#pragma mark -
#pragma mark Target/actions

- (void) addButtonClicked:(UIBarButtonItem *)addButton {
	UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Add Certificate"
													   delegate:self
											  cancelButtonTitle:@"Cancel"
										 destructiveButtonTitle:nil
											  otherButtonTitles:@"Generate New Certificate",
																@"Import From iTunes",
							nil];
	[sheet showInView:[self tableView]];
	[sheet release];
}

#pragma mark -
#pragma mark UIActionSheet delegate

- (void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)idx {
	if (idx == 0) { // Generate New Certificate
		UINavigationController *navCtrl = [[UINavigationController alloc] init];
		navCtrl.modalPresentationStyle = UIModalPresentationCurrentContext;
		CertificateCreationView *certGen = [[CertificateCreationView alloc] init];
		[navCtrl pushViewController:certGen animated:NO];
		[certGen release];
		[[self navigationController] presentModalViewController:navCtrl animated:YES];
		[navCtrl release];
	} else if (idx == 1) { // Import From Disk
		NSLog(@"DiskImport");
	}
}

#pragma mark -
#pragma mark Utils

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

	[_certificateItems release];
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

@end

