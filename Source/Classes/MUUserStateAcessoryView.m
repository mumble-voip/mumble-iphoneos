// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUUserStateAcessoryView.h"

#import <MumbleKit/MKUser.h>

@implementation MUUserStateAcessoryView

+ (UIView *) viewForUser:(MKUser *)user {
    const CGFloat iconHeight = 24.0f;
    const CGFloat iconWidth = 28.0f;
    
    NSMutableArray *states = [[NSMutableArray alloc] init];
    if ([user isAuthenticated])
        [states addObject:@"authenticated"];
    if ([user isSelfDeafened])
        [states addObject:@"deafened_self"];
    if ([user isSelfMuted])
        [states addObject:@"muted_self"];
    if ([user isMuted])
        [states addObject:@"muted_server"];
    if ([user isDeafened])
        [states addObject:@"deafened_server"];
    if ([user isLocalMuted])
        [states addObject:@"muted_local"];
    if ([user isSuppressed])
        [states addObject:@"muted_suppressed"];
    if ([user isPrioritySpeaker])
        [states addObject:@"priorityspeaker"];
    
    CGFloat widthOffset = [states count] * iconWidth;
    UIView *stateView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, widthOffset, iconHeight)];
    for (NSString *imageName in states) {
        UIImage *img = [UIImage imageNamed:imageName];
        UIImageView *imgView = [[UIImageView alloc] initWithImage:img];
        CGFloat ypos = (iconHeight - img.size.height)/2.0f;
        CGFloat xpos = (iconWidth - img.size.width)/2.0f;
        widthOffset -= iconWidth - xpos;
        imgView.frame = CGRectMake(ceilf(widthOffset), ceilf(ypos), img.size.width, img.size.height);
        [stateView addSubview:imgView];
        [imgView release];
    }
    
    [states release];
    return [stateView autorelease];
}

@end
