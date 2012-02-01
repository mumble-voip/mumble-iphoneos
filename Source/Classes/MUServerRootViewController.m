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

#import "MUServerRootViewController.h"
#import "MUServerViewController.h"
#import "MUChannelViewController.h"
#import "MUServerCertificateTrustViewController.h"
#import "MUAccessTokenViewController.h"
#import "MUCertificateViewController.h"
#import "MUNotificationController.h"
#import "MUConnectionController.h"
#import "MUMessagesViewController.h"
#import "MUDatabase.h"

#import <MumbleKit/MKConnection.h>
#import <MumbleKit/MKServerModel.h>
#import <MumbleKit/MKCertificate.h>
#import <MumbleKit/MKAudio.h>

#import "MKNumberBadgeView.h"

@interface MUServerRootViewController () <MKConnectionDelegate, MKServerModelDelegate, UIActionSheetDelegate> {
    MKConnection                *_connection;
    MKServerModel               *_model;
    
    NSInteger                   _segmentIndex;
    UISegmentedControl          *_segmentedControl;
    UIBarButtonItem             *_actionButton;
    UIBarButtonItem             *_smallIcon;
    MKNumberBadgeView           *_numberBadgeView;

    MUServerViewController      *_serverView;
    MUChannelViewController     *_channelView;
    MUMessagesViewController    *_messagesView;
    
    NSInteger                   _unreadMessages;
}
@end

@implementation MUServerRootViewController

- (id) initWithConnection:(MKConnection *)conn andServerModel:(MKServerModel *)model {
    if ((self = [super init])) {
        _connection = [conn retain];
        _model = [model retain];
        [_model addDelegate:self];
        _unreadMessages = 0;
    }
    return self;
}

- (void) dealloc {
    [_serverView release];
    [_channelView release];
   
    [_model removeDelegate:self];
    [_model release];
    [_connection setDelegate:nil];
    [_connection release];
    
    [_actionButton release];
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
    
    _serverView = [[MUServerViewController alloc] initWithServerModel:_model];
    _channelView = [[MUChannelViewController alloc] initWithServerModel:_model];
    _messagesView = [[MUMessagesViewController alloc] initWithServerModel:_model];
    
    _segmentedControl = [[UISegmentedControl alloc] initWithItems:
                         [NSArray arrayWithObjects:@"Server", @"Channel", @"Messages", nil]];
    
    _segmentIndex = 0;
    
    _segmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
    _segmentedControl.selectedSegmentIndex = _segmentIndex;
    [_segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    
    _serverView.navigationItem.titleView = _segmentedControl;
    
    _actionButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(actionButtonClicked:)];
    _serverView.navigationItem.rightBarButtonItem = _actionButton;
    
    UIImageView *imgView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"SmallMumbleIcon"]];
    _smallIcon = [[UIBarButtonItem alloc] initWithCustomView:imgView];
    [imgView release];
    _serverView.navigationItem.leftBarButtonItem = _smallIcon;
    
    _numberBadgeView = [[MKNumberBadgeView alloc] initWithFrame:CGRectMake(_segmentedControl.frame.size.width-38, -8, 50, 30)];
    [_segmentedControl addSubview:_numberBadgeView];
    _numberBadgeView.value = 0;
    _numberBadgeView.shadow = NO;
    _numberBadgeView.font = [UIFont boldSystemFontOfSize:10.0f];
    _numberBadgeView.hidden = YES;
    
    [self setViewControllers:[NSArray arrayWithObject:_serverView] animated:NO];
    
    self.navigationBar.barStyle = UIBarStyleBlackOpaque;
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
    if (_segmentedControl.selectedSegmentIndex == 0) {
        _serverView.navigationItem.titleView = _segmentedControl;
        _serverView.navigationItem.leftBarButtonItem = _smallIcon;
        _serverView.navigationItem.rightBarButtonItem = _actionButton;
        [self setViewControllers:[NSArray arrayWithObject:_serverView] animated:NO];
    } else if (_segmentedControl.selectedSegmentIndex == 1) {
        _channelView.navigationItem.titleView = _segmentedControl;
        _channelView.navigationItem.leftBarButtonItem = _smallIcon;
        _channelView.navigationItem.rightBarButtonItem = _actionButton;
        [self setViewControllers:[NSArray arrayWithObject:_channelView] animated:NO];
    } else if (_segmentedControl.selectedSegmentIndex == 2) {
        _messagesView.navigationItem.titleView = _segmentedControl;
        _messagesView.navigationItem.leftBarButtonItem = _smallIcon;
        _messagesView.navigationItem.rightBarButtonItem = _actionButton;
        [self setViewControllers:[NSArray arrayWithObject:_messagesView] animated:NO];
    }
    
    if (_segmentedControl.selectedSegmentIndex == 2) {
        _unreadMessages = 0;
        _numberBadgeView.value = 0;
        _numberBadgeView.hidden = YES;
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
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Connection closed" message:[err localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alertView show];
        [alertView release];

        [[MUConnectionController sharedController] disconnectFromServer];
    }
}

#pragma mark - MKServerModel delegate

- (void) serverModel:(MKServerModel *)model userKicked:(MKUser *)user byUser:(MKUser *)actor forReason:(NSString *)reason {
    if (user == [model connectedUser]) {
        NSString *reasonMsg = reason ? reason : @"(No reason)";
        NSString *alertMsg = [NSString stringWithFormat:@"Kicked by %@ for reason: \"%@\"", [actor userName], reasonMsg];
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"You were kicked" message:alertMsg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alertView show];
        [alertView release];
        
        [[MUConnectionController sharedController] disconnectFromServer];
    }
}

- (void) serverModel:(MKServerModel *)model userBanned:(MKUser *)user byUser:(MKUser *)actor forReason:(NSString *)reason {
    if (user == [model connectedUser]) {
        NSString *reasonMsg = reason ? reason : @"(No reason)";
        NSString *alertMsg = [NSString stringWithFormat:@"Banned by %@ for reason: \"%@\"", [actor userName], reasonMsg];
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"You were banned" message:alertMsg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alertView show];
        [alertView release];
        
        [[MUConnectionController sharedController] disconnectFromServer];
    }
}

- (void) serverModel:(MKServerModel *)model permissionDenied:(MKPermission)perm forUser:(MKUser *)user inChannel:(MKChannel *)channel {
    [[MUNotificationController sharedController] addNotification:@"Permission denied"];
}

- (void) serverModelInvalidChannelNameError:(MKServerModel *)model {
    [[MUNotificationController sharedController] addNotification:@"Invalid channel name"];
}

- (void) serverModelModifySuperUserError:(MKServerModel *)model {
    [[MUNotificationController sharedController] addNotification:@"Cannot modify SuperUser"];
}

- (void) serverModelTextMessageTooLongError:(MKServerModel *)model {
    [[MUNotificationController sharedController] addNotification:@"Message too long"];
}

- (void) serverModelTemporaryChannelError:(MKServerModel *)model {
    [[MUNotificationController sharedController] addNotification:@"Not permitted in temporary channel"];
}

- (void) serverModel:(MKServerModel *)model missingCertificateErrorForUser:(MKUser *)user {
    if (user == nil) {
        [[MUNotificationController sharedController] addNotification:@"Missing certificate"];
    } else {
        [[MUNotificationController sharedController] addNotification:@"Missing certificate for user"];
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
    [[MUNotificationController sharedController] addNotification:@"Channel is full"];
}

- (void) serverModel:(MKServerModel *)model permissionDeniedForReason:(NSString *)reason {
    if (reason == nil) {
        [[MUNotificationController sharedController] addNotification:@"Permission denied"];
    } else {
        [[MUNotificationController sharedController] addNotification:[NSString stringWithFormat:@"Permission denied: %@", reason]];
    }
}

- (void) serverModel:(MKServerModel *)model textMessageReceived:(MKTextMessage *)msg fromUser:(MKUser *)user {
    if (_segmentedControl.selectedSegmentIndex != 2) {
        _unreadMessages++;
        _numberBadgeView.value = _unreadMessages;
        _numberBadgeView.hidden = NO;
    }
}

#pragma mark - Actions

- (void) actionButtonClicked:(id)sender {
    UIActionSheet *actionSheet = [[UIActionSheet alloc] init];
    
    [actionSheet addButtonWithTitle:@"Disconnect"];
    [actionSheet setDestructiveButtonIndex:0];
    
    [actionSheet addButtonWithTitle:@"Access Tokens"];
    [actionSheet addButtonWithTitle:@"Certificates"];
    [actionSheet addButtonWithTitle:@"Clear Messages"];

    MKUser *connUser = [_model connectedUser];
    
    if ([connUser isSelfMuted] && [connUser isSelfDeafened]) {
        [actionSheet addButtonWithTitle:@"Unmute and undeafen"];
    } else {
        if (![connUser isSelfMuted])
            [actionSheet addButtonWithTitle:@"Self-Mute"];
        else
            [actionSheet addButtonWithTitle:@"Unmute Self"];

        if (![connUser isSelfDeafened])
            [actionSheet addButtonWithTitle:@"Self-Deafen"];
        else
            [actionSheet addButtonWithTitle:@"Undeafen Self"];
    }
    
    int cancelIndex = [actionSheet addButtonWithTitle:@"Cancel"];
    [actionSheet setCancelButtonIndex:cancelIndex];

    [actionSheet setDelegate:self];
    [actionSheet showFromBarButtonItem:_actionButton animated:YES];
    [actionSheet release];
}

- (void) childDoneButton:(id)sender {
    [[self modalViewController] dismissModalViewControllerAnimated:YES];
}

#pragma mark - UIActionSheetDelegate

- (void) actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    MKUser *connUser = [_model connectedUser];
    
    if (buttonIndex == [actionSheet cancelButtonIndex])
        return;

    if (buttonIndex == 0) { // Disconnect
        [[MUConnectionController sharedController] disconnectFromServer];
    } else if (buttonIndex == 1) { // Access Tokens
        MUAccessTokenViewController *tokenViewController = [[MUAccessTokenViewController alloc] initWithServerModel:_model];
        UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:tokenViewController];
        [self presentModalViewController:navCtrl animated:YES];
        [tokenViewController release];
        [navCtrl release];
    } else if (buttonIndex == 2) { // Certificates
        MUCertificateViewController *certView = [[MUCertificateViewController alloc] initWithCertificates:[_model serverCertificates]];
        UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:certView];
        UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(childDoneButton:)];
        certView.navigationItem.leftBarButtonItem = doneButton;
        [doneButton release];
        [self presentModalViewController:navCtrl animated:YES];
        [certView release];
        [navCtrl release];
    } else if (buttonIndex == 3) { // Clear Messages
        [_messagesView clearAllMessages];
    } else if (buttonIndex == 4) { // Toggle Self-Mute (or Unmute and undeafen if both muted and deafened)
        if ([connUser isSelfMuted] && [connUser isSelfDeafened])
            [_model setSelfMuted:NO andSelfDeafened:NO];
        else
            [_model setSelfMuted:![connUser isSelfMuted] andSelfDeafened:[connUser isSelfDeafened]];
    } else if (buttonIndex == 5) { // Toggle Self-Deafen
        [_model setSelfMuted:[connUser isSelfMuted] andSelfDeafened:![connUser isSelfDeafened]];
    }
}

@end
