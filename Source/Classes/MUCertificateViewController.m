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
#import "MUColor.h"

#import <MumbleKit/MKCertificate.h>

static const NSUInteger CertificateViewSectionSubject            = 0;
static const NSUInteger CertificateViewSectionIssuer             = 1;
static const NSUInteger CertificateViewSectionTotal              = 2;

@interface MUCertificateViewController () <UIAlertViewDelegate, UIActionSheetDelegate> {
    NSInteger           _curIdx;
    NSData              *_persistentRef;
    NSArray             *_certificates;
    NSArray             *_subjectItems;
    NSArray             *_issuerItems;
    NSString            *_certTitle;
    UISegmentedControl  *_arrows;
    BOOL                _allowExportAndDelete;
}
@end

@implementation MUCertificateViewController

#pragma mark -
#pragma mark Initialization

- (id) initWithPersistentRef:(NSData *)persistentRef {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        [MUCertificateController certificateWithPersistentRef:persistentRef];
        _certificates = [[NSArray arrayWithObject:[MUCertificateController certificateAndPrivateKeyWithPersistentRef:persistentRef]] retain];
        _allowExportAndDelete = YES;
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
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tableView.backgroundView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"BackgroundTextureBlackGradient"]] autorelease];
    
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
    [cell setBackgroundColor:[UIColor whiteColor]];

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

- (void) alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    // Export certificate chain
    if (alertView.alertViewStyle == UIAlertViewStyleLoginAndPasswordInput && buttonIndex == 1) {
        if ([_certificates count] > 1) {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Export Failed" message:@"Mumble can only export self-signed certificates at present." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alertView show];
            [alertView release];
            return;
        }

        MKCertificate *cert = [_certificates objectAtIndex:0];
        NSString *password = [[alertView textFieldAtIndex:1] text];
        NSData *data = [cert exportPKCS12WithPassword:password];
        if (data == nil) {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Export Failed" message:@"Mumble could not export the certificate from the certificate store." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
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
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Export Failed" message:[err localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
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
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Certificate Chain Actions" delegate:self
                                              cancelButtonTitle:@"Cancel"
                                         destructiveButtonTitle:@"Delete"
                                              otherButtonTitles:@"Export to iTunes", nil];
    [sheet showInView:self.tableView];
    [sheet release];
}

- (void) actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) { // Export
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Export Certificate Chain"
                                                            message:nil
                                                           delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Export", nil];
        [alertView setAlertViewStyle:UIAlertViewStyleLoginAndPasswordInput];
        [[alertView textFieldAtIndex:0] setPlaceholder:@"Filename"];
        [[alertView textFieldAtIndex:1] setPlaceholder:@"Password (for importing)"];
        [alertView show];
        [alertView release];
    } else if (buttonIndex == 0) { // Delete
        NSString *msg = @"Are you sure you want to delete this certificate chain?\n\nThis will permanently remove any rights associated with the certificate chain on any Mumble servers.";
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Delete Certificate Chain"
                                                            message:msg
                                                           delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Delete", nil];
        [alertView show];
        [alertView release];
    }
}

@end

