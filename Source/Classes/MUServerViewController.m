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

#import "MUServerViewController.h"
#import "MUUserStateAcessoryView.h"
#import "MUColor.h"

#import <MumbleKit/MKAudio.h>

#pragma mark -
#pragma mark MUChannelNavigationItem

@interface MUChannelNavigationItem : NSObject {
    id         _object;
    NSInteger  _indentLevel;
}

+ (MUChannelNavigationItem *) navigationItemWithObject:(id)obj indentLevel:(NSInteger)indentLevel;
- (id) initWithObject:(id)obj indentLevel:(NSInteger)indentLevel;
- (void) dealloc;
- (id) object;
- (NSInteger) indentLevel;
@end

@implementation MUChannelNavigationItem

+ (MUChannelNavigationItem *) navigationItemWithObject:(id)obj indentLevel:(NSInteger)indentLevel {
    return [[[MUChannelNavigationItem alloc] initWithObject:obj indentLevel:indentLevel] autorelease];
}

- (id) initWithObject:(id)obj indentLevel:(NSInteger)indentLevel {
    if (self = [super init]) {
        _object = obj;
        _indentLevel = indentLevel;
    }
    return self;
}

- (void) dealloc {
    [super dealloc];
}

- (id) object {
    return _object;
}

- (NSInteger) indentLevel {
    return _indentLevel;
}

@end

#pragma mark -
#pragma mark MUChannelNavigationViewController

@interface MUServerViewController () {
    MUServerViewControllerViewMode   _viewMode;
    MKServerModel                    *_serverModel;
    NSMutableArray                   *_modelItems;
    NSMutableDictionary              *_userIndexMap;
    NSMutableDictionary              *_channelIndexMap;
    BOOL                             _pttState;
    UIButton                         *_talkButton;
}
- (NSInteger) indexForUser:(MKUser *)user;
- (void) reloadUser:(MKUser *)user;
- (void) reloadChannel:(MKChannel *)channel;
- (void) rebuildModelArrayFromChannel:(MKChannel *)channel;
- (void) addChannelTreeToModel:(MKChannel *)channel indentLevel:(NSInteger)indentLevel;
@end

@implementation MUServerViewController

#pragma mark -
#pragma mark Initialization and lifecycle

- (id) initWithServerModel:(MKServerModel *)serverModel {
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        _serverModel = [serverModel retain];
        [_serverModel addDelegate:self];
        _viewMode = MUServerViewControllerViewModeServer;
    }
    return self;
}

- (void) dealloc {
    [_serverModel removeDelegate:self];
    [_serverModel release];
    [super dealloc];
}

- (void) viewWillAppear:(BOOL)animated {
    if (_viewMode == MUServerViewControllerViewModeServer) {
        [self rebuildModelArrayFromChannel:[_serverModel rootChannel]];
        [self.tableView reloadData];
    } else if (_viewMode == MUServerViewControllerViewModeChannel) {
        [self switchToChannelMode];
        [self.tableView reloadData];
    }
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if ([[MKAudio sharedAudio] transmitType] == MKTransmitTypeToggle) {
        UIImage *onImage = [UIImage imageNamed:@"talkbutton_on"];
        UIImage *offImage = [UIImage imageNamed:@"talkbutton_off"];
        
        UIWindow *window = [[[UIApplication sharedApplication] windows] objectAtIndex:0];
        CGRect windowRect = [window frame];
        CGRect buttonRect = windowRect;
        buttonRect.size = onImage.size;
        buttonRect.origin.y = windowRect.size.height - (buttonRect.size.height + 40);
        buttonRect.origin.x = (windowRect.size.width - buttonRect.size.width)/2;
        
        _talkButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _talkButton.frame = buttonRect;
        [_talkButton setBackgroundImage:onImage forState:UIControlStateHighlighted];
        [_talkButton setBackgroundImage:offImage forState:UIControlStateNormal];
        [_talkButton setOpaque:NO];
        [_talkButton setAlpha:0.80f];
        [window addSubview:_talkButton];
        
        [_talkButton addTarget:self action:@selector(talkOn:) forControlEvents:UIControlEventTouchDown];
        [_talkButton addTarget:self action:@selector(talkOff:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(repositionTalkButton) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
        [self repositionTalkButton];
    }
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    if (_talkButton) {
        [_talkButton removeFromSuperview];
        _talkButton = nil;
        
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
}

- (NSInteger) indexForUser:(MKUser *)user {
    NSNumber *number = [_userIndexMap objectForKey:[NSNumber numberWithInt:[user session]]];
    if (number) {
        return [number integerValue];
    }
    return NSNotFound;
}

- (NSInteger) indexForChannel:(MKChannel *)channel {
    NSNumber *number = [_channelIndexMap objectForKey:[NSNumber numberWithInt:[channel channelId]]];
    if (number) {
        return [number integerValue];
    }
    return NSNotFound;
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

- (void) rebuildModelArrayFromChannel:(MKChannel *)channel {
    [_modelItems release];
    _modelItems = [[NSMutableArray alloc] init];
    
    [_userIndexMap release];
    _userIndexMap = [[NSMutableDictionary alloc] init];

    [_channelIndexMap release];
    _channelIndexMap = [[NSMutableDictionary alloc] init];

    [self addChannelTreeToModel:channel indentLevel:0];
}

- (void) switchToServerMode {
    _viewMode = MUServerViewControllerViewModeServer;
    [self rebuildModelArrayFromChannel:[_serverModel rootChannel]];
}

- (void) switchToChannelMode {
    _viewMode = MUServerViewControllerViewModeChannel;
    
    [_modelItems release];
    _modelItems = [[NSMutableArray alloc] init];
    
    [_userIndexMap release];
    _userIndexMap = [[NSMutableDictionary alloc] init];
    
    [_channelIndexMap release];
    _channelIndexMap = [[NSMutableDictionary alloc] init];
    
    MKChannel *channel = [[_serverModel connectedUser] channel];
    for (MKUser *user in [channel users]) {
        [_userIndexMap setObject:[NSNumber numberWithInt:[_modelItems count]] forKey:[NSNumber numberWithInt:[user session]]];
        [_modelItems addObject:[MUChannelNavigationItem navigationItemWithObject:user indentLevel:0]];
    }
}

- (void) addChannelTreeToModel:(MKChannel *)channel indentLevel:(NSInteger)indentLevel {    
    [_channelIndexMap setObject:[NSNumber numberWithInt:[_modelItems count]] forKey:[NSNumber numberWithInt:[channel channelId]]];
    [_modelItems addObject:[MUChannelNavigationItem navigationItemWithObject:channel indentLevel:indentLevel]];

    for (MKUser *user in [channel users]) {
        [_userIndexMap setObject:[NSNumber numberWithInt:[_modelItems count]] forKey:[NSNumber numberWithInt:[user session]]];
        [_modelItems addObject:[MUChannelNavigationItem navigationItemWithObject:user indentLevel:indentLevel+1]];
    }
    for (MKChannel *chan in [channel channels]) {
        [self addChannelTreeToModel:chan indentLevel:indentLevel+1];
    }
}

#pragma mark - Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_modelItems count];
}

- (void) tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    MUChannelNavigationItem *navItem = [_modelItems objectAtIndex:[indexPath row]];
    id object = [navItem object];
    if ([object class] == [MKChannel class]) {
        MKChannel *chan = object;
        if (chan == [_serverModel rootChannel] && [_serverModel serverCertificatesTrusted]) {
            cell.backgroundColor = [MUColor verifiedCertificateChainColor];
        }
    }
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"ChannelNavigationCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }

    MUChannelNavigationItem *navItem = [_modelItems objectAtIndex:[indexPath row]];
    id object = [navItem object];

    MKUser *connectedUser = [_serverModel connectedUser];

    cell.textLabel.font = [UIFont systemFontOfSize:18];
    if ([object class] == [MKChannel class]) {
        MKChannel *chan = object;
        cell.imageView.image = [UIImage imageNamed:@"channel"];
        cell.textLabel.text = [chan channelName];
        if (chan == [connectedUser channel])
            cell.textLabel.font = [UIFont boldSystemFontOfSize:18];
        cell.accessoryView = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        
    } else if ([object class] == [MKUser class]) {
        MKUser *user = object;

        cell.textLabel.text = [user userName];
        if (user == connectedUser)
            cell.textLabel.font = [UIFont boldSystemFontOfSize:18];
        
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
        cell.accessoryView = [MUUserStateAcessoryView viewForUser:user];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }

    cell.indentationLevel = [navItem indentLevel];

    return cell;
}

#pragma mark - Table view delegate

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    MUChannelNavigationItem *navItem = [_modelItems objectAtIndex:[indexPath row]];
    id object = [navItem object];
    if ([object class] == [MKChannel class]) {
        [_serverModel joinChannel:object];
    }

    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0f;
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
    if (idx != NSNotFound) {
        if (_viewMode == MUServerViewControllerViewModeServer) {
            [self rebuildModelArrayFromChannel:[model rootChannel]];
        } else if (_viewMode) {
            [self switchToChannelMode];
        }
        [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:idx inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
    }
}

- (void) serverModel:(MKServerModel *)model userTalkStateChanged:(MKUser *)user {
    NSInteger userIndex = [self indexForUser:user];
    if (userIndex == NSNotFound) {
        return;
    }

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
    if (_viewMode == MUServerViewControllerViewModeServer) {
        [self rebuildModelArrayFromChannel:[model rootChannel]];
        NSInteger idx = [self indexForChannel:channel];
        [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:idx inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
    }
}

- (void) serverModel:(MKServerModel *)model channelRemoved:(MKChannel *)channel {
    if (_viewMode == MUServerViewControllerViewModeServer) {
        [self rebuildModelArrayFromChannel:[model rootChannel]];
        [self.tableView reloadData];
    } else if (_viewMode == MUServerViewControllerViewModeChannel) {
        [self switchToChannelMode];
        [self.tableView reloadData];
    }
}

- (void) serverModel:(MKServerModel *)model channelMoved:(MKChannel *)channel {
    if (_viewMode == MUServerViewControllerViewModeServer) {
        [self rebuildModelArrayFromChannel:[model rootChannel]];
        [self.tableView reloadData];
    }
}

- (void) serverModel:(MKServerModel *)model channelRenamed:(MKChannel *)channel {
    if (_viewMode == MUServerViewControllerViewModeServer) {
        [self reloadChannel:channel];
    }
}

- (void) serverModel:(MKServerModel *)model userMoved:(MKUser *)user toChannel:(MKChannel *)chan fromChannel:(MKChannel *)prevChan byUser:(MKUser *)mover {
    
    if (_viewMode == MUServerViewControllerViewModeServer) {
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
    } else if (_viewMode == MUServerViewControllerViewModeChannel) {
        NSInteger userIdx = [self indexForUser:user];
        MKChannel *curChan = [[_serverModel connectedUser] channel];
        
        if (user == [model connectedUser]) {
            [self switchToChannelMode];
            [self.tableView reloadData];
        } else {
            // User is leaving
            [self.tableView beginUpdates];
            if (prevChan == curChan && userIdx != NSNotFound) {
                [self switchToChannelMode];
                [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:userIdx inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
                // User is joining
            } else if (chan == curChan && userIdx == NSNotFound) {
                [self switchToChannelMode];
                userIdx = [self indexForUser:user];
                if (userIdx != NSNotFound) {
                    [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:userIdx inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
                }
            }
            [self.tableView endUpdates];
        }
    }
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

- (void) serverModel:(MKServerModel *)model userAuthenticatedStateChanged:(MKUser *)user {
    [self reloadUser:user];
}

- (void) serverModel:(MKServerModel *)model userPrioritySpeakerChanged:(MKUser *)user {
    [self reloadUser:user];
}

#pragma mark - PushToTalk

- (void) repositionTalkButton {
    // fixme(mkrautz): This should stay put if we're run on the iPhone.
    return;
    
    UIDevice *device = [UIDevice currentDevice];
    UIWindow *window = [[[UIApplication sharedApplication] windows] objectAtIndex:0];
    CGRect windowRect = window.frame;
    CGRect buttonRect;
    CGSize buttonSize;
    
    UIImage *onImage = [UIImage imageNamed:@"talkbutton_on"];
    buttonRect.size = onImage.size;
    buttonRect.origin = CGPointMake(0, 0);
    _talkButton.transform = CGAffineTransformIdentity;
    buttonSize = onImage.size;
    buttonRect.size = buttonSize;
    
    
    UIDeviceOrientation orientation = device.orientation;
    if (orientation == UIDeviceOrientationLandscapeLeft) {
        _talkButton.transform = CGAffineTransformMakeRotation(M_PI_2);
        buttonRect = _talkButton.frame;
        buttonRect.origin.y = (windowRect.size.height - buttonSize.width)/2;
        buttonRect.origin.x = 40;
        _talkButton.frame = buttonRect;
    } else if (orientation == UIDeviceOrientationLandscapeRight) {
        _talkButton.transform = CGAffineTransformMakeRotation(-M_PI_2);
        buttonRect = _talkButton.frame;
        buttonRect.origin.y = (windowRect.size.height - buttonSize.width)/2;
        buttonRect.origin.x = windowRect.size.width - (buttonSize.height + 40);
        _talkButton.frame = buttonRect;
    } else if (orientation == UIDeviceOrientationPortrait) {
        _talkButton.transform = CGAffineTransformMakeRotation(0.0f);
        buttonRect = _talkButton.frame;
        buttonRect.origin.y = windowRect.size.height - (buttonSize.height + 40);
        buttonRect.origin.x = (windowRect.size.width - buttonSize.width)/2;
        _talkButton.frame = buttonRect;
    } else if (orientation == UIDeviceOrientationPortraitUpsideDown) {
        _talkButton.transform = CGAffineTransformMakeRotation(M_PI);
        buttonRect = _talkButton.frame;
        buttonRect.origin.y = 40;
        buttonRect.origin.x = (windowRect.size.width - buttonSize.width)/2;
        _talkButton.frame = buttonRect;
    }
}

- (void) talkOn:(UIButton *)button {
    [button setAlpha:1.0f];
    [[MKAudio sharedAudio] setForceTransmit:YES];
}

- (void) talkOff:(UIButton *)button {
    [button setAlpha:0.80f];
    [[MKAudio sharedAudio] setForceTransmit:NO];
}

#pragma mark - Mode switch

- (void) toggleMode {
    if (_viewMode == MUServerViewControllerViewModeServer) {
        [self switchToChannelMode];
    } else if (_viewMode == MUServerViewControllerViewModeChannel) {
        [self switchToServerMode];
    }

    [self.tableView reloadData];
    
    if (_viewMode == MUServerViewControllerViewModeServer) {
        MKChannel *cur = [[_serverModel connectedUser] channel];
        NSInteger idx = [self indexForChannel:cur];
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:idx inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
    }
}

@end

