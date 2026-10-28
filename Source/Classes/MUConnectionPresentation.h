#import <UIKit/UIKit.h>

// UIKit transitions have their own lifetime. Keep them separate from the
// transport/session owner, and invalidate old continuations on cancellation.
@interface MUConnectionPresentation : NSObject
@property(nonatomic,weak) UIViewController *presenter;
- (void)invalidate;
- (void)presentAlert:(UIAlertController *)alert whileCurrent:(BOOL (^)(void))current;
- (void)presentViewController:(UIViewController *)controller whileCurrent:(BOOL (^)(void))current;
- (void)dismissAlert:(UIAlertController *)alert completion:(dispatch_block_t)completion;
@end
