// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUTableViewHeaderLabel.h"

@implementation MUTableViewHeaderLabel

- (id) init {
    if ((self = [super init])) {
        self.font = [UIFont boldSystemFontOfSize:18.0f];
        self.textColor = [UIColor whiteColor];
        self.shadowColor = [UIColor darkGrayColor];
        self.shadowOffset = CGSizeMake(1.5f, 1.5f);
        self.backgroundColor = [UIColor clearColor];
        self.textAlignment = UITextAlignmentCenter;
    }
    return self;
}

+ (CGFloat) defaultHeaderHeight {
    return 44.0f;
}

+ (MUTableViewHeaderLabel *) labelWithText:(NSString *)text {
    MUTableViewHeaderLabel *label = [[[MUTableViewHeaderLabel alloc] init] autorelease];
    label.text = text;
    return label;
}

@end
