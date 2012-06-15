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

#import "MUChannelViewController.h"
#import "MUUserStateAcessoryView.h"

#import <MumbleKit/MKAudio.h>

@interface MUChannelViewController () <MKServerModelDelegate> {
    NSMutableArray  *_users;
    MKChannel       *_channel;
    MKServerModel   *_model;
    BOOL            _pttState;
    UIButton        *_talkButton;
}
- (void) repositionTalkButton;
@end

@implementation MUChannelViewController

- (id) initWithServerModel:(MKServerModel *)model {
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        _model = [model retain];
    }
    return self;
}

- (void) dealloc {
    [_model release];
    [super dealloc];
}

- (void) didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void) viewDidAppear:(BOOL)animated {
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

- (void) viewWillAppear:(BOOL)flag {
    [_model addDelegate:self];
    
    _channel = [[_model connectedUser] channel];
    _users = [[_channel users] mutableCopy];
    
    [self.tableView reloadData];
}

- (void) viewWillDisappear:(BOOL)animated {
    if (_talkButton) {
        [_talkButton removeFromSuperview];
        _talkButton = nil;
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
}

- (void) viewDidDisappear:(BOOL)animated {
    [_model removeDelegate:self];
    
    _channel = nil;
    
    [_users release];
    _users = nil;
    
    [self.tableView reloadData];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

#pragma mark - MKServerModel Delegate

// A user joined the server.
- (void) serverModel:(MKServerModel *)server userJoined:(MKUser *)user {
    // fixme(mkrautz): Implement.
}

// A user left the server.
- (void) serverModel:(MKServerModel *)server userLeft:(MKUser *)user {
    if (_channel == nil)
        return;

    NSUInteger userIndex = [_users indexOfObject:user];
    if (userIndex != NSNotFound) {
        [_users removeObjectAtIndex:userIndex];
        [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:userIndex inSection:0]]
                              withRowAnimation:UITableViewRowAnimationRight];
    }
}

// A user moved channel
- (void) serverModel:(MKServerModel *)server userMoved:(MKUser *)user toChannel:(MKChannel *)chan byUser:(MKUser *)mover {
    if (_channel == nil)
        return;
    
    // Was this ourselves, or someone else?
    if (user != [server connectedUser]) {
        // Did the user join this channel?
        if (chan == _channel) {
            [_users addObject:user];
            NSUInteger userIndex = [_users indexOfObject:user];
            [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:userIndex inSection:0]]
                                  withRowAnimation:UITableViewRowAnimationLeft];
            // Or did he leave it?
        } else {
            NSUInteger userIndex = [_users indexOfObject:user];
            if (userIndex != NSNotFound) {
                [_users removeObjectAtIndex:userIndex];
                [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:userIndex inSection:0]]
                                      withRowAnimation:UITableViewRowAnimationRight];
            }
        }
        
        // We were moved. We need to redo the array holding the users of the
        // current channel.
    } else {
        NSUInteger numUsers = [_users count];
        [_users release];
        _users = nil;
        
        NSMutableArray *array = [[NSMutableArray alloc] init];
        for (NSUInteger i = 0; i < numUsers; i++) {
            [array addObject:[NSIndexPath indexPathForRow:i inSection:0]];
        }
        [[self tableView] deleteRowsAtIndexPaths:array withRowAnimation:UITableViewRowAnimationRight];
        
        _channel = chan;
        _users = [[chan users] mutableCopy];
        
        [array removeAllObjects];
        numUsers = [_users count];
        for (NSUInteger i = 0; i < numUsers; i++) {
            [array addObject:[NSIndexPath indexPathForRow:i inSection:0]];
        }
        [self.tableView insertRowsAtIndexPaths:array withRowAnimation:UITableViewRowAnimationLeft];
        [array release];
    }
}

// A channel was added.
- (void) serverModel:(MKServerModel *)server channelAdded:(MKChannel *)channel {
    NSLog(@"ServerViewController: channelAdded.");
}

// A channel was removed.
- (void) serverModel:(MKServerModel *)server channelRemoved:(MKChannel *)channel {
    NSLog(@"ServerViewController: channelRemoved.");
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
    NSUInteger userIndex = [_users indexOfObject:user];
    if (userIndex != NSNotFound) {
        [[self tableView] reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:userIndex inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
    }
}

// --

- (void) serverModel:(MKServerModel *)model userMutedAndDeafened:(MKUser *)user byUser:(MKUser *)actor {
    NSLog(@"%@ muted and deafened by %@", user, actor);
}

- (void) serverModel:(MKServerModel *)model userUnmutedAndUndeafened:(MKUser *)user byUser:(MKUser *)actor {
    NSLog(@"%@ unmuted and undeafened by %@", user, actor);
}

- (void) serverModel:(MKServerModel *)model userMuted:(MKUser *)user byUser:(MKUser *)actor {
    NSLog(@"%@ muted by %@", user, actor);
}

- (void) serverModel:(MKServerModel *)model userUnmuted:(MKUser *)user byUser:(MKUser *)actor {
    NSLog(@"%@ unmuted by %@", user, actor);
}

- (void) serverModel:(MKServerModel *)model userDeafened:(MKUser *)user byUser:(MKUser *)actor {
    NSLog(@"%@ deafened by %@", user, actor);
}

- (void) serverModel:(MKServerModel *)model userUndeafened:(MKUser *)user byUser:(MKUser *)actor {
    NSLog(@"%@ undeafened by %@", user, actor);
}

- (void) serverModel:(MKServerModel *)model userSuppressed:(MKUser *)user byUser:(MKUser *)actor {
    NSLog(@"%@ suppressed by %@", user, actor);
}

- (void) serverModel:(MKServerModel *)model userUnsuppressed:(MKUser *)user byUser:(MKUser *)actor {
    NSLog(@"%@ unsuppressed by %@", user, actor);
}

- (void) serverModel:(MKServerModel *)model userMuteStateChanged:(MKUser *)user {
    NSInteger userIndex = [_users indexOfObject:user];
    if (userIndex != NSNotFound) {
        [[self tableView] reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:userIndex inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
    }
}

// --

- (void) serverModel:(MKServerModel *)model userAuthenticatedStateChanged:(MKUser *)user {
    NSInteger userIndex = [_users indexOfObject:user];
    if (userIndex != NSNotFound) {
        [[self tableView] reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:userIndex inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
    }
}

- (void) serverModel:(MKServerModel *)model userPrioritySpeakerChanged:(MKUser *)user {
    NSInteger userIndex = [_users indexOfObject:user];
    if (userIndex != NSNotFound) {
        [[self tableView] reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:userIndex inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
    }
}

- (void) serverModel:(MKServerModel *)server userTalkStateChanged:(MKUser *)user {
    NSUInteger userIndex = [_users indexOfObject:user];
    if (userIndex == NSNotFound)
        return;

    NSLog(@"UserTalkStateChanged!");
    
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
    
    [[cell imageView] setImage:[UIImage imageNamed:talkImageName]];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_users count];
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }

    NSUInteger row = [indexPath row];
    MKUser *user = [_users objectAtIndex:row];

    cell.textLabel.text = [user userName];
    if ([_model connectedUser] == user) {
        cell.textLabel.font = [UIFont boldSystemFontOfSize:18.0f];
    } else {
        cell.textLabel.font = [UIFont systemFontOfSize:18.0f];
    }

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
    
    return cell;
}

#pragma mark -
#pragma mark UITableView delegate

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0f;
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

@end
