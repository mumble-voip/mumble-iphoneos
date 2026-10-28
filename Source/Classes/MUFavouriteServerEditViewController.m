#import "MUInterface.h"
// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUFavouriteServerEditViewController.h"

#import "MUDatabase.h"
#import "MUFavouriteServer.h"
#import "MUImage.h"

@interface MUFavouriteServerEditViewController () {
    BOOL               _editMode;
    BOOL               _quickConnect;
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
- (BOOL)canQuickConnect;
- (void)notifyDone;
@end

@implementation MUFavouriteServerEditViewController

#pragma mark -
#pragma mark Initialization

 + (void)configureTableViewConstraintWithCell:(UITableViewCell *)cell title:(NSString *)title andTextField:(UITextField *)field {
    MUConfigureFormCell(cell, title, field);
}

- (id) initInEditMode:(BOOL)editMode withContentOfFavouriteServer:(MUFavouriteServer *)favServ {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        _editMode = editMode;
        if (favServ) {
            _favourite = [favServ copy];
        } else {
            _favourite = [[MUFavouriteServer alloc] init];
        }
        
        _descriptionCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"MUFavouriteServerDescription"];
        MUConfigureStandardCell(_descriptionCell);
        [_descriptionCell setSelectionStyle:UITableViewCellSelectionStyleNone];
        _descriptionField = [[UITextField alloc] init];
        [_descriptionField setTextColor:[UIColor labelColor]];
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
        [MUFavouriteServerEditViewController configureTableViewConstraintWithCell:_descriptionCell title:NSLocalizedString(@"Description", nil) andTextField:_descriptionField];

        _addressCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"MUFavouriteServerAddress"];
        MUConfigureStandardCell(_addressCell);
        [_addressCell setSelectionStyle:UITableViewCellSelectionStyleNone];
        _addressField = [[UITextField alloc] init];
        [_addressField setTextColor:[UIColor labelColor]];
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
        [MUFavouriteServerEditViewController configureTableViewConstraintWithCell:_addressCell title:NSLocalizedString(@"Address", nil) andTextField:_addressField];

        _portCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"MUFavouriteServerPort"];
        MUConfigureStandardCell(_portCell);
        [_portCell setSelectionStyle:UITableViewCellSelectionStyleNone];
        _portField = [[UITextField alloc] init];
        [_portField setTextColor:[UIColor labelColor]];
        [_portField addTarget:self action:@selector(textFieldBeganEditing:) forControlEvents:UIControlEventEditingDidBegin];
        [_portField addTarget:self action:@selector(textFieldEndedEditing:) forControlEvents:UIControlEventEditingDidEnd];
        [_portField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        [_portField addTarget:self action:@selector(textFieldDidEndOnExit:) forControlEvents:UIControlEventEditingDidEndOnExit];
        [_portField setReturnKeyType:UIReturnKeyNext];
        [_portField setAdjustsFontSizeToFitWidth:YES];
        [_portField setAutocapitalizationType:UITextAutocapitalizationTypeNone];
        [_portField setAutocorrectionType:UITextAutocorrectionTypeNo];
        [_portField setTextAlignment:NSTextAlignmentLeft];
        [_portField setPlaceholder:@(64738).stringValue];
        [_portField setKeyboardType:UIKeyboardTypeNumbersAndPunctuation];
        if ([_favourite port] != 0)
            [_portField setText:[NSString stringWithFormat:@"%lu", (unsigned long)[_favourite port]]];
        else
            [_portField setText:@""];
        [_portField setClearButtonMode:UITextFieldViewModeWhileEditing];
        [MUFavouriteServerEditViewController configureTableViewConstraintWithCell:_portCell title:NSLocalizedString(@"Port", nil) andTextField:_portField];

        _usernameCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"MUFavouriteServerUsername"];
        MUConfigureStandardCell(_usernameCell);
        [_usernameCell setSelectionStyle:UITableViewCellSelectionStyleNone];
        _usernameField = [[UITextField alloc] init];
        [_usernameField setTextColor:[UIColor labelColor]];
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
        [MUFavouriteServerEditViewController configureTableViewConstraintWithCell:_usernameCell title:NSLocalizedString(@"Username", nil) andTextField:_usernameField];

        _passwordCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"MUFavouriteServerPassword"];
        MUConfigureStandardCell(_passwordCell);
        [_passwordCell setSelectionStyle:UITableViewCellSelectionStyleNone];
        _passwordField = [[UITextField alloc] init];
        [_passwordField setTextColor:[UIColor labelColor]];
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
        [MUFavouriteServerEditViewController configureTableViewConstraintWithCell:_passwordCell title:NSLocalizedString(@"Password", nil) andTextField:_passwordField];
    }
    return self;
}

- (id) init {
    return [self initInEditMode:NO withContentOfFavouriteServer:nil];
}

- (instancetype)initForQuickConnect {
    if ((self = [self initInEditMode:NO withContentOfFavouriteServer:nil])) _quickConnect = YES;
    return self;
}

- (BOOL)canQuickConnect {
    NSString *host = [_addressField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *port = [_portField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    BOOL validPort = !port.length || ([port rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] invertedSet]].location == NSNotFound && port.length <= 5 && port.integerValue > 0 && port.integerValue <= 65535);
    return host.length > 0 && validPort;
}

#pragma mark -
#pragma mark View lifecycle

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    MUConfigureTable(self.tableView);
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    
    self.tableView.backgroundView = nil;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 44;
    
    {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    }

    // View title
    if (_quickConnect) {
        self.title = NSLocalizedString(@"Quick Connect", nil);
    } else if (!_editMode) {
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
    if (_quickConnect) {
        cancelButton.image = [UIImage systemImageNamed:@"xmark"];
        doneButton.title = NSLocalizedString(@"Connect", nil);
        doneButton.image = [UIImage systemImageNamed:@"arrow.right"];
        doneButton.enabled = [self canQuickConnect];
    }
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
    return section==0 ? self.formCells.count : 0;
}
- (NSArray<UITableViewCell *> *)formCells {
    return _quickConnect ? @[_addressCell,_portCell,_usernameCell,_passwordCell] : @[_descriptionCell,_addressCell,_portCell,_usernameCell,_passwordCell];
}
- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    return self.formCells[indexPath.row];
}

#pragma mark -
#pragma mark UIBarButton actions

- (void) cancelClicked:(id)sender {
    [[self navigationController] dismissViewControllerAnimated:YES completion:nil];
}

- (void) doneClicked:(id)sender {
    if (_quickConnect) {
        if (![self canQuickConnect]) return;
        _favourite.hostName = [_addressField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        _favourite.port = _portField.text.integerValue ?: 64738;
        NSString *username = [_usernameField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        _favourite.userName = username.length ? username : [NSUserDefaults.standardUserDefaults stringForKey:@"DefaultUserName"];
        _favourite.password = _passwordField.text;
        [self.view endEditing:YES];
        self.navigationItem.rightBarButtonItem.enabled = NO;
        // The connection UI belongs to Home, after the form has finished closing.
        [self.navigationController dismissViewControllerAnimated:YES completion:^{ [self notifyDone]; }];
        return;
    }
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
    [self notifyDone];
}

- (void)notifyDone {
    if (_doneAction != NULL && [_target respondsToSelector:_doneAction]) {
        IMP implementation = [_target methodForSelector:_doneAction];
        void (*invoke)(id, SEL, id) = (void *)implementation;
        invoke(_target, _doneAction, self);
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
    if (_quickConnect) self.navigationItem.rightBarButtonItem.enabled = [self canQuickConnect];
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






@end
