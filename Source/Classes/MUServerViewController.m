// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUServerViewController.h"
#import "MUUserStateAcessoryView.h"
#import "MUNotificationController.h"
#import "MUColor.h"
#import "MUBackgroundView.h"
#import "MUServerTableViewCell.h"

#import <MumbleKit/MKAudio.h>

#pragma mark -
#pragma mark MUChannelNavigationItem

@interface MUChannelNavigationItem : NSObject {
    id         _object;
    NSInteger  _indentLevel;
}

+ (MUChannelNavigationItem *) navigationItemWithObject:(id)obj indentLevel:(NSInteger)indentLevel;
- (id) initWithObject:(id)obj indentLevel:(NSInteger)indentLevel;
- (id) object;
- (NSInteger) indentLevel;
@end

@implementation MUChannelNavigationItem

+ (MUChannelNavigationItem *) navigationItemWithObject:(id)obj indentLevel:(NSInteger)indentLevel {
    return [[MUChannelNavigationItem alloc] initWithObject:obj indentLevel:indentLevel];
}

- (id) initWithObject:(id)obj indentLevel:(NSInteger)indentLevel {
    if (self = [super init]) {
        _object = obj;
        _indentLevel = indentLevel;
    }
    return self;
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
        _serverModel = serverModel;
        [_serverModel addDelegate:self];
        _viewMode = MUServerViewControllerViewModeServer;
    }
    return self;
}

- (void) dealloc {
    [_serverModel removeDelegate:self];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
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
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    }
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    if (_talkButton) {
        [_talkButton removeFromSuperview];
        _talkButton = nil;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSInteger) indexForUser:(MKUser *)user {
    NSNumber *number = [_userIndexMap objectForKey:[NSNumber numberWithInteger:[user session]]];
    if (number) {
        return [number integerValue];
    }
    return NSNotFound;
}

- (NSInteger) indexForChannel:(MKChannel *)channel {
    NSNumber *number = [_channelIndexMap objectForKey:[NSNumber numberWithInteger:[channel channelId]]];
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
    _modelItems = [[NSMutableArray alloc] init];

    _userIndexMap = [[NSMutableDictionary alloc] init];

    _channelIndexMap = [[NSMutableDictionary alloc] init];

    [self addChannelTreeToModel:channel indentLevel:0];
}

- (void) switchToServerMode {
    _viewMode = MUServerViewControllerViewModeServer;
    [self rebuildModelArrayFromChannel:[_serverModel rootChannel]];
}

- (void) switchToChannelMode {
    _viewMode = MUServerViewControllerViewModeChannel;

    _modelItems = [[NSMutableArray alloc] init];

    _userIndexMap = [[NSMutableDictionary alloc] init];

    _channelIndexMap = [[NSMutableDictionary alloc] init];
    
    MKChannel *channel = [[_serverModel connectedUser] channel];
    for (MKUser *user in [channel users]) {
        [_userIndexMap setObject:[NSNumber numberWithUnsignedInteger:[_modelItems count]] forKey:[NSNumber numberWithUnsignedInteger:[user session]]];
        [_modelItems addObject:[MUChannelNavigationItem navigationItemWithObject:user indentLevel:0]];
    }
}

- (void) addChannelTreeToModel:(MKChannel *)channel indentLevel:(NSInteger)indentLevel {    
    [_channelIndexMap setObject:[NSNumber numberWithUnsignedInteger:[_modelItems count]] forKey:[NSNumber numberWithInteger:[channel channelId]]];
    [_modelItems addObject:[MUChannelNavigationItem navigationItemWithObject:channel indentLevel:indentLevel]];

    for (MKUser *user in [channel users]) {
        [_userIndexMap setObject:[NSNumber numberWithUnsignedInteger:[_modelItems count]] forKey:[NSNumber numberWithUnsignedInteger:[user session]]];
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
        if (@available(iOS 7, *)) {
            cell = [[MUServerTableViewCell alloc] initWithReuseIdentifier:CellIdentifier];
        } else {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        }
    }

    MUChannelNavigationItem *navItem = [_modelItems objectAtIndex:[indexPath row]];
    id object = [navItem object];

    MKUser *connectedUser = [_serverModel connectedUser];

    cell.textLabel.font = [UIFont systemFontOfSize:16];
    cell.textLabel.textColor = [MUColor primaryTextColor];
    
    if ([object class] == [MKChannel class]) {
        MKChannel *chan = object;
        
        if (@available(iOS 13.0, *)) {
            cell.imageView.image = [UIImage systemImageNamed:@"number"
                                    withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium]];
            cell.imageView.tintColor = [UIColor secondaryLabelColor];
        } else {
            cell.imageView.image = [UIImage imageNamed:@"channel"];
        }
        
        cell.textLabel.text = [chan channelName];
        if (chan == [connectedUser channel]) {
            cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
            if (@available(iOS 13.0, *)) {
                cell.imageView.tintColor = [UIColor systemBlueColor];
            }
        }
        cell.accessoryView = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        
    } else if ([object class] == [MKUser class]) {
        MKUser *user = object;

        cell.textLabel.text = [user userName];
        if (user == connectedUser) {
            cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        }
        
        MKTalkState talkState = [user talkState];
        
        // Fix PTT state when backgrounding
        if (user == connectedUser && [[MKAudio sharedAudio] transmitType] == MKTransmitTypeToggle) {
            if (![[MKAudio sharedAudio] forceTransmit]) {
                talkState = MKTalkStatePassive;
            }
        }
        
        // Generate initials avatar with talk state ring
        cell.imageView.image = [self initialsAvatarForUser:[user userName] talkState:talkState];
        
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

- (UIImage *) initialsAvatarForUser:(NSString *)userName talkState:(MKTalkState)talkState {
    CGFloat size = 30.0f;
    CGFloat ringWidth = 2.0f;
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    // Draw ring based on talk state
    UIColor *ringColor;
    BOOL isActive = (talkState == MKTalkStateTalking || talkState == MKTalkStateShouting);
    BOOL isWhispering = (talkState == MKTalkStateWhispering);
    
    if (isActive) {
        ringColor = [UIColor systemGreenColor];
    } else if (isWhispering) {
        ringColor = [UIColor systemYellowColor];
    } else {
        ringColor = [UIColor clearColor];
    }
    
    if (isActive || isWhispering) {
        CGContextSetStrokeColorWithColor(ctx, ringColor.CGColor);
        CGContextSetLineWidth(ctx, ringWidth);
        CGRect ringRect = CGRectInset(CGRectMake(0, 0, size, size), ringWidth / 2.0f, ringWidth / 2.0f);
        CGContextStrokeEllipseInRect(ctx, ringRect);
    }
    
    // Draw circle background
    CGFloat inset = isActive || isWhispering ? ringWidth + 1.5f : 2.0f;
    CGRect circleRect = CGRectInset(CGRectMake(0, 0, size, size), inset, inset);
    
    // Use a hash of the username for consistent color
    NSUInteger hash = [userName hash];
    CGFloat hue = (hash % 360) / 360.0f;
    UIColor *bgColor = [UIColor colorWithHue:hue saturation:0.5f brightness:0.7f alpha:1.0f];
    
    CGContextSetFillColorWithColor(ctx, bgColor.CGColor);
    CGContextFillEllipseInRect(ctx, circleRect);
    
    // Draw initials
    NSString *initials = @"?";
    if (userName && [userName length] > 0) {
        initials = [[userName substringToIndex:1] uppercaseString];
    }
    
    NSDictionary *attrs = @{
        NSFontAttributeName: [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold],
        NSForegroundColorAttributeName: [UIColor whiteColor]
    };
    CGSize textSize = [initials sizeWithAttributes:attrs];
    CGPoint textPoint = CGPointMake(
        CGRectGetMidX(circleRect) - textSize.width / 2.0f,
        CGRectGetMidY(circleRect) - textSize.height / 2.0f
    );
    [initials drawAtPoint:textPoint withAttributes:attrs];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

- (void) serverModel:(MKServerModel *)model userTalkStateChanged:(MKUser *)user {
    NSInteger userIndex = [self indexForUser:user];
    if (userIndex == NSNotFound) {
        return;
    }

    UITableViewCell *cell = [[self tableView] cellForRowAtIndexPath:[NSIndexPath indexPathForRow:userIndex inSection:0]];
    
    MKTalkState talkState = [user talkState];
    cell.imageView.image = [self initialsAvatarForUser:[user userName] talkState:talkState];
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
    // Currently disabled — no-op.
}

- (void) talkOn:(UIButton *)button {
    [button setAlpha:1.0f];
    [[MKAudio sharedAudio] setForceTransmit:YES];
    
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [feedback impactOccurred];
    }
}

- (void) talkOff:(UIButton *)button {
    [button setAlpha:0.80f];
    [[MKAudio sharedAudio] setForceTransmit:NO];
    
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [feedback impactOccurred];
    }
}

#pragma mark - Mode switch

- (void) toggleMode {
    if (_viewMode == MUServerViewControllerViewModeServer) {
        NSString *msg = NSLocalizedString(@"Switched to channel view mode.", nil);
        [[MUNotificationController sharedController] addNotification:msg];
        [self switchToChannelMode];
    } else if (_viewMode == MUServerViewControllerViewModeChannel) {
        NSString *msg = NSLocalizedString(@"Switched to server view mode.", nil);
        [[MUNotificationController sharedController] addNotification:msg];
        [self switchToServerMode];
    }

    [self.tableView reloadData];
    
    if (_viewMode == MUServerViewControllerViewModeServer) {
        MKChannel *cur = [[_serverModel connectedUser] channel];
        NSInteger idx = [self indexForChannel:cur];
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:idx inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
    }
}

#pragma mark - Background notification

- (void) appDidEnterBackground:(NSNotification *)notification {
    // Force Push-to-Talk to stop when the app is backgrounded.
    [[MKAudio sharedAudio] setForceTransmit:NO];
    
    // Reload the table view to re-render the talk state for the user
    // as not talking if they were holding down their Push-to-Talk buttons
    // at the moment the app was sent to the background.
    [[self tableView] reloadData];
}

@end

