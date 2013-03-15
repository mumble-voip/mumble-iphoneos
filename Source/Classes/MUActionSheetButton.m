// Copyright 2013 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUActionSheetButton.h"

@interface MUActionSheetButton () {
    NSString                 *_title;
    MUActionSheetButtonKind  _kind;
}
- (id) initWithKind:(MUActionSheetButtonKind)kind;
- (void) drawBlueHighlightState;
- (void) drawGrayHighlightState;
- (void) drawCancelState;
- (void) drawNormalState;
- (void) drawConstructiveState;
@end

@implementation MUActionSheetButton

+ (MUActionSheetButton *) buttonWithKind:(MUActionSheetButtonKind)kind {
    return [[[MUActionSheetButton alloc] initWithKind:kind] autorelease];
}

- (id) initWithKind:(MUActionSheetButtonKind)kind {
    if ((self = [super initWithFrame:CGRectZero])) {
        self.opaque = NO;
        _kind = kind;
    }
    return self;
}

- (void) dealloc {
    [_title release];
    
    [super dealloc];
}

- (void) setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [self setNeedsDisplay];
}

- (void) setTitle:(NSString *)title {
    [_title release];
    _title = [title copy];
}

- (NSString *) title {
    return _title;
}

- (void) drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextClearRect(context, self.bounds);

    if (self.highlighted) {
        [self drawGrayHighlightState];
    } else if (_kind == MUActionSheetButtonKindNormal) {
        [self drawNormalState];
    } else if (_kind == MUActionSheetButtonKindCancel) {
        [self drawCancelState];
    } else if (_kind == MUActionSheetButtonKindDestructive) {
        [self drawDestructiveState];
    } else if (_kind == MUActionSheetButtonKindConstructive) {
        [self drawConstructiveState];
    }
}

// Drawing code generated using 'Resources/UIElements/MUActionSheet/MUActionSheetButtonBlueHighlight.pcvd'
- (void) drawBlueHighlightState {
    //// General Declarations
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    //// Color Declarations
    UIColor* strokeColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 1];
    UIColor* gradientStartColor = [UIColor colorWithRed: 1 green: 1 blue: 1 alpha: 1];
    UIColor* gradientMiddleColor = [UIColor colorWithRed: 0.031 green: 0.161 blue: 0.698 alpha: 1];
    UIColor* fontColor = [UIColor colorWithRed: 1 green: 1 blue: 1 alpha: 1];
    UIColor* gradientEndColor = [UIColor colorWithRed: 0.275 green: 0.38 blue: 0.816 alpha: 1];
    UIColor* textShadowColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 1];
    
    //// Gradient Declarations
    NSArray* gradientColors = [NSArray arrayWithObjects:
                               (id)gradientStartColor.CGColor,
                               (id)[UIColor colorWithRed: 0.516 green: 0.58 blue: 0.849 alpha: 1].CGColor,
                               (id)gradientMiddleColor.CGColor,
                               (id)[UIColor colorWithRed: 0.031 green: 0.161 blue: 0.698 alpha: 1].CGColor,
                               (id)gradientMiddleColor.CGColor,
                               (id)[UIColor colorWithRed: 0.153 green: 0.271 blue: 0.757 alpha: 1].CGColor,
                               (id)gradientEndColor.CGColor, nil];
    CGFloat gradientLocations[] = {0, 0.03, 0.67, 0.74, 0.83, 0.95, 1};
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (CFArrayRef)gradientColors, gradientLocations);
    
    //// Shadow Declarations
    UIColor* shadow = [UIColor whiteColor];
    CGSize shadowOffset = CGSizeMake(0.1, 1.1);
    CGFloat shadowBlurRadius = 2;
    UIColor* textShadow = textShadowColor;
    CGSize textShadowOffset = CGSizeMake(0.1, -1.1);
    CGFloat textShadowBlurRadius = 0;
    
    //// Frames
    CGRect frame = self.bounds;
    
    //// Abstracted Attributes
    NSString* textContent = _title;
    
    
    //// Rounded Rectangle Drawing
    CGRect roundedRectangleRect = CGRectMake(CGRectGetMinX(frame) + 1.5, CGRectGetMinY(frame) + 1.5, CGRectGetWidth(frame) - 3, CGRectGetHeight(frame) - 5);
    UIBezierPath* roundedRectanglePath = [UIBezierPath bezierPathWithRoundedRect: roundedRectangleRect cornerRadius: 10];
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, shadowOffset, shadowBlurRadius, shadow.CGColor);
    CGContextBeginTransparencyLayer(context, NULL);
    [roundedRectanglePath addClip];
    CGContextDrawLinearGradient(context, gradient,
                                CGPointMake(CGRectGetMidX(roundedRectangleRect), CGRectGetMinY(roundedRectangleRect)),
                                CGPointMake(CGRectGetMidX(roundedRectangleRect), CGRectGetMaxY(roundedRectangleRect)),
                                0);
    CGContextEndTransparencyLayer(context);
    CGContextRestoreGState(context);
    
    [strokeColor setStroke];
    roundedRectanglePath.lineWidth = 3;
    [roundedRectanglePath stroke];
    
    
    //// Text Drawing
    CGRect textRect = CGRectMake(CGRectGetMinX(frame) + 1, CGRectGetMinY(frame) + 2, CGRectGetWidth(frame) - 3, CGRectGetHeight(frame) - 5);
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, textShadowOffset, textShadowBlurRadius, textShadow.CGColor);
    [fontColor setFill];
    [textContent drawInRect: CGRectInset(textRect, 0, 9) withFont: [UIFont boldSystemFontOfSize: 20.5] lineBreakMode: UILineBreakModeWordWrap alignment: UITextAlignmentCenter];
    CGContextRestoreGState(context);
    
    
    
    //// Cleanup
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
}

// Drawing code generated using 'Resources/UIElements/MUActionSheet/MUActionSheetButtonGrayHighlight.pcvd'
- (void) drawGrayHighlightState {
    //// General Declarations
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    //// Color Declarations
    UIColor* strokeColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 1];
    UIColor* gradientStartColor = [UIColor colorWithRed: 0.654 green: 0.654 blue: 0.654 alpha: 1];
    UIColor* gradientMiddleColor = [UIColor colorWithRed: 0.205 green: 0.198 blue: 0.198 alpha: 1];
    UIColor* fontColor = [UIColor colorWithRed: 1 green: 1 blue: 1 alpha: 1];
    UIColor* gradientEndColor = [UIColor colorWithRed: 0.303 green: 0.301 blue: 0.301 alpha: 1];
    UIColor* textShadowColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 1];
    
    //// Gradient Declarations
    NSArray* gradientColors = [NSArray arrayWithObjects:
                               (id)gradientStartColor.CGColor,
                               (id)[UIColor colorWithRed: 0.429 green: 0.426 blue: 0.426 alpha: 1].CGColor,
                               (id)gradientMiddleColor.CGColor,
                               (id)[UIColor colorWithRed: 0.205 green: 0.198 blue: 0.198 alpha: 1].CGColor,
                               (id)gradientMiddleColor.CGColor,
                               (id)[UIColor colorWithRed: 0.254 green: 0.25 blue: 0.25 alpha: 1].CGColor,
                               (id)gradientEndColor.CGColor, nil];
    CGFloat gradientLocations[] = {0, 0.03, 0.67, 0.74, 0.83, 0.95, 1};
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (CFArrayRef)gradientColors, gradientLocations);
    
    //// Shadow Declarations
    UIColor* shadow = [UIColor whiteColor];
    CGSize shadowOffset = CGSizeMake(0.1, 1.1);
    CGFloat shadowBlurRadius = 2;
    UIColor* textShadow = textShadowColor;
    CGSize textShadowOffset = CGSizeMake(0.1, -1.1);
    CGFloat textShadowBlurRadius = 0;
    
    //// Frames
    CGRect frame = self.bounds;
    
    
    //// Abstracted Attributes
    NSString* textContent = _title;
    
    
    //// Rounded Rectangle Drawing
    CGRect roundedRectangleRect = CGRectMake(CGRectGetMinX(frame) + 1.5, CGRectGetMinY(frame) + 1.5, CGRectGetWidth(frame) - 3, CGRectGetHeight(frame) - 5);
    UIBezierPath* roundedRectanglePath = [UIBezierPath bezierPathWithRoundedRect: roundedRectangleRect cornerRadius: 10];
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, shadowOffset, shadowBlurRadius, shadow.CGColor);
    CGContextBeginTransparencyLayer(context, NULL);
    [roundedRectanglePath addClip];
    CGContextDrawLinearGradient(context, gradient,
                                CGPointMake(CGRectGetMidX(roundedRectangleRect), CGRectGetMinY(roundedRectangleRect)),
                                CGPointMake(CGRectGetMidX(roundedRectangleRect), CGRectGetMaxY(roundedRectangleRect)),
                                0);
    CGContextEndTransparencyLayer(context);
    CGContextRestoreGState(context);
    
    [strokeColor setStroke];
    roundedRectanglePath.lineWidth = 3;
    [roundedRectanglePath stroke];
    
    
    //// Text Drawing
    CGRect textRect = CGRectMake(CGRectGetMinX(frame) + 1, CGRectGetMinY(frame) + 2, CGRectGetWidth(frame) - 3, CGRectGetHeight(frame) - 5);
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, textShadowOffset, textShadowBlurRadius, textShadow.CGColor);
    [fontColor setFill];
    [textContent drawInRect: CGRectInset(textRect, 0, 9) withFont: [UIFont boldSystemFontOfSize: 20.5] lineBreakMode: UILineBreakModeWordWrap alignment: UITextAlignmentCenter];
    CGContextRestoreGState(context);
    
    
    
    //// Cleanup
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
}

// Drawing code generated using 'Resources/MUActionSheet/MUActionSheetButtonCancel.pcvd'
- (void) drawCancelState {
    //// General Declarations
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    //// Color Declarations
    UIColor* strokeColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 1];
    UIColor* gradientStartColor = [UIColor colorWithRed: 0.706 green: 0.706 blue: 0.706 alpha: 1];
    UIColor* gradientMiddleColor = [UIColor colorWithRed: 0.004 green: 0.004 blue: 0.004 alpha: 1];
    UIColor* fontColor = [UIColor colorWithRed: 1 green: 1 blue: 1 alpha: 1];
    UIColor* gradientEndColor = [UIColor colorWithRed: 0.232 green: 0.232 blue: 0.232 alpha: 1];
    UIColor* textShadowColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 1];
    
    //// Gradient Declarations
    NSArray* gradientColors = [NSArray arrayWithObjects:
                               (id)gradientStartColor.CGColor,
                               (id)[UIColor colorWithRed: 0.355 green: 0.355 blue: 0.355 alpha: 1].CGColor,
                               (id)gradientMiddleColor.CGColor,
                               (id)[UIColor colorWithRed: 0.004 green: 0.004 blue: 0.004 alpha: 1].CGColor,
                               (id)gradientMiddleColor.CGColor,
                               (id)[UIColor colorWithRed: 0.118 green: 0.118 blue: 0.118 alpha: 1].CGColor,
                               (id)gradientEndColor.CGColor, nil];
    CGFloat gradientLocations[] = {0, 0.03, 0.67, 0.74, 0.83, 0.95, 1};
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (CFArrayRef)gradientColors, gradientLocations);
    
    //// Shadow Declarations
    UIColor* shadow = [UIColor whiteColor];
    CGSize shadowOffset = CGSizeMake(0.1, 1.1);
    CGFloat shadowBlurRadius = 2;
    UIColor* textShadow = textShadowColor;
    CGSize textShadowOffset = CGSizeMake(0.1, -1.1);
    CGFloat textShadowBlurRadius = 0;
    
    //// Frames
    CGRect frame = self.bounds;
    
    
    //// Abstracted Attributes
    NSString* textContent = _title;
    
    
    //// Rounded Rectangle Drawing
    CGRect roundedRectangleRect = CGRectMake(CGRectGetMinX(frame) + 1.5, CGRectGetMinY(frame) + 1.5, CGRectGetWidth(frame) - 3, CGRectGetHeight(frame) - 5);
    UIBezierPath* roundedRectanglePath = [UIBezierPath bezierPathWithRoundedRect: roundedRectangleRect cornerRadius: 10];
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, shadowOffset, shadowBlurRadius, shadow.CGColor);
    CGContextBeginTransparencyLayer(context, NULL);
    [roundedRectanglePath addClip];
    CGContextDrawLinearGradient(context, gradient,
                                CGPointMake(CGRectGetMidX(roundedRectangleRect), CGRectGetMinY(roundedRectangleRect)),
                                CGPointMake(CGRectGetMidX(roundedRectangleRect), CGRectGetMaxY(roundedRectangleRect)),
                                0);
    CGContextEndTransparencyLayer(context);
    CGContextRestoreGState(context);
    
    [strokeColor setStroke];
    roundedRectanglePath.lineWidth = 3;
    [roundedRectanglePath stroke];
    
    
    //// Text Drawing
    CGRect textRect = CGRectMake(CGRectGetMinX(frame) + 1, CGRectGetMinY(frame) + 2, CGRectGetWidth(frame) - 3, CGRectGetHeight(frame) - 5);
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, textShadowOffset, textShadowBlurRadius, textShadow.CGColor);
    [fontColor setFill];
    [textContent drawInRect: CGRectInset(textRect, 0, 9) withFont: [UIFont boldSystemFontOfSize: 20.5] lineBreakMode: UILineBreakModeWordWrap alignment: UITextAlignmentCenter];
    CGContextRestoreGState(context);
    
    
    
    //// Cleanup
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
}

// Drawing code generated using 'Resources/MUActionSheet/MUActionSheetButtonNormal.pcvd'
- (void) drawNormalState {
    //// General Declarations
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    //// Color Declarations
    UIColor* strokeColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 1];
    UIColor* gradientStartColor = [UIColor colorWithRed: 1 green: 1 blue: 1 alpha: 1];
    UIColor* gradientMiddleColor = [UIColor colorWithRed: 0.765 green: 0.769 blue: 0.776 alpha: 1];
    UIColor* fontColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 1];
    UIColor* gradientEndColor = [UIColor colorWithRed: 1 green: 1 blue: 1 alpha: 1];
    
    //// Gradient Declarations
    NSArray* gradientColors = [NSArray arrayWithObjects:
                               (id)gradientStartColor.CGColor,
                               (id)[UIColor colorWithRed: 0.882 green: 0.884 blue: 0.888 alpha: 1].CGColor,
                               (id)gradientMiddleColor.CGColor,
                               (id)[UIColor colorWithRed: 0.765 green: 0.769 blue: 0.776 alpha: 1].CGColor,
                               (id)gradientMiddleColor.CGColor,
                               (id)[UIColor colorWithRed: 0.882 green: 0.884 blue: 0.888 alpha: 1].CGColor,
                               (id)gradientEndColor.CGColor, nil];
    CGFloat gradientLocations[] = {0, 0.03, 0.67, 0.74, 0.83, 0.95, 1};
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (CFArrayRef)gradientColors, gradientLocations);
    
    //// Shadow Declarations
    UIColor* shadow = [UIColor whiteColor];
    CGSize shadowOffset = CGSizeMake(0.1, 1.1);
    CGFloat shadowBlurRadius = 2;
    
    //// Frames
    CGRect frame = self.bounds;
    
    
    //// Abstracted Attributes
    NSString* textContent = _title;
    
    
    //// Rounded Rectangle Drawing
    CGRect roundedRectangleRect = CGRectMake(CGRectGetMinX(frame) + 1.5, CGRectGetMinY(frame) + 1.5, CGRectGetWidth(frame) - 3, CGRectGetHeight(frame) - 5);
    UIBezierPath* roundedRectanglePath = [UIBezierPath bezierPathWithRoundedRect: roundedRectangleRect cornerRadius: 10];
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, shadowOffset, shadowBlurRadius, shadow.CGColor);
    CGContextBeginTransparencyLayer(context, NULL);
    [roundedRectanglePath addClip];
    CGContextDrawLinearGradient(context, gradient,
                                CGPointMake(CGRectGetMidX(roundedRectangleRect), CGRectGetMinY(roundedRectangleRect)),
                                CGPointMake(CGRectGetMidX(roundedRectangleRect), CGRectGetMaxY(roundedRectangleRect)),
                                0);
    CGContextEndTransparencyLayer(context);
    CGContextRestoreGState(context);
    
    [strokeColor setStroke];
    roundedRectanglePath.lineWidth = 3;
    [roundedRectanglePath stroke];
    
    
    //// Text Drawing
    CGRect textRect = CGRectMake(CGRectGetMinX(frame) + 1, CGRectGetMinY(frame) + 2, CGRectGetWidth(frame) - 3, CGRectGetHeight(frame) - 5);
    [fontColor setFill];
    [textContent drawInRect: CGRectInset(textRect, 0, 9) withFont: [UIFont boldSystemFontOfSize: 20.5] lineBreakMode: UILineBreakModeWordWrap alignment: UITextAlignmentCenter];
    
    
    //// Cleanup
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
}

// Drawing code generated using 'Resources/UIElements/MUActionSheet/MUActionSheetButtonDestructive.pcvd'
- (void) drawDestructiveState {
    //// General Declarations
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    //// Color Declarations
    UIColor* strokeColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 1];
    UIColor* gradientStartColor = [UIColor colorWithRed: 1 green: 1 blue: 1 alpha: 1];
    UIColor* gradientMiddleColor = [UIColor colorWithRed: 0.808 green: 0.051 blue: 0.071 alpha: 1];
    UIColor* fontColor = [UIColor colorWithRed: 1 green: 1 blue: 1 alpha: 1];
    UIColor* gradientEndColor = [UIColor colorWithRed: 0.768 green: 0.569 blue: 0.569 alpha: 1];
    UIColor* textShadowColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 0.303];
    
    //// Gradient Declarations
    NSArray* gradientColors = [NSArray arrayWithObjects:
                               (id)gradientStartColor.CGColor,
                               (id)[UIColor colorWithRed: 0.904 green: 0.525 blue: 0.535 alpha: 1].CGColor,
                               (id)gradientMiddleColor.CGColor,
                               (id)[UIColor colorWithRed: 0.808 green: 0.051 blue: 0.071 alpha: 1].CGColor,
                               (id)gradientMiddleColor.CGColor,
                               (id)[UIColor colorWithRed: 0.788 green: 0.31 blue: 0.32 alpha: 1].CGColor,
                               (id)gradientEndColor.CGColor, nil];
    CGFloat gradientLocations[] = {0, 0.03, 0.67, 0.74, 0.83, 0.95, 1};
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (CFArrayRef)gradientColors, gradientLocations);
    
    //// Shadow Declarations
    UIColor* shadow = [UIColor whiteColor];
    CGSize shadowOffset = CGSizeMake(0.1, 1.1);
    CGFloat shadowBlurRadius = 2;
    UIColor* textShadow = textShadowColor;
    CGSize textShadowOffset = CGSizeMake(0.1, -1.1);
    CGFloat textShadowBlurRadius = 0;
    
    //// Frames
    CGRect frame = self.bounds;
    
    
    //// Abstracted Attributes
    NSString* textContent = _title;
    
    
    //// Rounded Rectangle Drawing
    CGRect roundedRectangleRect = CGRectMake(CGRectGetMinX(frame) + 1.5, CGRectGetMinY(frame) + 1.5, CGRectGetWidth(frame) - 3, CGRectGetHeight(frame) - 5);
    UIBezierPath* roundedRectanglePath = [UIBezierPath bezierPathWithRoundedRect: roundedRectangleRect cornerRadius: 10];
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, shadowOffset, shadowBlurRadius, shadow.CGColor);
    CGContextBeginTransparencyLayer(context, NULL);
    [roundedRectanglePath addClip];
    CGContextDrawLinearGradient(context, gradient,
                                CGPointMake(CGRectGetMidX(roundedRectangleRect), CGRectGetMinY(roundedRectangleRect)),
                                CGPointMake(CGRectGetMidX(roundedRectangleRect), CGRectGetMaxY(roundedRectangleRect)),
                                0);
    CGContextEndTransparencyLayer(context);
    CGContextRestoreGState(context);
    
    [strokeColor setStroke];
    roundedRectanglePath.lineWidth = 3;
    [roundedRectanglePath stroke];
    
    
    //// Text Drawing
    CGRect textRect = CGRectMake(CGRectGetMinX(frame) + 1, CGRectGetMinY(frame) + 2, CGRectGetWidth(frame) - 3, CGRectGetHeight(frame) - 5);
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, textShadowOffset, textShadowBlurRadius, textShadow.CGColor);
    [fontColor setFill];
    [textContent drawInRect: CGRectInset(textRect, 0, 9) withFont: [UIFont boldSystemFontOfSize: 20.5] lineBreakMode: UILineBreakModeWordWrap alignment: UITextAlignmentCenter];
    CGContextRestoreGState(context);
    
    
    
    //// Cleanup
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
}

// Drawing code generated using 'Resources/UIElements/MUActionSheet/MUActionSheetButtonConstructive.pcvd'
- (void) drawConstructiveState {
    //// General Declarations
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    //// Color Declarations
    UIColor* strokeColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 1];
    UIColor* gradientStartColor = [UIColor colorWithRed: 0.685 green: 0.844 blue: 0.566 alpha: 1];
    UIColor* gradientMiddleColor = [UIColor colorWithRed: 0.182 green: 0.486 blue: 0.044 alpha: 1];
    UIColor* fontColor = [UIColor colorWithRed: 1 green: 1 blue: 1 alpha: 1];
    UIColor* gradientEndColor = [UIColor colorWithRed: 0.185 green: 0.353 blue: 0 alpha: 1];
    UIColor* textShadowColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 0.303];
    
    //// Gradient Declarations
    NSArray* gradientColors = [NSArray arrayWithObjects:
                               (id)gradientStartColor.CGColor,
                               (id)[UIColor colorWithRed: 0.433 green: 0.665 blue: 0.305 alpha: 1].CGColor,
                               (id)gradientMiddleColor.CGColor,
                               (id)[UIColor colorWithRed: 0.182 green: 0.486 blue: 0.044 alpha: 1].CGColor,
                               (id)gradientMiddleColor.CGColor,
                               (id)[UIColor colorWithRed: 0.183 green: 0.42 blue: 0.022 alpha: 1].CGColor,
                               (id)gradientEndColor.CGColor, nil];
    CGFloat gradientLocations[] = {0, 0.03, 0.67, 0.74, 0.83, 0.95, 1};
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (CFArrayRef)gradientColors, gradientLocations);
    
    //// Shadow Declarations
    UIColor* shadow = [UIColor whiteColor];
    CGSize shadowOffset = CGSizeMake(0.1, 1.1);
    CGFloat shadowBlurRadius = 2;
    UIColor* textShadow = textShadowColor;
    CGSize textShadowOffset = CGSizeMake(0.1, -1.1);
    CGFloat textShadowBlurRadius = 0;
    
    //// Frames
    CGRect frame = self.bounds;
    
    
    //// Abstracted Attributes
    NSString* textContent = _title;
    
    
    //// Rounded Rectangle Drawing
    CGRect roundedRectangleRect = CGRectMake(CGRectGetMinX(frame) + 1.5, CGRectGetMinY(frame) + 1.5, CGRectGetWidth(frame) - 3, CGRectGetHeight(frame) - 5);
    UIBezierPath* roundedRectanglePath = [UIBezierPath bezierPathWithRoundedRect: roundedRectangleRect cornerRadius: 10];
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, shadowOffset, shadowBlurRadius, shadow.CGColor);
    CGContextBeginTransparencyLayer(context, NULL);
    [roundedRectanglePath addClip];
    CGContextDrawLinearGradient(context, gradient,
                                CGPointMake(CGRectGetMidX(roundedRectangleRect), CGRectGetMinY(roundedRectangleRect)),
                                CGPointMake(CGRectGetMidX(roundedRectangleRect), CGRectGetMaxY(roundedRectangleRect)),
                                0);
    CGContextEndTransparencyLayer(context);
    CGContextRestoreGState(context);
    
    [strokeColor setStroke];
    roundedRectanglePath.lineWidth = 3;
    [roundedRectanglePath stroke];
    
    
    //// Text Drawing
    CGRect textRect = CGRectMake(CGRectGetMinX(frame) + 1, CGRectGetMinY(frame) + 2, CGRectGetWidth(frame) - 3, CGRectGetHeight(frame) - 5);
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, textShadowOffset, textShadowBlurRadius, textShadow.CGColor);
    [fontColor setFill];
    [textContent drawInRect: CGRectInset(textRect, 0, 9) withFont: [UIFont boldSystemFontOfSize: 20.5] lineBreakMode: UILineBreakModeWordWrap alignment: UITextAlignmentCenter];
    CGContextRestoreGState(context);
    
    
    
    //// Cleanup
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
}

@end
