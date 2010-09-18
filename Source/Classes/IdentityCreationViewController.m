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

#import "IdentityCreationViewController.h"
#import "TableViewTextFieldCell.h"
#import "IdentityViewController.h"
#import "Database.h"
#import "Identity.h"
#import "AvatarCell.h"
#import "CertificateCell.h"
#import "CertificatePickerViewController.h"

#import <MumbleKit/MKCertificate.h>

@interface IdentityCreationViewController (Private)
- (void) deselectSelectedRowAnimated:(BOOL)animated;
- (void) presentExistingImagePicker;
- (void) presentCameraImagePicker;
@end

@implementation IdentityCreationViewController

#pragma mark -
#pragma mark Initialization

- (id) initWithIdentity:(Identity *)identity {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self == nil)
		return nil;

	if (identity) {
		_identity = [identity retain];
		_editMode = YES;
	} else
		_identity = [[Identity alloc] init];

	return self;
}

- (id) init {
	return [self initWithIdentity:nil];
}

- (void) dealloc {
	[_identity release];
	[super dealloc];
}

- (void) viewWillAppear:(BOOL)animated {
	if (_editMode)
		[[self navigationItem] setTitle:@"Edit Identity"];
	else
		[[self navigationItem] setTitle:@"Create Identity"];

	UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelButtonClicked:)];
	[[self navigationItem] setLeftBarButtonItem:cancelButton];
	[cancelButton release];

	NSString *createText = _editMode ? @"Done" : @"Create";
	UIBarButtonItem *createButton = [[UIBarButtonItem alloc] initWithTitle:createText style:UIBarButtonItemStyleDone target:self action:@selector(createButtonClicked:)];
	[[self navigationItem] setRightBarButtonItem:createButton];
	[createButton release];
}

#pragma mark -
#pragma mark Table view delegate

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSUInteger section = [indexPath section], row = [indexPath row];
	if (section == 0) // Avatar
		return 155.0f;
	if (section == 1 && row == 1)
		return 85.0f;
	return 44.0f;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	// Avatar
	if ([indexPath section] == 0) {
		// If the device can take pictures, give the user a choice between taking a new picture,
		// or picking one from the photo library.
		if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
			UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Select Avatar" delegate:self
															cancelButtonTitle:@"Cancel"
															destructiveButtonTitle:nil
															otherButtonTitles:@"Take Picture", @"Use Existing",
															nil];
			[sheet showInView:[self tableView]];
			[sheet release];

		// If not camera is available, pop up the photo library picker immediately.
		} else if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
			[self presentExistingImagePicker];

			// Can this happen?
		} else {
			[self deselectSelectedRowAnimated:NO];
		}

	// Certificate
	} else if ([indexPath section] == 1 && [indexPath row] == 1) {
		CertificatePickerViewController *certPicker = [[CertificatePickerViewController alloc] initWithPersistentRef:[_identity persistent]];
		[[self navigationController] pushViewController:certPicker animated:YES];
		[certPicker setDelegate:self];
		[certPicker release];
		[self deselectSelectedRowAnimated:YES];
	}
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0) // Avatar
		return 1;
	if (section == 1) // Identity
		return 2;

	return 0;
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == 0) // Avatar
		return @"Avatar";
	if (section == 1) // Identity
		return @"Identity";

	return @"Default";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if ([indexPath section] == 0) { // Avatar
		AvatarCell *cell = (AvatarCell *)[tableView dequeueReusableCellWithIdentifier:@"AvatarCell"];
		if (cell == nil) {
			cell = [AvatarCell loadFromNib];
		}

		UIView *transparentBackground = [[UIView alloc] initWithFrame:CGRectZero];
		transparentBackground.backgroundColor = [UIColor clearColor];
		cell.backgroundView = transparentBackground;
		cell.selectedBackgroundView = transparentBackground;
		[cell setAvatarImage:_identity.avatar];
		 return cell;

	} else if ([indexPath section] == 1) { // Identity
		NSUInteger row = [indexPath row];
		if (row == 0) { // Nickname
			static NSString *CellIdentifier = @"IdentityCreationTextFieldCell";
			TableViewTextFieldCell *cell = (TableViewTextFieldCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
			if (cell == nil) {
				cell = [[[TableViewTextFieldCell alloc] initWithReuseIdentifier:CellIdentifier] autorelease];
			}
			[cell setLabel:@"Nickname"];
			[cell setPlaceholder:@"MumbleUser"];
			[cell setAutocapitalizationType:UITextAutocapitalizationTypeNone];
			[cell setValueChangedAction:@selector(nicknameChanged:)];
			[cell setTextValue:_identity.userName];
			[cell setTarget:self];
			return cell;

		} else if (row == 1) { // Certificate
			static NSString *CellIdentifier = @"CertificateCell";
			CertificateCell *cell = (CertificateCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
			if (cell == nil)
				cell = [CertificateCell loadFromNib];

			// Fetch the certificate

			MKCertificate *cert = nil;
			NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
										[_identity persistent],		kSecValuePersistentRef,
										kCFBooleanTrue,				kSecReturnRef,
										kSecMatchLimitOne,			kSecMatchLimit,
										nil];
			SecIdentityRef identityRef = NULL;
			OSStatus err = SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&identityRef);
			if (err == noErr && identityRef) {
				SecCertificateRef secCert = NULL;
				err = SecIdentityCopyCertificate(identityRef, &secCert);
				if (err == noErr && secCert) {
					NSData *certData = (NSData *)SecCertificateCopyData(secCert);
					if (certData) {
						cert = [MKCertificate certificateWithCertificate:certData privateKey:nil];
					}
					[certData release];
					CFRelease(secCert);
				}
				CFRelease(identityRef);
			}

			if (cert == nil) {
				[cell setSubjectName:@"(Unknown)"];
				[cell setEmail:@"unknown"];
				[cell setIssuerText:@"issuer"];
				[cell setExpiryText:@"expiry"];
			} else {
				[cell setSubjectName:[cert commonName]];
				[cell setEmail:[cert emailAddress]];
				[cell setIssuerText:[cert issuerName]];
				[cell setExpiryText:[[cert notAfter] description]];
			}

			[cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
			return cell;
		}
	}

	return nil;
}

#pragma mark -
#pragma mark Target/actions

- (void) cancelButtonClicked:(UIBarButtonItem *)cancelButton {
	[[self navigationController] dismissModalViewControllerAnimated:YES];
}

- (void) createButtonClicked:(UIBarButtonItem *)doneButton {
	[Database storeIdentity:_identity];
	[[self navigationController] dismissModalViewControllerAnimated:YES];
}

- (void) nicknameChanged:(TableViewTextFieldCell *)nicknameField {
	_identity.userName = [nicknameField textValue];
}

#pragma mark -
#pragma mark UIActionSheet delegate

- (void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)idx {
	if (idx == 0) { // Take Picture
		[self presentCameraImagePicker];
	} else if (idx == 1) { // Use Existing
		[self presentExistingImagePicker];
	}
}

#pragma mark -
#pragma mark UINavigationController delegate

- (void) navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
}

- (void) navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
}

#pragma mark -
#pragma mark UIImagePickerController delegate

- (void) imagePickerController:(UIImagePickerController *)imagePicker didFinishPickingMediaWithInfo:(NSDictionary *)info {
	// We only allow users to pick images, and we always allow them to edit them.
	//
	// The default iOS UIImagePickerController only allows users to crop their images
	// to a 320x320 rect.  Since we expect rectangular images, it's an OK fit. We can
	// just resize them if we want a smaller image.
	UIImage *editedImage = [info objectForKey:UIImagePickerControllerEditedImage];
	_identity.avatar = editedImage;

	[self dismissModalViewControllerAnimated:YES];
	[self deselectSelectedRowAnimated:NO];
	[[self tableView] reloadData];
}

- (void) imagePickerControllerDidCancel:(UIImagePickerController *)imagePicker {
	[self dismissModalViewControllerAnimated:YES];
	[self deselectSelectedRowAnimated:NO];
	[[self tableView] deselectRowAtIndexPath:[[self tableView] indexPathForSelectedRow] animated:NO];
}

#pragma mark -
#pragma mark CertificatePickerViewController delegate

- (void) certificatePickerViewController:(CertificatePickerViewController *)certPicker didSelectCertificate:(NSData *)persistentRef {
	[_identity setPersistent:persistentRef];
	[[self tableView] reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:1 inSection:1]] withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark -
#pragma mark Private methods

- (void) deselectSelectedRowAnimated:(BOOL)animated {
	[[self tableView] deselectRowAtIndexPath:[[self tableView] indexPathForSelectedRow] animated:animated];
}												 

- (void) presentExistingImagePicker {
	UIImagePickerController *imgPicker = [[UIImagePickerController alloc] init];
	[imgPicker setDelegate:self];
	[imgPicker setAllowsEditing:YES];
	[imgPicker setSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
	[self presentModalViewController:imgPicker animated:YES];
	[imgPicker release];
}

- (void) presentCameraImagePicker {
	UIImagePickerController *imgPicker = [[UIImagePickerController alloc] init];

	// Use front-facing camera, if available.
	if ([UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceFront]) {
		[imgPicker setCameraDevice:UIImagePickerControllerCameraDeviceFront];
	}

	[imgPicker setDelegate:self];
	[imgPicker setAllowsEditing:YES];
	[imgPicker setSourceType:UIImagePickerControllerSourceTypeCamera];
	[self presentModalViewController:imgPicker animated:YES];
	[imgPicker release];
}

@end

