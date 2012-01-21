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

@end
