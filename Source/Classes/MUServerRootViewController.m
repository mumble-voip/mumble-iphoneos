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

@interface MUServerRootViewController () <MKConnectionDelegate, MKServerModelDelegate, UIActionSheetDelegate, UIAlertViewDelegate> {
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
    
    NSInteger                   _disconnectIndex;
    NSInteger                   _mixerDebugIndex;
    NSInteger                   _accessTokensIndex;
    NSInteger                   _certificatesIndex;
    NSInteger                   _selfRegisterIndex;
    NSInteger                   _clearMessagesIndex;
    NSInteger                   _selfMuteIndex;
    NSInteger                   _selfDeafenIndex;
    NSInteger                   _selfUnmuteAndUndeafenIndex;
}
@end

@implementation MUServerRootViewController

- (id) initWithConnection:(MKConnection *)conn andServerModel:(MKServerModel *)model {
    if ((self = [super init])) {
        _connection = [conn retain];
        _model = [model retain];
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
    [_serverView release];
    [_messagesView release];
   
    [_model removeDelegate:self];
    [_model release];
    [_connection setDelegate:nil];
    [_connection release];
    
    [_menuButton release];
    [_segmentedControl release];
    [_smallIcon release];
    [_numberBadgeView release];

    [super dealloc];
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
    
    _segmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
    _segmentedControl.selectedSegmentIndex = _segmentIndex;
    [_segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    
    _serverView.navigationItem.titleView = _segmentedControl;
    
    _menuButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"MumbleMenuButton"] style:UIBarButtonItemStyleBordered target:self action:@selector(actionButtonClicked:)];
    _serverView.navigationItem.rightBarButtonItem = _menuButton;
    
    UIButton *button = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
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

- (void) viewDidUnload {
    [super viewDidUnload];
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
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Connection closed", nil)
                                                            message:[err localizedDescription]
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                  otherButtonTitles:nil];
        [alertView show];
        [alertView release];

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
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title
                                                            message:alertMsg
                                                           delegate:nil
                                                   cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                  otherButtonTitles:nil];
        [alertView show];
        [alertView release];
        
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
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title
                                                            message:alertMsg
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                  otherButtonTitles:nil];
        [alertView show];
        [alertView release];
        
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
    UIActionSheet *actionSheet = [[UIActionSheet alloc] init];
    [actionSheet setActionSheetStyle:UIActionSheetStyleBlackOpaque];
    BOOL inMessagesView = [[self viewControllers] objectAtIndex:0] == _messagesView;
    
    _disconnectIndex = [actionSheet addButtonWithTitle:NSLocalizedString(@"Disconnect", nil)];
    [actionSheet setDestructiveButtonIndex:0];
    
    if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"AudioMixerDebug"] boolValue]) {
        _mixerDebugIndex = [actionSheet addButtonWithTitle:NSLocalizedString(@"Mixer Debug", nil)];
    } else {
        _mixerDebugIndex = -1;
    }
    
    _accessTokensIndex = [actionSheet addButtonWithTitle:NSLocalizedString(@"Access Tokens", nil)];
    
    if (!inMessagesView)
        _certificatesIndex = [actionSheet addButtonWithTitle:NSLocalizedString(@"Certificates", nil)];
    else
        _certificatesIndex = -1;

    if (![connUser isAuthenticated]) {
        _selfRegisterIndex = [actionSheet addButtonWithTitle:NSLocalizedString(@"Self-Register", nil)];
    } else {
        _selfRegisterIndex = -1;
    }
    
    if (inMessagesView)
        _clearMessagesIndex = [actionSheet addButtonWithTitle:NSLocalizedString(@"Clear Messages", nil)];
    else
        _clearMessagesIndex = -1;
    
    _selfMuteIndex = -1;
    _selfDeafenIndex = -1;
    _selfUnmuteAndUndeafenIndex = -1;

    if ([connUser isSelfMuted] && [connUser isSelfDeafened]) {
        _selfUnmuteAndUndeafenIndex = [actionSheet addButtonWithTitle:NSLocalizedString(@"Unmute and undeafen", nil)];
    } else {
        if (![connUser isSelfMuted])
            _selfMuteIndex = [actionSheet addButtonWithTitle:NSLocalizedString(@"Self-Mute", nil)];
        else
            _selfMuteIndex = [actionSheet addButtonWithTitle:NSLocalizedString(@"Unmute Self", nil)];

        if (![connUser isSelfDeafened])
            _selfDeafenIndex = [actionSheet addButtonWithTitle:NSLocalizedString(@"Self-Deafen", nil)];
        else
            _selfDeafenIndex = [actionSheet addButtonWithTitle:NSLocalizedString(@"Undeafen Self", nil)];
    }
    
    NSInteger cancelIndex = [actionSheet addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
    [actionSheet setCancelButtonIndex:cancelIndex];

    [actionSheet setDelegate:self];
    [actionSheet showFromBarButtonItem:_menuButton animated:YES];
    [actionSheet release];
}

- (void) childDoneButton:(id)sender {
    [[self modalViewController] dismissModalViewControllerAnimated:YES];
}

- (void) modeSwitchButtonReleased:(id)sender {
    [_serverView toggleMode];
}

#pragma mark - UIAlertViewDelegate

- (void) alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) { // Self-Register
        [_model registerConnectedUser];
    }
}

#pragma mark - UIActionSheetDelegate

- (void) actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    MKUser *connUser = [_model connectedUser];
    
    if (buttonIndex == [actionSheet cancelButtonIndex])
        return;

    if (buttonIndex == _disconnectIndex) { // Disconnect
        [[MUConnectionController sharedController] disconnectFromServer];
    } else if (buttonIndex == _mixerDebugIndex) {
        MUAudioMixerDebugViewController *audioMixerDebugViewController = [[MUAudioMixerDebugViewController alloc] init];
        UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:audioMixerDebugViewController];
        [self presentModalViewController:navCtrl animated:YES];
        [audioMixerDebugViewController release];
        [navCtrl release];
    } else if (buttonIndex == _accessTokensIndex) {
        MUAccessTokenViewController *tokenViewController = [[MUAccessTokenViewController alloc] initWithServerModel:_model];
        UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:tokenViewController];
        [self presentModalViewController:navCtrl animated:YES];
        [tokenViewController release];
        [navCtrl release];
    } else if (buttonIndex == _certificatesIndex) { // Certificates
        MUCertificateViewController *certView = [[MUCertificateViewController alloc] initWithCertificates:[_model serverCertificates]];
        UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:certView];
        UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(childDoneButton:)];
        certView.navigationItem.leftBarButtonItem = doneButton;
        [doneButton release];
        [self presentModalViewController:navCtrl animated:YES];
        [certView release];
        [navCtrl release];
    } else if (buttonIndex == _selfRegisterIndex) { // Self-Register
        NSString *title = NSLocalizedString(@"User Registration", nil);
        NSString *msg = [NSString stringWithFormat:
                            NSLocalizedString(@"You are about to register yourself on this server. "
                                              @"This cannot be undone, and your username cannot be changed once this is done. "
                                              @"You will forever be known as '%@' on this server.\n\n"
                                              @"Are you sure you want to register yourself?", 
                                              @"Self-registration with given username"),
                            [connUser userName]];
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title
                                                            message:msg
                                                           delegate:self
                                                  cancelButtonTitle:NSLocalizedString(@"No", nil)
                                                  otherButtonTitles:NSLocalizedString(@"Yes", nil), nil];
        [alertView show];
        [alertView release];
    } else if (buttonIndex == _clearMessagesIndex) { // Clear Messages
        [_messagesView clearAllMessages];
    } else if (buttonIndex == _selfMuteIndex) { // Self-Mute, Unmute Self
        [_model setSelfMuted:![connUser isSelfMuted] andSelfDeafened:[connUser isSelfDeafened]];
    } else if (buttonIndex == _selfDeafenIndex) { // Self-Deafen, Undeafen Self
        [_model setSelfMuted:[connUser isSelfMuted] andSelfDeafened:![connUser isSelfDeafened]];
    } else if (buttonIndex == _selfUnmuteAndUndeafenIndex) { // Unmute and undeafen
        [_model setSelfMuted:NO andSelfDeafened:NO];
    }
}

@end
