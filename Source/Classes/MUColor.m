// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUColor.h"

@implementation MUColor

+ (UIColor *) selectedTextColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor secondaryLabelColor];
    }
    return [UIColor colorWithRed:0x5d/255.0f green:0x5d/255.0f blue:0x5d/255.0f alpha:1.0f];
}

+ (UIColor *) goodPingColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor systemGreenColor];
    }
    return [UIColor colorWithRed:0x60/255.0f green:0x9a/255.0f blue:0x4b/255.0f alpha:1.0f];
}

+ (UIColor *) mediumPingColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor systemYellowColor];
    }
    return [UIColor colorWithRed:0xf2/255.0f green:0xde/255.0f blue:0x69/255.0f alpha:1.0f];
}

+ (UIColor *) badPingColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor systemRedColor];
    }
    return [UIColor colorWithRed:0xd1/255.0f green:0x4d/255.0f blue:0x54/255.0f alpha:1.0f];
}

+ (UIColor *) userCountColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor secondaryLabelColor];
    }
    return [UIColor darkGrayColor];
}

+ (UIColor *) verifiedCertificateChainColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:0x1a/255.0f green:0x3a/255.0f blue:0x1a/255.0f alpha:1.0f];
            }
            return [UIColor colorWithRed:0xdf/255.0f green:1.0f blue:0xdf/255.0f alpha:1.0f];
        }];
    }
    return [UIColor colorWithRed:0xdf/255.0f green:1.0f blue:0xdf/255.0f alpha:1.0f];
}

+ (UIColor *) backgroundViewiOS7Color {
    if (@available(iOS 13.0, *)) {
        return [UIColor systemBackgroundColor];
    }
    return [UIColor colorWithRed:0x1C/255.0f green:0x1C/255.0f blue:0x1C/255.0f alpha:1.0f];
}

+ (UIColor *) backgroundColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor systemBackgroundColor];
    }
    return [UIColor colorWithRed:0x1C/255.0f green:0x1C/255.0f blue:0x1C/255.0f alpha:1.0f];
}

+ (UIColor *) secondaryBackgroundColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor secondarySystemBackgroundColor];
    }
    return [UIColor colorWithRed:0x2C/255.0f green:0x2C/255.0f blue:0x2C/255.0f alpha:1.0f];
}

+ (UIColor *) groupedBackgroundColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor systemGroupedBackgroundColor];
    }
    return [UIColor colorWithRed:0x1C/255.0f green:0x1C/255.0f blue:0x1C/255.0f alpha:1.0f];
}

+ (UIColor *) cellBackgroundColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor secondarySystemGroupedBackgroundColor];
    }
    return [UIColor colorWithRed:0x2C/255.0f green:0x2C/255.0f blue:0x2C/255.0f alpha:1.0f];
}

+ (UIColor *) primaryTextColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor labelColor];
    }
    return [UIColor whiteColor];
}

+ (UIColor *) secondaryTextColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor secondaryLabelColor];
    }
    return [UIColor lightGrayColor];
}

+ (UIColor *) tertiaryTextColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor tertiaryLabelColor];
    }
    return [UIColor lightGrayColor];
}

+ (UIColor *) tintColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor systemBlueColor];
    }
    return [UIColor colorWithRed:0.0f green:0.48f blue:1.0f alpha:1.0f];
}

@end
