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
#import "MUConnectionViewController.h"
#import "MUServerCertificateTrustViewController.h"
#import "MUNotificationController.h"
#import "MUConnectionController.h"
#import "MUDatabase.h"

#import <MumbleKit/MKConnection.h>
#import <MumbleKit/MKServerModel.h>
#import <MumbleKit/MKCertificate.h>

@interface MUServerRootViewController () <MKConnectionDelegate, MKServerModelDelegate> {
    MKConnection                *_connection;
    MKServerModel               *_model;
    
    NSInteger                   _segmentIndex;
    UISegmentedControl          *_segmentedControl;

    MUServerViewController      *_serverView;
    MUChannelViewController     *_channelView;
    MUConnectionViewController  *_connectionView;
}
@end

@implementation MUServerRootViewController

- (id) initWithConnection:(MKConnection *)conn andServerModel:(MKServerModel *)model {
    if ([super init]) {
        _connection = [conn retain];
        _model = [model retain];
        [_model addDelegate:self];
    }
    return self;
}

- (void) dealloc {
    [_serverView release];
    [_channelView release];
    [_connectionView release];
   
    [_model removeDelegate:self];
    [_model release];
    [_connection setDelegate:nil];
    [_connection release];
    
    [super dealloc];
}

- (void) takeOwnershipOfConnectionDelegate {
    [_connection setDelegate:self];
}

#pragma mark - View lifecycle

- (void) viewDidUnload {
    [super viewDidUnload];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    _serverView = [[MUServerViewController alloc] initWithServerModel:_model];
    _channelView = [[MUChannelViewController alloc] initWithServerModel:_model];
    _connectionView = [[MUConnectionViewController alloc] initWithServerModel:_model];
    
    _segmentedControl = [[UISegmentedControl alloc] initWithItems:
                            [NSArray arrayWithObjects:@"Server", @"Channel", @"Connection", nil]];

    _segmentIndex = 0;

    _segmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
    _segmentedControl.selectedSegmentIndex = _segmentIndex;
    [_segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];

    _serverView.navigationItem.titleView = _segmentedControl;

    [self setViewControllers:[NSArray arrayWithObject:_serverView] animated:NO];

    self.navigationBar.barStyle = UIBarStyleBlackOpaque;
    self.toolbar.barStyle = UIBarStyleBlackOpaque;
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // On iPad, we support all interface orientations.
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        return YES;
    }

    return interfaceOrientation == UIInterfaceOrientationPortrait;
}

- (void) segmentChanged:(id)sender {
    UIViewController *oldTop = [self topViewController];
    [oldTop viewWillDisappear:NO];
    if (_segmentedControl.selectedSegmentIndex == 0) {
        _serverView.navigationItem.titleView = _segmentedControl;
        [self setViewControllers:[NSArray arrayWithObject:_serverView] animated:NO];
    } else if (_segmentedControl.selectedSegmentIndex == 1) {
        _channelView.navigationItem.titleView = _segmentedControl;
        [self setViewControllers:[NSArray arrayWithObject:_channelView] animated:NO];
    } else if (_segmentedControl.selectedSegmentIndex == 2) {
        _connectionView.navigationItem.titleView = _segmentedControl;
        [self setViewControllers:[NSArray arrayWithObject:_connectionView] animated:NO];
    }
    [oldTop viewDidDisappear:NO];
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

@end
