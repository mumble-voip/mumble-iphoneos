// Use of this source code is governed by the BSD-style license in LICENSE.
#import "MUNotificationController.h"

@interface MUServerNotice : NSObject
@property(nonatomic, copy) NSString *text;
@property(nonatomic, weak) UIViewController *presenter;
@end
@implementation MUServerNotice
@end

@implementation MUNotificationController {
    NSMutableArray<MUServerNotice *> *_notificationQueue;
    BOOL _running;
}
+ (MUNotificationController *)sharedController {
    static MUNotificationController *controller; static dispatch_once_t once;
    dispatch_once(&once, ^{ controller = [self new]; }); return controller;
}
- (id)init {
    if ((self = [super init])) {
        _notificationQueue = [NSMutableArray array];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(becameActive:) name:UISceneDidActivateNotification object:nil];
    }
    return self;
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)becameActive:(NSNotification *)notification { if (!_running) [self showNext]; }
- (void)addNotification:(NSString *)text fromViewController:(UIViewController *)presenter {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self addNotification:text fromViewController:presenter]; }); return; }
    if (text.length && presenter && _notificationQueue.count < 10) {
        MUServerNotice *notice = [MUServerNotice new];
        notice.text = text; notice.presenter = presenter;
        [_notificationQueue addObject:notice];
    }
    if (!_running) [self showNext];
}
- (void)showNext {
    while (_notificationQueue.count && !_notificationQueue.firstObject.presenter) [_notificationQueue removeObjectAtIndex:0];
    UIViewController *presenter = _notificationQueue.firstObject.presenter;
    UIWindowScene *scene = presenter.viewIfLoaded.window.windowScene;
    if (!scene || scene.activationState != UISceneActivationStateForegroundActive) { _running = NO; return; }
    _running = YES;
    while (presenter.presentedViewController) presenter = presenter.presentedViewController;
    if ([presenter isKindOfClass:UIAlertController.class] || presenter.isBeingPresented || presenter.isBeingDismissed || presenter.transitionCoordinator) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 2), dispatch_get_main_queue(), ^{ [self showNext]; });
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Server Notice", nil) message:_notificationQueue.firstObject.text preferredStyle:UIAlertControllerStyleAlert];
    [_notificationQueue removeObjectAtIndex:0];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        self->_running = NO;
        dispatch_async(dispatch_get_main_queue(), ^{ [self showNext]; });
    }]];
    [presenter presentViewController:alert animated:YES completion:nil];
}
@end
