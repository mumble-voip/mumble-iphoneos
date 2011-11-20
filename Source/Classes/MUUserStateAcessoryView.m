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
