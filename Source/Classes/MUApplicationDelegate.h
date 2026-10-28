// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

FOUNDATION_EXPORT NSNotificationName const MUAudioTransmissionModeDidChangeNotification;

@interface MUApplicationDelegate : NSObject <UIApplicationDelegate>
+ (void) setApplicationBadgeCount:(NSInteger)count;
+ (void) incrementApplicationBadgeCount;
- (void) reloadPreferences;
- (void)setAudioTransmitMethod:(NSString *)method;
- (void) installUserInterfaceInWindow:(UIWindow *)window;
- (BOOL) openMumbleURL:(NSURL *)url;
- (void) sceneWillResignActive;
- (void) sceneDidBecomeActive;
@end
