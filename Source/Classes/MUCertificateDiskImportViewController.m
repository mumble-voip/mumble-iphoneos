// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUCertificateDiskImportViewController.h"
#import "MUTableViewHeaderLabel.h"
#import "MUCertificateController.h"
#import "MUCertificateCell.h"
#import "MUImage.h"
#import "MUOperatingSystem.h"
#import "MUBackgroundView.h"

static void ShowAlertDialog(NSString *title, NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        [alert release];
    });
}

@interface MUCertificateDiskImportViewController () <UIActionSheetDelegate> {
    BOOL             _showHelp;
    NSMutableArray   *_diskCertificates;
    NSIndexPath      *_attemptIndexPath;
    UITextField      *_passwordField;
}
- (void) tryImportCertificateWithPassword:(NSString *)password;
- (void) showPasswordDialog;
- (void) removeAllDiskCertificates;
- (void) showRemoveAlert;
@end

@implementation MUCertificateDiskImportViewController

- (id) init {
    self.contentSizeForViewInPopover = CGSizeMake(320, 480);
    
    UITableViewStyle style = UITableViewStyleGrouped;
    NSArray *documentDirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSError *err = nil;
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[documentDirs objectAtIndex:0] error:&err];
    NSMutableArray *diskCerts = nil;

    if ([documentDirs count] > 0) {
        diskCerts = [[[NSMutableArray alloc] init] autorelease];
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
        if (style == UITableViewStyleGrouped)
            _showHelp = YES;
        _diskCertificates = [diskCerts retain];
    }

    return self;
}

- (void) dealloc {
    [_diskCertificates release];
    [_attemptIndexPath release];
    [super dealloc];
}

#pragma mark - View lifecycle

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    UINavigationBar *navBar = self.navigationController.navigationBar;
    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        navBar.tintColor = [UIColor whiteColor];
        navBar.translucent = NO;
        navBar.backgroundColor = [UIColor blackColor];
    }
    navBar.barStyle = UIBarStyleBlackOpaque;

    if (self.tableView.style == UITableViewStyleGrouped) {
        self.tableView.backgroundView = [MUBackgroundView backgroundView];
    } else {
        if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
            self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
            self.tableView.separatorInset = UIEdgeInsetsZero;
        }
    }

    NSString *iTunesImport = NSLocalizedString(@"iTunes Import", @"Import a certificate from iTunes action sheet button.");
    [[self navigationItem] setTitle:iTunesImport];

    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneClicked:)];
    [[self navigationItem] setLeftBarButtonItem:doneButton];
    [doneButton release];

    if (!_showHelp) {
        UIBarButtonItem *actionButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(actionClicked:)];
        [[self navigationItem] setRightBarButtonItem:actionButton];
        [actionButton release];
    }
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
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }

    [[cell imageView] setImage:[UIImage imageNamed:@"certificatecell"]];
    [[cell textLabel] setText:[_diskCertificates objectAtIndex:[indexPath row]]];
    [cell setAccessoryType:UITableViewCellAccessoryNone];
    [cell setSelectionStyle:UITableViewCellSelectionStyleGray];

    return cell;
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 85.0f;
}

#pragma mark - Table view delegate

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [_attemptIndexPath release];
    _attemptIndexPath = [indexPath retain];

    [self tryImportCertificateWithPassword:nil];
}

- (UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (_showHelp) {
        NSString *help = NSLocalizedString(@"To import your own certificate into\n"
                                           @"Mumble, please transfer them to your\n"
                                           @"device using iTunes File Transfer.",
                                           @"Help text for iTunes File Transfer (iTunes Import)");
        MUTableViewHeaderLabel *lbl = [MUTableViewHeaderLabel labelWithText:help];
        lbl.font = [UIFont systemFontOfSize:16.0f];
        lbl.lineBreakMode = UILineBreakModeWordWrap;
        lbl.numberOfLines = 0;
        return lbl;
    }
    return nil;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (_showHelp) {
        return 80.0f;
    }
    return 0.0f;
}

#pragma mark - Import logic

- (void) tryImportCertificateWithPassword:(NSString *)password {
    NSString *fileName = [_diskCertificates objectAtIndex:[_attemptIndexPath row]];
    NSArray *documentDirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *pkcs12File = [[documentDirs objectAtIndex:0] stringByAppendingFormat:@"/%@", fileName];
    NSData *pkcs12Data = [NSData dataWithContentsOfFile:pkcs12File];

    NSArray *chain = [MKCertificate certificatesWithPKCS12:pkcs12Data password:password];
    if ([chain count] == 0) {
        [self showPasswordDialog];
        [[self tableView] deselectRowAtIndexPath:_attemptIndexPath animated:YES];
        return;
    }
    
    MKCertificate *leaf = [chain objectAtIndex:0];
    NSData *transformedPkcs12Data = [leaf exportPKCS12WithPassword:@""];
    if (transformedPkcs12Data == nil) {
        ShowAlertDialog(NSLocalizedString(@"Import Error", nil),
                        NSLocalizedString(@"Mumble was unable to export the specified certificate.",
                                          @"Error shown when when the conversion from PKCS12 to DER-encoded X.509 fails."));
        [[self tableView] deselectRowAtIndexPath:_attemptIndexPath animated:YES];
        return;
    }
    
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"", kSecImportExportPassphrase, nil];
    NSArray *items = nil;
    OSStatus err = SecPKCS12Import((CFDataRef)transformedPkcs12Data, (CFDictionaryRef)dict, (CFArrayRef *)&items);

    if (err == errSecSuccess && [items count] > 0) {
        // Add all elements except the leaf certificate to the keychain
        for (int i = 1; i < [chain count]; i++) {
            MKCertificate *cert = [chain objectAtIndex:i];
            SecCertificateRef secCert = SecCertificateCreateWithData(NULL, (CFDataRef)[cert certificate]);
            if (secCert == NULL) {
                ShowAlertDialog(NSLocalizedString(@"Import Error", nil),
                                NSLocalizedString(@"Mumble was unable to import one of the intermediate certificates in the certificate chain.", nil));
                continue;
            }

            NSDictionary *op = [NSDictionary dictionaryWithObjectsAndKeys:
                                (id)secCert, kSecValueRef, nil];
            err = SecItemAdd((CFDictionaryRef)op, NULL);
            if (err != noErr) {
                if (err == errSecDuplicateItem) {
                    // Duplicates are OK in this case.
                } else {
                    ShowAlertDialog(NSLocalizedString(@"Import Error", nil),
                                    NSLocalizedString(@"Mumble was unable to import one of the intermediate certificates in the certificate chain.", nil));
                }
            }
            
            CFRelease(secCert);
        }
        
        // Get the SecIdentityRef, and add it to the keychain
        NSDictionary *pkcsDict = [items objectAtIndex:0];
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
            
            // Remove the file from disk
            NSError *errObj = nil;
            if ([[NSFileManager defaultManager] removeItemAtPath:pkcs12File error:&errObj] == NO) {
                ShowAlertDialog(NSLocalizedString(@"Import Error", nil), [errObj localizedFailureReason]);
            }

            [[self tableView] deselectRowAtIndexPath:_attemptIndexPath animated:YES];
            [_diskCertificates removeObjectAtIndex:[_attemptIndexPath row]];
            [[self tableView] deleteRowsAtIndexPaths:[NSArray arrayWithObject:_attemptIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            return;
        } else if (err == errSecDuplicateItem || (err == noErr && data == nil)) {
            ShowAlertDialog(NSLocalizedString(@"Import Error", nil),
                            // todo(mkrautz): Keep in sync with MUCertificateCreationView: refactor!
                            NSLocalizedString(@"A certificate with the same name already exist.",
                                              @"Error body when adding a certificate fails because of a subject name clash."));
        } else {
            NSString *msg = [NSString stringWithFormat:
                                NSLocalizedString(@"Mumble was unable to import the certificate.\nError Code: %li",
                                                  @"Generic import error (with error code) for iTunes Import."), (long int)err];
            ShowAlertDialog(@"Import Error", msg);
        }

        [[self tableView] deselectRowAtIndexPath:_attemptIndexPath animated:YES];

    } else if (err == errSecAuthFailed) {
        [self showPasswordDialog];
        [[self tableView] deselectRowAtIndexPath:_attemptIndexPath animated:YES];
    } else if (err == errSecDecode) {
        ShowAlertDialog(NSLocalizedString(@"Import Error", nil), @"Unable to decode PKCS12 file");
        [[self tableView] deselectRowAtIndexPath:_attemptIndexPath animated:YES];
    } else {
        NSString *msg = NSLocalizedString(@"Mumble was unable to import the certificate.",
                                          @"Generic import error for iTunes Import.");
        ShowAlertDialog(NSLocalizedString(@"Import Error", nil), msg);
        [[self tableView] deselectRowAtIndexPath:_attemptIndexPath animated:YES];
    }
}

- (void) showPasswordDialog {
    UIAlertView *dialog = [[UIAlertView alloc] init];
    [dialog setDelegate:self];
    
    NSString *title = NSLocalizedString(@"Enter Password", @"Title for certificate import password unlock UIAlertView.");
    NSString *msg = NSLocalizedString(@"The certificate is protected by a password. Please enter it below:",
                                      @"Body text for certificate import password unlock UIAlertView.");
    [dialog setTitle:title];
    [dialog setMessage:msg];
    [dialog addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
    [dialog addButtonWithTitle:NSLocalizedString(@"OK", nil)];
    [dialog setAlertViewStyle:UIAlertViewStyleSecureTextInput];
    [dialog show];
    [dialog release];
}

- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    // Password view
    if (alertView.alertViewStyle == UIAlertViewStyleSecureTextInput) {
        if (buttonIndex == 1) { // OK
            [self tryImportCertificateWithPassword:[[alertView textFieldAtIndex:0] text]];
        }
        _passwordField = nil;
    }
    // Delete all view
    if (alertView.alertViewStyle == UIAlertViewStyleDefault) {
        if (buttonIndex == 1) { // Remove 'Em
            [self removeAllDiskCertificates];
        }
    }
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
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title
                                                                message:msg
                                                               delegate:nil
                                                      cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                      otherButtonTitles:nil];
            [alertView show];
            [alertView release];
        } else {
            [_diskCertificates removeObjectIdenticalTo:fn];
        }
    }
    [self.tableView reloadData];
    [diskCerts release];
}

#pragma mark - Actions

- (void) doneClicked:(id)sender {
    [self dismissModalViewControllerAnimated:YES];
}

- (void) showRemoveAlert {
    NSString *title = NSLocalizedString(@"Remove Importable Certificates",
                                        @"Title for remove all importable certificates UIAlertView.");
    NSString *msg = NSLocalizedString(@"Are you sure you want to delete all importable certificates?\n\n"
                                      @"Certificates already imported into Mumble will not be touched.",
                                      @"Body for remove all importable certificates UIAlertView");
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title
                                                        message:msg
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"No", nil)
                                              otherButtonTitles:NSLocalizedString(@"Yes", nil), nil];
    [alertView show];
    [alertView release];
}

- (void) actionClicked:(id)sender {
    NSString *title = NSLocalizedString(@"Import Actions", @"Title for UIActionSheet for iTunes Import.");
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:title
                                                             delegate:self
                                                    cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                               destructiveButtonTitle:NSLocalizedString(@"Remove All",
                                                                                        @"Remove all importable certificates action.")
                                                    otherButtonTitles:nil];
    [actionSheet setActionSheetStyle:UIActionSheetStyleBlackOpaque];
    [actionSheet showFromBarButtonItem:sender animated:YES];
    [actionSheet release];
}

- (void) actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        [self showRemoveAlert];
    }
}

@end
