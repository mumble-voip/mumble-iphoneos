// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUColor.h"

@implementation MUColor

+ (UIColor *) selectedTextColor {
    // #5d5d5d
    return [UIColor colorWithRed:0x5d/255.0f green:0x5d/255.0f blue:0x5d/255.0f alpha:1.0f];
}

+ (UIColor *) goodPingColor {
    // #2B9F78
    return [UIColor colorWithRed:0x2b/255.0f green:0x9f/255.0f blue:0x78/255.0f alpha:1.0f];
}

+ (UIColor *) mediumPingColor {
    // #F0E54B
    return [UIColor colorWithRed:0xf0/255.0f green:0xe5/255.0f blue:0x4b/255.0f alpha:1.0f];
}

+ (UIColor *) badPingColor {
    // #D6641E
    return [UIColor colorWithRed:0xd6/255.0f green:0x64/255.0f blue:0x1e/255.0f alpha:1.0f];
}

+ (UIColor *) userCountColor {
    return [UIColor darkGrayColor];
}

+ (UIColor *) verifiedCertificateChainColor {
    return [UIColor colorWithRed:0xdf/255.0f green:1.0f blue:0xdf/255.0f alpha:1.0f];
}

+ (UIColor *) backgroundViewiOS7Color {
    return [UIColor colorWithRed:0x1C/255.0f green:0x1C/255.0f blue:0x1C/255.0f alpha:1.0f];
}

@end
