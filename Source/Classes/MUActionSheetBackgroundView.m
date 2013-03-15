// Copyright 2013 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUActionSheetBackgroundView.h"

@implementation MUActionSheetBackgroundView

- (id) initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        // ...
    }
    return self;
}

// Drawing code generated using 'Resources/UIElements/MUActionSheet/MUActionSheetBackgroundView.pcvd'
- (void)drawRect:(CGRect)rect {
    //// General Declarations
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    //// Color Declarations
    UIColor* fillColor = [UIColor colorWithRed: 0.365 green: 0.365 blue: 0.365 alpha: 1];
    UIColor* strokeColor = [UIColor colorWithRed: 0.125 green: 0.125 blue: 0.125 alpha: 1];
    UIColor* shadowColor2 = [UIColor colorWithRed: 0.541 green: 0.541 blue: 0.541 alpha: 1];
    UIColor* gradientColor = [UIColor colorWithRed: 0.063 green: 0.063 blue: 0.063 alpha: 1];
    UIColor* gradientColor2 = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 1];
    
    //// Gradient Declarations
    NSArray* gradientColors = [NSArray arrayWithObjects:
                               (id)fillColor.CGColor,
                               (id)[UIColor colorWithRed: 0.245 green: 0.245 blue: 0.245 alpha: 1].CGColor,
                               (id)strokeColor.CGColor, nil];
    CGFloat gradientLocations[] = {0, 0, 1};
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (CFArrayRef)gradientColors, gradientLocations);
    NSArray* gradient2Colors = [NSArray arrayWithObjects:
                                (id)gradientColor.CGColor,
                                (id)[UIColor colorWithRed: 0.031 green: 0.031 blue: 0.031 alpha: 1].CGColor,
                                (id)gradientColor2.CGColor, nil];
    CGFloat gradient2Locations[] = {0, 0.89, 1};
    CGGradientRef gradient2 = CGGradientCreateWithColors(colorSpace, (CFArrayRef)gradient2Colors, gradient2Locations);
    
    //// Shadow Declarations
    UIColor* shadow = shadowColor2;
    CGSize shadowOffset = CGSizeMake(0.1, 1.1);
    CGFloat shadowBlurRadius = 0;
    
    //// Frames
    CGRect frame = self.bounds;
    
    //// Background Drawing
    UIBezierPath* backgroundPath = [UIBezierPath bezierPathWithRect: CGRectMake(CGRectGetMinX(frame) + floor((CGRectGetWidth(frame)) * 0.00000 + 0.5), CGRectGetMinY(frame), CGRectGetWidth(frame) - floor((CGRectGetWidth(frame)) * 0.00000 + 0.5), CGRectGetHeight(frame))];
    [[UIColor blackColor] setFill];
    [backgroundPath fill];
    
    
    //// BottomTopGradient Drawing
    CGRect bottomTopGradientRect = CGRectMake(CGRectGetMinX(frame) + floor(CGRectGetWidth(frame) * 0.00000 + 0.5), CGRectGetMinY(frame) + 22, floor(CGRectGetWidth(frame) * 1.00000 + 0.5) - floor(CGRectGetWidth(frame) * 0.00000 + 0.5), 21);
    UIBezierPath* bottomTopGradientPath = [UIBezierPath bezierPathWithRect: bottomTopGradientRect];
    CGContextSaveGState(context);
    [bottomTopGradientPath addClip];
    CGContextDrawLinearGradient(context, gradient2,
                                CGPointMake(CGRectGetMidX(bottomTopGradientRect), CGRectGetMinY(bottomTopGradientRect)),
                                CGPointMake(CGRectGetMidX(bottomTopGradientRect), CGRectGetMaxY(bottomTopGradientRect)),
                                0);
    CGContextRestoreGState(context);
    
    
    //// TopTopGradient Drawing
    CGRect topTopGradientRect = CGRectMake(CGRectGetMinX(frame) + floor((CGRectGetWidth(frame)) * 0.00000 + 0.5), CGRectGetMinY(frame) + 1, CGRectGetWidth(frame) - floor((CGRectGetWidth(frame)) * 0.00000 + 0.5), 21);
    UIBezierPath* topTopGradientPath = [UIBezierPath bezierPathWithRect: topTopGradientRect];
    CGContextSaveGState(context);
    [topTopGradientPath addClip];
    CGContextDrawLinearGradient(context, gradient,
                                CGPointMake(CGRectGetMidX(topTopGradientRect), CGRectGetMinY(topTopGradientRect)),
                                CGPointMake(CGRectGetMidX(topTopGradientRect), CGRectGetMaxY(topTopGradientRect)),
                                0);
    CGContextRestoreGState(context);
    
    ////// TopTopGradient Inner Shadow
    CGRect topTopGradientBorderRect = CGRectInset([topTopGradientPath bounds], -shadowBlurRadius, -shadowBlurRadius);
    topTopGradientBorderRect = CGRectOffset(topTopGradientBorderRect, -shadowOffset.width, -shadowOffset.height);
    topTopGradientBorderRect = CGRectInset(CGRectUnion(topTopGradientBorderRect, [topTopGradientPath bounds]), -1, -1);
    
    UIBezierPath* topTopGradientNegativePath = [UIBezierPath bezierPathWithRect: topTopGradientBorderRect];
    [topTopGradientNegativePath appendPath: topTopGradientPath];
    topTopGradientNegativePath.usesEvenOddFillRule = YES;
    
    CGContextSaveGState(context);
    {
        CGFloat xOffset = shadowOffset.width + round(topTopGradientBorderRect.size.width);
        CGFloat yOffset = shadowOffset.height;
        CGContextSetShadowWithColor(context,
                                    CGSizeMake(xOffset + copysign(0.1, xOffset), yOffset + copysign(0.1, yOffset)),
                                    shadowBlurRadius,
                                    shadow.CGColor);
        
        [topTopGradientPath addClip];
        CGAffineTransform transform = CGAffineTransformMakeTranslation(-round(topTopGradientBorderRect.size.width), 0);
        [topTopGradientNegativePath applyTransform: transform];
        [[UIColor grayColor] setFill];
        [topTopGradientNegativePath fill];
    }
    CGContextRestoreGState(context);
    
    
    
    //// Cleanup
    CGGradientRelease(gradient);
    CGGradientRelease(gradient2);
    CGColorSpaceRelease(colorSpace);
}

@end
