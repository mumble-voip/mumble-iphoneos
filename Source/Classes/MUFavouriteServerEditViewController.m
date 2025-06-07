// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUFavouriteServerEditViewController.h"

#import "MUColor.h"
#import "MUDatabase.h"
#import "MUFavouriteServer.h"
#import "MUTableViewHeaderLabel.h"
#import "MUImage.h"
#import "MUBackgroundView.h"

@interface MUFavouriteServerEditViewController () {
    BOOL               _editMode;
    MUFavouriteServer  *_favourite;
    id                 _target;
    SEL                _doneAction;

    UITableViewCell    *_descriptionCell;
    UITextField        *_descriptionField;
    UITableViewCell    *_addressCell;
    UITextField        *_addressField;
    UITableViewCell    *_portCell;
    UITextField        *_portField;
    UITableViewCell    *_usernameCell;
    UITextField        *_usernameField;
    UITableViewCell    *_passwordCell;
    UITextField        *_passwordField;

    UITextField        *_activeTextField;
    UITableViewCell    *_activeCell;
}
- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView;
@end

@implementation MUFavouriteServerEditViewController

#pragma mark -
#pragma mark Initialization

+ (void) configureTableViewConstraintWithCell:(UITableViewCell *)cell andTextField:(UITextField *)textField {
    [textField setTranslatesAutoresizingMaskIntoConstraints:NO];

    NSLayoutConstraint *top = [NSLayoutConstraint constraintWithItem:textField attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:[cell contentView] attribute:NSLayoutAttributeTop multiplier:1 constant:8];
    NSLayoutConstraint *bottom = [NSLayoutConstraint constraintWithItem:textField attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:[cell contentView] attribute:NSLayoutAttributeBottom multiplier:1 constant:-8];
    NSLayoutConstraint *left = [NSLayoutConstraint constraintWithItem:textField attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:[cell contentView] attribute:NSLayoutAttributeLeft multiplier:1 constant:110];
    NSLayoutConstraint *right = [NSLayoutConstraint constraintWithItem:textField attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:[cell contentView] attribute:NSLayoutAttributeRight multiplier:1 constant:0];

    [NSLayoutConstraint activateConstraints:@[top, bottom, left, right]];
}

- (id) initInEditMode:(BOOL)editMode withContentOfFavouriteServer:(MUFavouriteServer *)favServ {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        _editMode = editMode;
        if (favServ) {
            _favourite = [favServ copy];
        } else {
            _favourite = [[MUFavouriteServer alloc] init];
        }
        
        CGRect textFieldRect = CGRectMake(110.0, 10.0, 185.0, 30.0);
        
        _descriptionCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"MUFavouriteServerDescription"];
        [_descriptionCell setSelectionStyle:UITableViewCellSelectionStyleNone];
        [[_descriptionCell textLabel] setText:NSLocalizedString(@"Description", nil)];
        _descriptionField = [[UITextField alloc] initWithFrame:textFieldRect];
        [_descriptionField setTextColor:[MUColor selectedTextColor]];
        [_descriptionField addTarget:self action:@selector(textFieldBeganEditing:) forControlEvents:UIControlEventEditingDidBegin];
        [_descriptionField addTarget:self action:@selector(textFieldEndedEditing:) forControlEvents:UIControlEventEditingDidEnd];
        [_descriptionField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        [_descriptionField addTarget:self action:@selector(textFieldDidEndOnExit:) forControlEvents:UIControlEventEditingDidEndOnExit];
        [_descriptionField setReturnKeyType:UIReturnKeyNext];
        [_descriptionField setAdjustsFontSizeToFitWidth:NO];
        [_descriptionField setTextAlignment:NSTextAlignmentLeft];
        [_descriptionField setPlaceholder:NSLocalizedString(@"Mumble Server", nil)];
        [_descriptionField setAutocapitalizationType:UITextAutocapitalizationTypeWords];
        [_descriptionField setText:[_favourite displayName]];
        [_descriptionField setClearButtonMode:UITextFieldViewModeWhileEditing];
        [[_descriptionCell contentView] addSubview:_descriptionField];

        [MUFavouriteServerEditViewController configureTableViewConstraintWithCell:_descriptionCell andTextField:_descriptionField];

        _addressCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"MUFavouriteServerAddress"];
        [_addressCell setSelectionStyle:UITableViewCellSelectionStyleNone];
        [[_addressCell textLabel] setText:NSLocalizedString(@"Address", nil)];
        _addressField = [[UITextField alloc] initWithFrame:textFieldRect];
        [_addressField setTextColor:[MUColor selectedTextColor]];
        [_addressField addTarget:self action:@selector(textFieldBeganEditing:) forControlEvents:UIControlEventEditingDidBegin];
        [_addressField addTarget:self action:@selector(textFieldEndedEditing:) forControlEvents:UIControlEventEditingDidEnd];
        [_addressField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        [_addressField addTarget:self action:@selector(textFieldDidEndOnExit:) forControlEvents:UIControlEventEditingDidEndOnExit];
        [_addressField setReturnKeyType:UIReturnKeyNext];
        [_addressField setAdjustsFontSizeToFitWidth:NO];
        [_addressField setTextAlignment:NSTextAlignmentLeft];
        [_addressField setPlaceholder:NSLocalizedString(@"Hostname or IP address", nil)];
        [_addressField setAutocapitalizationType:UITextAutocapitalizationTypeNone];
        [_addressField setAutocorrectionType:UITextAutocorrectionTypeNo];
        [_addressField setKeyboardType:UIKeyboardTypeURL];
        [_addressField setText:[_favourite hostName]];
        [_addressField setClearButtonMode:UITextFieldViewModeWhileEditing];
        [[_addressCell contentView] addSubview:_addressField];

        [MUFavouriteServerEditViewController configureTableViewConstraintWithCell:_addressCell andTextField:_addressField];

        _portCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"MUFavouriteServerPort"];
        [_portCell setSelectionStyle:UITableViewCellSelectionStyleNone];
        [[_portCell textLabel] setText:NSLocalizedString(@"Port", nil)];
        _portField = [[UITextField alloc] initWithFrame:textFieldRect];
        [_portField setTextColor:[MUColor selectedTextColor]];
        [_portField addTarget:self action:@selector(textFieldBeganEditing:) forControlEvents:UIControlEventEditingDidBegin];
        [_portField addTarget:self action:@selector(textFieldEndedEditing:) forControlEvents:UIControlEventEditingDidEnd];
        [_portField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        [_portField addTarget:self action:@selector(textFieldDidEndOnExit:) forControlEvents:UIControlEventEditingDidEndOnExit];
        [_portField setReturnKeyType:UIReturnKeyNext];
        [_portField setAdjustsFontSizeToFitWidth:YES];
        [_portField setAutocapitalizationType:UITextAutocapitalizationTypeNone];
        [_portField setAutocorrectionType:UITextAutocorrectionTypeNo];
        [_portField setTextAlignment:NSTextAlignmentLeft];
        [_portField setPlaceholder:@"64738"];
        [_portField setKeyboardType:UIKeyboardTypeNumbersAndPunctuation];
        if ([_favourite port] != 0)
            [_portField setText:[NSString stringWithFormat:@"%lu", (unsigned long)[_favourite port]]];
        else
            [_portField setText:@""];
        [_portField setClearButtonMode:UITextFieldViewModeWhileEditing];
        [[_portCell contentView] addSubview:_portField];

        [MUFavouriteServerEditViewController configureTableViewConstraintWithCell:_portCell andTextField:_portField];

        _usernameCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"MUFavouriteServerUsername"];
        [_usernameCell setSelectionStyle:UITableViewCellSelectionStyleNone];
        [[_usernameCell textLabel] setText:NSLocalizedString(@"Username", nil)];
        _usernameField = [[UITextField alloc] initWithFrame:textFieldRect];
        [_usernameField setTextColor:[MUColor selectedTextColor]];
        [_usernameField addTarget:self action:@selector(textFieldBeganEditing:) forControlEvents:UIControlEventEditingDidBegin];
        [_usernameField addTarget:self action:@selector(textFieldEndedEditing:) forControlEvents:UIControlEventEditingDidEnd];
        [_usernameField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        [_usernameField addTarget:self action:@selector(textFieldDidEndOnExit:) forControlEvents:UIControlEventEditingDidEndOnExit];
        [_usernameField setReturnKeyType:UIReturnKeyNext];
        [_usernameField setAdjustsFontSizeToFitWidth:NO];
        [_usernameField setAutocapitalizationType:UITextAutocapitalizationTypeNone];
        [_usernameField setAutocorrectionType:UITextAutocorrectionTypeNo];
        [_usernameField setTextAlignment:NSTextAlignmentLeft];
        [_usernameField setPlaceholder:[[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultUserName"]];
        [_usernameField setSecureTextEntry:NO];
        [_usernameField setText:[_favourite userName]];
        [_usernameField setClearButtonMode:UITextFieldViewModeWhileEditing];
        [[_usernameCell contentView] addSubview:_usernameField];

        [MUFavouriteServerEditViewController configureTableViewConstraintWithCell:_usernameCell andTextField:_usernameField];

        _passwordCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"MUFavouriteServerPassword"];
        [_passwordCell setSelectionStyle:UITableViewCellSelectionStyleNone];
        [[_passwordCell textLabel] setText:NSLocalizedString(@"Password", nil)];
        _passwordField = [[UITextField alloc] initWithFrame:textFieldRect];
        [_passwordField setTextColor:[MUColor selectedTextColor]];
        [_passwordField addTarget:self action:@selector(textFieldBeganEditing:) forControlEvents:UIControlEventEditingDidBegin];
        [_passwordField addTarget:self action:@selector(textFieldEndedEditing:) forControlEvents:UIControlEventEditingDidEnd];
        [_passwordField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        [_passwordField addTarget:self action:@selector(textFieldDidEndOnExit:) forControlEvents:UIControlEventEditingDidEndOnExit];
        [_passwordField setReturnKeyType:UIReturnKeyDefault];
        [_passwordField setAdjustsFontSizeToFitWidth:NO];
        [_passwordField setAutocapitalizationType:UITextAutocapitalizationTypeNone];
        [_passwordField setAutocorrectionType:UITextAutocorrectionTypeNo];
        [_passwordField setPlaceholder:NSLocalizedString(@"Optional", nil)];
        [_passwordField setSecureTextEntry:YES];
        [_passwordField setTextAlignment:NSTextAlignmentLeft];
        [_passwordField setText:[_favourite password]];
        [_passwordField setClearButtonMode:UITextFieldViewModeWhileEditing];
        [[_passwordCell contentView] addSubview:_passwordField];

        [MUFavouriteServerEditViewController configureTableViewConstraintWithCell:_passwordCell andTextField:_passwordField];
    }
    return self;
}

- (id) init {
    return [self initInEditMode:NO withContentOfFavouriteServer:nil];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    // On iPad, we support all interface orientations.
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        return YES;
    }
    
    return toInterfaceOrientation == UIInterfaceOrientationPortrait;
}

#pragma mark -
#pragma mark View lifecycle

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.tableView.backgroundView = [MUBackgroundView backgroundView];
    
    if (@available(iOS 7, *)) {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        self.tableView.separatorInset = UIEdgeInsetsZero;
    } else {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];

    // View title
    if (!_editMode) {
        [[self navigationItem] setTitle:NSLocalizedString(@"New Favourite", nil)];
    } else {
        [[self navigationItem] setTitle:NSLocalizedString(@"Edit Favourite", nil)];
    }

    // Cancel button
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel", nil)
                                                                     style:UIBarButtonItemStylePlain
                                                                    target:self
                                                                    action:@selector(cancelClicked:)];
    [[self navigationItem] setLeftBarButtonItem:cancelButton];

    // Done
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", nil)
                                                                   style:UIBarButtonItemStyleDone
                                                                  target:self
                                                                  action:@selector(doneClicked:)];
    [[self navigationItem] setRightBarButtonItem:doneButton];
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
     return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 5;
    }
    return 0;
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([indexPath section] == 0) {
        if ([indexPath row] == 0) {
            return _descriptionCell;
        } else if ([indexPath row] == 1) {
            return _addressCell;
        } else if ([indexPath row] == 2) {
            return _portCell;
        } else if ([indexPath row] == 3) {
            return _usernameCell;
        } else if ([indexPath row] == 4) {
            return _passwordCell;
        }
    }
    return nil;
}

#pragma mark -
#pragma mark UIBarButton actions

- (void) cancelClicked:(id)sender {
    [[self navigationController] dismissViewControllerAnimated:YES completion:nil];
}

- (void) doneClicked:(id)sender {
    // Perform some basic tidying up. For example, for the port field, we
    // want the default port number to be used if it wasn't filled out.
    if ([_favourite displayName] == nil) {
        [_favourite setDisplayName:NSLocalizedString(@"Mumble Server", nil)];
    }
    if ([_favourite port] == 0) {
        [_favourite setPort:64738];
    }

    // Get rid of oureslves and call back to our target to tell it that
    // we're done.
    [[self navigationController] dismissViewControllerAnimated:YES completion:nil];
    if ([_target respondsToSelector:_doneAction]) {
        [_target performSelector:_doneAction withObject:self];
    }
}

#pragma mark -
#pragma mark Data accessors

- (MUFavouriteServer *) copyFavouriteFromContent {
    return [_favourite copy];
}

#pragma mark -
#pragma mark Target/actions

- (void) setTarget:(id)target {
    _target = target;
}

- (id) target {
    return _target;
}

- (void) setDoneAction:(SEL)action {
    _doneAction = action;
}

- (SEL) doneAction {
    return _doneAction;
}

#pragma mark -
#pragma mark Text field actions

- (void) textFieldBeganEditing:(UITextField *)sender {
    _activeTextField = sender;
    if (sender == _descriptionField) {
        _activeCell = _descriptionCell;
    } else if (sender == _addressField) {
        _activeCell = _addressCell;
    } else if (sender == _portField) {
        _activeCell = _portCell;
    } else if (sender == _usernameField) {
        _activeCell = _usernameCell;
    } else if (sender == _passwordField) {
        _activeCell = _passwordCell;
    }
}

- (void) textFieldEndedEditing:(UITextField *)sender {
    _activeTextField = nil;
}

- (void) textFieldDidChange:(UITextField *)sender {
    if (sender == _descriptionField) {
        [_favourite setDisplayName:[sender text]];
    } else if (sender == _addressField) {
        [_favourite setHostName:[sender text]];
    } else if (sender == _portField) {
        [_favourite setPort:[[sender text] integerValue]];
    } else if (sender == _usernameField) {
        [_favourite setUserName:[sender text]];
    } else if (sender == _passwordField) {
        [_favourite setPassword:[sender text]];
    }
}

- (void) textFieldDidEndOnExit:(UITextField *)sender {
    if (sender == _descriptionField) {
        [_addressField becomeFirstResponder];
        _activeTextField = _addressField;
        _activeCell = _addressCell;
    } else if (sender == _addressField) {
        [_portField becomeFirstResponder];
        _activeTextField = _portField;
        _activeCell = _portCell;
    } else if (sender == _portField) {
        [_usernameField becomeFirstResponder];
        _activeTextField = _usernameField;
        _activeCell = _usernameCell;
    } else if (sender == _usernameField) {
        [_passwordField becomeFirstResponder];
        _activeTextField = _passwordField;
        _activeCell = _passwordCell;
    } else if (sender == _passwordField) {
        [_passwordField resignFirstResponder];
        _activeTextField = nil;
        _activeCell = nil;
    }
    if (self->_activeCell) {
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

        [self.tableView scrollToRowAtIndexPath:[self.tableView indexPathForCell:self->_activeCell]
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


@end
