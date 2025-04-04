// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUServerRootViewController.h"
#import "MUServerViewController.h"
#import "MUServerCertificateTrustViewController.h"
#import "MUAccessTokenViewController.h"
#import "MUCertificateViewController.h"
#import "MUNotificationController.h"
#import "MUConnectionController.h"
#import "MUMessagesViewController.h"
#import "MUDatabase.h"
#import "MUAudioMixerDebugViewController.h"
#import "MUOperatingSystem.h"

#import <MumbleKit/MKConnection.h>
#import <MumbleKit/MKServerModel.h>
#import <MumbleKit/MKCertificate.h>
#import <MumbleKit/MKAudio.h>

#import "MKNumberBadgeView.h"

@interface MUServerRootViewController () <MKConnectionDelegate, MKServerModelDelegate> {
    MKConnection                *_connection;
    MKServerModel               *_model;
    
    NSInteger                   _segmentIndex;
    UISegmentedControl          *_segmentedControl;
    UIBarButtonItem             *_menuButton;
    UIBarButtonItem             *_smallIcon;
    UIButton                    *_modeSwitchButton;
    MKNumberBadgeView           *_numberBadgeView;

    MUServerViewController      *_serverView;
    MUMessagesViewController    *_messagesView;
    
    NSInteger                   _unreadMessages;
}
@end

@implementation MUServerRootViewController

- (id) initWithConnection:(MKConnection *)conn andServerModel:(MKServerModel *)model {
    if ((self = [super init])) {
        _connection = conn;
        _model = model;
        [_model addDelegate:self];
        
        _unreadMessages = 0;
        
        _serverView = [[MUServerViewController alloc] initWithServerModel:_model];
        _messagesView = [[MUMessagesViewController alloc] initWithServerModel:_model];
        
        _numberBadgeView = [[MKNumberBadgeView alloc] initWithFrame:CGRectZero];
        _numberBadgeView.shadow = NO;
        _numberBadgeView.font = [UIFont boldSystemFontOfSize:10.0f];
        _numberBadgeView.hidden = YES;
    }
    return self;
}

- (void) dealloc {
    [_model removeDelegate:self];
    [_connection setDelegate:nil];
}

- (void) takeOwnershipOfConnectionDelegate {
    [_connection setDelegate:self];
}

#pragma mark - View lifecycle

- (void) viewDidLoad {
    [super viewDidLoad];

    _segmentedControl = [[UISegmentedControl alloc] initWithItems:
                         [NSArray arrayWithObjects:
                            NSLocalizedString(@"Server", nil),
                            NSLocalizedString(@"Messages", nil),
                          nil]];
    
    _segmentIndex = 0;
    
    _segmentedControl.selectedSegmentIndex = _segmentIndex;
    [_segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    
    _serverView.navigationItem.titleView = _segmentedControl;
    
    _menuButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"MumbleMenuButton"] style:UIBarButtonItemStylePlain target:self action:@selector(actionButtonClicked:)];
    _serverView.navigationItem.rightBarButtonItem = _menuButton;
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setFrame:CGRectMake(0, 0, 35, 30)];
    [button setBackgroundImage:[UIImage imageNamed:@"SmallMumbleIcon"] forState:UIControlStateNormal];
    [button setAdjustsImageWhenDisabled:NO];
    [button setEnabled:YES];
    [button addTarget:self action:@selector(modeSwitchButtonReleased:) forControlEvents:UIControlEventTouchUpInside];
    _smallIcon = [[UIBarButtonItem alloc] initWithCustomView:button];
    _modeSwitchButton = button;
    _serverView.navigationItem.leftBarButtonItem = _smallIcon;
    
    [_segmentedControl addSubview:_numberBadgeView];
    _numberBadgeView.frame = CGRectMake(_segmentedControl.frame.size.width-24, -10, 50, 30);
    _numberBadgeView.value = _unreadMessages;
    _numberBadgeView.hidden = _unreadMessages == 0;
    
    [self setViewControllers:[NSArray arrayWithObject:_serverView] animated:NO];
    
    UINavigationBar *navBar = self.navigationBar;
    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        navBar.tintColor = [UIColor whiteColor];
        navBar.translucent = NO;
        navBar.backgroundColor = [UIColor blackColor];
    }
    navBar.barStyle = UIBarStyleBlackOpaque;

    self.toolbar.barStyle = UIBarStyleBlackOpaque;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // On iPad, we support all interface orientations.
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        return YES;
    }

    return interfaceOrientation == UIInterfaceOrientationPortrait;
}

- (void) segmentChanged:(id)sender {
    if (_segmentedControl.selectedSegmentIndex == 0) { // Server view
        _serverView.navigationItem.titleView = _segmentedControl;
        _serverView.navigationItem.leftBarButtonItem = _smallIcon;
        _serverView.navigationItem.rightBarButtonItem = _menuButton;
        [self setViewControllers:[NSArray arrayWithObject:_serverView] animated:NO];
        [_modeSwitchButton setEnabled:YES];
    } else if (_segmentedControl.selectedSegmentIndex == 1) { // Messages view
        _messagesView.navigationItem.titleView = _segmentedControl;
        _messagesView.navigationItem.leftBarButtonItem = _smallIcon;
        _messagesView.navigationItem.rightBarButtonItem = _menuButton;
        [self setViewControllers:[NSArray arrayWithObject:_messagesView] animated:NO];
        [_modeSwitchButton setEnabled:NO];
    }
    
    if (_segmentedControl.selectedSegmentIndex == 1) { // Messages view
        _unreadMessages = 0;
        _numberBadgeView.value = 0;
        _numberBadgeView.hidden = YES;
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    } else if (_numberBadgeView.value > 0) {
        _numberBadgeView.hidden = NO;
    }

    [_segmentedControl performSelector:@selector(bringSubviewToFront:) withObject:_numberBadgeView afterDelay:0.0f];

    [[MKAudio sharedAudio] setForceTransmit:NO];
}

#pragma mark - MKConnection delegate

- (void) connectionOpened:(MKConnection *)conn {
}

- (void) connection:(MKConnection *)conn rejectedWithReason:(MKRejectReason)reason explanation:(NSString *)explanation {
}

- (void) connection:(MKConnection *)conn trustFailureInCertificateChain:(NSArray *)chain {
}

- (void) connection:(MKConnection *)conn unableToConnectWithError:(NSError *)err {
}

- (void) connection:(MKConnection *)conn closedWithError:(NSError *)err {
    if (err) {
        UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Connection closed", nil)
                                                                           message:[err localizedDescription]
                                                                    preferredStyle:UIAlertControllerStyleAlert];
        [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                       style:UIAlertActionStyleCancel
                                                     handler:nil]];
        
        [self presentViewController:alertCtrl animated:YES completion:nil];

        [[MUConnectionController sharedController] disconnectFromServer];
    }
}

#pragma mark - MKServerModel delegate

- (void) serverModel:(MKServerModel *)model userKicked:(MKUser *)user byUser:(MKUser *)actor forReason:(NSString *)reason {
    if (user == [model connectedUser]) {
        NSString *reasonMsg = reason ? reason : NSLocalizedString(@"(No reason)", nil);
        NSString *title = NSLocalizedString(@"You were kicked", nil);
        NSString *alertMsg = [NSString stringWithFormat:
                                NSLocalizedString(@"Kicked by %@ for reason: \"%@\"", @"Kicked by user for reason"),
                                    [actor userName], reasonMsg];
        
        UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                                           message:alertMsg
                                                                    preferredStyle:UIAlertControllerStyleAlert];
        [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                       style:UIAlertActionStyleCancel
                                                     handler:nil]];
        
        [self presentViewController:alertCtrl animated:YES completion:nil];
        
        [[MUConnectionController sharedController] disconnectFromServer];
    }
}

- (void) serverModel:(MKServerModel *)model userBanned:(MKUser *)user byUser:(MKUser *)actor forReason:(NSString *)reason {
    if (user == [model connectedUser]) {
        NSString *reasonMsg = reason ? reason : NSLocalizedString(@"(No reason)", nil);
        NSString *title = NSLocalizedString(@"You were banned", nil);
        NSString *alertMsg = [NSString stringWithFormat:
                                NSLocalizedString(@"Banned by %@ for reason: \"%@\"", nil),
                                    [actor userName], reasonMsg];
        
        UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                                           message:alertMsg
                                                                    preferredStyle:UIAlertControllerStyleAlert];
        [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                       style:UIAlertActionStyleCancel
                                                     handler:nil]];
        
        [self presentViewController:alertCtrl animated:YES completion:nil];
        
        [[MUConnectionController sharedController] disconnectFromServer];
    }
}

- (void) serverModel:(MKServerModel *)model permissionDenied:(MKPermission)perm forUser:(MKUser *)user inChannel:(MKChannel *)channel {
    [[MUNotificationController sharedController] addNotification:NSLocalizedString(@"Permission denied", nil)];
}

- (void) serverModelInvalidChannelNameError:(MKServerModel *)model {
    [[MUNotificationController sharedController] addNotification:NSLocalizedString(@"Invalid channel name", nil)];
}

- (void) serverModelModifySuperUserError:(MKServerModel *)model {
    [[MUNotificationController sharedController] addNotification:NSLocalizedString(@"Cannot modify SuperUser", nil)];
}

- (void) serverModelTextMessageTooLongError:(MKServerModel *)model {
    [[MUNotificationController sharedController] addNotification:NSLocalizedString(@"Message too long", nil)];
}

- (void) serverModelTemporaryChannelError:(MKServerModel *)model {
    [[MUNotificationController sharedController] addNotification:NSLocalizedString(@"Not permitted in temporary channel", nil)];
}

- (void) serverModel:(MKServerModel *)model missingCertificateErrorForUser:(MKUser *)user {
    if (user == nil) {
        [[MUNotificationController sharedController] addNotification:NSLocalizedString(@"Missing certificate", nil)];
    } else {
        [[MUNotificationController sharedController] addNotification:NSLocalizedString(@"Missing certificate for user", nil)];
    }
}

- (void) serverModel:(MKServerModel *)model invalidUsernameErrorForName:(NSString *)name {
    if (name == nil) {
        [[MUNotificationController sharedController] addNotification:@"Invalid username"];
    } else {
        [[MUNotificationController sharedController] addNotification:[NSString stringWithFormat:@"Invalid username: %@", name]];   
    }
}

- (void) serverModelChannelFullError:(MKServerModel *)model {
    [[MUNotificationController sharedController] addNotification:NSLocalizedString(@"Channel is full", nil)];
}

- (void) serverModel:(MKServerModel *)model permissionDeniedForReason:(NSString *)reason {
    if (reason == nil) {
        [[MUNotificationController sharedController] addNotification:NSLocalizedString(@"Permission denied", nil)];
    } else {
        [[MUNotificationController sharedController] addNotification:[NSString stringWithFormat:
                                                                        NSLocalizedString(@"Permission denied: %@",
                                                                                          @"Permission denied with reason"),
                                                                        reason]];
    }
}

- (void) serverModel:(MKServerModel *)model textMessageReceived:(MKTextMessage *)msg fromUser:(MKUser *)user {
    if (_segmentedControl.selectedSegmentIndex != 1) { // When not in messages view
        _unreadMessages++;
        _numberBadgeView.value = _unreadMessages;
        _numberBadgeView.hidden = NO;
    }
}

#pragma mark - Actions

- (void) actionButtonClicked:(id)sender {
    MKUser *connUser = [_model connectedUser];
    BOOL inMessagesView = [[self viewControllers] objectAtIndex:0] == _messagesView;
    
    UIAlertController *sheetCtrl = [UIAlertController alertControllerWithTitle:nil
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
    
    [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Disconnect", nil)
                                                   style:UIAlertActionStyleDestructive
                                                 handler:^(UIAlertAction * _Nonnull action) {
        [[MUConnectionController sharedController] disconnectFromServer];
    }]];
    
    if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"AudioMixerDebug"] boolValue]) {
        [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Mixer Debug", nil)
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * _Nonnull action) {
            MUAudioMixerDebugViewController *audioMixerDebugViewController = [[MUAudioMixerDebugViewController alloc] init];
            UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:audioMixerDebugViewController];
            [self presentViewController:navCtrl animated:YES completion:nil];
        }]];
    }
    
    [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Access Tokens", nil)
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * _Nonnull action) {
        MUAccessTokenViewController *tokenViewController = [[MUAccessTokenViewController alloc] initWithServerModel:self->_model];
        UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:tokenViewController];
        [self presentViewController:navCtrl animated:YES completion:nil];
    }]];
    
    if (!inMessagesView) {
        [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Certificates", nil)
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * _Nonnull action) {
            MUCertificateViewController *certView = [[MUCertificateViewController alloc] initWithCertificates:[self->_model serverCertificates]];
            UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:certView];
            UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                        target:self
                                                                                        action:@selector(childDoneButton:)];
            certView.navigationItem.leftBarButtonItem = doneButton;
            [self presentViewController:navCtrl animated:YES completion:nil];
        }]];
    }
    
    if (![connUser isAuthenticated]) {
        [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Self-Register", nil)
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * _Nonnull action) {
            NSString *title = NSLocalizedString(@"User Registration", nil);
            NSString *msg = [NSString stringWithFormat:
                             NSLocalizedString(@"You are about to register yourself on this server. "
                                               @"This cannot be undone, and your username cannot be changed once this is done. "
                                               @"You will forever be known as '%@' on this server.\n\n"
                                               @"Are you sure you want to register yourself?",
                                               @"Self-registration with given username"),
                             [connUser userName]];
            UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                                               message:msg
                                                                        preferredStyle:UIAlertControllerStyleAlert];
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"No", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil]];
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
                [self->_model registerConnectedUser];
            }]];
            
            [self presentViewController:alertCtrl animated:YES completion:nil];
        }]];
    }
    
    if (inMessagesView) {
        [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Clear Messages", nil)
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * _Nonnull action) {
            
        }]];
    }
    
    if ([connUser isSelfMuted] && [connUser isSelfDeafened]) {
        [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Unmute and undeafen", nil)
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * _Nonnull action) {
            [self->_model setSelfMuted:NO andSelfDeafened:NO];
        }]];
    } else {
        void (^muteHandler)(UIAlertAction * _Nonnull action) = ^(UIAlertAction * _Nonnull action) {
            [self->_model setSelfMuted:![connUser isSelfMuted] andSelfDeafened:[connUser isSelfDeafened]];
        };
        void (^deafenHandler)(UIAlertAction * _Nonnull action) = ^(UIAlertAction * _Nonnull action) {
            [self->_model setSelfMuted:[connUser isSelfMuted] andSelfDeafened:![connUser isSelfDeafened]];
        };
        if (![connUser isSelfMuted]) {
            [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Self-Mute", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:muteHandler]];
        } else {
            [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Unmute Self", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:muteHandler]];
        }
        
        if (![connUser isSelfDeafened]) {
            [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Self-Deafen", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:deafenHandler]];
        } else {
            [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Undeafen Self", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:deafenHandler]];
        }
    }
    
    [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                   style:UIAlertActionStyleCancel
                                                 handler:nil]];
    
    [self presentViewController:sheetCtrl animated:YES completion:nil];
}

- (void) childDoneButton:(id)sender {
    [[self presentedViewController] dismissViewControllerAnimated:YES completion:nil];
}

- (void) modeSwitchButtonReleased:(id)sender {
    [_serverView toggleMode];
}

@end
