#import "MUInterface.h"
// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUAccessTokenViewController.h"
#import "MUDatabase.h"

@interface MUAccessTokenViewController () {
    MLServerModel    *_model;
    NSMutableArray   *_tokens;

    NSString         *_tokenValue;
    NSInteger        _editingRow;
    
    UITableViewCell  *_editingCell;
    UITextField     *_editingField;
}
- (void) editItemAtIndex:(NSInteger)row;
- (void) finishEditingToken;
@end

@implementation MUAccessTokenViewController

- (id) initWithServerModel:(MLServerModel *)model {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        _model = model;
        _editingRow = -1;
        // The draft belongs to this editor, not to an appearance transition.
        _tokens = [[MUDatabase accessTokensForServerWithHostname:model.hostname port:model.port] mutableCopy] ?: [NSMutableArray new];
    }
    return self;
}

#pragma mark - View lifecycle

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    MUConfigureTable(self.tableView);
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    [[self navigationItem] setTitle:NSLocalizedString(@"Access Tokens", nil)];
    
    {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    }

    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addButtonClicked:)];
    [[self navigationItem] setRightBarButtonItem:addButton];
    
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneButtonClicked:)];
    [[self navigationItem] setLeftBarButtonItem:doneButton];

}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self finishEditingToken];

    [_model setAccessTokens:_tokens];

    [MUDatabase storeAccessTokens:_tokens forServerWithHostname:[_model hostname] port:[_model port]];
}

#pragma mark - Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_tokens count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"AccessTokenCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        MUConfigureStandardCell(cell);
    }
    if ([indexPath row] == _editingRow) {
        return _editingCell;
    } else {
        NSString *token = [_tokens objectAtIndex:[indexPath row]];
        if ([token length] == 0) {
            cell.textLabel.textColor = [UIColor secondaryLabelColor];
            cell.textLabel.text = NSLocalizedString(@"(Empty)", nil);
        } else {
            cell.textLabel.textColor = [UIColor labelColor];
            cell.textLabel.text = token;
        }
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return cell;
}

- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_editingRow != -1)
        return NO;
    return YES;
}

- (void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [_tokens removeObjectAtIndex:[indexPath row]];
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_editingRow != -1)
        return;
    [self editItemAtIndex:[indexPath row]];
    [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - Actions

- (void) editItemAtIndex:(NSInteger)row {
    if (row < 0 || row >= (NSInteger)_tokens.count) return;
    _editingRow = row;

    _tokenValue = [[_tokens objectAtIndex:row] copy];

    _editingCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"AccessTokenEditingCell"];
    MUConfigureStandardCell(_editingCell);
    UITextField *editingField;
    {
        editingField = [[UITextField alloc] initWithFrame:CGRectMake(14.0, 0.0, _editingCell.frame.size.width-14.0, _editingCell.frame.size.height)];
        editingField.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        editingField.adjustsFontForContentSizeCategory = YES;
        editingField.accessibilityLabel = NSLocalizedString(@"Access Token", nil);
        editingField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }
    [editingField setAutocorrectionType:UITextAutocorrectionTypeNo];
    [editingField addTarget:self action:@selector(textFieldBeganEditing:) forControlEvents:UIControlEventEditingDidBegin];
    [editingField addTarget:self action:@selector(textFieldEndedEditing:) forControlEvents:UIControlEventEditingDidEnd];
    [editingField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [editingField addTarget:self action:@selector(textFieldDidEndOnExit:) forControlEvents:UIControlEventEditingDidEndOnExit];
    [editingField setText:_tokenValue];
    [editingField setReturnKeyType:UIReturnKeyDone];
    _editingField = editingField;
    [[_editingCell contentView] addSubview:editingField];

    [editingField setTranslatesAutoresizingMaskIntoConstraints:NO];

    UILayoutGuide *margins = _editingCell.contentView.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[
        [editingField.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor], [editingField.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor],
        [editingField.topAnchor constraintEqualToAnchor:margins.topAnchor], [editingField.bottomAnchor constraintEqualToAnchor:margins.bottomAnchor],
        [_editingCell.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:52]
    ]];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_editingField == editingField && editingField.window) [editingField becomeFirstResponder];
    });
}

- (void) addButtonClicked:(id)sender {
    if (_editingRow != -1)
        return;
    // Establish the table's initial snapshot before changing the backing array.
    [self.tableView numberOfRowsInSection:0];
    NSInteger insertRow = [_tokens count];
    [_tokens addObject:@""];
    [self editItemAtIndex:insertRow];
    [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:insertRow inSection:0]] withRowAnimation:UITableViewRowAnimationBottom];
}

- (void) doneButtonClicked:(id)sender {
    [self finishEditingToken];
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark -
#pragma mark Text field actions

- (void) textFieldBeganEditing:(UITextField *)sender {
}

- (void) textFieldEndedEditing:(UITextField *)sender {
    if (sender == _editingField) [self finishEditingToken];
}

- (void) textFieldDidChange:(UITextField *)sender {
    if (sender == _editingField) _tokenValue = [[sender text] copy];
}

- (void) textFieldDidEndOnExit:(UITextField *)sender {
    if (sender == _editingField) [self finishEditingToken];
}

- (void) finishEditingToken {
    if (_editingRow < 0) return;
    NSInteger row = _editingRow;
    UITextField *field = _editingField;
    if (row < (NSInteger)_tokens.count) _tokens[row] = field.text ?: _tokenValue ?: @"";
    // Clear ownership before resigning: UIKit sends EditingDidEnd synchronously.
    _editingRow = -1;
    _editingField = nil;
    _tokenValue = nil;
    [field resignFirstResponder];
    _editingCell = nil;
    if (row < [self.tableView numberOfRowsInSection:0])
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:row inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
}





@end
