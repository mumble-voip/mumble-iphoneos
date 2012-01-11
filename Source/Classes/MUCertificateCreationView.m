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

#import "MUCertificateCreationView.h"
#import "MUCertificateCreationProgressView.h"
#import "MUCertificateController.h"
#import "MUColor.h"

#import <MumbleKit/MKCertificate.h>

static void ShowAlertDialog(NSString *title, NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
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
        
        _nameCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"MUFavouriteServerDescription"];
        [_nameCell setSelectionStyle:UITableViewCellSelectionStyleNone];
        [[_nameCell textLabel] setText:@"Name"];
        _nameField = [[UITextField alloc] initWithFrame:CGRectMake(110.0, 10.0, 185.0, 30.0)];
        [_nameField setTextColor:[MUColor selectedTextColor]];
        [_nameField addTarget:self action:@selector(textFieldBeganEditing:) forControlEvents:UIControlEventEditingDidBegin];
        [_nameField addTarget:self action:@selector(textFieldEndedEditing:) forControlEvents:UIControlEventEditingDidEnd];
        [_nameField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        [_nameField addTarget:self action:@selector(textFieldDidEndOnExit:) forControlEvents:UIControlEventEditingDidEndOnExit];
        [_nameField setReturnKeyType:UIReturnKeyNext];
        [_nameField setAdjustsFontSizeToFitWidth:NO];
        [_nameField setTextAlignment:UITextAlignmentLeft];
        [_nameField setPlaceholder:@"Mumble User"];
        [_nameField setAutocapitalizationType:UITextAutocapitalizationTypeWords];
        [_nameField setText:_fullName];
        [_nameField setClearButtonMode:UITextFieldViewModeWhileEditing];
        [[_nameCell contentView] addSubview:_nameField];

        _emailCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"MUFavouriteServerDescription"];
        [_emailCell setSelectionStyle:UITableViewCellSelectionStyleNone];
        [[_emailCell textLabel] setText:@"Email"];
        _emailField = [[UITextField alloc] initWithFrame:CGRectMake(110.0, 10.0, 185.0, 30.0)];
        [_emailField setTextColor:[MUColor selectedTextColor]];
        [_emailField addTarget:self action:@selector(textFieldBeganEditing:) forControlEvents:UIControlEventEditingDidBegin];
        [_emailField addTarget:self action:@selector(textFieldEndedEditing:) forControlEvents:UIControlEventEditingDidEnd];
        [_emailField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        [_emailField addTarget:self action:@selector(textFieldDidEndOnExit:) forControlEvents:UIControlEventEditingDidEndOnExit];
        [_emailField setReturnKeyType:UIReturnKeyDefault];
        [_emailField setAdjustsFontSizeToFitWidth:NO];
        [_emailField setTextAlignment:UITextAlignmentLeft];
        [_emailField setPlaceholder:@"(Optional)"];
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

    self.tableView.backgroundView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"BackgroundTextureBlackGradient"]] autorelease];
    self.navigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;

    [self setTitle:@"New Certificate"];

    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(cancelClicked:)];
    [[self navigationItem] setLeftBarButtonItem:cancelButton];
    [cancelButton release];

    UIBarButtonItem *createButton = [[UIBarButtonItem alloc] initWithTitle:@"Create" style:UIBarButtonItemStyleDone target:self action:@selector(createClicked:)];
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
            ShowAlertDialog(@"Unable to generate certificate",
                            @"Mumble was unable to generate a certificate for the your identity.");
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
                    ShowAlertDialog(@"Unable to add identity",
                                    @"The certificate of the just-added identity could not be added to the certificate store because it "
                                    @"has the same name as a certificate already found in the store.");
                }
            } else {
                ShowAlertDialog(@"Unable to import generated certificate",
                                @"Mumble was unable to import the generated certificate into the certificate store.");
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[self navigationController] dismissModalViewControllerAnimated:YES];
        });
    });    
}

@end

