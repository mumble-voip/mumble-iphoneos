// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import <Foundation/Foundation.h>
FOUNDATION_EXPORT NSNotificationName const MUConnectionStateDidChangeNotification;
@class MUFavouriteServer, UIViewController;
typedef NS_ENUM(NSUInteger,MUConnectionState) {
    MUConnectionStateIdle, MUConnectionStateConnecting, MUConnectionStateAuthenticating,
    MUConnectionStateAwaitingCertificate, MUConnectionStateAwaitingCredentials,
    MUConnectionStateConnected, MUConnectionStateReconnecting, MUConnectionStateDisconnecting
};

@interface MUConnectionController : NSObject
// Main-thread owned. Notifications coalesce to the latest state. Capture demand
// follows hasActiveSession, including recovery; isConnected means joined now.
@property(nonatomic,readonly) MUConnectionState state;
@property(nonatomic,readonly) BOOL hasActiveSession, hasPendingConnection;
+ (MUConnectionController *) sharedController;
- (void) connectToHostname:(NSString *)hostName port:(NSUInteger)port withUsername:(NSString *)userName andPassword:(NSString *)password withParentViewController:(UIViewController *)parentViewController;
- (void)connectToFavouriteServer:(MUFavouriteServer *)server withParentViewController:(UIViewController *)parentViewController;
- (BOOL) isConnected;
- (void) disconnectFromServer;
@end
