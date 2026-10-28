#import "MUInterface.h"
// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

@import UniformTypeIdentifiers;

#import "MUCertificateViewController.h"
#import "MUCertificateController.h"
#import "MUCertificateChainBuilder.h"
#import "MUImage.h"

#import "MLClient.h"

static const NSUInteger CertificateViewSectionSubject            = 0;
static const NSUInteger CertificateViewSectionIssuer             = 1;
static const NSUInteger CertificateViewSectionSHA1Fingerprint    = 2;
static const NSUInteger CertificateViewSectionSHA256Fingerprint  = 3;
static const NSUInteger CertificateViewSectionTotal              = 4;

@interface MUCertificateViewController () <UIDocumentPickerDelegate> {
    NSURL *_exportDirectoryURL;
    NSInteger            _curIdx;
    NSData              *_persistentRef;
    NSArray             *_certificates;
    NSArray             *_subjectItems;
    NSArray             *_issuerItems;
    NSString            *_certTitle;
    UIBarButtonItem     *_previousCertificateButton, *_nextCertificateButton;
    BOOL                 _allowExportAndDelete;
}
@end

@implementation MUCertificateViewController

#pragma mark -
#pragma mark Initialization

- (id) initWithPersistentRef:(NSData *)persistentRef {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        self.preferredContentSize = CGSizeMake(320, 480);

        // Try to build a chain, if possible.
        NSArray *chains = [MUCertificateChainBuilder buildChainFromPersistentRef:persistentRef];
        NSMutableArray *certificates = [[NSMutableArray alloc] initWithCapacity:[chains count]];
        [certificates addObject:[MUCertificateController certificateWithPersistentRef:persistentRef]];
        for (int i = 1; i < [chains count]; i++) {
            SecCertificateRef secCert = (__bridge SecCertificateRef)[chains objectAtIndex:i];
            NSData *certData = CFBridgingRelease(SecCertificateCopyData(secCert));
            [certificates addObject:[MLCertificate certificateWithCertificate:certData privateKey:nil]];

        }
        _certificates = certificates;
        _allowExportAndDelete = YES;
        _curIdx = 0;
        _persistentRef = persistentRef;

    }
    return self;
}

- (id) initWithCertificate:(MLCertificate *)cert {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        _certificates = [[NSArray alloc] initWithObjects:cert, nil];
        _curIdx = 0;
        self.preferredContentSize = CGSizeMake(320, 480);
    }
    return self;
}

- (id) initWithCertificates:(NSArray *)cert {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        _certificates = [[NSArray alloc] initWithArray:cert];
        _curIdx = 0;
        self.preferredContentSize = CGSizeMake(320, 480);
    }
    return self;
}

- (void) dealloc {
    [self clearTemporaryExport];

}

- (void) viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    [self setTitle:_certTitle];

    [[self tableView] setRowHeight:UITableViewAutomaticDimension];
    [[self tableView] setEstimatedRowHeight:44.0f];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (_previousCertificateButton == nil) {
        _previousCertificateButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"chevron.up"] style:UIBarButtonItemStylePlain target:self action:@selector(previousCertificate:)];
        _nextCertificateButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"chevron.down"] style:UIBarButtonItemStylePlain target:self action:@selector(nextCertificate:)];
        _previousCertificateButton.accessibilityLabel = NSLocalizedString(@"Previous Certificate", nil);
        _nextCertificateButton.accessibilityLabel = NSLocalizedString(@"Next Certificate", nil);
    }

    self.tableView.backgroundView = nil;

    {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    }

    UIBarButtonItem *actions = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(actionClicked:)];
    [actions setStyle:UIBarButtonItemStylePlain];

    NSMutableArray *buttons = [NSMutableArray array];
    // Use navigation bar items directly; wrapping a segmented control or
    // toolbar adds a second system glass surface inside the navigation bar.
    if ([_certificates count] > 1) {
        // UIKit lays out right bar items from the trailing edge inward.
        [buttons addObject:_nextCertificateButton];
        [buttons addObject:_previousCertificateButton];
    }
    if ([_certificates count] > 0 && _allowExportAndDelete) [buttons addObject:actions];
    self.navigationItem.rightBarButtonItems = buttons;

    [self updateCertificateDisplay];
}

- (void) showDataForCertificate:(MLCertificate *)cert {
    NSMutableArray *subject = [[NSMutableArray alloc] init];
    NSMutableArray *issuer = [[NSMutableArray alloc] init];
    NSString *str = nil;

    NSString *cn = NSLocalizedString(@"Common Name", @"Common Name (CN) of an X.509 certificate");
    NSString *org = NSLocalizedString(@"Organization", @"Organization (O) of an X.509 certificate");

    // Subject DN + additional

    str = [cert subjectItem:MLCertificateItemCommonName];
    if (str) {
        [subject addObject:[NSArray arrayWithObjects:cn, str, nil]];
        _certTitle = [str copy];
    } else {
        _certTitle = [NSLocalizedString(@"Unknown Certificate",
                                       @"Title shown when viewing a certificate without a Subject Common Name (CN)") copy];
    }

    str = [cert subjectItem:MLCertificateItemOrganization];
    if (str) {
        [subject addObject:[NSArray arrayWithObjects:org, str, nil]];
    }

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
    NSDate *date = nil;

    date = [cert notBefore];
    if (date) {
        str = [dateFormatter stringFromDate:date];
    } else {
        str = nil;
    }
    if (str) {
        NSString *notBefore = NSLocalizedString(@"Not Before", @"Not Before date (validity period) of an X.509 certificate");
        [subject addObject:[NSArray arrayWithObjects:notBefore, str, nil]];
    }

    date = [cert notAfter];
    if (date) {
        str = [dateFormatter stringFromDate:date];
    } else {
        str = nil;
    }
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
    str = [cert issuerItem:MLCertificateItemCommonName];
    if (str)
        [issuer addObject:[NSArray arrayWithObjects:cn, str, nil]];

    str = [cert issuerItem:MLCertificateItemOrganization];
    if (str)
        [issuer addObject:[NSArray arrayWithObjects:org, str, nil]];

    _subjectItems = subject;

    _issuerItems = issuer;

    [self.tableView reloadData];
}

- (void) updateCertificateDisplay {
    [self showDataForCertificate:[_certificates objectAtIndex:_curIdx]];

    NSString *indexFmt = NSLocalizedString(@"%i of %i", @"Title for viewing a certificate chain (1 of 2, etc.)");
    self.navigationItem.title = [NSString stringWithFormat:indexFmt, _curIdx+1, [_certificates count]];
    _previousCertificateButton.enabled = _curIdx > 0;
    _nextCertificateButton.enabled = _curIdx + 1 < [_certificates count];
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
    } else if (section == CertificateViewSectionSHA1Fingerprint) {
        return 1;
    } else if (section == CertificateViewSectionSHA256Fingerprint) {
        return 1;
    }
    return 0;
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == CertificateViewSectionSubject) {
        return NSLocalizedString(@"Subject", @"Subject of an X.509 certificate");
    } else if (section == CertificateViewSectionIssuer) {
        return NSLocalizedString(@"Issuer", @"Issuer of an X.509 certificate");
    } else if (section == CertificateViewSectionSHA1Fingerprint) {
        return NSLocalizedString(@"SHA1 Fingerprint", @"SHA1 fingerprint of an X.509 certificate");
    } else if (section == CertificateViewSectionSHA256Fingerprint) {
        return NSLocalizedString(@"SHA256 Fingerprint", @"SHA256 fingerprint of an X.509 certificate");
    }
    return nil;
}

// Customize the appearance of table view cells.
- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"CertificateViewCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
        MUConfigureStandardCell(cell);
    }

    [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
    [[cell detailTextLabel] setAdjustsFontSizeToFitWidth:NO];
    [cell setBackgroundColor:[UIColor secondarySystemGroupedBackgroundColor]];

    NSUInteger section = [indexPath section];
    NSUInteger row = [indexPath row];
    if (section == CertificateViewSectionSHA1Fingerprint) {
        MLCertificate *cert = [_certificates objectAtIndex:_curIdx];
        NSString *hexDigest = [cert hexDigestOfKind:@"sha1"];
        if ([indexPath row] == 0 && hexDigest.length == 40) {
            cell.textLabel.text = hexDigest;
            cell.textLabel.textColor = [UIColor labelColor];
            cell.textLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightRegular]];
            cell.textLabel.numberOfLines = 0;
            cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        }
    } else if (section == CertificateViewSectionSHA256Fingerprint) {
        MLCertificate *cert = [_certificates objectAtIndex:_curIdx];
        NSString *hexDigest = [cert hexDigestOfKind:@"sha256"];
        if ([indexPath row] == 0 && hexDigest.length == 64) {
            cell.textLabel.text = hexDigest;
            cell.textLabel.textColor = [UIColor labelColor];
            cell.textLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightRegular]];
            cell.textLabel.numberOfLines = 0;
            cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        }
    } else {
        NSArray *item = nil;
        if (section == CertificateViewSectionSubject)
            item = [_subjectItems objectAtIndex:row];
        else if (section == CertificateViewSectionIssuer)
            item = [_issuerItems objectAtIndex:row];
        cell.textLabel.text = [item objectAtIndex:0];
        cell.textLabel.textColor = [UIColor labelColor];
        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        cell.detailTextLabel.text = [item objectAtIndex:1];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    cell.textLabel.adjustsFontForContentSizeCategory = YES;
    cell.detailTextLabel.adjustsFontForContentSizeCategory = YES;
    cell.detailTextLabel.numberOfLines = 0;
    return cell;
}

#pragma mark -
#pragma mark Table view delegate

- (BOOL) canCopyCertificateFieldAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case CertificateViewSectionSubject:
        case CertificateViewSectionIssuer:
        case CertificateViewSectionSHA1Fingerprint:
        case CertificateViewSectionSHA256Fingerprint:
            return YES;
    }
    return NO;
}

- (void) copyCertificateFieldAtIndexPath:(NSIndexPath *)indexPath {
    MLCertificate *cert = [_certificates objectAtIndex:_curIdx];
    NSString *str = nil;
    switch (indexPath.section) {
        case CertificateViewSectionSubject:
        case CertificateViewSectionIssuer: {
            NSArray *item = nil;
            if (indexPath.section == CertificateViewSectionSubject)
                item = [_subjectItems objectAtIndex:indexPath.row];
            else if (indexPath.section == CertificateViewSectionIssuer)
                item = [_issuerItems objectAtIndex:indexPath.row];
            str = [item objectAtIndex:1];
            break;
        }
        case CertificateViewSectionSHA1Fingerprint:
            str = [cert hexDigestOfKind:@"sha1"];
            break;
        case CertificateViewSectionSHA256Fingerprint:
            str = [cert hexDigestOfKind:@"sha256"];
            break;
    }
    if (str != nil) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        [pasteboard setValue:str forPasteboardType:UTTypeUTF8PlainText.identifier];
    }
}

- (UIContextMenuConfiguration *) tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point {
    if (![self canCopyCertificateFieldAtIndexPath:indexPath]) {
        return nil;
    }
    return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggestedActions) {
        UIAction *copyAction = [UIAction actionWithTitle:NSLocalizedString(@"Copy", nil) image:nil identifier:nil handler:^(__kindof UIAction *action) {
            [self copyCertificateFieldAtIndexPath:indexPath];
        }];
        return [UIMenu menuWithChildren:@[copyAction]];
    }];
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

- (void)previousCertificate:(id)sender {
    if (_curIdx <= 0) return;
    _curIdx--;
    [self updateCertificateDisplay];
}

- (void)nextCertificate:(id)sender {
    if (_curIdx + 1 >= [_certificates count]) return;
    _curIdx++;
    [self updateCertificateDisplay];
}

- (void) actionClicked:(id)sender {
    NSString *cancel = NSLocalizedString(@"Cancel", nil);
    NSString *delete = NSLocalizedString(@"Delete", nil);
    NSString *export = NSLocalizedString(@"Export to iTunes", @"iTunes export button text for certificate chain action sheet");

    UIAlertController *sheetCtrl = [UIAlertController alertControllerWithTitle:nil
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
    sheetCtrl.popoverPresentationController.sourceView = self.view;
    sheetCtrl.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
    sheetCtrl.popoverPresentationController.permittedArrowDirections = 0;
    [sheetCtrl addAction: [UIAlertAction actionWithTitle:cancel
                                                   style:UIAlertActionStyleCancel
                                                 handler:nil]];

    [sheetCtrl addAction: [UIAlertAction actionWithTitle:delete
                                                   style:UIAlertActionStyleDestructive
                                                 handler:^(UIAlertAction * _Nonnull action) {
        NSString *title = NSLocalizedString(@"Delete Certificate Chain", @"Certificate deletion warning title");
        NSString *msg = NSLocalizedString(@"Are you sure you want to delete this certificate chain?\n\n"
                                          @"If you don't have a backup, this will permanently remove any rights associated with the certificate chain on any Mumble servers.",
                                          @"Certificate deletion warning message");
        NSString *cancel = NSLocalizedString(@"Cancel", nil);
        NSString *delete = NSLocalizedString(@"Delete", nil);

        UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                                           message:msg
                                                                    preferredStyle:UIAlertControllerStyleAlert];
        [alertCtrl addAction: [UIAlertAction actionWithTitle:cancel
                                                       style:UIAlertActionStyleCancel
                                                     handler:nil]];

        [alertCtrl addAction: [UIAlertAction actionWithTitle:delete
                                                       style:UIAlertActionStyleDestructive
                                                     handler:^(UIAlertAction * _Nonnull action) {
                [MUCertificateController deleteCertificateWithPersistentRef:self->_persistentRef];
                [self.navigationController popViewControllerAnimated:YES];
        }]];

        [self presentViewController:alertCtrl animated:YES completion:nil];

    }]];

    [sheetCtrl addAction: [UIAlertAction actionWithTitle:export
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * _Nonnull action) {
        NSString *title = NSLocalizedString(@"Export Certificate Chain", @"Title for certificate export alert view (with username and password field)");
        NSString *cancel = NSLocalizedString(@"Cancel", nil);
        NSString *export = NSLocalizedString(@"Export", nil);
        NSString *filename = NSLocalizedString(@"Filename", @"Filename text field in certificate export alert view");
        NSString *password = NSLocalizedString(@"Password (for importing)", @"Password text field in certificate export alert view");

        UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                                           message:nil
                                                                    preferredStyle:UIAlertControllerStyleAlert];
        [alertCtrl addAction: [UIAlertAction actionWithTitle:cancel
                                                       style:UIAlertActionStyleCancel
                                                     handler:nil]];

        __weak UIAlertController *weakAlert = alertCtrl;
        [alertCtrl addAction: [UIAlertAction actionWithTitle:export
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * _Nonnull action) {
            NSString *exportFailedTitle = NSLocalizedString(@"Export Failed", @"Title for UIAlertController when a certificate export fails");
            NSString *cancelButtonText = NSLocalizedString(@"OK", @"Default Cancel button text for UIAlertControllers that are shown when certificate export fails.");

            NSString *password = weakAlert.textFields[1].text;
            NSData *data = [MLCertificate exportCertificateChainAsPKCS12:self->_certificates withPassword:password];
            if (data == nil) {
                NSString *unknownExportErrorMsg = NSLocalizedString(@"Mumble was unable to export the certificate.",
                                                                    @"Error message shown for a failed export, cause unknown.");

                UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:exportFailedTitle
                                                                                   message:unknownExportErrorMsg
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                [alertCtrl addAction: [UIAlertAction actionWithTitle:cancelButtonText
                                                               style:UIAlertActionStyleCancel
                                                             handler:nil]];

                [self presentViewController:alertCtrl animated:YES completion:nil];

                return;
            }

            NSString *fileName = [weakAlert.textFields.firstObject.text lastPathComponent];
            if (!fileName.length) fileName = @"Certificate.pkcs12";
            if ([[fileName pathExtension] isEqualToString:@""]) {
                fileName = [fileName stringByAppendingPathExtension:@"pkcs12"];
            }

            NSURL *folder = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES] URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
            [NSFileManager.defaultManager createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:nil];
            NSString *pkcs12File = [[folder URLByAppendingPathComponent:fileName] path];
            NSError *err = nil;
            if (![data writeToFile:pkcs12File options:NSDataWritingAtomic error:&err]) {
                UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:exportFailedTitle
                                                                                   message:[err localizedDescription]
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                [alertCtrl addAction: [UIAlertAction actionWithTitle:cancelButtonText
                                                               style:UIAlertActionStyleCancel
                                                             handler:nil]];

                [self presentViewController:alertCtrl animated:YES completion:nil];

                return;
            }
            self->_exportDirectoryURL = folder;
            UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForExportingURLs:@[[NSURL fileURLWithPath:pkcs12File]] asCopy:YES];
            picker.delegate = self;
            void (^presentPicker)(void) = ^{ [self presentViewController:picker animated:YES completion:nil]; };
            if (self.presentedViewController) [self dismissViewControllerAnimated:YES completion:presentPicker];
            else presentPicker();

        }]];

        [alertCtrl addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            [textField setPlaceholder:filename];
        }];

        [alertCtrl addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            [textField setSecureTextEntry:YES];
            [textField setPlaceholder:password];
        }];

        [self presentViewController:alertCtrl animated:YES completion:nil];

    }]];

    [self presentViewController:sheetCtrl animated:YES completion:nil];

}

- (void)clearTemporaryExport {
    if (_exportDirectoryURL) [NSFileManager.defaultManager removeItemAtURL:_exportDirectoryURL error:nil];
    _exportDirectoryURL = nil;
}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller { [self clearTemporaryExport]; }
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls { [self clearTemporaryExport]; }

@end

