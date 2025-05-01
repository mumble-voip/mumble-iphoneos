// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

@import UIKit;

#import "Classes/MUApplicationDelegate.h"

int main(int argc, char *argv[]) {
    NSString * appDelegateClassName;
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
        appDelegateClassName = NSStringFromClass([MUApplicationDelegate class]);
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}
