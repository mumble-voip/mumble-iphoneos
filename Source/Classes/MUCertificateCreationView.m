#import "MUInterface.h"
// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUCertificateCreationView.h"
#import "MUCertificateCreationProgressView.h"
#import "MUCertificateController.h"
#import "MUImage.h"

#import "MLClient.h"

static void ShowAlertDialog(UIViewController *presenter, NSString *title, NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *ok = NSLocalizedString(@"OK", nil);
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:ok style:UIAlertActionStyleCancel handler:nil]];
        [presenter presentViewController:alert animated:YES completion:nil];
    });
}

@interface MUCertificateCreationView () {
    NSString         *_fullName;
    NSString         *_emailAddress;
    UITableViewCell  *_nameCell;
    UITextField      *_nameField;
    UITableViewCell  *_emailCell;
    UITextField      *_emailField;
    UITableViewCell  *_activeCell;
}
@end

@implementation MUCertificateCreationView

#pragma mark -
#pragma mark Initialization

 + (void)configureTableViewConstraintWithCell:(UITableViewCell *)cell andTextField:(UITextField *)field {
    MUConfigureFormCell(cell, cell.textLabel.text, field);
}

- (id) init {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        self.preferredContentSize = CGSizeMake(320, 480);

        NSString *name = NSLocalizedString(@"Name", nil);
        NSString *defaultName = NSLocalizedString(@"Mumble User", nil);
        NSString *email = NSLocalizedString(@"Email", nil);
        NSString *optional = NSLocalizedString(@"Optional", nil);

        CGRect textFieldRect = CGRectMake(110.0, 10.0, 185.0, 30.0);

        _nameCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"MUFavouriteServerDescription"];
        MUConfigureStandardCell(_nameCell);
        [_nameCell setSelectionStyle:UITableViewCellSelectionStyleNone];
        [[_nameCell textLabel] setText:name];
        _nameField = [[UITextField alloc] initWithFrame:textFieldRect];
        [_nameField setTextColor:[UIColor labelColor]];
        [_nameField addTarget:self action:@selector(textFieldBeganEditing:) forControlEvents:UIControlEventEditingDidBegin];
        [_nameField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        [_nameField addTarget:self action:@selector(textFieldDidEndOnExit:) forControlEvents:UIControlEventEditingDidEndOnExit];
        [_nameField setReturnKeyType:UIReturnKeyNext];
        [_nameField setAdjustsFontSizeToFitWidth:NO];
        [_nameField setTextAlignment:NSTextAlignmentLeft];
        [_nameField setPlaceholder:defaultName];
        [_nameField setAutocapitalizationType:UITextAutocapitalizationTypeWords];
        [_nameField setText:_fullName];
        [_nameField setClearButtonMode:UITextFieldViewModeWhileEditing];
        [[_nameCell contentView] addSubview:_nameField];

        [MUCertificateCreationView configureTableViewConstraintWithCell:_nameCell andTextField:_nameField];

        _emailCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"MUFavouriteServerDescription"];
        MUConfigureStandardCell(_emailCell);
        [_emailCell setSelectionStyle:UITableViewCellSelectionStyleNone];
        [[_emailCell textLabel] setText:email];
        _emailField = [[UITextField alloc] initWithFrame:textFieldRect];
        [_emailField setTextColor:[UIColor labelColor]];
        [_emailField addTarget:self action:@selector(textFieldBeganEditing:) forControlEvents:UIControlEventEditingDidBegin];
        [_emailField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        [_emailField addTarget:self action:@selector(textFieldDidEndOnExit:) forControlEvents:UIControlEventEditingDidEndOnExit];
        [_emailField setReturnKeyType:UIReturnKeyDefault];
        [_emailField setAdjustsFontSizeToFitWidth:NO];
        [_emailField setTextAlignment:NSTextAlignmentLeft];
        [_emailField setPlaceholder:optional];
        [_emailField setAutocapitalizationType:UITextAutocapitalizationTypeNone];
        _emailField.textContentType = UITextContentTypeEmailAddress;
        [_emailField setKeyboardType:UIKeyboardTypeEmailAddress];
        [_emailField setText:_emailAddress];
        [_emailField setClearButtonMode:UITextFieldViewModeWhileEditing];
        [[_emailCell contentView] addSubview:_emailField];

        [MUCertificateCreationView configureTableViewConstraintWithCell:_emailCell andTextField:_emailField];
    }
    return self;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    MUConfigureTable(self.tableView);
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    NSString *newCert = NSLocalizedString(@"New Certificate",
                                          @"Title of MUCertificateCreationView (shown when creating a self-signed certificate)");
    [self setTitle:newCert];

    self.tableView.backgroundView = nil;

    {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    }

    NSString *create = NSLocalizedString(@"Create", @"'Create' text for certificate creation");
    NSString *cancel = NSLocalizedString(@"Cancel", nil);

    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:cancel style:UIBarButtonItemStylePlain target:self action:@selector(cancelClicked:)];
    [[self navigationItem] setLeftBarButtonItem:cancelButton];

    UIBarButtonItem *createButton = [[UIBarButtonItem alloc] initWithTitle:create style:UIBarButtonItemStyleDone target:self action:@selector(createClicked:)];
    [[self navigationItem] setRightBarButtonItem:createButton];

}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
    NSParameterAssert(indexPath.row<2);
    return indexPath.row==0 ? _nameCell : _emailCell;
}

#pragma mark -
#pragma mark Text field handling

- (void) textFieldBeganEditing:(UITextField *)sender {
    if (sender == _nameField) {
        _activeCell = _nameCell;
    } else if (sender == _emailField) {
        _activeCell = _emailCell;
    }
}

- (void) textFieldDidChange:(UITextField *)sender {
    if (sender == _nameField) {

        _fullName = [[sender text] copy];
    } else if (sender == _emailField) {

        _emailAddress = [[sender text] copy];
    }
}

- (void) textFieldDidEndOnExit:(UITextField *)sender {
    if (sender == _nameField) {
        [_emailField becomeFirstResponder];
        _activeCell = _emailCell;
    } else if (sender == _emailField) {
        [_emailField resignFirstResponder];
        _activeCell = nil;
    }
    if (_activeCell) {
        [self.tableView scrollToRowAtIndexPath:[self.tableView indexPathForCell:_activeCell]
                              atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }
}

#pragma mark -
#pragma mark Target/actions

- (void) cancelClicked:(id)sender {
    [[self navigationController] dismissViewControllerAnimated:YES completion:nil];
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

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        OSStatus err = noErr;
        BOOL saved = NO;
        NSString *failureTitle = nil, *failureMessage = nil;

        // Generate a certificate for this identity.
        MLCertificate *cert = [MLCertificate selfSignedCertificateWithName:name email:email];
        // A transient nonempty password avoids Security.framework's empty-password
        // PKCS#12 compatibility issue. It is used only for this in-memory transfer.
        NSString *transferPassword = [[NSUUID UUID] UUIDString];
        NSData *pkcs12 = [cert exportPKCS12WithPassword:transferPassword];
        if (pkcs12 == nil) {
            NSString *title = NSLocalizedString(@"Unable to generate certificate", @"Certificate generation error title");
            NSString *msg = NSLocalizedString(@"Mumble was unable to generate a certificate for your identity.",
                                              @"Certificate generation error body text");
            failureTitle = title;
            failureMessage = msg;
        } else {
            NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:transferPassword, (__bridge id)kSecImportExportPassphrase, nil];
            CFArrayRef importedItems = NULL;
            err = SecPKCS12Import((__bridge CFDataRef)pkcs12, (__bridge CFDictionaryRef)dict, &importedItems);
            NSArray *items = CFBridgingRelease(importedItems);
            if (err == errSecSuccess && [items count] > 0) {
                NSDictionary *pkcsDict = [items objectAtIndex:0];
                // Get the SecIdentityRef
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
                    saved = YES;

                // This happens when a certificate with a duplicate subject name is added.
                } else if (err == errSecDuplicateItem || (err == noErr && data == nil)) {
                    NSString *title = NSLocalizedString(@"Unable to add identity",
                                                        @"Error title shown when adding a certificate fails because of a subject name clash.");
                    NSString *msg = NSLocalizedString(@"A certificate with the same name already exist.",
                                                      @"Error body when adding a certificate fails because of a subject name clash.");
                    failureTitle = title;
                    failureMessage = msg;
                } else {
                    failureTitle = NSLocalizedString(@"Unable to add identity", nil);
                    failureMessage = CFBridgingRelease(SecCopyErrorMessageString(err, NULL)) ?: NSLocalizedString(@"Mumble was unable to save the certificate.", nil);
                }

            } else {
                NSString *title = NSLocalizedString(@"Import Error", nil);
                NSString *msg = NSLocalizedString(@"Mumble was unable to import the generated certificate.",
                                                  @"Generic certificate import error message body.");
                failureTitle = title;
                failureMessage = msg;
            }

        }

        dispatch_async(dispatch_get_main_queue(), ^{
            // Storage changes still reach the list if the sheet was dismissed
            // while the background task was finishing.
            if (saved) [MUCertificateController notifyCertificatesChanged];
            void (^finishUI)(void) = ^{
                if (saved) {
                    [[self navigationController] dismissViewControllerAnimated:YES completion:nil];
                } else if (self.navigationController.presentingViewController) {
                    // Keep the form available for correction/retry.
                    [[self navigationController] popToViewController:self animated:NO];
                    ShowAlertDialog(self, failureTitle ?: NSLocalizedString(@"Import Error", nil), failureMessage ?: NSLocalizedString(@"Mumble was unable to save the certificate.", nil));
                }
            };
            id<UIViewControllerTransitionCoordinator> transition = self.navigationController.transitionCoordinator;
            if (transition) {
                [transition animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
                    dispatch_async(dispatch_get_main_queue(), finishUI);
                }];
            } else {
                finishUI();
            }
        });
    });
}

@end

