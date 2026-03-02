// Copyright 2009-2024 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

@import UIKit;

@interface MUOnboardingViewController : UIViewController
@property (nonatomic, copy) void (^completionHandler)(void);
@end
