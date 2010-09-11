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
#import "IdentityCreationProgressView.h"
#import "UINavigationController-AnimationAdditions.h"
#import "IdentityViewController.h"
#import "Database.h"
#import "Identity.h"
#import "AvatarCell.h"

#import <MumbleKit/MKCertificate.h>

static void ShowAlertDialog(NSString *title, NSString *msg) {
	dispatch_async(dispatch_get_main_queue(), ^{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
		[alert release];
	});
}

@interface IdentityCreationViewController (Private)
- (void) deselectSelectedRowAnimated:(BOOL)animated;
- (void) presentExistingImagePicker;
- (void) presentCameraImagePicker;
@end

@implementation IdentityCreationViewController

#pragma mark -
#pragma mark Initialization

- (id) init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self == nil)
		return nil;

	// fixme(mkrautz): Can we fetch these from the device?
	_identityName = nil;
	_emailAddress = nil;
	_avatarImage = [UIImage imageNamed:@"DefaultAvatar"];

	return self;
}

- (void) dealloc {
	[_identityName release];
	[_emailAddress release];
	[_avatarImage release];
	[super dealloc];
}

- (void) viewWillAppear:(BOOL)animated {
	[[self navigationItem] setTitle:@"Create Identity"];

	UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelButtonClicked:)];
	[[self navigationItem] setLeftBarButtonItem:cancelButton];
	[cancelButton release];

	UIBarButtonItem *createButton = [[UIBarButtonItem alloc] initWithTitle:@"Create" style:UIBarButtonItemStyleDone target:self action:@selector(createButtonClicked:)];
	[[self navigationItem] setRightBarButtonItem:createButton];
	[createButton release];
}

#pragma mark -
#pragma mark Table view delegate

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if ([indexPath section] == 0) {
		return 155.0f;
	} else {
		return 44.0f;
	}
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	// We can only select the avatar.
	if ([indexPath section] != 0)
		return;

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
		return 3;

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
		[cell setAvatarImage:_avatarImage];

		 return cell;
	} else if ([indexPath section] == 1) { // Identity
		NSUInteger row = [indexPath row];
		static NSString *CellIdentifier = @"IdentityCreationTextFieldCell";
		TableViewTextFieldCell *cell = (TableViewTextFieldCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
		if (cell == nil) {
			cell = [[[TableViewTextFieldCell alloc] initWithReuseIdentifier:CellIdentifier] autorelease];
		}

		[cell setTarget:self];

		if (row == 0) { // Name
			[cell setLabel:@"Name"];
			[cell setPlaceholder:@"Mumble User"];
			[cell setAutocapitalizationType:UITextAutocapitalizationTypeWords];
			[cell setValueChangedAction:@selector(nameChanged:)];
			[cell setTextValue:_identityName];
		} else if (row == 1) { // E-mail
			[cell setLabel:@"Email"];
			[cell setPlaceholder:@"(Optional)"];
			[cell setAutocapitalizationType:UITextAutocapitalizationTypeNone];
			[cell setValueChangedAction:@selector(emailChanged:)];
			[cell setTextValue:_emailAddress];
		} else if (row == 2) { // Nickname
			[cell setLabel:@"Nickname"];
			[cell setPlaceholder:@"(Optional)"];
			[cell setAutocapitalizationType:UITextAutocapitalizationTypeNone];
			[cell setValueChangedAction:@selector(nicknameChanged:)];
			[cell setTextValue:_nickname];
		}

		return cell;
	}

	return nil;
}

#pragma mark -
#pragma mark Target/actions

- (void) cancelButtonClicked:(UIBarButtonItem *)cancelButton {
	[[self navigationController] dismissModalViewControllerAnimated:YES];
}

- (void) createButtonClicked:(UIBarButtonItem *)doneButton {
	NSString *name, *email;
	if (_identityName == nil || [_identityName length] == 0) {
		name = @"Mumble User";
	} else {
		name = _identityName;
	}
	if (_emailAddress == nil || [_emailAddress length] == 0) {
		email = nil;
	} else {
		// fixme(mkrautz): RegEx this or do a DNS lookup like the desktop client to determine if
		// the email has a chance to be valid.
		email = _emailAddress;
	}

	IdentityCreationProgressView *progress = [[IdentityCreationProgressView alloc] initWithName:name email:email image:_avatarImage];
	[[self navigationController] pushViewController:progress animated:YES];
	[progress release];

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		OSStatus err = noErr;

		// Generate a certificate for this identity.
		MKCertificate *cert = [MKCertificate selfSignedCertificateWithName:name email:email];
		NSData *pkcs12 = [cert exportPKCS12WithPassword:@""];
		if (pkcs12 == nil) {
			ShowAlertDialog(@"Unable to generate certificate",
							@"Mumble was unable to generate a certificate for the your identity.");
		} else {
			NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"", kSecImportExportPassphrase, nil];
			NSArray *items = nil;
			err = SecPKCS12Import((CFDataRef)pkcs12, (CFDictionaryRef)dict, (CFArrayRef *)&items);
			if (err == errSecSuccess && [items count] > 0) {
				NSDictionary *pkcsDict = [items objectAtIndex:0];
				// Get the SecIdentityRef
				SecIdentityRef identity = (SecIdentityRef)[pkcsDict objectForKey:(id)kSecImportItemIdentity];
				NSDictionary *op = [NSDictionary dictionaryWithObjectsAndKeys:
				                        (id)identity, kSecValueRef,
				                        kCFBooleanTrue, kSecReturnPersistentRef, nil];
				NSData *data = nil;
				err = SecItemAdd((CFDictionaryRef)op, (CFTypeRef *)&data);
				if (err == noErr && data != nil) {

					Identity *ident = [[Identity alloc] init];
					ident.persistent = data;
					ident.fullName = name;
					ident.emailAddress = email;
					ident.avatar = _avatarImage;
					if (_nickname == nil || [_nickname length] == 0) {
						// fixme(mkrautz): Convert the full name to a nickname.
						ident.userName = nil;
					} else {
						ident.userName = _nickname;
					}

					[Database storeIdentity:ident];
					[ident release];
					NSLog(@"Stored identity...");
				// This happens when a certificate with a duplicate subject name is added.
				} else if (err == noErr && data == nil) {
					ShowAlertDialog(@"Unable to add identity",
									@"The certificate of the just-added identity could not be added to the certificate store because it "
									@"has the same name as a certificate already found in the store.");
				}
			} else {
				ShowAlertDialog(@"Unable to import generated certificate",
								@"Mumble was unable to import the generated certificate into the certificate store.");
			}
		}

		dispatch_async(dispatch_get_main_queue(), ^{
			[[self navigationController] dismissModalViewControllerAnimated:YES];
		});
	});
}

- (void) nameChanged:(TableViewTextFieldCell *)firstNameField {
	[_identityName release];
	_identityName = [[firstNameField textValue] copy];
}

- (void) emailChanged:(TableViewTextFieldCell *)emailField {
	[_emailAddress release];
	_emailAddress = [[emailField textValue] copy];
}

- (void) nicknameChanged:(TableViewTextFieldCell *)nicknameField {
	[_nickname release];
	_nickname = [[nicknameField textValue] copy];
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
#pragma mark UIImagePickerController delegate

- (void) imagePickerController:(UIImagePickerController *)imagePicker didFinishPickingMediaWithInfo:(NSDictionary *)info {
	// We only allow users to pick images, and we always allow them to edit them.
	//
	// The default iOS UIImagePickerController only allows users to crop their images
	// to a 320x320 rect.  Since we expect rectangular images, it's an OK fit. We can
	// just resize them if we want a smaller image.
	UIImage *editedImage = [info objectForKey:UIImagePickerControllerEditedImage];
	_avatarImage = [[UIImage alloc] initWithCGImage:[editedImage CGImage]];
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

