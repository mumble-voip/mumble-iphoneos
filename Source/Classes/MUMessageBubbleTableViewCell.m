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

#import "MUMessageBubbleTableViewCell.h"

@interface MUMessageBubbleView : UIView {
    NSString *_message;
    NSString *_header;
    NSDate   *_date;
    BOOL     _rightSide;
}
- (void) setDate:(NSDate *)date;
- (void) setMessage:(NSString *)msg;
- (void) setRightSide:(BOOL)rightSide;
+ (CGSize) cellSizeForText:(NSString *)text andHeader:(NSString *)header andDate:(NSDate *)date;
@end

@implementation MUMessageBubbleView

- (id) initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self setOpaque:NO];
        _rightSide = YES;
    }
    return self;
}

- (void) dealloc {
    [_message release];
    [_header release];
    [_date release];
    [super dealloc];
}

+ (CGSize) textSizeForText:(NSString *)text {
    CGFloat bubbleWidth = 190.0f;
    CGSize constraintSize = CGSizeMake(bubbleWidth-(19.0f + 11.0f), CGFLOAT_MAX);
    return [text sizeWithFont:[UIFont systemFontOfSize:14.0f] constrainedToSize:constraintSize lineBreakMode:UILineBreakModeCharacterWrap];
}

+ (CGSize) headerSizeForText:(NSString *)text {
    CGFloat bubbleWidth = 190.0f;
    CGSize constraintSize = CGSizeMake(bubbleWidth-(19.0f + 11.0f), CGFLOAT_MAX);
    return [text sizeWithFont:[UIFont boldSystemFontOfSize:14.0f] constrainedToSize:constraintSize lineBreakMode:UILineBreakModeCharacterWrap];
}

+ (CGSize) timestampSizeForText:(NSString *)text {
    CGFloat bubbleWidth = 190.0f;
    CGSize constraintSize = CGSizeMake(bubbleWidth-(19.0f + 11.0f), CGFLOAT_MAX);
    return [text sizeWithFont:[UIFont systemFontOfSize:11.0f] constrainedToSize:constraintSize lineBreakMode:UILineBreakModeHeadTruncation];
}

+ (NSString *) stringForDate:(NSDate *)date {
    NSDateFormatter *fmt = [[[NSDateFormatter alloc] init] autorelease];
    [fmt setDateFormat:@"HH:mm"];
    return [fmt stringFromDate:date];
}

+ (CGSize) cellSizeForText:(NSString *)text andHeader:(NSString *)header andDate:(NSDate *)date {
    CGFloat padding = 3.0f; // top and bottom padding
    CGSize textSize = [MUMessageBubbleView textSizeForText:text];
    CGSize headerSize = [MUMessageBubbleView headerSizeForText:header];
    NSString *str = [MUMessageBubbleView stringForDate:date];
    CGSize timestampSize = [MUMessageBubbleView timestampSizeForText:str];
    
    NSLog(@"textSize = %@", NSStringFromCGSize(textSize));
    NSLog(@"headerSize = %@", NSStringFromCGSize(headerSize));
    NSLog(@"timestampSize = %@", NSStringFromCGSize(timestampSize));
    
    return CGSizeMake(MAX(textSize.width, headerSize.width + 5.0f + timestampSize.width)+(19.0f + 11.0f), textSize.height+headerSize.height+(8.0f+10.0f)+(2*padding));
}

- (void) drawRect:(CGRect)rect {
    rect = self.bounds;

    UIImage *balloon = nil;
    UIImage *stretchableBalloon = nil;
    if (_rightSide) {
        balloon = [UIImage imageNamed:@"Balloon_Blue"];
        stretchableBalloon = [balloon resizableImageWithCapInsets:UIEdgeInsetsMake(14.0f, 17.0f, 17.0f, 23.0f)];
    } else {
        balloon = [UIImage imageNamed:@"Balloon_2"];
        stretchableBalloon = [balloon resizableImageWithCapInsets:UIEdgeInsetsMake(14.0f, 23.0f, 17.0f, 16.0f)];
    }

    NSString *text = _message;
    NSString *header = _header;
    CGSize textSize = [MUMessageBubbleView textSizeForText:text];
    CGSize headerSize = [MUMessageBubbleView headerSizeForText:header];

    NSString *dateStr = [MUMessageBubbleView stringForDate:_date];
    CGSize timestampSize = [MUMessageBubbleView timestampSizeForText:dateStr];

    CGRect imgRect = CGRectMake(0.0f, 3.0f, MAX(textSize.width, headerSize.width + 5.0f + timestampSize.width)+(19.0f + 11.0f), textSize.height+headerSize.height+(8.0f+10.0f));
    CGRect headerRect = CGRectMake(19.0f, 3.0f + 8.0f, headerSize.width, headerSize.height);
    CGRect timestampRect = CGRectMake(imgRect.size.width - 11.0f - timestampSize.width, headerRect.origin.y, timestampSize.width, timestampSize.height);
    CGRect textRect = CGRectMake(19.0f, 3.0f + 8.0f + headerSize.height, textSize.width, textSize.height);
    if (_rightSide) {
        imgRect.origin.x = 320.0f - imgRect.size.width;
        headerRect.origin.x = imgRect.origin.x + 11.0f;
        timestampRect.origin.x = 320.0f - 19.0f - timestampRect.size.width;
        textRect.origin.x = imgRect.origin.x + 11.0f;
    }

    [stretchableBalloon drawInRect:imgRect];

    [header drawInRect:headerRect withFont:[UIFont boldSystemFontOfSize:14.0f] lineBreakMode:UILineBreakModeCharacterWrap];
    [dateStr drawInRect:timestampRect withFont:[UIFont systemFontOfSize:11.0f] lineBreakMode:UILineBreakModeHeadTruncation];
    [text drawInRect:textRect withFont:[UIFont systemFontOfSize:14.0f] lineBreakMode:UILineBreakModeCharacterWrap];
}

- (void) setHeader:(NSString *)header {
    [_header release];
    _header = [header copy];
    [self setNeedsDisplay];
}

- (void) setMessage:(NSString *)msg {
    [_message release];
    _message = [msg copy];
    [self setNeedsDisplay];
}

- (void) setDate:(NSDate *)date {
    [_date release];
    _date = [date copy];
    [self setNeedsDisplay];
}

- (void) setRightSide:(BOOL)rightSide {
    _rightSide = rightSide;
}

@end

@interface MUMessageBubbleTableViewCell () {
    MUMessageBubbleView *_bubbleView;
}
@end

@implementation MUMessageBubbleTableViewCell

+ (CGFloat) heightForCellWithHeader:(NSString *)header message:(NSString *)msg date:(NSDate *)date {
    return [MUMessageBubbleView cellSizeForText:msg andHeader:header andDate:date].height;
}

- (id) initWithReuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier])) {
        [self setSelectionStyle:UITableViewCellSelectionStyleNone];
        _bubbleView = [[MUMessageBubbleView alloc] initWithFrame:self.contentView.frame];
        [_bubbleView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        [[self contentView] addSubview:_bubbleView];
    }
    return self;
}

- (void) setHeader:(NSString *)header {
    [_bubbleView setHeader:header];
}

- (void) setMessage:(NSString *)msg {
    [_bubbleView setMessage:msg];
}

- (void) setDate:(NSDate *)date {
    [_bubbleView setDate:date];
}

- (void) setRightSide:(BOOL)rightSide {
    [_bubbleView setRightSide:rightSide];
}

@end
