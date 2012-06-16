/* Copyright (C) 2009-2012 Mikkel Krautz <mikkel@krautz.dk>

   All rights reserved.

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions
   are met:

   - Redistributions of source code must retain the above copyright notice,
     this list of conditions and the following disclaimer.
   - Redistributions in binary form must reproduce the above copyright notice,
     this list of conditions and the following disclaimer in the documentation
     and/or other materials provided with the distribution.
   - Neither the name of the Mumble Developers nor the names of its
     contributors may be used to endorse or promote products derived from this
     software without specific prior written permission.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
   ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
   A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR
   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

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
