// Copyright 2009-2012 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUImage.h"

@implementation MUImage

+ (UIImage *) tableViewCellImageFromImage:(UIImage *)srcImage {
    CGFloat scale = [[UIScreen mainScreen] scale];
    CGFloat scaledWidth = srcImage.size.width * (44.0f/srcImage.size.height);
    CGRect rect = CGRectMake(0, 0, scaledWidth, 44.0f);
    
    // Create the rounded-rect mask
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat radius = 10.0f;
    CGContextBeginPath(ctx);
    CGContextMoveToPoint(ctx, rect.origin.x, rect.origin.y + radius);
    CGContextAddLineToPoint(ctx, rect.origin.x, rect.origin.y + rect.size.height - radius);
    CGContextAddArc(ctx, rect.origin.x + radius, rect.origin.y + rect.size.height - radius, radius, M_PI, M_PI / 2, 1);
    CGContextAddLineToPoint(ctx, rect.origin.x + rect.size.width, rect.origin.y + rect.size.height);
    CGContextAddLineToPoint(ctx, rect.origin.x + rect.size.width, rect.origin.y);
    CGContextAddLineToPoint(ctx, rect.origin.x + radius, rect.origin.y);
    CGContextAddArc(ctx, rect.origin.x + radius, rect.origin.y + radius, radius, -M_PI / 2, M_PI, 1);
    CGContextClosePath(ctx);
    [[UIColor blackColor] set];
    CGContextFillPath(ctx);
    UIImage *alphaMask = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // Draw the image
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, scale);
    ctx = UIGraphicsGetCurrentContext();
    CGContextClipToMask(ctx, rect, alphaMask.CGImage);
    [srcImage drawInRect:rect];
    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return scaledImage;
}

+ (UIImage *) imageNamed:(NSString *)imageName {
    CGFloat scale = [UIScreen mainScreen].scale;
    CGFloat height = [UIScreen mainScreen].bounds.size.height;
    // For now, we require all -568h images to also be @2x.
    if (height == 568 && scale == 2) {
        NSString *expectedFn = [NSString stringWithFormat:@"%@-568h", imageName];
        UIImage *attemptedImage = [UIImage imageNamed:expectedFn];
        if (attemptedImage != nil) {
            return attemptedImage;
        }
        // fallthrough
    }
    return [UIImage imageNamed:imageName];
}

@end
