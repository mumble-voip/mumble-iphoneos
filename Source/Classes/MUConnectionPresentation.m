#import "MUConnectionPresentation.h"

@implementation MUConnectionPresentation {
    NSUInteger _generation;
    __weak UIViewController *_presentedController;
}
- (void)invalidate {
    NSAssert(NSThread.isMainThread,@"Presentation runs on main");
    ++_generation;
    [self dismissController:_presentedController completion:nil];
    _presentedController=nil;
}
- (void)presentAlert:(UIAlertController *)alert whileCurrent:(BOOL (^)(void))current {
    [self presentViewController:alert whileCurrent:current];
}
- (void)presentViewController:(UIViewController *)controller whileCurrent:(BOOL (^)(void))current {
    [self presentController:controller whileCurrent:current generation:_generation];
}
- (void)presentController:(UIViewController *)alert whileCurrent:(BOOL (^)(void))current generation:(NSUInteger)generation {
    NSAssert(NSThread.isMainThread,@"Presentation runs on main");
    UIViewController *presenter=self.presenter;
    if(generation!=_generation || !alert || !current() || !presenter.viewIfLoaded.window)return;
    UIViewController *presented=presenter.presentedViewController;
    if(presented==alert)return;
    if(!presented){_presentedController=alert;[presenter presentViewController:alert animated:YES completion:nil];return;}
    __weak MUConnectionPresentation *weakSelf=self;
    dispatch_block_t dismiss=^{
        MUConnectionPresentation *owner=weakSelf;
        if(!owner || generation!=owner->_generation || !current())return;
        if(!presented.presentingViewController){[owner presentController:alert whileCurrent:current generation:generation];return;}
        [presented dismissViewControllerAnimated:YES completion:^{[weakSelf presentController:alert whileCurrent:current generation:generation];}];
    };
    id<UIViewControllerTransitionCoordinator> transition=presented.transitionCoordinator;
    if(transition)[transition animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context){dispatch_async(dispatch_get_main_queue(),dismiss);}];
    else dismiss();
}
- (void)dismissAlert:(UIAlertController *)alert completion:(dispatch_block_t)completion {
    [self dismissController:alert completion:completion];
}
- (void)dismissController:(UIViewController *)alert completion:(dispatch_block_t)completion {
    NSAssert(NSThread.isMainThread,@"Presentation runs on main");
    NSUInteger generation=_generation;__weak MUConnectionPresentation *weakSelf=self;
    dispatch_block_t finish=^{MUConnectionPresentation *owner=weakSelf;if(owner && generation==owner->_generation && completion)completion();};
    if(!alert.presentingViewController){finish();return;}
    dispatch_block_t dismiss=^{
        MUConnectionPresentation *owner=weakSelf;if(!owner || generation!=owner->_generation)return;
        if(alert.presentingViewController)[alert dismissViewControllerAnimated:YES completion:finish];else finish();
    };
    id<UIViewControllerTransitionCoordinator> transition=alert.transitionCoordinator;
    if(transition)[transition animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context){dispatch_async(dispatch_get_main_queue(),dismiss);}];
    else dismiss();
}
@end
