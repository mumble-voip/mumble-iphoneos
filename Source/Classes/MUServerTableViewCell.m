// Copyright 2014 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUServerTableViewCell.h"

@implementation MUServerTableViewCell

- (id) initWithReuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier])) {
        // ...
    }
    return self;
}

- (void) layoutSubviews {
    [super layoutSubviews];

    self.separatorInset = UIEdgeInsetsMake(0, 0, 0, 0);

    self.imageView.frame = CGRectMake(
        8 + self.indentationLevel * self.indentationWidth,
        CGRectGetMinY(self.imageView.frame),
        CGRectGetWidth(self.imageView.frame),
        CGRectGetHeight(self.imageView.frame)
    );

    self.textLabel.frame = CGRectMake(
        CGRectGetMinX(self.imageView.frame) + 40,
        CGRectGetMinY(self.textLabel.frame),
        CGRectGetWidth(self.frame) - (CGRectGetMinX(self.imageView.frame) + 60),
        CGRectGetHeight(self.textLabel.frame)
    );
}

@end
