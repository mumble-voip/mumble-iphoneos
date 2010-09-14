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

@interface CertificateViewController (Private)
- (void) extractCertData:(MKCertificate *)cert;
@end

@implementation CertificateViewController

#pragma mark -
#pragma mark Initialization

- (id) initWithCertificate:(MKCertificate *)cert {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self == nil)
		return nil;

	[self extractCertData:cert];

	return self;
}

- (void) dealloc {
	[_subjectItems release];
	[_issuerItems release];
	[_certTitle release];
	[super dealloc];
}

- (void) viewDidLoad {
	[self setTitle:_certTitle];
}

- (void) extractCertData:(MKCertificate *)cert {
	NSMutableArray *subject = [[NSMutableArray alloc] init];
	NSMutableArray *issuer = [[NSMutableArray alloc] init];
	NSString *str = nil;

	// Subject DN + additional
	str = [cert subjectItem:MKCertificateItemCommonName];
	if (str) {
		[subject addObject:[NSArray arrayWithObjects:@"Common Name", str, nil]];
		_certTitle = [str copy];
	} else
		_certTitle = @"Unknown Certificate";

	str = [cert subjectItem:MKCertificateItemOrganization];
	if (str)
		[subject addObject:[NSArray arrayWithObjects:@"Organization", str, nil]];

	str = [[cert notBefore] description];
	if (str)
		[subject addObject:[NSArray arrayWithObjects:@"Not Before", str, nil]];

	str = [[cert notAfter] description];
	if (str)
		[subject addObject:[NSArray arrayWithObjects:@"Not After", str, nil]];

	str = [cert emailAddress];
	if (str)
		[subject addObject:[NSArray arrayWithObjects:@"Email", str, nil]];

	// Issuer DN
	str = [cert issuerItem:MKCertificateItemCommonName];
	if (str)
		[issuer addObject:[NSArray arrayWithObjects:@"Common Name", str, nil]];

	str = [cert issuerItem:MKCertificateItemOrganization];
	if (str)
		[issuer addObject:[NSArray arrayWithObjects:@"Organization", str, nil]];

	_subjectItems = subject;
	_issuerItems = issuer;
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
	return CertificateViewSectionTotal;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == CertificateViewSectionSubject) {
		return [_subjectItems count];
	} else if (section == CertificateViewSectionIssuer) {
		return [_issuerItems count];
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

	NSArray *item = nil;
	if (section == CertificateViewSectionSubject)
		item = [_subjectItems objectAtIndex:row];
	else if (section == CertificateViewSectionIssuer)
		item = [_issuerItems objectAtIndex:row];

	cell.textLabel.text = [item objectAtIndex:0];
	cell.detailTextLabel.text = [item objectAtIndex:1];

    return cell;
}

@end

