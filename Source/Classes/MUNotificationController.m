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

#import "MUNotificationController.h"

@interface MUNotificationController () {
    UIView          *_notificationView;
    NSMutableArray  *_notificationQueue;
    BOOL            _running;
}
- (void) showNext;
- (void) hideCurrent;
@end

@implementation MUNotificationController

+ (MUNotificationController *) sharedController {
    static MUNotificationController *nc;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        nc = [[MUNotificationController alloc] init];
    });
    return nc;
}

- (id) init {
    if ((self = [super init])) {
        _notificationQueue = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void) dealloc {
    [_notificationQueue release];
    [super dealloc];
}

- (void) addNotification:(NSString *)text {
    if ([_notificationQueue count] < 10)
        [_notificationQueue addObject:[[text copy] autorelease]];
    if (!_running) {
        [self showNext];
    }
}

- (void) showNext {
    _running = YES;

    UIScreen *screen = [UIScreen mainScreen];
    CGRect bounds = screen.bounds;
    
    CGFloat width = ceilf(bounds.size.width - 50.0f);
    CGFloat height = 50.0f;
    
    CGRect frame = CGRectMake(25.0f, ceilf(bounds.size.height/2 - 25.0f), width, height);
   
    UIView *container = [[UIView alloc] initWithFrame:frame];
    container.alpha = 0.0f;
    container.userInteractionEnabled = NO;
    
    UIView *bg = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    bg.layer.cornerRadius = 8.0f;
    bg.backgroundColor = [UIColor blackColor];
    bg.alpha = 0.8f;
    [container addSubview:bg];
    [bg release];

    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    lbl.font = [UIFont systemFontOfSize:16.0f];
    NSString *notificationText = [_notificationQueue objectAtIndex:0];
    lbl.text = notificationText;
    [_notificationQueue removeObjectAtIndex:0];
    lbl.textColor = [UIColor whiteColor];
    lbl.backgroundColor = [UIColor clearColor];
    lbl.textAlignment = UITextAlignmentCenter;
    [container addSubview:lbl];
    [lbl release];
    
    [[[UIApplication sharedApplication] keyWindow] addSubview:container];

    _notificationView = container;
    [UIView animateWithDuration:0.1f animations:^{
        _notificationView.alpha = 1.0f;
    } completion:^(BOOL completed) {
        NSTimer *timer = [NSTimer timerWithTimeInterval:0.3f target:self selector:@selector(hideCurrent) userInfo:nil repeats:NO];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    }];
}

- (void) hideCurrent {
    [UIView animateWithDuration:0.1f animations:^{
        _notificationView.alpha = 0.0f;
    } completion:^(BOOL completed) {
        [_notificationView removeFromSuperview];
        [_notificationView release];
        _notificationView = nil;
        if ([_notificationQueue count] > 0) {
            [self performSelectorOnMainThread:@selector(showNext) withObject:nil waitUntilDone:NO];
        } else {
           _running = NO;
        }
    }];
}

@end
