// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUAccessTokenViewController.h"
#import "MUDatabase.h"
#import "MUOperatingSystem.h"
#import "MUBAckgroundView.h"

@interface MUAccessTokenViewController () {
    MKServerModel    *_model;
    NSMutableArray   *_tokens;

    NSString         *_tokenValue;
    NSInteger        _editingRow;
    
    UITableViewCell  *_editingCell;
}
- (void) editItemAtIndex:(NSInteger)row;
@end

@implementation MUAccessTokenViewController

- (id) initWithServerModel:(MKServerModel *)model {
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        _model = [model retain];
        _editingRow = -1;
    }
    return self;
}

- (void) dealloc {
    [_model release];
    [_editingCell release];
    [super dealloc];
}

#pragma mark - View lifecycle

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [[self navigationItem] setTitle:NSLocalizedString(@"Access Tokens", nil)];

    UINavigationBar *navBar = self.navigationController.navigationBar;
    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        navBar.tintColor = [UIColor whiteColor];
        navBar.translucent = NO;
        navBar.backgroundColor = [UIColor blackColor];
    }
    navBar.barStyle = UIBarStyleBlackOpaque;
    
    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        self.tableView.separatorInset = UIEdgeInsetsZero;
    }

    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addButtonClicked:)];
    [[self navigationItem] setRightBarButtonItem:addButton];
    [addButton release];
    
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneButtonClicked:)];
    [[self navigationItem] setLeftBarButtonItem:doneButton];
    [doneButton release];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];

    NSArray *dbTokens = [MUDatabase accessTokensForServerWithHostname:[_model hostname] port:[_model port]];
    _tokens = [[NSMutableArray alloc] initWithArray:dbTokens];
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [_model setAccessTokens:_tokens];

    [MUDatabase storeAccessTokens:_tokens forServerWithHostname:[_model hostname] port:[_model port]];
    [_tokens release];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
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
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    if ([indexPath row] == _editingRow) {
        return _editingCell;
    } else {
        NSString *token = [_tokens objectAtIndex:[indexPath row]];
        if ([token length] == 0) {
            cell.textLabel.textColor = [UIColor lightGrayColor];
            cell.textLabel.text = NSLocalizedString(@"(Empty)", nil);
        } else {
            cell.textLabel.textColor = [UIColor blackColor];
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
    _editingRow = row;

    [_tokenValue release];
    _tokenValue = [[_tokens objectAtIndex:row] copy];

    _editingCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"AccessTokenEditingCell"];
    UITextField *editingField;
    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        editingField = [[UITextField alloc] initWithFrame:CGRectMake(14.0, 0.0, _editingCell.frame.size.width-14.0, _editingCell.frame.size.height)];
        [editingField setFont:[UIFont boldSystemFontOfSize:18.0f]];
    } else {
        editingField = [[UITextField alloc] initWithFrame:CGRectMake(10.0, 10.0, _editingCell.frame.size.width-10, _editingCell.frame.size.height-10)];
        [editingField setFont:[UIFont boldSystemFontOfSize:20.0f]];
    }
    [editingField setAutocorrectionType:UITextAutocorrectionTypeNo];
    [editingField addTarget:self action:@selector(textFieldBeganEditing:) forControlEvents:UIControlEventEditingDidBegin];
    [editingField addTarget:self action:@selector(textFieldEndedEditing:) forControlEvents:UIControlEventEditingDidEnd];
    [editingField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [editingField addTarget:self action:@selector(textFieldDidEndOnExit:) forControlEvents:UIControlEventEditingDidEndOnExit];
    [editingField setText:_tokenValue];
    [editingField setReturnKeyType:UIReturnKeyDone];
    [[_editingCell contentView] addSubview:editingField];
    [editingField release];

    [editingField becomeFirstResponder];
}

- (void) addButtonClicked:(id)sender {
    if (_editingRow != -1)
        return;
    NSInteger insertRow = [_tokens count];
    [_tokens addObject:@""];
    [self editItemAtIndex:insertRow];
    [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:insertRow inSection:0]] withRowAnimation:UITableViewRowAnimationBottom];
}

- (void) doneButtonClicked:(id)sender {
    [self dismissModalViewControllerAnimated:YES];
}

#pragma mark -
#pragma mark Text field actions

- (void) textFieldBeganEditing:(UITextField *)sender {
}

- (void) textFieldEndedEditing:(UITextField *)sender {
}

- (void) textFieldDidChange:(UITextField *)sender {
    [_tokenValue release];
    _tokenValue = [[sender text] copy];
}

- (void) textFieldDidEndOnExit:(UITextField *)sender {
    [sender resignFirstResponder];
    [_tokens replaceObjectAtIndex:_editingRow withObject:_tokenValue];
    [_tokenValue release];
    _tokenValue = nil;
    NSInteger row = _editingRow;
    _editingRow = -1;
    [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:row inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
    [_editingCell release];
    _editingCell = nil;
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
        
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:_editingRow inSection:0]
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
