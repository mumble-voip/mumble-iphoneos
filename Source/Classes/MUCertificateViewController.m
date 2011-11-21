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

#import "MUCertificateViewController.h"
#import "MUTableViewHeaderLabel.h"
#import "MUColor.h"

#import <MumbleKit/MKCertificate.h>

static const NSUInteger CertificateViewSectionSubject            = 0;
static const NSUInteger CertificateViewSectionIssuer             = 1;
static const NSUInteger CertificateViewSectionTotal              = 2;

@interface MUCertificateViewController () {
    NSInteger           _curIdx;
    NSArray             *_certificates;
    NSArray             *_subjectItems;
    NSArray             *_issuerItems;
    NSString            *_certTitle;
    UISegmentedControl  *_arrows;
}
@end

@implementation MUCertificateViewController

#pragma mark -
#pragma mark Initialization

- (id) initWithCertificate:(MKCertificate *)cert {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        _certificates = [[NSArray alloc] initWithObjects:cert, nil];
        _curIdx = 0;
        [self setContentSizeForViewInPopover:CGSizeMake(320, 480)];
    }
    return self;
}

- (id) initWithCertificates:(NSArray *)cert {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        _certificates = [[NSArray alloc] initWithArray:cert];
        _curIdx = 0;
        [self setContentSizeForViewInPopover:CGSizeMake(320, 480)];
    }
    return self;
}

- (void) dealloc {
    [_subjectItems release];
    [_issuerItems release];
    [_certTitle release];
    [_arrows release];
    [super dealloc];
}

- (void) viewDidLoad {
    [self setTitle:_certTitle];
}

- (void) viewWillAppear:(BOOL)animated {
    if (_arrows == nil) {
        _arrows = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:
                    [UIImage imageNamed:@"up.png"],
                    [UIImage imageNamed:@"down.png"],
                nil]];

        _arrows.segmentedControlStyle = UISegmentedControlStyleBar;
        _arrows.momentary = YES;
        [_arrows addTarget:self action:@selector(certificateSwitch:) forControlEvents:UIControlEventValueChanged];
    }

    self.tableView.backgroundView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"BackgroundTextureBlackGradient"]] autorelease];
    
    UIBarButtonItem *segmentedContainer = [[UIBarButtonItem alloc] initWithCustomView:_arrows];
    self.navigationItem.rightBarButtonItem = segmentedContainer;
    [segmentedContainer release];

    [self updateCertificateDisplay];
}

- (void) showDataForCertificate:(MKCertificate *)cert {
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

    [_subjectItems release];
    _subjectItems = subject;

    [_issuerItems release];
    _issuerItems = issuer;

    [self.tableView reloadData];
}

- (void) updateCertificateDisplay {
    [self showDataForCertificate:[_certificates objectAtIndex:_curIdx]];

    self.navigationItem.title = [NSString stringWithFormat:@"%i of %i", _curIdx+1, [_certificates count]];
    [_arrows setEnabled:(_curIdx != [_certificates count]-1) forSegmentAtIndex:0];
    [_arrows setEnabled:(_curIdx != 0) forSegmentAtIndex:1];
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

- (UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == CertificateViewSectionSubject) {
        return [MUTableViewHeaderLabel labelWithText:@"Subject"];
    } else if (section == CertificateViewSectionIssuer) {
        return [MUTableViewHeaderLabel labelWithText:@"Issuer"];
    }
    return nil;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return [MUTableViewHeaderLabel defaultHeaderHeight];
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
    cell.detailTextLabel.textColor = [MUColor selectedTextColor];

    return cell;
}

#pragma mark -
#pragma mark Actions

- (void) certificateSwitch:(id)sender {
    if ([_arrows selectedSegmentIndex] == 0) {
        if (_curIdx < [_certificates count]-1) {
            _curIdx += 1;
        }
    } else {
        if (_curIdx > 0) {
            _curIdx -= 1;
        }
        
    }

    [self updateCertificateDisplay];
}

@end

