// Copyright 2009-2012 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUPopoverBackgroundView.h"

@interface MUPopoverBackgroundView () {
    UIImageView *_imgView;
}
@end

@implementation MUPopoverBackgroundView

- (id) initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        UIEdgeInsets insets = UIEdgeInsetsMake(41.0f, 47.0f, 10.0f, 10.0f);
        UIImage *img = [UIImage imageNamed:@"_UIPopoverViewBlackBackgroundArrowUp"];
        UIImage *stretchableImg = [img resizableImageWithCapInsets:insets];
        
        _imgView = [[UIImageView alloc] initWithImage:stretchableImg];
        [self addSubview:_imgView];
    }
    return self;
}

- (void) dealloc {
    [_imgView release];
    [super dealloc];
}

- (UIPopoverArrowDirection) arrowDirection {
    return UIPopoverArrowDirectionUp;
}

- (void) setArrowDirection:(UIPopoverArrowDirection)arrowDirection {
}

- (CGFloat) arrowOffset {
    return 0.0f;
}

- (void) setArrowOffset:(CGFloat)arrowOffset {
}

+ (CGFloat) arrowBase {
    return 35.0f;
}

+ (CGFloat) arrowHeight {
    return 19.0f;
}

+ (UIEdgeInsets) contentViewInsets {
    return UIEdgeInsetsMake(8.0f, 11.0f, 11.0f, 11.0f);
}

- (void) layoutSubviews {
    [super layoutSubviews];
    _imgView.frame = self.frame;
}

@end
