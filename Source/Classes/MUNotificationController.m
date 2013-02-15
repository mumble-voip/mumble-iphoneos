// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUNotificationController.h"

@interface MUNotificationController () {
    UIView          *_notificationView;
    NSMutableArray  *_notificationQueue;
    BOOL            _running;
    CGRect          _keyboardFrame;
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
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidShow:) name:UIKeyboardDidShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidHide:) name:UIKeyboardDidHideNotification object:nil];
    }
    return self;
}

- (void) dealloc {
    [_notificationQueue release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void) keyboardDidShow:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    NSValue *val = [userInfo valueForKey:UIKeyboardFrameEndUserInfoKey];
    [val getValue:&_keyboardFrame];
}

- (void) keyboardDidHide:(NSNotification *)notification {
    _keyboardFrame = CGRectZero;
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
    
    CGRect frame = CGRectMake(25.0f, ceilf((bounds.size.height - _keyboardFrame.size.height)/2) - 25.0f, width, height);
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
