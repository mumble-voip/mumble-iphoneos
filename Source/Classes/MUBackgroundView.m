// Copyright 2014 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUBackgroundView.h"
#import "MUColor.h"
#import "MUImage.h"

@implementation MUBackgroundView

+ (UIView *) backgroundView {
    UIView *view = [[UIView alloc] init];
    if (@available(iOS 13.0, *)) {
        [view setBackgroundColor:[UIColor systemGroupedBackgroundColor]];
    } else if (@available(iOS 7, *)) {
        [view setBackgroundColor:[MUColor backgroundViewiOS7Color]];
    } else {
        return [[UIImageView alloc] initWithImage:[MUImage imageNamed:@"BackgroundTextureBlackGradient"]];
    }
    return view;
}

@end
