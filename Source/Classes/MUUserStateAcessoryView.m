// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUUserStateAcessoryView.h"
#import "MUImage.h"

#import "MLClient.h"

@implementation MUUserStateAcessoryView

+ (UIView *) viewForUser:(MLUser *)user {
    const CGFloat iconHeight = 24;
    const CGFloat iconWidth = 22;
    NSMutableArray *states = [NSMutableArray array];
    NSMutableArray<UIColor *> *colors = [NSMutableArray array];
    if (user.isAuthenticated)
        { [states addObject:@"checkmark.seal.fill"]; [colors addObject:UIColor.secondaryLabelColor]; }
    if (user.isSelfDeafened || user.isDeafened)
        { [states addObject:@"speaker.slash.fill"]; [colors addObject:UIColor.systemRedColor]; }
    if (user.isSuppressed)
        { [states addObject:@"mic.badge.xmark"]; [colors addObject:UIColor.systemRedColor]; }
    else if (user.isSelfMuted || user.isMuted)
        { [states addObject:@"mic.slash.fill"]; [colors addObject:UIColor.systemRedColor]; }
    else if (user.isLocalMuted)
        { [states addObject:@"mic.slash"]; [colors addObject:UIColor.secondaryLabelColor]; }
    if (user.isPrioritySpeaker)
        { [states addObject:@"star.fill"]; [colors addObject:UIColor.secondaryLabelColor]; }
    if (!states.count) return nil;

    CGFloat widthOffset = [states count] * iconWidth;
    UIView *stateView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, widthOffset, iconHeight)];
    stateView.accessibilityElementsHidden = YES;
    for (NSUInteger index = 0; index < states.count; index++) {
        UIImage *img = [[MUImage symbolNamed:states[index] pointSize:16] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        UIImageView *imgView = [[UIImageView alloc] initWithImage:img];
        imgView.tintColor = colors[index];
        imgView.contentMode = UIViewContentModeScaleAspectFit;
        widthOffset -= iconWidth;
        imgView.frame = CGRectMake(ceilf(widthOffset), 2.0f, iconWidth, iconHeight - 4.0f);
        [stateView addSubview:imgView];
    }

    return stateView;
}

@end
