// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUUserStateAcessoryView.h"
#import "MUColor.h"

#import <MumbleKit/MKUser.h>

@implementation MUUserStateAcessoryView

+ (UIView *) viewForUser:(MKUser *)user {
    const CGFloat iconSize = 20.0f;
    const CGFloat iconSpacing = 4.0f;
    
    NSMutableArray *iconViews = [[NSMutableArray alloc] init];
    
    if ([user isAuthenticated])
        [iconViews addObject:[self _iconWithSFSymbol:@"checkmark.shield.fill" color:[UIColor systemGreenColor] size:iconSize]];
    if ([user isSelfDeafened])
        [iconViews addObject:[self _iconWithSFSymbol:@"speaker.slash.fill" color:[UIColor systemRedColor] size:iconSize]];
    else if ([user isDeafened])
        [iconViews addObject:[self _iconWithSFSymbol:@"speaker.slash" color:[UIColor systemRedColor] size:iconSize]];
    if ([user isSelfMuted])
        [iconViews addObject:[self _iconWithSFSymbol:@"mic.slash.fill" color:[UIColor systemRedColor] size:iconSize]];
    else if ([user isMuted])
        [iconViews addObject:[self _iconWithSFSymbol:@"mic.slash" color:[UIColor systemRedColor] size:iconSize]];
    else if ([user isLocalMuted])
        [iconViews addObject:[self _iconWithSFSymbol:@"mic.slash.fill" color:[UIColor systemOrangeColor] size:iconSize]];
    else if ([user isSuppressed])
        [iconViews addObject:[self _iconWithSFSymbol:@"mic.slash" color:[MUColor secondaryTextColor] size:iconSize]];
    if ([user isPrioritySpeaker])
        [iconViews addObject:[self _iconWithSFSymbol:@"exclamationmark.triangle.fill" color:[UIColor systemYellowColor] size:iconSize]];
    
    if ([iconViews count] == 0)
        return nil;
    
    CGFloat totalWidth = [iconViews count] * iconSize + ([iconViews count] - 1) * iconSpacing;
    UIView *stateView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, totalWidth, iconSize)];
    
    CGFloat x = 0;
    for (UIImageView *iv in iconViews) {
        iv.frame = CGRectMake(x, 0, iconSize, iconSize);
        [stateView addSubview:iv];
        x += iconSize + iconSpacing;
    }
    
    return stateView;
}

+ (UIImageView *) _iconWithSFSymbol:(NSString *)symbolName color:(UIColor *)color size:(CGFloat)size {
    UIImageView *imageView = [[UIImageView alloc] init];
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:size - 4 weight:UIImageSymbolWeightMedium];
        UIImage *img = [UIImage systemImageNamed:symbolName withConfiguration:config];
        imageView.image = img;
        imageView.tintColor = color;
    } else {
        // Fallback to old PNGs for pre-iOS 13
        imageView.image = [UIImage imageNamed:symbolName];
    }
    imageView.contentMode = UIViewContentModeCenter;
    return imageView;
}

@end
