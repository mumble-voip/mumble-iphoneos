// Copyright 2009-2012 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUImage.h"

@implementation MUImage

+ (UIImage *) tableViewCellImageFromImage:(UIImage *)srcImage {
    if (srcImage.size.height <= 0) return nil;
    CGSize size = CGSizeMake(srcImage.size.width * 44.0 / srcImage.size.height, 44.0);
    CGRect bounds = (CGRect){CGPointZero, size};
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [[UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:10] addClip];
        [srcImage drawInRect:bounds];
    }];
}

+ (UIImage *) symbolNamed:(NSString *)name pointSize:(CGFloat)pointSize {
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:UIImageSymbolWeightMedium];
    return [UIImage systemImageNamed:name withConfiguration:configuration];
}

+ (UIImage *)channelSymbolForCurrentChannel:(BOOL)current {
    return [[self symbolNamed:current ? @"speaker.wave.2.fill" : @"speaker.wave.2" pointSize:22] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

// Keep the symbol a template; its image view owns the live speaking-state tint.
+ (UIImage *)userTalkSymbolForState:(NSInteger)talkState {
    return [[self symbolNamed:talkState == 0 ? @"person.fill" : @"person.wave.2.fill" pointSize:22] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

+ (UIColor *)userTalkColorForState:(NSInteger)talkState {
    return talkState == 0 ? [UIColor secondaryLabelColor] : [UIColor systemGreenColor];
}

@end
