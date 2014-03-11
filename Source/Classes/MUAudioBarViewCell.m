// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUAudioBarView.h"
#import "MUAudioBarViewCell.h"
#import "MUOperatingSystem.h"

@interface MUAudioBarViewCell () {
    MUAudioBarView *_audioBarView;
}
@end

@implementation MUAudioBarViewCell

- (id) initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        MUAudioBarView *audioBarView = [[MUAudioBarView alloc] initWithFrame:self.bounds];
        [audioBarView setBelow:0.4f];
        [audioBarView setAbove:0.6f];
        [self setBackgroundView:audioBarView];
        // Round the corners on anything but iOS 7 and greater.
        if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
            self.backgroundView.layer.masksToBounds = NO;
            self.backgroundView.layer.cornerRadius = 0.0f;
        } else {
            self.backgroundView.layer.masksToBounds = YES;
            self.backgroundView.layer.cornerRadius = 8.0f;
        }
        self.backgroundColor = [UIColor clearColor];
        [audioBarView release];
    }
    return self;
}

@end
