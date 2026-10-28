// Copyright 2009-2012 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUMessageRecipientViewController.h"
#import "MUUserStateAcessoryView.h"
#import "MUImage.h"
#import "MUServerTableViewCell.h"

@interface MUMessageRecipientViewController () {
    MLServerModel                                 *_serverModel;
    NSMutableArray                                *_modelItems;
    NSMutableDictionary                           *_userIndexMap;
    NSMutableDictionary                           *_channelIndexMap;
    id<MUMessageRecipientViewControllerDelegate>  _delegate;
    BOOL _refreshScheduled;
}
- (void) rebuildModelArrayFromChannel:(MLChannel *)channel;
- (void) addChannelTreeToModel:(MLChannel *)channel indentLevel:(NSInteger)indentLevel;
@end

@implementation MUMessageRecipientViewController

- (id) initWithServerModel:(MLServerModel *)model {
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        _serverModel = model;
        [_serverModel addDelegate:self];
    }
    return self;
}

- (void) dealloc {
    [_serverModel removeDelegate:self];
}

- (id<MUMessageRecipientViewControllerDelegate>) delegate {
    return _delegate;
}

- (void) setDelegate:(id<MUMessageRecipientViewControllerDelegate>)delegate {
    _delegate = delegate;
}

- (void) rebuildModelArrayFromChannel:(MLChannel *)channel {
    _modelItems = [[NSMutableArray alloc] init];

    _userIndexMap = [[NSMutableDictionary alloc] init];

    _channelIndexMap = [[NSMutableDictionary alloc] init];

    [self addChannelTreeToModel:channel indentLevel:0];
}

- (void) addChannelTreeToModel:(MLChannel *)channel indentLevel:(NSInteger)indentLevel {
    [_channelIndexMap setObject:[NSNumber numberWithUnsignedInteger:[_modelItems count]] forKey:[NSNumber numberWithUnsignedInteger:[channel channelId]]];
    [_modelItems addObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:indentLevel], @"indentLevel", channel, @"object", nil]];

    for (MLUser *user in [channel users]) {
        [_userIndexMap setObject:[NSNumber numberWithUnsignedInteger:[_modelItems count]] forKey:[NSNumber numberWithUnsignedInteger:[user session]]];
        [_modelItems addObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:indentLevel+1], @"indentLevel", user, @"object", nil]];
    }
    for (MLChannel *chan in [channel channels]) {
        [self addChannelTreeToModel:chan indentLevel:indentLevel+1];
    }
}

- (NSInteger) indexForUser:(MLUser *)user {
    NSNumber *index = _userIndexMap[@(user.session)];
    NSInteger userIndex = index ? 1 + index.integerValue : NSNotFound;
    return userIndex;
}

- (NSInteger) indexForChannel:(MLChannel *)channel {
    NSNumber *index = _channelIndexMap[@(channel.channelId)];
    NSInteger channelIndex = index ? 1 + index.integerValue : NSNotFound;
    return channelIndex;
}

- (void)reloadUser:(MLUser *)user {
    if (!self.viewIfLoaded.window) return;
    NSInteger row = [self indexForUser:user];
    if (row == NSNotFound) return;
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
    cell.accessoryView = [MUUserStateAcessoryView viewForUser:user];
    UIListContentConfiguration *content = [(UIListContentConfiguration *)cell.contentConfiguration copy];
    content.image = [MUImage userTalkSymbolForState:user.talkState];
    content.imageProperties.tintColor = [MUImage userTalkColorForState:user.talkState];
    cell.contentConfiguration = content;
}
- (void)scheduleRefresh {
    if (!self.viewIfLoaded.window || _refreshScheduled) return;
    _refreshScheduled = YES;
    __weak MUMessageRecipientViewController *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        MUMessageRecipientViewController *controller = weakSelf;
        if (!controller || !controller->_refreshScheduled) return;
        controller->_refreshScheduled = NO;
        if (!controller.viewIfLoaded.window) return;
        [controller rebuildModelArrayFromChannel:controller->_serverModel.rootChannel];
        [controller.tableView reloadData];
    });
}

#pragma mark - View lifecycle

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _refreshScheduled = NO;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 48;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    self.navigationItem.title = NSLocalizedString(@"Message Recipient", nil);

    {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    }

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelClicked:)];

    [self rebuildModelArrayFromChannel:[_serverModel rootChannel]];
    [self.tableView reloadData];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    _refreshScheduled = NO;
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

#pragma mark - Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1 + [_modelItems count];
}

- (void) tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    cell.backgroundColor = [UIColor systemBackgroundColor];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MUServerTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MUMessageRecipientCell"];
    if (!cell) cell = [[MUServerTableViewCell alloc] initWithReuseIdentifier:@"MUMessageRecipientCell"];
    UIListContentConfiguration *content = [UIListContentConfiguration cellConfiguration];
    NSInteger indent = 0;
    BOOL bold = indexPath.row == 0;
    cell.channelRow = YES;
    cell.accessoryView = nil;
    content.imageProperties.tintColor = UIColor.secondaryLabelColor;
    if (!indexPath.row) {
        content.text = NSLocalizedString(@"Current Channel", nil);
        content.image = [MUImage channelSymbolForCurrentChannel:YES];
    } else {
        NSDictionary *item = _modelItems[indexPath.row - 1]; id object = item[@"object"];
        indent = [item[@"indentLevel"] integerValue];
        if ([object isKindOfClass:MLChannel.class]) {
            MLChannel *channel = object; content.text = channel.channelName;
            bold = channel == _serverModel.connectedUser.channel;
            content.image = [MUImage channelSymbolForCurrentChannel:bold];
        } else {
            MLUser *user = object; content.text = user.userName; content.image = [MUImage userTalkSymbolForState:user.talkState];
            content.imageProperties.tintColor = [MUImage userTalkColorForState:user.talkState];
            bold = user == _serverModel.connectedUser; cell.channelRow = NO;
            cell.accessoryView = [MUUserStateAcessoryView viewForUser:user];
        }
    }
    content.textProperties.font = [UIFont preferredFontForTextStyle:bold ? UIFontTextStyleHeadline : UIFontTextStyleBody compatibleWithTraitCollection:self.traitCollection];
    content.textProperties.numberOfLines = 0;
    content.imageProperties.maximumSize = CGSizeMake(40, 24); content.imageProperties.reservedLayoutSize = CGSizeMake(40, 24);
    content.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(10, 16 + indent * 14, 10, 16); content.imageToTextPadding = 8;
    cell.contentConfiguration = content; cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

#pragma mark - Table view delegate

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([indexPath row] == 0) {
        [_delegate messageRecipientViewControllerDidSelectCurrentChannel:self];
    } else {
        NSDictionary *dict = [_modelItems objectAtIndex:[indexPath row]-1];
        id object = [dict objectForKey:@"object"];
        if ([object class] == [MLChannel class]) {
            [_delegate messageRecipientViewController:self didSelectChannel:object];
        } else if ([object class] == [MLUser class]) {
            [_delegate messageRecipientViewController:self didSelectUser:object];
        }
    }

    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Actions

- (void) cancelClicked:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - MLServerModel delegate

- (void)serverModel:(MLServerModel *)model joinedServerAsUser:(MLUser *)user { [self scheduleRefresh]; }
- (void)serverModel:(MLServerModel *)model userJoined:(MLUser *)user { [self scheduleRefresh]; }
- (void)serverModel:(MLServerModel *)model userLeft:(MLUser *)user { [self scheduleRefresh]; }
- (void)serverModel:(MLServerModel *)model userTalkStateChanged:(MLUser *)user { [self reloadUser:user]; }
- (void)serverModel:(MLServerModel *)model userRenamed:(MLUser *)user { [self scheduleRefresh]; }
- (void)serverModel:(MLServerModel *)model channelAdded:(MLChannel *)channel { [self scheduleRefresh]; }
- (void)serverModel:(MLServerModel *)model channelRemoved:(MLChannel *)channel { [self scheduleRefresh]; }
- (void)serverModel:(MLServerModel *)model channelMoved:(MLChannel *)channel { [self scheduleRefresh]; }
- (void)serverModel:(MLServerModel *)model channelRenamed:(MLChannel *)channel { [self scheduleRefresh]; }
- (void)serverModel:(MLServerModel *)model channelPositionChanged:(MLChannel *)channel { [self scheduleRefresh]; }
- (void)serverModel:(MLServerModel *)model userMoved:(MLUser *)user toChannel:(MLChannel *)channel fromChannel:(MLChannel *)previous byUser:(MLUser *)actor { [self scheduleRefresh]; }
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath { return UITableViewAutomaticDimension; }

- (void) serverModel:(MLServerModel *)model userSelfMuted:(MLUser *)user {
}

- (void) serverModel:(MLServerModel *)model userRemovedSelfMute:(MLUser *)user {
}

- (void) serverModel:(MLServerModel *)model userSelfMutedAndDeafened:(MLUser *)user {
}

- (void) serverModel:(MLServerModel *)model userRemovedSelfMuteAndDeafen:(MLUser *)user {
}

- (void) serverModel:(MLServerModel *)model userSelfMuteDeafenStateChanged:(MLUser *)user {
    [self reloadUser:user];
}

// --

- (void) serverModel:(MLServerModel *)model userMutedAndDeafened:(MLUser *)user byUser:(MLUser *)actor {
    [self reloadUser:user];
}

- (void) serverModel:(MLServerModel *)model userUnmutedAndUndeafened:(MLUser *)user byUser:(MLUser *)actor {
    [self reloadUser:user];
}

- (void) serverModel:(MLServerModel *)model userMuted:(MLUser *)user byUser:(MLUser *)actor {
    [self reloadUser:user];
}

- (void) serverModel:(MLServerModel *)model userUnmuted:(MLUser *)user byUser:(MLUser *)actor {
    [self reloadUser:user];
}

- (void) serverModel:(MLServerModel *)model userDeafened:(MLUser *)user byUser:(MLUser *)actor {
    [self reloadUser:user];
}

- (void) serverModel:(MLServerModel *)model userUndeafened:(MLUser *)user byUser:(MLUser *)actor {
    [self reloadUser:user];
}

- (void) serverModel:(MLServerModel *)model userSuppressed:(MLUser *)user byUser:(MLUser *)actor {
    [self reloadUser:user];
}

- (void) serverModel:(MLServerModel *)model userUnsuppressed:(MLUser *)user byUser:(MLUser *)actor {
    [self reloadUser:user];
}

- (void) serverModel:(MLServerModel *)model userMuteStateChanged:(MLUser *)user {
    [self reloadUser:user];
}

@end
