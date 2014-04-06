// Copyright 2009-2012 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUMessageRecipientViewController.h"
#import "MUUserStateAcessoryView.h"
#import "MUColor.h"
#import "MUOperatingSystem.h"
#import "MUBackgroundView.h"
#import "MUServerTableViewCell.h"

@interface MUMessageRecipientViewController () {
    MKServerModel                                 *_serverModel;
    NSMutableArray                                *_modelItems;
    NSMutableDictionary                           *_userIndexMap;
    NSMutableDictionary                           *_channelIndexMap;
    id<MUMessageRecipientViewControllerDelegate>  _delegate;
}
- (void) rebuildModelArrayFromChannel:(MKChannel *)channel;
- (void) addChannelTreeToModel:(MKChannel *)channel indentLevel:(NSInteger)indentLevel;
@end

@implementation MUMessageRecipientViewController

- (id) initWithServerModel:(MKServerModel *)model {
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        _serverModel = [model retain];
        [_serverModel addDelegate:self];
    }
    return self;
}

- (void) dealloc {
    [_serverModel removeDelegate:self];
    [super dealloc];
}

- (id<MUMessageRecipientViewControllerDelegate>) delegate {
    return _delegate;
}

- (void) setDelegate:(id<MUMessageRecipientViewControllerDelegate>)delegate {
    _delegate = delegate;
}

- (void) rebuildModelArrayFromChannel:(MKChannel *)channel {
    [_modelItems release];
    _modelItems = [[NSMutableArray alloc] init];
    
    [_userIndexMap release];
    _userIndexMap = [[NSMutableDictionary alloc] init];
    
    [_channelIndexMap release];
    _channelIndexMap = [[NSMutableDictionary alloc] init];
    
    [self addChannelTreeToModel:channel indentLevel:0];
}

- (void) addChannelTreeToModel:(MKChannel *)channel indentLevel:(NSInteger)indentLevel {    
    [_channelIndexMap setObject:[NSNumber numberWithUnsignedInteger:[_modelItems count]] forKey:[NSNumber numberWithUnsignedInteger:[channel channelId]]];
    [_modelItems addObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:indentLevel], @"indentLevel", channel, @"object", nil]];
    
    for (MKUser *user in [channel users]) {
        [_userIndexMap setObject:[NSNumber numberWithUnsignedInteger:[_modelItems count]] forKey:[NSNumber numberWithUnsignedInteger:[user session]]];
        [_modelItems addObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:indentLevel+1], @"indentLevel", user, @"object", nil]];
    }
    for (MKChannel *chan in [channel channels]) {
        [self addChannelTreeToModel:chan indentLevel:indentLevel+1];
    }
}

- (NSInteger) indexForUser:(MKUser *)user {
    NSInteger userIndex = 1+[[_userIndexMap objectForKey:[NSNumber numberWithUnsignedInteger:[user session]]] integerValue];
    return userIndex;
}

- (NSInteger) indexForChannel:(MKChannel *)channel {
    NSInteger channelIndex = 1+[[_channelIndexMap objectForKey:[NSNumber numberWithUnsignedInteger:[channel channelId]]] integerValue];
    return channelIndex;
}

- (void) reloadUser:(MKUser *)user {
    NSInteger userIndex = [self indexForUser:user];
    if (userIndex != NSNotFound) {
        [[self tableView] reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:userIndex inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
    }
}

- (void) reloadChannel:(MKChannel *)channel {
    NSInteger idx = [self indexForChannel:channel];
    if (idx != NSNotFound) {
        [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:idx inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
    }
}

#pragma mark - View lifecycle

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.navigationItem.title = NSLocalizedString(@"Message Recipient", nil);
    
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

    self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelClicked:)] autorelease];
    
    [self rebuildModelArrayFromChannel:[_serverModel rootChannel]];
    [self.tableView reloadData];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1 + [_modelItems count];
}

- (void) tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([indexPath row] == 0)
        return;
    NSDictionary *dict = [_modelItems objectAtIndex:[indexPath row]-1];
    id object = [dict objectForKey:@"object"];
    if ([object class] == [MKChannel class]) {
        MKChannel *channel = (MKChannel *) object;
        if (channel == [_serverModel rootChannel] && [_serverModel serverCertificatesTrusted]) {
            cell.backgroundColor = [MUColor verifiedCertificateChainColor];
        }
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"MUMessageRecipientCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
            cell = [[[MUServerTableViewCell alloc] initWithReuseIdentifier:CellIdentifier] autorelease];
        } else {
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
        }
    }

    cell.textLabel.font = [UIFont systemFontOfSize:18.0f];
    cell.selectionStyle = UITableViewCellSelectionStyleGray;

    if ([indexPath row] == 0) {
        [[cell imageView] setImage:[UIImage imageNamed:@"channel"]];
        [[cell textLabel] setText:NSLocalizedString(@"Current Channel", nil)];
        [[cell textLabel] setFont:[UIFont boldSystemFontOfSize:18.0f]];
        [cell setIndentationLevel:0];
        [cell setAccessoryView:nil];
    } else {
        NSDictionary *dict = [_modelItems objectAtIndex:[indexPath row]-1];
        id object = [dict objectForKey:@"object"];
        NSInteger indentLevel = [[dict objectForKey:@"indentLevel"] integerValue];
        if ([object class] == [MKChannel class]) {
            MKChannel *channel = (MKChannel *) object;
            if ([[_serverModel connectedUser] channel] == channel) {
                [[cell textLabel] setFont:[UIFont boldSystemFontOfSize:18.0f]];
            } else {
                [[cell textLabel] setFont:[UIFont systemFontOfSize:18.0f]];    
            }
            [[cell imageView] setImage:[UIImage imageNamed:@"channel"]];
            [[cell textLabel] setText:[channel channelName]];
            [cell setIndentationLevel:indentLevel];
            [cell setAccessoryView:nil];
        } else if ([object class] == [MKUser class]) {
            MKUser *user = (MKUser *) object;
            if (user == [_serverModel connectedUser]) {
                [[cell textLabel] setFont:[UIFont boldSystemFontOfSize:18.0f]];
            } else {
                [[cell textLabel] setFont:[UIFont systemFontOfSize:18.0f]];    
            }
            [[cell textLabel] setText:[user userName]];
            [cell setIndentationLevel:indentLevel];
            
            MKTalkState talkState = [user talkState];
            NSString *talkImageName = nil;
            if (talkState == MKTalkStatePassive)
                talkImageName = @"talking_off";
            else if (talkState == MKTalkStateTalking)
                talkImageName = @"talking_on";
            else if (talkState == MKTalkStateWhispering)
                talkImageName = @"talking_whisper";
            else if (talkState == MKTalkStateShouting)
                talkImageName = @"talking_alt";
            [[cell imageView] setImage:[UIImage imageNamed:talkImageName]];

            [cell setAccessoryView:[MUUserStateAcessoryView viewForUser:user]];
        }
    }
    
    return cell;
}

#pragma mark - Table view delegate

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([indexPath row] == 0) {
        [_delegate messageRecipientViewControllerDidSelectCurrentChannel:self];
    } else {
        NSDictionary *dict = [_modelItems objectAtIndex:[indexPath row]-1];
        id object = [dict objectForKey:@"object"];
        if ([object class] == [MKChannel class]) {
            [_delegate messageRecipientViewController:self didSelectChannel:object];
        } else if ([object class] == [MKUser class]) {
            [_delegate messageRecipientViewController:self didSelectUser:object];
        }
    }

    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self dismissModalViewControllerAnimated:YES];
}

#pragma mark - Actions

- (void) cancelClicked:(id)sender {
    [self dismissModalViewControllerAnimated:YES];
}

#pragma mark - MKServerModel delegate

- (void) serverModel:(MKServerModel *)model joinedServerAsUser:(MKUser *)user {
    [self rebuildModelArrayFromChannel:[model rootChannel]];
    [self.tableView reloadData];
}

- (void) serverModel:(MKServerModel *)model userJoined:(MKUser *)user {
}

- (void) serverModel:(MKServerModel *)model userDisconnected:(MKUser *)user {
}

- (void) serverModel:(MKServerModel *)model userLeft:(MKUser *)user {
    NSInteger idx = [self indexForUser:user];
    [self rebuildModelArrayFromChannel:[model rootChannel]];
    [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:idx inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
}

- (void) serverModel:(MKServerModel *)model userTalkStateChanged:(MKUser *)user {
    NSInteger userIndex = [self indexForUser:user];
    UITableViewCell *cell = [[self tableView] cellForRowAtIndexPath:[NSIndexPath indexPathForRow:userIndex inSection:0]];
    
    MKTalkState talkState = [user talkState];
    NSString *talkImageName = nil;
    if (talkState == MKTalkStatePassive)
        talkImageName = @"talking_off";
    else if (talkState == MKTalkStateTalking)
        talkImageName = @"talking_on";
    else if (talkState == MKTalkStateWhispering)
        talkImageName = @"talking_whisper";
    else if (talkState == MKTalkStateShouting)
        talkImageName = @"talking_alt";
    
    cell.imageView.image = [UIImage imageNamed:talkImageName];
}

- (void) serverModel:(MKServerModel *)model channelAdded:(MKChannel *)channel {
    [self rebuildModelArrayFromChannel:[model rootChannel]];
    NSInteger idx = [self indexForChannel:channel];
    [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:idx inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
}

- (void) serverModel:(MKServerModel *)model channelRemoved:(MKChannel *)channel {
    [self rebuildModelArrayFromChannel:[model rootChannel]];
    [self.tableView reloadData];
}

- (void) serverModel:(MKServerModel *)model channelMoved:(MKChannel *)channel {
    [self rebuildModelArrayFromChannel:[model rootChannel]];
    [self.tableView reloadData];
}

- (void) serverModel:(MKServerModel *)model channelRenamed:(MKChannel *)channel {
    [self reloadChannel:channel];
}

- (void) serverModel:(MKServerModel *)model userMoved:(MKUser *)user toChannel:(MKChannel *)chan fromChannel:(MKChannel *)prevChan byUser:(MKUser *)mover {
    [self.tableView beginUpdates]; 
    if (user == [model connectedUser]) {
        [self reloadChannel:chan];
        [self reloadChannel:prevChan];
    }
    
    // Check if the user is joining a channel for the first time.
    if (prevChan != nil) {
        NSInteger prevIdx = [self indexForUser:user];
        [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:prevIdx inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
    }
    
    [self rebuildModelArrayFromChannel:[model rootChannel]];
    NSInteger newIdx = [self indexForUser:user];
    [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:newIdx inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
    [self.tableView endUpdates];
}

- (void) serverModel:(MKServerModel *)model userSelfMuted:(MKUser *)user {
}

- (void) serverModel:(MKServerModel *)model userRemovedSelfMute:(MKUser *)user {
}

- (void) serverModel:(MKServerModel *)model userSelfMutedAndDeafened:(MKUser *)user {
}

- (void) serverModel:(MKServerModel *)model userRemovedSelfMuteAndDeafen:(MKUser *)user {
}

- (void) serverModel:(MKServerModel *)model userSelfMuteDeafenStateChanged:(MKUser *)user {
    [self reloadUser:user];
}

// --

- (void) serverModel:(MKServerModel *)model userMutedAndDeafened:(MKUser *)user byUser:(MKUser *)actor {
    [self reloadUser:user];
}

- (void) serverModel:(MKServerModel *)model userUnmutedAndUndeafened:(MKUser *)user byUser:(MKUser *)actor {
    [self reloadUser:user];
}

- (void) serverModel:(MKServerModel *)model userMuted:(MKUser *)user byUser:(MKUser *)actor {
    [self reloadUser:user];
}

- (void) serverModel:(MKServerModel *)model userUnmuted:(MKUser *)user byUser:(MKUser *)actor {
    [self reloadUser:user];
}

- (void) serverModel:(MKServerModel *)model userDeafened:(MKUser *)user byUser:(MKUser *)actor {
    [self reloadUser:user];
}

- (void) serverModel:(MKServerModel *)model userUndeafened:(MKUser *)user byUser:(MKUser *)actor {
    [self reloadUser:user];
}

- (void) serverModel:(MKServerModel *)model userSuppressed:(MKUser *)user byUser:(MKUser *)actor {
    [self reloadUser:user];
}

- (void) serverModel:(MKServerModel *)model userUnsuppressed:(MKUser *)user byUser:(MKUser *)actor {
    [self reloadUser:user];
}

- (void) serverModel:(MKServerModel *)model userMuteStateChanged:(MKUser *)user {
    [self reloadUser:user];
}

@end
