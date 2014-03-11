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
    // #609a4b
    return [UIColor colorWithRed:0x60/255.0f green:0x9a/255.0f blue:0x4b/255.0f alpha:1.0f];
}

+ (UIColor *) mediumPingColor {
    // #F2DE69
    return [UIColor colorWithRed:0xf2/255.0f green:0xde/255.0f blue:0x69/255.0f alpha:1.0f];
}

+ (UIColor *) badPingColor {
    // #D14D54
    return [UIColor colorWithRed:0xd1/255.0f green:0x4d/255.0f blue:0x54/255.0f alpha:1.0f];
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
