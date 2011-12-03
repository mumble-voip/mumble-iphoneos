/* Copyright (C) 2009-2011 Mikkel Krautz <mikkel@krautz.dk>

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

#import "MUAudioBarView.h"

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
    
    if (_above < _below) {
        CGContextSetFillColorWithColor(ctx, [[UIColor redColor] colorWithAlphaComponent:0.6f].CGColor);
        CGContextFillRect(ctx, bounds);
        return;
    }
    
    CGFloat scale = bounds.size.width / (_max - _min);
    int below = (int)((_below-_min)*scale);
    int above = (int)((_above-_min)*scale);
    int value = (int)((_value-_min)*scale);
    
    CGColorRef redA = [[UIColor redColor] colorWithAlphaComponent:0.6f].CGColor;
    CGColorRef redO = [UIColor redColor].CGColor;
    CGColorRef yellowA = [[UIColor yellowColor] colorWithAlphaComponent:0.6f].CGColor;
    CGColorRef yellowO = [UIColor yellowColor].CGColor;
    CGColorRef greenA = [[UIColor greenColor] colorWithAlphaComponent:0.6f].CGColor;
    CGColorRef greenO = [UIColor greenColor].CGColor;
    
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
