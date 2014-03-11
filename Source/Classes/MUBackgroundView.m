// Copyright 2014 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUBackgroundView.h"
#import "MUOperatingSystem.h"
#import "MUColor.h"
#import "MUImage.h"

@implementation MUBackgroundView

+ (UIView *) backgroundView {
    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        UIView *view = [[[UIView alloc] init] autorelease];
        [view setBackgroundColor:[MUColor backgroundViewiOS7Color]];
        return view;
    }
    
    return [[[UIImageView alloc] initWithImage:[MUImage imageNamed:@"BackgroundTextureBlackGradient"]] autorelease];
}

@end
