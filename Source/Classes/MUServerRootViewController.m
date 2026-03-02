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
#import "MUApplicationDelegate.h"

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
    
    UIView                      *_controlPanel;
    UIButton                    *_muteBtn;
    UIButton                    *_deafenBtn;
    UIButton                    *_disconnectBtn;
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
        _numberBadgeView.font = [UIFont boldSystemFontOfSize:11.0f];
        _numberBadgeView.hidden = YES;
        _numberBadgeView.shine = NO;
        _numberBadgeView.strokeColor = [UIColor redColor];
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
    
    UIView* containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, _segmentedControl.frame.size.width, 30)];
    [containerView addSubview:_segmentedControl];
    [containerView addSubview:_numberBadgeView];
    _numberBadgeView.frame = CGRectMake(_segmentedControl.frame.size.width-24, -10, 50, 30);
    _numberBadgeView.value = _unreadMessages;
    _numberBadgeView.hidden = _unreadMessages == 0;
    
    _serverView.navigationItem.titleView = containerView;
    
    [self setViewControllers:[NSArray arrayWithObject:_serverView] animated:NO];

    // Hide the default toolbar — we use a custom floating panel instead
    [self setToolbarHidden:YES animated:NO];
    [self _setupControlPanel];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setToolbarHidden:YES animated:NO];
    [self _updateControlPanelState];
}

- (BOOL) shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask) supportedInterfaceOrientations {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        return UIInterfaceOrientationMaskAll;
    }
    return UIInterfaceOrientationMaskPortrait;
}

- (void) segmentChanged:(id)sender {
    if (_segmentedControl.selectedSegmentIndex == 0) { // Server view
        _serverView.navigationItem.titleView = _segmentedControl;
        _serverView.navigationItem.leftBarButtonItem = _smallIcon;
        _serverView.navigationItem.rightBarButtonItem = _menuButton;
        [self setViewControllers:[NSArray arrayWithObject:_serverView] animated:NO];
        [_modeSwitchButton setEnabled:YES];
        _controlPanel.hidden = NO;
    } else if (_segmentedControl.selectedSegmentIndex == 1) { // Messages view
        _messagesView.navigationItem.titleView = _segmentedControl;
        _messagesView.navigationItem.leftBarButtonItem = _smallIcon;
        _messagesView.navigationItem.rightBarButtonItem = _menuButton;
        [self setViewControllers:[NSArray arrayWithObject:_messagesView] animated:NO];
        [_modeSwitchButton setEnabled:NO];
        _controlPanel.hidden = YES;
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
        // Disconnect first (switches tabs), then show alert on the tab bar
        [[MUConnectionController sharedController] disconnectFromServer];
        
        MUApplicationDelegate *appDelegate = (MUApplicationDelegate *)[[UIApplication sharedApplication] delegate];
        UITabBarController *tabBar = [appDelegate tabBarController];
        
        UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Connection closed", nil)
                                                                           message:[err localizedDescription]
                                                                    preferredStyle:UIAlertControllerStyleAlert];
        [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                       style:UIAlertActionStyleCancel
                                                     handler:nil]];
        [tabBar presentViewController:alertCtrl animated:YES completion:nil];
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
        
        [[MUConnectionController sharedController] disconnectFromServer];
        
        MUApplicationDelegate *appDelegate = (MUApplicationDelegate *)[[UIApplication sharedApplication] delegate];
        UITabBarController *tabBar = [appDelegate tabBarController];
        
        UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                                           message:alertMsg
                                                                    preferredStyle:UIAlertControllerStyleAlert];
        [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                       style:UIAlertActionStyleCancel
                                                     handler:nil]];
        [tabBar presentViewController:alertCtrl animated:YES completion:nil];
    }
}

- (void) serverModel:(MKServerModel *)model userBanned:(MKUser *)user byUser:(MKUser *)actor forReason:(NSString *)reason {
    if (user == [model connectedUser]) {
        NSString *reasonMsg = reason ? reason : NSLocalizedString(@"(No reason)", nil);
        NSString *title = NSLocalizedString(@"You were banned", nil);
        NSString *alertMsg = [NSString stringWithFormat:
                                NSLocalizedString(@"Banned by %@ for reason: \"%@\"", nil),
                                    [actor userName], reasonMsg];
        
        [[MUConnectionController sharedController] disconnectFromServer];
        
        MUApplicationDelegate *appDelegate = (MUApplicationDelegate *)[[UIApplication sharedApplication] delegate];
        UITabBarController *tabBar = [appDelegate tabBarController];
        
        UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                                           message:alertMsg
                                                                    preferredStyle:UIAlertControllerStyleAlert];
        [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                       style:UIAlertActionStyleCancel
                                                     handler:nil]];
        [tabBar presentViewController:alertCtrl animated:YES completion:nil];
    }
}

- (void) serverModel:(MKServerModel *)model userSelfMuteDeafenStateChanged:(MKUser *)user {
    if (user == [model connectedUser])
        [self _updateControlPanelState];
}

- (void) serverModel:(MKServerModel *)model userSelfMuted:(MKUser *)user {
    if (user == [model connectedUser])
        [self _updateControlPanelState];
}

- (void) serverModel:(MKServerModel *)model userSelfMutedAndDeafened:(MKUser *)user {
    if (user == [model connectedUser])
        [self _updateControlPanelState];
}

- (void) serverModel:(MKServerModel *)model userUnmutedAndUndeafened:(MKUser *)user byUser:(MKUser *)actor {
    if (user == [model connectedUser])
        [self _updateControlPanelState];
}

- (void) serverModel:(MKServerModel *)model userMutedAndDeafened:(MKUser *)user byUser:(MKUser *)actor {
    if (user == [model connectedUser])
        [self _updateControlPanelState];
}

- (void) serverModel:(MKServerModel *)model userUnmuted:(MKUser *)user byUser:(MKUser *)actor {
    if (user == [model connectedUser])
        [self _updateControlPanelState];
}

- (void) serverModel:(MKServerModel *)model userUndeafened:(MKUser *)user byUser:(MKUser *)actor {
    if (user == [model connectedUser])
        [self _updateControlPanelState];
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

#pragma mark - Control Panel

- (UIButton *) _makeControlButton {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.layer.cornerRadius = 22;
    btn.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        btn.backgroundColor = [UIColor tertiarySystemFillColor];
    } else {
        btn.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
    }
    [NSLayoutConstraint activateConstraints:@[
        [btn.widthAnchor constraintEqualToConstant:44],
        [btn.heightAnchor constraintEqualToConstant:44]
    ]];
    return btn;
}

- (void) _setupControlPanel {
    _controlPanel = [[UIView alloc] init];
    _controlPanel.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) {
        _controlPanel.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    } else {
        _controlPanel.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    }
    _controlPanel.layer.cornerRadius = 16;
    _controlPanel.layer.shadowColor = [UIColor blackColor].CGColor;
    _controlPanel.layer.shadowOpacity = 0.12;
    _controlPanel.layer.shadowOffset = CGSizeMake(0, 2);
    _controlPanel.layer.shadowRadius = 8;
    
    _muteBtn = [self _makeControlButton];
    [_muteBtn addTarget:self action:@selector(toggleMute:) forControlEvents:UIControlEventTouchUpInside];
    
    _deafenBtn = [self _makeControlButton];
    [_deafenBtn addTarget:self action:@selector(toggleDeafen:) forControlEvents:UIControlEventTouchUpInside];
    
    _disconnectBtn = [self _makeControlButton];
    [_disconnectBtn addTarget:self action:@selector(disconnectTapped:) forControlEvents:UIControlEventTouchUpInside];
    if (@available(iOS 13.0, *)) {
        _disconnectBtn.backgroundColor = [[UIColor systemRedColor] colorWithAlphaComponent:0.15];
    }
    
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[_muteBtn, _deafenBtn, _disconnectBtn]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 20;
    stack.alignment = UIStackViewAlignmentCenter;
    
    [_controlPanel addSubview:stack];
    [self.view addSubview:_controlPanel];
    
    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:_controlPanel.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:_controlPanel.centerYAnchor],
        [_controlPanel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_controlPanel.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8],
        [_controlPanel.heightAnchor constraintEqualToConstant:60],
        [stack.leadingAnchor constraintEqualToAnchor:_controlPanel.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:_controlPanel.trailingAnchor constant:-20],
    ]];
    
    [self _updateControlPanelState];
}

- (void) _updateControlPanelState {
    MKUser *connUser = [_model connectedUser];
    BOOL muted = [connUser isSelfMuted];
    BOOL deafened = [connUser isSelfDeafened];
    
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium];
        
        if (muted) {
            [_muteBtn setImage:[UIImage systemImageNamed:@"mic.slash.fill" withConfiguration:config] forState:UIControlStateNormal];
            _muteBtn.tintColor = [UIColor whiteColor];
            _muteBtn.backgroundColor = [UIColor systemRedColor];
        } else {
            [_muteBtn setImage:[UIImage systemImageNamed:@"mic.fill" withConfiguration:config] forState:UIControlStateNormal];
            _muteBtn.tintColor = [UIColor systemGreenColor];
            _muteBtn.backgroundColor = [UIColor tertiarySystemFillColor];
        }
        
        if (deafened) {
            [_deafenBtn setImage:[UIImage systemImageNamed:@"speaker.slash.fill" withConfiguration:config] forState:UIControlStateNormal];
            _deafenBtn.tintColor = [UIColor whiteColor];
            _deafenBtn.backgroundColor = [UIColor systemRedColor];
        } else {
            [_deafenBtn setImage:[UIImage systemImageNamed:@"speaker.wave.2.fill" withConfiguration:config] forState:UIControlStateNormal];
            _deafenBtn.tintColor = [UIColor labelColor];
            _deafenBtn.backgroundColor = [UIColor tertiarySystemFillColor];
        }
        
        [_disconnectBtn setImage:[UIImage systemImageNamed:@"xmark" withConfiguration:config] forState:UIControlStateNormal];
        _disconnectBtn.tintColor = [UIColor systemRedColor];
    }
}

- (void) toggleMute:(id)sender {
    MKUser *connUser = [_model connectedUser];
    BOOL newMuted = ![connUser isSelfMuted];
    // If unmuting while deafened, also undeafen
    BOOL newDeafened = newMuted ? [connUser isSelfDeafened] : NO;
    [_model setSelfMuted:newMuted andSelfDeafened:newDeafened];
    
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [feedback impactOccurred];
    }
}

- (void) toggleDeafen:(id)sender {
    MKUser *connUser = [_model connectedUser];
    BOOL newDeafened = ![connUser isSelfDeafened];
    // Deafening also mutes; undeafening also unmutes
    [_model setSelfMuted:newDeafened andSelfDeafened:newDeafened];
    
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [feedback impactOccurred];
    }
}

- (void) disconnectTapped:(id)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Disconnect", nil)
                                                                   message:NSLocalizedString(@"Are you sure you want to disconnect from this server?", nil)
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Disconnect", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [[MUConnectionController sharedController] disconnectFromServer];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Actions

- (void) actionButtonClicked:(id)sender {
    MKUser *connUser = [_model connectedUser];
    BOOL inMessagesView = [[self viewControllers] objectAtIndex:0] == _messagesView;
    
    UIAlertController *sheetCtrl = [UIAlertController alertControllerWithTitle:nil
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
    
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
    
    if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"AudioMixerDebug"] boolValue]) {
        [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Mixer Debug", nil)
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * _Nonnull action) {
            MUAudioMixerDebugViewController *audioMixerDebugViewController = [[MUAudioMixerDebugViewController alloc] init];
            UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:audioMixerDebugViewController];
            [self presentViewController:navCtrl animated:YES completion:nil];
        }]];
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
