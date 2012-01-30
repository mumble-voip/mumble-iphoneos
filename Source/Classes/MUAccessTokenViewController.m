/* Copyright (C) 2009-2011 Mikkel Krautz <mikkel@krautz.dk>

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

#import "MUAccessTokenViewController.h"
#import "MUDatabase.h"

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

    [[self navigationItem] setTitle:@"Access Tokens"];

    self.navigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
    
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
            cell.textLabel.text = @"(Empty)";
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
    UITextField *editingField = [[UITextField alloc] initWithFrame:CGRectMake(10.0, 10.0, _editingCell.frame.size.width-10, _editingCell.frame.size.height-10)];
    [editingField setFont:[UIFont boldSystemFontOfSize:20.0f]];
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
    [_tokens replaceObjectAtIndex:_editingRow withObject:[_tokenValue copy]];
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
