// Copyright 2009-2026 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUSceneDelegate.h"
#import "MUApplicationDelegate.h"

@implementation MUSceneDelegate

- (void) scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:[UIWindowScene class]]) {
        return;
    }

    UIWindowScene *windowScene = (UIWindowScene *)scene;
    self.window = [[UIWindow alloc] initWithWindowScene:windowScene];

    MUApplicationDelegate *appDelegate = (MUApplicationDelegate *)[UIApplication sharedApplication].delegate;
    [appDelegate installUserInterfaceInWindow:self.window];

    for (UIOpenURLContext *context in connectionOptions.URLContexts) {
        [appDelegate openMumbleURL:context.URL];
    }
}

- (void) sceneDidDisconnect:(UIScene *)scene {
    self.window = nil;
}

- (void) sceneWillResignActive:(UIScene *)scene {
    MUApplicationDelegate *appDelegate = (MUApplicationDelegate *)[UIApplication sharedApplication].delegate;
    [appDelegate sceneWillResignActive];
}

- (void) sceneDidBecomeActive:(UIScene *)scene {
    MUApplicationDelegate *appDelegate = (MUApplicationDelegate *)[UIApplication sharedApplication].delegate;
    [appDelegate sceneDidBecomeActive];
}

- (void) scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts {
    MUApplicationDelegate *appDelegate = (MUApplicationDelegate *)[UIApplication sharedApplication].delegate;
    for (UIOpenURLContext *context in URLContexts) {
        [appDelegate openMumbleURL:context.URL];
    }
}

@end
