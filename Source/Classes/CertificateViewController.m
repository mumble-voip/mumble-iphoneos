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

#import "CertificateViewController.h"

#import <MumbleKit/MKCertificate.h>

static const NSUInteger CertificateViewSectionSubject            = 0;
static const NSUInteger CertificateViewSectionIssuer             = 1;
static const NSUInteger CertificateViewSectionTotal              = 2;

static const NSUInteger CertificateViewSubjectCommonName         = 0;
static const NSUInteger CertificateViewSubjectOrganization       = 1;
static const NSUInteger CertificateViewSubjectOrganizationalUnit = 2;
static const NSUInteger CertificateViewSubjectCountry            = 3;
static const NSUInteger CertificateViewSubjectLocale             = 4;
static const NSUInteger CertificateViewSubjectState              = 5;
static const NSUInteger CertificateViewSubjectNotBefore          = 6;
static const NSUInteger CertificateViewSubjectNotAfter           = 7;
static const NSUInteger CertificateViewSubjectEmail              = 8;
static const NSUInteger CertificateViewSubjectNumRows            = 9;

static const NSUInteger CertificateViewIssuerCommonName          = 0;
static const NSUInteger CertificateViewIssuerOrganization        = 1;
static const NSUInteger CertificateViewIssuerOrganizationalUnit  = 2;
static const NSUInteger CertificateViewIssuerCountry             = 3;
static const NSUInteger CertificateViewIssuerLocale              = 4;
static const NSUInteger CertificateViewIssuerState               = 5;
static const NSUInteger CertificateViewIssuerNumRows             = 6;


@implementation CertificateViewController


#pragma mark -
#pragma mark Initialization

- (id) initWithCertificate:(MKCertificate *)cert {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self == nil)
		return nil;

	_cert = [cert retain];

	return self;
}

- (void) dealloc {
	[_cert release];
	[super dealloc];
}

- (void) viewDidLoad {
	[self setTitle:[_cert subjectItem:MKCertificateItemCommonName]];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
	return CertificateViewSectionTotal;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == CertificateViewSectionSubject) {
		return CertificateViewSubjectNumRows;
	} else if (section == CertificateViewSectionIssuer) {
		return CertificateViewIssuerNumRows;
	}
	return 0;
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == CertificateViewSectionSubject) {
		return @"Subject";
	} else if (section == CertificateViewSectionIssuer) {
		return @"Issuer";
	}
	return @"Unknown";
}

// Customize the appearance of table view cells.
- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *CellIdentifier = @"CertificateViewCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier] autorelease];
	}

	[cell setSelectionStyle:UITableViewCellSelectionStyleNone];
	[[cell detailTextLabel] setAdjustsFontSizeToFitWidth:YES];

	NSUInteger section = [indexPath section];
	NSUInteger row = [indexPath row];

	if (section == CertificateViewSectionSubject) {
		if (row == CertificateViewSubjectCommonName) {
			cell.textLabel.text = @"Common Name";
			cell.detailTextLabel.text = [_cert subjectItem:MKCertificateItemCommonName];
		} else if (row == CertificateViewSubjectOrganization) {
			cell.textLabel.text = @"Organization";
			cell.detailTextLabel.text = [_cert subjectItem:MKCertificateItemOrganization];
		} else if (row == CertificateViewSubjectOrganizationalUnit) {
			cell.textLabel.text = @"Org. Unit";
			cell.detailTextLabel.text = @"";
		} else if (row == CertificateViewSubjectCountry) {
			cell.textLabel.text = @"Country";
			cell.detailTextLabel.text = @"";
		} else if (row == CertificateViewSubjectLocale) {
			cell.textLabel.text = @"Locale";
			cell.detailTextLabel.text = @"";
		} else if (row == CertificateViewSubjectState) {
			cell.textLabel.text = @"State";
			cell.detailTextLabel.text = @"";
		} else if (row == CertificateViewSubjectNotBefore) {
			cell.textLabel.text = @"Valid from";
			cell.detailTextLabel.text = [[_cert notBefore] description];
		} else if (row == CertificateViewSubjectNotAfter) {
			cell.textLabel.text = @"Valid to";
			cell.detailTextLabel.text = [[_cert notAfter] description];
		} else if (row == CertificateViewSubjectEmail) {
			cell.textLabel.text = @"Email";
			cell.detailTextLabel.text = [_cert emailAddress];
		}
	} else if (section == CertificateViewSectionIssuer) {
		if (row == CertificateViewIssuerCommonName) {
			cell.textLabel.text = @"Common Name";
			cell.detailTextLabel.text = [_cert issuerItem:MKCertificateItemCommonName];
		} else if (row == CertificateViewIssuerOrganization) {
			cell.textLabel.text = @"Organization";
			cell.detailTextLabel.text = [_cert issuerItem:MKCertificateItemOrganization];
		} else if (row == CertificateViewIssuerOrganizationalUnit) {
			cell.textLabel.text = @"Org. Unit";
			cell.detailTextLabel.text = @"";
		} else if (row == CertificateViewIssuerCountry) {
			cell.textLabel.text = @"Country";
			cell.detailTextLabel.text = @"";
		} else if (row == CertificateViewIssuerLocale) {
			cell.textLabel.text = @"Locale";
			cell.detailTextLabel.text = @"";
		} else if (row == CertificateViewIssuerState) {
			cell.textLabel.text = @"State";
			cell.detailTextLabel.text = @"";
		}
	}
    
    return cell;
}

@end

