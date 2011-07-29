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

#import "MUCertificateCreationView.h"
#import "MUTableViewTextFieldCell.h"
#import "MUCertificateCreationProgressView.h"
#import "MUCertificateController.h"

#import <MumbleKit/MKCertificate.h>

static void ShowAlertDialog(NSString *title, NSString *msg) {
	dispatch_async(dispatch_get_main_queue(), ^{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
		[alert release];
	});
}

@interface MUCertificateCreationView () {
    NSString  *_fullName;
    NSString  *_emailAddress;
}
@end

@implementation MUCertificateCreationView

#pragma mark -
#pragma mark Initialization

- (id) init {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		[self setContentSizeForViewInPopover:CGSizeMake(320, 480)];
	}
	return self;
}

- (void) dealloc {
	[super dealloc];
}

- (void) viewWillAppear:(BOOL)animated {
	[self setTitle:@"New Certificate"];

	UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(cancelClicked:)];
	[[self navigationItem] setLeftBarButtonItem:cancelButton];
	[cancelButton release];

	UIBarButtonItem *createButton = [[UIBarButtonItem alloc] initWithTitle:@"Create" style:UIBarButtonItemStyleDone target:self action:@selector(createClicked:)];
	[[self navigationItem] setRightBarButtonItem:createButton];
	[createButton release];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"CertGenCell";
    MUTableViewTextFieldCell *cell = (MUTableViewTextFieldCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
		cell = [[[MUTableViewTextFieldCell alloc] initWithReuseIdentifier:CellIdentifier] autorelease];
    }

	NSUInteger row = [indexPath row];
	if (row == 0) { // Full name
		[cell setLabel:@"Name"];
		[cell setPlaceholder:@"Mumble User"];
		[cell setAutocapitalizationType:UITextAutocapitalizationTypeWords];
		[cell setValueChangedAction:@selector(nameChanged:)];
		[cell setTextValue:_fullName];
		[cell setTarget:self];
	} else if (row == 1) { // Email
		[cell setLabel:@"Email"];
		[cell setPlaceholder:@"(Optional)"];
		[cell setAutocapitalizationType:UITextAutocapitalizationTypeNone];
		[cell setValueChangedAction:@selector(emailChanged:)];
		[cell setTextValue:_emailAddress];
		[cell setTarget:self];
	}

    return (UITableViewCell *)cell;
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
}

#pragma mark -
#pragma mark Target/actions

- (void) nameChanged:(MUTableViewTextFieldCell *)sender {
	[_fullName release];
	_fullName = [[sender textValue] copy];
}

- (void) emailChanged:(MUTableViewTextFieldCell *)sender {
	[_emailAddress release];
	_emailAddress = [[sender textValue] copy];
}

- (void) cancelClicked:(id)sender {
	[[self navigationController] dismissModalViewControllerAnimated:YES];
}

- (void) createClicked:(id)sender {
	NSString *name, *email;
	
	if (_fullName == nil || [_fullName length] == 0) {
		name = @"Mumble User";
	} else {
		name = _fullName;
	}
	
	if (_emailAddress == nil || [_emailAddress length] == 0) {
		email = nil;
	} else {
		// fixme(mkrautz): RegEx this or do a DNS lookup like the desktop client to determine if
		// the email has a chance to be valid.
		email = _emailAddress;
	}

	MUCertificateCreationProgressView *progress = [[MUCertificateCreationProgressView alloc] initWithName:name email:email];
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
					// Success!
					// Now, check if there's already a default certificate set.
                    if ([MUCertificateController defaultCertificate] == nil) {
                        [MUCertificateController setDefaultCertificateByPersistentRef:data];
                    }

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

@end

