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
#import "MUCertificateController.h"
#import "MUCertificateChainBuilder.h"
#import "MUColor.h"
#import "MUImage.h"

#import <MumbleKit/MKCertificate.h>

static const NSUInteger CertificateViewSectionSubject            = 0;
static const NSUInteger CertificateViewSectionIssuer             = 1;
static const NSUInteger CertificateViewSectionFingerprint        = 2;
static const NSUInteger CertificateViewSectionTotal              = 3;

@interface MUCertificateViewController () <UIAlertViewDelegate, UIActionSheetDelegate> {
    NSInteger            _curIdx;
    NSData              *_persistentRef;
    NSArray             *_certificates;
    NSArray             *_subjectItems;
    NSArray             *_issuerItems;
    NSString            *_certTitle;
    UISegmentedControl  *_arrows;
    BOOL                 _allowExportAndDelete;
}
@end

@implementation MUCertificateViewController

#pragma mark -
#pragma mark Initialization

- (id) initWithPersistentRef:(NSData *)persistentRef {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        self.contentSizeForViewInPopover = CGSizeMake(320, 480);
        
        // Try to build a chain, if possible.
        NSArray *chains = [MUCertificateChainBuilder buildChainFromPersistentRef:persistentRef];
        NSMutableArray *certificates = [[NSMutableArray alloc] initWithCapacity:[chains count]];
        [certificates addObject:[MUCertificateController certificateWithPersistentRef:persistentRef]];
        for (int i = 1; i < [chains count]; i++) {
            SecCertificateRef secCert = (SecCertificateRef) [chains objectAtIndex:i];
            NSData *certData = (NSData *) SecCertificateCopyData(secCert);
            [certificates addObject:[MKCertificate certificateWithCertificate:certData privateKey:nil]];
            [certData release];
        }
        _certificates = certificates;
        _allowExportAndDelete = YES;
        _curIdx = 0;
        _persistentRef = [persistentRef retain];
        
    }
    return self;
}

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
    [_persistentRef release];
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

    self.navigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundView = [[[UIImageView alloc] initWithImage:[MUImage imageNamed:@"BackgroundTextureBlackGradient"]] autorelease];
    
    UIBarButtonItem *actions = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(actionClicked:)];
    [actions setStyle:UIBarButtonItemStyleBordered];
    [actions autorelease];

    // If there's more than one certificate in the chain, show the arrows
    if ([_certificates count] > 1) {
        UIBarButtonItem *segmentedContainer = [[[UIBarButtonItem alloc] initWithCustomView:_arrows] autorelease];
        if (_allowExportAndDelete) {
            UIToolbar *toolbar = [[[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 125, 45)] autorelease];
            [toolbar setBarStyle:UIBarStyleBlackOpaque];
            [toolbar setItems:[NSArray arrayWithObjects:actions, segmentedContainer, nil]];
    
            UIBarButtonItem *toolbarContainer = [[[UIBarButtonItem alloc] initWithCustomView:toolbar] autorelease];        
            self.navigationItem.rightBarButtonItem = toolbarContainer;
        } else {
            self.navigationItem.rightBarButtonItem = segmentedContainer;
        }
    } else if ([_certificates count] == 1 &&_allowExportAndDelete) {
        self.navigationItem.rightBarButtonItem = actions;
    }

    [self updateCertificateDisplay];
}

- (void) showDataForCertificate:(MKCertificate *)cert {
    NSMutableArray *subject = [[NSMutableArray alloc] init];
    NSMutableArray *issuer = [[NSMutableArray alloc] init];
    NSString *str = nil;

    NSString *cn = NSLocalizedString(@"Common Name", @"Common Name (CN) of an X.509 certificate");
    NSString *org = NSLocalizedString(@"Organization", @"Organization (O) of an X.509 certificate");
    
    // Subject DN + additional
    str = [cert subjectItem:MKCertificateItemCommonName];
    if (str) {
        [subject addObject:[NSArray arrayWithObjects:cn, str, nil]];
        _certTitle = [str copy];
    } else {
        _certTitle = NSLocalizedString(@"Unknown Certificate",
                                       @"Title shown when viewing a certificate without a Subject Common Name (CN)");
    }

    str = [cert subjectItem:MKCertificateItemOrganization];
    if (str) {
        [subject addObject:[NSArray arrayWithObjects:org, str, nil]];
    }

    str = [[cert notBefore] description];
    if (str) {
        NSString *notBefore = NSLocalizedString(@"Not Before", @"Not Before date (validity period) of an X.509 certificate");
        [subject addObject:[NSArray arrayWithObjects:notBefore, str, nil]];
    }

    str = [[cert notAfter] description];
    if (str) {
        NSString *notAfter = NSLocalizedString(@"Not After", @"Not After date (validity period) of an X.509 certificate");
        [subject addObject:[NSArray arrayWithObjects:notAfter, str, nil]];
    }

    str = [cert emailAddress];
    if (str) {
        NSString *emailAddr = NSLocalizedString(@"Email", @"Email address of an X.509 certificate");
        [subject addObject:[NSArray arrayWithObjects:emailAddr, str, nil]];
    }

    // Issuer DN
    str = [cert issuerItem:MKCertificateItemCommonName];
    if (str)
        [issuer addObject:[NSArray arrayWithObjects:cn, str, nil]];

    str = [cert issuerItem:MKCertificateItemOrganization];
    if (str)
        [issuer addObject:[NSArray arrayWithObjects:org, str, nil]];

    [_subjectItems release];
    _subjectItems = subject;

    [_issuerItems release];
    _issuerItems = issuer;

    [self.tableView reloadData];
}

- (void) updateCertificateDisplay {
    [self showDataForCertificate:[_certificates objectAtIndex:_curIdx]];

    NSString *indexFmt = NSLocalizedString(@"%i of %i", @"Title for viewing a certificate chain (1 of 2, etc.)");
    self.navigationItem.title = [NSString stringWithFormat:indexFmt, _curIdx+1, [_certificates count]];
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
    } else if (section == CertificateViewSectionFingerprint) {
        return 2;
    }
    return 0;
}

- (UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *subject = NSLocalizedString(@"Subject", @"Subject of an X.509 certificate");
    NSString *issuer = NSLocalizedString(@"Issuer", @"Issuer of an X.509 certificate");
    NSString *fingerprint = NSLocalizedString(@"Fingerprint", @"Fingerprint of an X.509 certificate");
    if (section == CertificateViewSectionSubject) {
        return [MUTableViewHeaderLabel labelWithText:subject];
    } else if (section == CertificateViewSectionIssuer) {
        return [MUTableViewHeaderLabel labelWithText:issuer];
    } else if (section == CertificateViewSectionFingerprint) {
        return [MUTableViewHeaderLabel labelWithText:fingerprint];
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
    [cell setBackgroundColor:[UIColor whiteColor]];

    NSUInteger section = [indexPath section];
    NSUInteger row = [indexPath row];
    if (section == CertificateViewSectionFingerprint) {
        MKCertificate *cert = [_certificates objectAtIndex:_curIdx];
        NSString *hexDigest = [cert hexDigest];
        if (hexDigest.length == 40) {
            if (row == 0) {
                cell.textLabel.text = [MUCertificateController fingerprintFromHexString:[hexDigest substringToIndex:20]];
            } else if (row == 1) {
                cell.textLabel.text = [MUCertificateController fingerprintFromHexString:[hexDigest substringFromIndex:20]];
            }
            cell.textLabel.textColor = [MUColor selectedTextColor];
            cell.textLabel.font = [UIFont fontWithName:@"Courier" size:16];
        }
    } else {
        NSArray *item = nil;
        if (section == CertificateViewSectionSubject)
            item = [_subjectItems objectAtIndex:row];
        else if (section == CertificateViewSectionIssuer)
            item = [_issuerItems objectAtIndex:row];
        cell.textLabel.text = [item objectAtIndex:0];
        cell.detailTextLabel.text = [item objectAtIndex:1];
        cell.detailTextLabel.textColor = [MUColor selectedTextColor];
    }
    return cell;
}

#pragma mark -
#pragma mark Actions

- (void) alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    NSString *exportFailedTitle = NSLocalizedString(@"Export Failed", @"Title for UIAlertView when a certificate export fails");
    NSString *cancelButtonText = NSLocalizedString(@"OK", @"Default Cancel button text for UIAlertViews that are shown when certificate export fails.");
    
    // Export certificate chain
    if (alertView.alertViewStyle == UIAlertViewStyleLoginAndPasswordInput && buttonIndex == 1) {
        NSString *password = [[alertView textFieldAtIndex:1] text];
        NSData *data = [MKCertificate exportCertificateChainAsPKCS12:_certificates withPassword:password];
        if (data == nil) {
            NSString *unknownExportErrorMsg = NSLocalizedString(@"Mumble was unable to export the certificate.",
                                                                @"Error message shown for a failed export, cause unknown.");
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:exportFailedTitle
                                                                message:unknownExportErrorMsg
                                                               delegate:nil
                                                      cancelButtonTitle:cancelButtonText
                                                      otherButtonTitles:nil];
            [alertView show];
            [alertView release];
            return;
        }

        NSString *fileName = [[alertView textFieldAtIndex:0] text];
        if ([[fileName pathExtension] isEqualToString:@""]) {
            fileName = [fileName stringByAppendingPathExtension:@"pkcs12"];
        }

        NSArray *documentDirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *pkcs12File = [[documentDirs objectAtIndex:0] stringByAppendingPathComponent:fileName];        
        NSError *err = nil;
        if (![data writeToFile:pkcs12File options:NSDataWritingAtomic error:&err]) {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:exportFailedTitle
                                                                message:[err localizedDescription]
                                                               delegate:nil
                                                      cancelButtonTitle:cancelButtonText
                                                      otherButtonTitles:nil];
            [alertView show];
            [alertView release];
            return;
        }
    }

    // Delete certificate chain
    if (alertView.alertViewStyle == UIAlertViewStyleDefault && buttonIndex == 1) {
        [MUCertificateController deleteCertificateWithPersistentRef:_persistentRef];
        [self.navigationController popViewControllerAnimated:YES];
    }
}

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

- (void) actionClicked:(id)sender {
    NSString *cancel = NSLocalizedString(@"Cancel", nil);
    NSString *delete = NSLocalizedString(@"Delete", nil);
    NSString *export = NSLocalizedString(@"Export to iTunes", @"iTunes export button text for certificate chain action sheet");

    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil
                                                       delegate:self
                                              cancelButtonTitle:cancel
                                         destructiveButtonTitle:delete
                                              otherButtonTitles:export, nil];
    [sheet setActionSheetStyle:UIActionSheetStyleBlackOpaque];
    [sheet showInView:self.tableView];
    [sheet release];
}

- (void) actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) { // Export
        NSString *title = NSLocalizedString(@"Export Certificate Chain", @"Title for certificate export alert view (with username and password field)");
        NSString *cancel = NSLocalizedString(@"Cancel", nil);
        NSString *export = NSLocalizedString(@"Export", nil);
        NSString *filename = NSLocalizedString(@"Filename", @"Filename text field in certificate export alert view");
        NSString *password = NSLocalizedString(@"Password (for importing)", @"Password text field in certificate export alert view");
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title
                                                            message:nil
                                                           delegate:self
                                                  cancelButtonTitle:cancel
                                                  otherButtonTitles:export, nil];
        [alertView setAlertViewStyle:UIAlertViewStyleLoginAndPasswordInput];
        [[alertView textFieldAtIndex:0] setPlaceholder:filename];
        [[alertView textFieldAtIndex:1] setPlaceholder:password];
        [alertView show];
        [alertView release];
    } else if (buttonIndex == 0) { // Delete
        NSString *title = NSLocalizedString(@"Delete Certificate Chain", @"Certificate deletion warning title");
        NSString *msg = NSLocalizedString(@"Are you sure you want to delete this certificate chain?\n\n"
                                          @"This will permanently remove any rights associated with the certificate chain on any Mumble servers.",
                                                @"Certificate deletion warning message");
        NSString *cancel = NSLocalizedString(@"Cancel", nil);
        NSString *delete = NSLocalizedString(@"Delete", nil);
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title
                                                            message:msg
                                                           delegate:self cancelButtonTitle:cancel otherButtonTitles:delete, nil];
        [alertView show];
        [alertView release];
    }
}

@end

