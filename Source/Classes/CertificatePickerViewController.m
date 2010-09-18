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

#import "CertificatePickerViewController.h"
#import "CertificateCell.h"

#import <MumbleKit/MKCertificate.h>

@interface CertificatePickerViewController (Private)
- (void) fetchCertificates;
@end

@implementation CertificatePickerViewController

#pragma mark -
#pragma mark Initialization

- (id) initWithPersistentRef:(NSData *)persistentRef {
	self = [super initWithStyle:UITableViewStyleGrouped];

	if (self != nil) {
		[self fetchCertificates];
		_selected = persistentRef;
	}

	return self;
}

- (void) dealloc {
	[_certificateItems release];
	[super dealloc];
}

- (void) viewWillAppear:(BOOL)animated {
	[self setTitle:@"Choose..."];
}

#pragma mark -
#pragma mark Delegate

- (id<CertificatePickerViewControllerDelegate>) delegate {
	return _delegate;
}

- (void) setDelegate:(id<CertificatePickerViewControllerDelegate>)delegate {
	_delegate = delegate;
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_certificateItems count] + 1;
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
		if (_selected != nil) {
			[cell setAccessoryType:UITableViewCellAccessoryNone];
		} else {
			[cell setAccessoryType:UITableViewCellAccessoryCheckmark];
			_selectedRow = row;
		}
		return cell;
	}

	static NSString *CellIdentifier = @"CertificateCell";
	CertificateCell *cell = (CertificateCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (cell == nil)
		cell = [CertificateCell loadFromNib];

	NSDictionary *dict = [_certificateItems objectAtIndex:row-1];
	MKCertificate *cert = [dict objectForKey:@"cert"];
	[cell setSubjectName:[cert commonName]];
	[cell setEmail:[cert emailAddress]];
	[cell setIssuerText:[cert issuerName]];
	[cell setExpiryText:[[cert notAfter] description]];
	if ([_selected isEqualToData:[dict objectForKey:@"persistentRef"]]) {
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
	if (row == _selectedRow)
		return;

	UITableViewCell *cell = [[self tableView] cellForRowAtIndexPath:[NSIndexPath indexPathForRow:_selectedRow inSection:0]];
	[cell setAccessoryType:UITableViewCellAccessoryNone];

	cell = [[self tableView] cellForRowAtIndexPath:indexPath];
	[cell setAccessoryType:UITableViewCellAccessoryCheckmark];
	_selectedRow = row;

	NSDictionary *dict = row > 0 ? [_certificateItems objectAtIndex:row-1] : nil;
	_selected = [dict objectForKey:@"persistentRef"];
	if ([(id)_delegate respondsToSelector:@selector(certificatePickerViewController:didSelectCertificate:)]) {
		[_delegate certificatePickerViewController:self didSelectCertificate:_selected];
	}

	[[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if ([indexPath row] == 0) {
		return 44.0f;
	}
	return 85.0f;
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

