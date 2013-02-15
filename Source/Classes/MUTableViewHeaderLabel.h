// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import <UIKit/UIKit.h>

@interface MUTableViewHeaderLabel : UILabel
+ (MUTableViewHeaderLabel *) labelWithText:(NSString *)text;
+ (CGFloat) defaultHeaderHeight;
@end
