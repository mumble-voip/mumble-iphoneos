// Copyright 2014 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUHorizontalFlipTransitionDelegate.h"

@implementation MUHorizontalFlipTransitionDelegate

- (id<UIViewControllerAnimatedTransitioning>) animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source {
    return (id<UIViewControllerAnimatedTransitioning>) self;
}

- (id<UIViewControllerAnimatedTransitioning>) animationControllerForDismissedController:(UIViewController *)dismissed {
    return (id<UIViewControllerAnimatedTransitioning>)self;
}

- (NSTimeInterval) transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext {
    return 0.7f;
}

- (void) animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    UIView *containerView = [transitionContext containerView];

    UIViewController *fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    [containerView addSubview:fromViewController.view];

    UIViewController *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    [containerView addSubview:toViewController.view];

    UIViewAnimationOptions animationOption;
    if ([toViewController.presentedViewController isEqual:fromViewController]) {
        animationOption = UIViewAnimationOptionTransitionFlipFromLeft;
    } else {
        animationOption = UIViewAnimationOptionTransitionFlipFromRight;
    }

    [UIView transitionFromView:fromViewController.view
                        toView:toViewController.view
                      duration:[self transitionDuration:transitionContext]
                       options:animationOption
                    completion:^(BOOL finished) {
                        [transitionContext completeTransition:YES];
                    }];
}

@end
