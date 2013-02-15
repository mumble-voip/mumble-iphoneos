// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUAudioBarView.h"
#import "MUAudioBarViewCell.h"

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
        self.backgroundView.layer.masksToBounds = YES;
        self.backgroundView.layer.cornerRadius = 8.0f;
        [audioBarView release];
    }
    return self;
}

@end
