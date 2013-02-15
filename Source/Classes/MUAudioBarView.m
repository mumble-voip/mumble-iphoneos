// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUAudioBarView.h"
#import "MUColor.h"

#import <MumbleKit/MKAudio.h>

@interface MUAudioBarView () {
    CGFloat _below;
    CGFloat _above;
    CGFloat _min;
    CGFloat _max;
    CGFloat _value;
    NSTimer *_timer;
}
@end

@implementation MUAudioBarView

- (id) initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _value = 0.5f;
        _min = 0.0f;
        _max = 1.0f;
        _timer = [[NSTimer timerWithTimeInterval:1/60.0f target:self selector:@selector(tickTock) userInfo:nil repeats:YES] retain];
        [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
    }
    return self;
}

- (void) dealloc {
    [_timer invalidate];
    [_timer release];
    [super dealloc];
}

- (void) setBelow:(CGFloat)below {
    _below = below;
}

- (void) setAbove:(CGFloat)above {
    _above = above;
}

- (void) drawRect:(CGRect)rect {
    CGRect bounds = self.bounds;
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextClearRect(ctx, bounds);

    _below = [[NSUserDefaults standardUserDefaults] floatForKey:@"AudioVADBelow"];
    _above = [[NSUserDefaults standardUserDefaults] floatForKey:@"AudioVADAbove"];
    
    CGFloat scale = bounds.size.width / (_max - _min);
    int below = (int)((_below-_min)*scale);
    int above = (int)((_above-_min)*scale);
    int value = (int)((_value-_min)*scale);
    
    CGColorRef redA = [[MUColor badPingColor] colorWithAlphaComponent:0.6f].CGColor;
    CGColorRef redO = [MUColor badPingColor].CGColor;
    CGColorRef yellowA = [[MUColor mediumPingColor] colorWithAlphaComponent:0.6f].CGColor;
    CGColorRef yellowO = [MUColor mediumPingColor].CGColor;
    CGColorRef greenA = [[MUColor goodPingColor] colorWithAlphaComponent:0.6f].CGColor;
    CGColorRef greenO = [MUColor goodPingColor].CGColor;
    
    if (_above < _below) {
        CGContextSetFillColorWithColor(ctx, redA);
        CGContextFillRect(ctx, bounds);
        return;
    }
    
    CGRect redBounds = CGRectMake(bounds.origin.x, 0, below, bounds.size.height);
    CGContextSetFillColorWithColor(ctx, redA);
    CGContextFillRect(ctx, redBounds);

    int x = redBounds.size.width;
    CGRect yellowBounds = CGRectMake(x, 0, above-x, bounds.size.height);
    CGContextSetFillColorWithColor(ctx, yellowA);
    CGContextFillRect(ctx, yellowBounds);

    x = yellowBounds.origin.x+yellowBounds.size.width;
    CGRect greenBounds = CGRectMake(x, 0, bounds.size.width-x, bounds.size.height);
    CGContextSetFillColorWithColor(ctx, greenA);
    CGContextFillRect(ctx, greenBounds);

    if (value > below) {
        CGContextSetFillColorWithColor(ctx, redO);
        CGContextFillRect(ctx, redBounds);
    } else {
        redBounds = CGRectMake(bounds.origin.x, 0, value, bounds.size.height);
        CGContextSetFillColorWithColor(ctx, redO);
        CGContextFillRect(ctx, redBounds);
    }
    if (value > above) {
        CGContextSetFillColorWithColor(ctx, yellowO);
        CGContextFillRect(ctx, yellowBounds);

        greenBounds = CGRectMake(x, 0, value-x, bounds.size.height);
        CGContextSetFillColorWithColor(ctx, greenO);
        CGContextFillRect(ctx, greenBounds);
    } else if (value > below && value <= above) {
        x = redBounds.size.width;
        CGRect yellowBounds = CGRectMake(x, 0, value-x, bounds.size.height);
        CGContextSetFillColorWithColor(ctx, yellowO);
        CGContextFillRect(ctx, yellowBounds);
    }
}

- (void) tickTock {
    MKAudio *audio = [MKAudio sharedAudio];
    NSString *kind = [[NSUserDefaults standardUserDefaults] objectForKey:@"AudioVADKind"];
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"AudioPreprocessor"])
        kind = @"amplitude";
    if ([kind isEqualToString:@"snr"]) {
        _value = [audio speechProbablity];
    } else {
        _value = ([audio peakCleanMic] + 96.0)/96.0;
    }
    [self setNeedsDisplay];
}

@end
