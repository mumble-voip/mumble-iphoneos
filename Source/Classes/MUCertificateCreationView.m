// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUCertificateCreationView.h"
#import "MUCertificateCreationProgressView.h"
#import "MUCertificateController.h"
#import "MUColor.h"
#import "MUImage.h"
#import "MUOperatingSystem.h"
#import "MUBackgroundView.h"

#import <MumbleKit/MKCertificate.h>

static void ShowAlertDialog(NSString *title, NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *ok = NSLocalizedString(@"OK", nil);
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:msg delegate:nil cancelButtonTitle:ok otherButtonTitles:nil];
        [alert show];
        [alert release];
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
    UITextField      *_activeTextField;
}
@end

@implementation MUCertificateCreationView

#pragma mark -
#pragma mark Initialization

- (id) init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        [self setContentSizeForViewInPopover:CGSizeMake(320, 480)];
        
        NSString *name = NSLocalizedString(@"Name", nil);
        NSString *defaultName = NSLocalizedString(@"Mumble User", nil);
        NSString *email = NSLocalizedString(@"Email", nil);
        NSString *optional = NSLocalizedString(@"Optional", nil);
        
        _nameCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"MUFavouriteServerDescription"];
        [_nameCell setSelectionStyle:UITableViewCellSelectionStyleNone];
        [[_nameCell textLabel] setText:name];
        _nameField = [[UITextField alloc] initWithFrame:CGRectMake(110.0, 10.0, 185.0, 30.0)];
        [_nameField setTextColor:[MUColor selectedTextColor]];
        [_nameField addTarget:self action:@selector(textFieldBeganEditing:) forControlEvents:UIControlEventEditingDidBegin];
        [_nameField addTarget:self action:@selector(textFieldEndedEditing:) forControlEvents:UIControlEventEditingDidEnd];
        [_nameField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        [_nameField addTarget:self action:@selector(textFieldDidEndOnExit:) forControlEvents:UIControlEventEditingDidEndOnExit];
        [_nameField setReturnKeyType:UIReturnKeyNext];
        [_nameField setAdjustsFontSizeToFitWidth:NO];
        [_nameField setTextAlignment:UITextAlignmentLeft];
        [_nameField setPlaceholder:defaultName];
        [_nameField setAutocapitalizationType:UITextAutocapitalizationTypeWords];
        [_nameField setText:_fullName];
        [_nameField setClearButtonMode:UITextFieldViewModeWhileEditing];
        [[_nameCell contentView] addSubview:_nameField];

        _emailCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"MUFavouriteServerDescription"];
        [_emailCell setSelectionStyle:UITableViewCellSelectionStyleNone];
        [[_emailCell textLabel] setText:email];
        _emailField = [[UITextField alloc] initWithFrame:CGRectMake(110.0, 10.0, 185.0, 30.0)];
        [_emailField setTextColor:[MUColor selectedTextColor]];
        [_emailField addTarget:self action:@selector(textFieldBeganEditing:) forControlEvents:UIControlEventEditingDidBegin];
        [_emailField addTarget:self action:@selector(textFieldEndedEditing:) forControlEvents:UIControlEventEditingDidEnd];
        [_emailField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        [_emailField addTarget:self action:@selector(textFieldDidEndOnExit:) forControlEvents:UIControlEventEditingDidEndOnExit];
        [_emailField setReturnKeyType:UIReturnKeyDefault];
        [_emailField setAdjustsFontSizeToFitWidth:NO];
        [_emailField setTextAlignment:UITextAlignmentLeft];
        [_emailField setPlaceholder:optional];
        [_emailField setAutocapitalizationType:UITextAutocapitalizationTypeWords];
        [_emailField setKeyboardType:UIKeyboardTypeEmailAddress];
        [_emailField setText:_fullName];
        [_emailField setClearButtonMode:UITextFieldViewModeWhileEditing];
        [[_emailCell contentView] addSubview:_emailField];
    }
    return self;
}

- (void) dealloc {
    [super dealloc];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    NSString *newCert = NSLocalizedString(@"New Certificate",
                                          @"Title of MUCertificateCreationView (shown when creating a self-signed certificate)");
    [self setTitle:newCert];
    
    UINavigationBar *navBar = self.navigationController.navigationBar;
    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        navBar.tintColor = [UIColor whiteColor];
        navBar.translucent = NO;
        navBar.backgroundColor = [UIColor blackColor];
    }
    navBar.barStyle = UIBarStyleBlackOpaque;
    
    self.tableView.backgroundView = [MUBackgroundView backgroundView];
    
    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        self.tableView.separatorInset = UIEdgeInsetsZero;
    } else {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    }
    
    NSString *create = NSLocalizedString(@"Create", @"'Create' text for certificate creation");
    NSString *cancel = NSLocalizedString(@"Cancel", nil);

    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:cancel style:UIBarButtonItemStylePlain target:self action:@selector(cancelClicked:)];
    [[self navigationItem] setLeftBarButtonItem:cancelButton];
    [cancelButton release];

    UIBarButtonItem *createButton = [[UIBarButtonItem alloc] initWithTitle:create style:UIBarButtonItemStyleDone target:self action:@selector(createClicked:)];
    [[self navigationItem] setRightBarButtonItem:createButton];
    [createButton release];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
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
    NSUInteger row = [indexPath row];
    if (row == 0) { // Full name
        return _nameCell;
    } else if (row == 1) { // Email
        return _emailCell;
    }
    return nil;
}

#pragma mark -
#pragma mark Text field handling

- (void) textFieldBeganEditing:(UITextField *)sender {
    _activeTextField = sender;
    if (sender == _nameField) {
        _activeCell = _nameCell;
    } else if (sender == _emailField) {
        _activeCell = _emailCell;
    }
}

- (void) textFieldEndedEditing:(UITextField *)sender {
    _activeTextField = nil;
}

- (void) textFieldDidChange:(UITextField *)sender {
    if (sender == _nameField) {
        [_fullName release];
        _fullName = [[sender text] copy];
    } else if (sender == _emailField) {
        [_emailAddress release];
        _emailAddress = [[sender text] copy];
    }
}

- (void) textFieldDidEndOnExit:(UITextField *)sender {
    if (sender == _nameField) {
        [_emailField becomeFirstResponder];
        _activeTextField = _emailField;
        _activeCell = _emailCell;
    } else if (sender == _emailField) {
        [_emailField resignFirstResponder];
        _activeTextField = nil;
        _activeCell = nil;
    }
    if (_activeCell) {
        [self.tableView scrollToRowAtIndexPath:[self.tableView indexPathForCell:_activeCell]
                              atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }
}

- (void) keyboardWasShown:(NSNotification*)aNotification {
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    [UIView animateWithDuration:0.2f animations:^{
        UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height, 0.0);
        self.tableView.contentInset = contentInsets;
        self.tableView.scrollIndicatorInsets = contentInsets;
    } completion:^(BOOL finished) {
        if (!finished)
            return;
        [self.tableView scrollToRowAtIndexPath:[self.tableView indexPathForCell:_activeCell]
                              atScrollPosition:UITableViewScrollPositionBottom animated:YES];
        
    }];
}

- (void) keyboardWillBeHidden:(NSNotification*)aNotification {
    [UIView animateWithDuration:0.2f animations:^{
        UIEdgeInsets contentInsets = UIEdgeInsetsZero;
        self.tableView.contentInset = contentInsets;
        self.tableView.scrollIndicatorInsets = contentInsets;
    } completion:^(BOOL finished) {
        // ...
    }];
}


#pragma mark -
#pragma mark Target/actions

- (void) cancelClicked:(id)sender {
    [[self navigationController] dismissModalViewControllerAnimated:YES];
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
    [progress release];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        OSStatus err = noErr;
        
        // Generate a certificate for this identity.
        MKCertificate *cert = [MKCertificate selfSignedCertificateWithName:name email:email];
        NSData *pkcs12 = [cert exportPKCS12WithPassword:@""];
        if (pkcs12 == nil) {
            NSString *title = NSLocalizedString(@"Unable to generate certificate", @"Certificate generation error title");
            NSString *msg = NSLocalizedString(@"Mumble was unable to generate a certificate for your identity.", 
                                              @"Certificate generation error body text");
            ShowAlertDialog(title, msg);
        } else {
            NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"", kSecImportExportPassphrase, nil];
            NSArray *items = nil;
            err = SecPKCS12Import((CFDataRef)pkcs12, (CFDictionaryRef)dict, (CFArrayRef *)&items);
            if (err == errSecSuccess && [items count] > 0) {
                NSDictionary *pkcsDict = [items objectAtIndex:0];
                // Get the SecIdentityRef
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

                // This happens when a certificate with a duplicate subject name is added.
                } else if (err == noErr && data == nil) {
                    NSString *title = NSLocalizedString(@"Unable to add identity",
                                                        @"Error title shown when adding a certificate fails because of a subject name clash.");
                    NSString *msg = NSLocalizedString(@"A certificate with the same name already exist.",
                                                      @"Error body when adding a certificate fails because of a subject name clash.");
                    ShowAlertDialog(title, msg);
                }
            } else {
                NSString *title = NSLocalizedString(@"Import Error", nil);
                NSString *msg = NSLocalizedString(@"Mumble was unable to import the generated certificate.",
                                                  @"Generic certificate import error message body.");
                ShowAlertDialog(title, msg);
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[self navigationController] dismissModalViewControllerAnimated:YES];
        });
    });    
}

@end

