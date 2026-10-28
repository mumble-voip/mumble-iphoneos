#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "MUInterface.h"
// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUCertificateDiskImportViewController.h"
#import "MUCertificateController.h"
#import "MUCertificateCell.h"
#import "MUImage.h"

static void ShowAlertDialog(UIViewController *presenter, NSString *title, NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleCancel handler:nil]];
        [presenter presentViewController:alert animated:YES completion:nil];
    });
}

@interface MUCertificateDiskImportViewController () <UIDocumentPickerDelegate> {
    NSMutableArray   *_diskCertificates;
    NSIndexPath      *_attemptIndexPath;
}
- (void) tryImportCertificateWithPassword:(NSString *)password;
- (void) showPasswordDialog;
- (void) removeAllDiskCertificates;
- (void) showRemoveAlert;
@end

@implementation MUCertificateDiskImportViewController

- (id) init {
    UITableViewStyle style = UITableViewStyleInsetGrouped;
    NSArray *documentDirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSError *err = nil;
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentDirs.firstObject error:&err];
    NSMutableArray *diskCerts = [NSMutableArray array];

    if ([documentDirs count] > 0) {
        for (NSString *fileName in dirContents) {
            if ([fileName hasSuffix:@".pkcs12"])
                [diskCerts addObject:fileName];
            if ([fileName hasSuffix:@".p12"])
                [diskCerts addObject:fileName];
            if ([fileName hasSuffix:@".pfx"])
                [diskCerts addObject:fileName];
        }
    }
    if ([diskCerts count] > 0) {
        style = UITableViewStylePlain;
    }

    if ((self = [super initWithStyle:style])) {
        self.preferredContentSize = CGSizeMake(320, 480);
        _diskCertificates = diskCerts;
    }

    return self;
}

#pragma mark - View lifecycle

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    MUConfigureTable(self.tableView);
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    if (self.tableView.style == UITableViewStyleInsetGrouped) {
        self.tableView.backgroundView = nil;
    } else {
        {
            self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        }
    }

    NSString *iTunesImport = NSLocalizedString(@"Import Certificates", nil);
    [[self navigationItem] setTitle:iTunesImport];

    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneClicked:)];
    [[self navigationItem] setLeftBarButtonItem:doneButton];

    [self updateDocumentActions];
}

- (void)updateDocumentActions {
    UIBarButtonItem *add = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(importFromFiles:)];
    if (_diskCertificates.count) {
        UIBarButtonItem *actions = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(actionClicked:)];
        self.navigationItem.rightBarButtonItems = @[add, actions];

        self.contentUnavailableConfiguration = nil;
    } else {
        self.navigationItem.rightBarButtonItems = @[add];
        UIContentUnavailableConfiguration *empty = [UIContentUnavailableConfiguration emptyConfiguration];
        empty.image = [UIImage systemImageNamed:@"doc.badge.plus"];
        empty.text = NSLocalizedString(@"Import Certificates", nil);
        empty.secondaryText = NSLocalizedString(@"Choose a certificate file (.p12 or .pfx).", nil);
        __weak MUCertificateDiskImportViewController *controller = self;
        empty.buttonProperties.primaryAction = [UIAction actionWithTitle:NSLocalizedString(@"Choose File", nil) image:nil identifier:nil handler:^(UIAction *action) { [controller importFromFiles:nil]; }];
        self.contentUnavailableConfiguration = empty;
    }

}
- (void)importFromFiles:(id)sender {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypePKCS12] asCopy:YES];
    picker.delegate = self;
    picker.shouldShowFileExtensions = YES;
    [self presentViewController:picker animated:YES completion:nil];

}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *source = urls.firstObject;
    if (!source) return;
    BOOL scoped = [source startAccessingSecurityScopedResource];
    NSURL *folder = [NSURL fileURLWithPath:NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject isDirectory:YES];
    NSString *name = source.lastPathComponent;
    NSURL *destination = [folder URLByAppendingPathComponent:name];
    if ([NSFileManager.defaultManager fileExistsAtPath:destination.path]) {
        name = [NSString stringWithFormat:@"%@-%@", NSUUID.UUID.UUIDString, name];
        destination = [folder URLByAppendingPathComponent:name];
    }
    NSError *error = nil;
    BOOL copied = [NSFileManager.defaultManager copyItemAtURL:source toURL:destination error:&error];
    if (scoped) [source stopAccessingSecurityScopedResource];
    if (!copied) { ShowAlertDialog(self, NSLocalizedString(@"Import Failed", nil), error.localizedDescription); return; }
    [_diskCertificates addObject:name];
    [self updateDocumentActions];
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_diskCertificates count];
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"DiskCertificateCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        MUConfigureStandardCell(cell);
    }

    [[cell imageView] setImage:[MUImage symbolNamed:@"checkmark.seal" pointSize:24]];
    [[cell textLabel] setText:[_diskCertificates objectAtIndex:[indexPath row]]];
    [cell setAccessoryType:UITableViewCellAccessoryNone];
    [cell setSelectionStyle:UITableViewCellSelectionStyleDefault];

    return cell;
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

#pragma mark - Table view delegate

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    _attemptIndexPath = indexPath;

    [self tryImportCertificateWithPassword:nil];
}

#pragma mark - Import logic

- (void) tryImportCertificateWithPassword:(NSString *)password {
    NSString *fileName = [_diskCertificates objectAtIndex:[_attemptIndexPath row]];
    NSArray *documentDirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *pkcs12File = [[documentDirs objectAtIndex:0] stringByAppendingFormat:@"/%@", fileName];
    NSData *pkcs12Data = [NSData dataWithContentsOfFile:pkcs12File];

    NSArray *chain = [MLCertificate certificatesWithPKCS12:pkcs12Data password:password];
    if ([chain count] == 0) {
        [self showPasswordDialog];
        [[self tableView] deselectRowAtIndexPath:_attemptIndexPath animated:YES];
        return;
    }

    MLCertificate *leaf = [chain objectAtIndex:0];
    NSString *transferPassword = [[NSUUID UUID] UUIDString];
    NSData *transformedPkcs12Data = [leaf exportPKCS12WithPassword:transferPassword];
    if (transformedPkcs12Data == nil) {
        ShowAlertDialog(self, NSLocalizedString(@"Import Error", nil),
                        NSLocalizedString(@"Mumble was unable to export the specified certificate.",
                                          @"Error shown when when the conversion from PKCS12 to DER-encoded X.509 fails."));
        [[self tableView] deselectRowAtIndexPath:_attemptIndexPath animated:YES];
        return;
    }

    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:transferPassword, (__bridge id)kSecImportExportPassphrase, nil];
    CFArrayRef importedItems = NULL;
    OSStatus err = SecPKCS12Import((__bridge CFDataRef)transformedPkcs12Data, (__bridge CFDictionaryRef)dict, &importedItems);
    NSArray *items = CFBridgingRelease(importedItems);

    if (err == errSecSuccess && [items count] > 0) {
        // Add all elements except the leaf certificate to the keychain
        for (int i = 1; i < [chain count]; i++) {
            MLCertificate *cert = [chain objectAtIndex:i];
            SecCertificateRef secCert = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)[cert certificate]);
            if (secCert == NULL) {
                ShowAlertDialog(self, NSLocalizedString(@"Import Error", nil),
                                NSLocalizedString(@"Mumble was unable to import one of the intermediate certificates in the certificate chain.", nil));
                continue;
            }

            NSDictionary *op = [NSDictionary dictionaryWithObjectsAndKeys:
                                (__bridge id)secCert, (__bridge id)kSecValueRef, nil];
            err = SecItemAdd((__bridge CFDictionaryRef)op, NULL);
            if (err != noErr) {
                if (err == errSecDuplicateItem) {
                    // Duplicates are OK in this case.
                } else {
                    ShowAlertDialog(self, NSLocalizedString(@"Import Error", nil),
                                    NSLocalizedString(@"Mumble was unable to import one of the intermediate certificates in the certificate chain.", nil));
                }
            }

            CFRelease(secCert);
        }

        // Get the SecIdentityRef, and add it to the keychain
        NSDictionary *pkcsDict = [items objectAtIndex:0];
        id identity = [pkcsDict objectForKey:(__bridge id)kSecImportItemIdentity];
        NSDictionary *op = [NSDictionary dictionaryWithObjectsAndKeys:
                            identity, (__bridge id)kSecValueRef,
                            (__bridge id)kCFBooleanTrue, (__bridge id)kSecReturnPersistentRef, nil];
        CFTypeRef persistentResult = NULL;
        err = SecItemAdd((__bridge CFDictionaryRef)op, &persistentResult);
        NSData *data = CFBridgingRelease(persistentResult);
        if (err == noErr && data != nil) {
            // Success!
            // Now, check if there's already a default certificate set.
            if ([MUCertificateController defaultCertificate] == nil) {
                [MUCertificateController setDefaultCertificateByPersistentRef:data];
            }
            [MUCertificateController notifyCertificatesChanged];

            // Remove the file from disk
            NSError *errObj = nil;
            if ([[NSFileManager defaultManager] removeItemAtPath:pkcs12File error:&errObj] == NO) {
                ShowAlertDialog(self, NSLocalizedString(@"Import Error", nil), [errObj localizedFailureReason]);
            }

            [[self tableView] deselectRowAtIndexPath:_attemptIndexPath animated:YES];
            [_diskCertificates removeObjectAtIndex:[_attemptIndexPath row]];
            [[self tableView] deleteRowsAtIndexPaths:[NSArray arrayWithObject:_attemptIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            [self updateDocumentActions];
            return;
        } else if (err == errSecDuplicateItem || (err == noErr && data == nil)) {
            ShowAlertDialog(self, NSLocalizedString(@"Import Error", nil),
                            // todo(mkrautz): Keep in sync with MUCertificateCreationView: refactor!
                            NSLocalizedString(@"A certificate with the same name already exist.",
                                              @"Error body when adding a certificate fails because of a subject name clash."));
        } else {
            NSString *msg = [NSString stringWithFormat:
                                NSLocalizedString(@"Mumble was unable to import the certificate.\nError Code: %li",
                                                  @"Generic import error (with error code) for iTunes Import."), (long int)err];
            ShowAlertDialog(self, @"Import Error", msg);
        }

        [[self tableView] deselectRowAtIndexPath:_attemptIndexPath animated:YES];

    } else if (err == errSecAuthFailed) {
        [self showPasswordDialog];
        [[self tableView] deselectRowAtIndexPath:_attemptIndexPath animated:YES];
    } else if (err == errSecDecode) {
        ShowAlertDialog(self, NSLocalizedString(@"Import Error", nil), @"Unable to decode PKCS12 file");
        [[self tableView] deselectRowAtIndexPath:_attemptIndexPath animated:YES];
    } else {
        NSString *msg = NSLocalizedString(@"Mumble was unable to import the certificate.",
                                          @"Generic import error for iTunes Import.");
        ShowAlertDialog(self, NSLocalizedString(@"Import Error", nil), msg);
        [[self tableView] deselectRowAtIndexPath:_attemptIndexPath animated:YES];
    }
}

- (void) showPasswordDialog {
    NSString *title = NSLocalizedString(@"Enter Password", @"Title for certificate import password unlock UIAlertController.");
    NSString *msg = NSLocalizedString(@"The certificate is protected by a password. Please enter it below:",
                                      @"Body text for certificate import password unlock UIAlertController.");
    UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                                       message:msg
                                                                preferredStyle:UIAlertControllerStyleAlert];

    __weak UIAlertController *weakAlert = alertCtrl;
    [alertCtrl addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        [textField setSecureTextEntry:YES];
    }];

    [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                   style:UIAlertActionStyleCancel
                                                 handler:nil]];
    [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * _Nonnull action) {
        [self tryImportCertificateWithPassword:weakAlert.textFields.firstObject.text];
    }]];

    [self presentViewController:alertCtrl animated:YES completion:nil];

}

- (void) removeAllDiskCertificates {
    NSArray *documentDirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *directory = [documentDirs objectAtIndex:0];
    NSArray *diskCerts = [_diskCertificates copy];
    for (int i = 0; i < [diskCerts count]; i++) {
        NSError *err = nil;
        NSString *fn = [diskCerts objectAtIndex:i];
        [[NSFileManager defaultManager] removeItemAtPath:[directory stringByAppendingPathComponent:fn] error:&err];
        if (err != nil) {
            NSString *title = NSLocalizedString(@"Unable to remove file",
                                                @"Certificate import file removal error title.");
            NSString *msg = [NSString stringWithFormat:
                                NSLocalizedString(@"File '%@' could not be deleted: %@",
                                                  @"Certificate import file removal error body."),
                                    fn, [err localizedDescription]];

            UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                                               message:msg
                                                                        preferredStyle:UIAlertControllerStyleAlert];

            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil]];

            [self presentViewController:alertCtrl animated:YES completion:nil];

        } else {
            [_diskCertificates removeObjectIdenticalTo:fn];
        }
    }
    [self updateDocumentActions];
    [self.tableView reloadData];

}

#pragma mark - Actions

- (void) doneClicked:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void) showRemoveAlert {
    NSString *title = NSLocalizedString(@"Remove Importable Certificates",
                                        @"Title for remove all importable certificates UIAlertController.");
    NSString *msg = NSLocalizedString(@"Are you sure you want to delete all importable certificates?\n\n"
                                      @"Certificates already imported into Mumble will not be touched.",
                                      @"Body for remove all importable certificates UIAlertController");

    UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                                       message:msg
                                                                preferredStyle:UIAlertControllerStyleAlert];

    [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"No", nil)
                                                   style:UIAlertActionStyleCancel
                                                 handler:nil]];
    [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", nil)
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * _Nonnull action) {
        [self removeAllDiskCertificates];
    }]];

    [self presentViewController:alertCtrl animated:YES completion:nil];

}

- (void) actionClicked:(id)sender {
    NSString *title = NSLocalizedString(@"Import Actions", @"Title for action sheet for iTunes Import.");

    UIAlertController *sheetCtrl = [UIAlertController alertControllerWithTitle:title
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
    sheetCtrl.popoverPresentationController.sourceView = self.view;
    sheetCtrl.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
    sheetCtrl.popoverPresentationController.permittedArrowDirections = 0;

    [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                   style:UIAlertActionStyleCancel
                                                 handler:nil]];
    [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Remove All",
                                                                           @"Remove all importable certificates action.")
                                                   style:UIAlertActionStyleDestructive
                                                 handler:^(UIAlertAction * _Nonnull action) {
        [self showRemoveAlert];
    }]];

    [self presentViewController:sheetCtrl animated:YES completion:nil];

}

@end
