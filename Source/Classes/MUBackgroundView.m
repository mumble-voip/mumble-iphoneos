// Copyright 2014 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUBackgroundView.h"
#import "MUColor.h"
#import "MUImage.h"

@implementation MUBackgroundView

+ (UIView *) backgroundView {
    if (@available(iOS 7, *)) {
        UIView *view = [[UIView alloc] init];
        [view setBackgroundColor:[MUColor backgroundViewiOS7Color]];
        return view;
    }
    
    return [[UIImageView alloc] initWithImage:[MUImage imageNamed:@"BackgroundTextureBlackGradient"]];
}

@end
