// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUAudioBarView.h"
#import "MUAudioBarViewCell.h"

@interface MUAudioBarViewCell () {
}
@end

@implementation MUAudioBarViewCell

- (id) initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        MUAudioBarView *meter = [[MUAudioBarView alloc] initWithFrame:CGRectZero];
        meter.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:meter];
        [NSLayoutConstraint activateConstraints:@[
            [meter.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [meter.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [meter.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [meter.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
            [self.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:72]
        ]];
    }
    return self;
}

@end
