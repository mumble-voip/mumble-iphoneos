// Copyright 2013 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUActionSheet.h"
#import "MUActionSheetBackgroundView.h"
#import "MUActionSheetButton.h"

@interface MUActionSheet () {
    UIView                      *_fadeView;
    MUActionSheetBackgroundView *_bgView;
    UIViewController            *_viewController;
    NSString                    *_title;
    
    NSMutableArray              *_otherButtons;

    MUActionSheetButton         *_cancelButton;
    NSInteger                   _cancelButtonIndex;

    MUActionSheetButton         *_destructiveButton;
    NSInteger                   _destructiveButtonIndex;

    MUActionSheetButton         *_constructiveButton;
    NSInteger                   _constructiveButtonIndex;
    
    BOOL                        _shouldReenableScroll;
    
    UIBarButtonItem             *_oldLeftBarButtonItem;
    UIBarButtonItem             *_oldRightBarButtonItem;
    
    NSArray                     *_oldViewGestureRecognizers;
    
    id<MUActionSheetDelegate>   _delegate;
}
@end

@implementation MUActionSheet

- (id) initWithTitle:(NSString *)title delegate:(id<MUActionSheetDelegate>)delegate cancelButtonTitle:(NSString *)cancelButtonTitle destructiveButtonTitle:(NSString *)destructiveButtonTitle constructiveButtonTitle:(NSString *)constructiveButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ... {
    if ((self = [super init])) {
        _delegate = delegate;
        _title = [title copy];
        
        _otherButtons = [[NSMutableArray alloc] init];
        NSInteger idx = 0;

        {
            va_list args;
            va_start(args, otherButtonTitles);
            for (NSString *title = otherButtonTitles; title != nil; title = va_arg(args, NSString *)) {
                MUActionSheetButton *btn = [MUActionSheetButton buttonWithKind:MUActionSheetButtonKindNormal];
                [btn setTitle:title];
                [btn addTarget:self action:@selector(buttonClicked:) forControlEvents:UIControlEventTouchUpInside];
                [_otherButtons addObject:btn];
                
                idx++;
            }
        }

        _cancelButton = [[MUActionSheetButton buttonWithKind:MUActionSheetButtonKindCancel] retain];
        [_cancelButton setTitle:cancelButtonTitle ? cancelButtonTitle : @"Cancel"];
        [_cancelButton addTarget:self action:@selector(buttonClicked:) forControlEvents:UIControlEventTouchUpInside];
        _cancelButtonIndex = idx++;
        
        if (constructiveButtonTitle) {
            _constructiveButton = [[MUActionSheetButton buttonWithKind:MUActionSheetButtonKindConstructive] retain];
            [_constructiveButton setTitle:constructiveButtonTitle];
            [_constructiveButton addTarget:self action:@selector(buttonClicked:) forControlEvents:UIControlEventTouchUpInside];
            _constructiveButtonIndex = idx++;
        } else {
            _constructiveButtonIndex = -1;
        }
        
        if (destructiveButtonTitle) {
            _destructiveButton = [[MUActionSheetButton buttonWithKind:MUActionSheetButtonKindDestructive] retain];
            [_destructiveButton setTitle:destructiveButtonTitle];
            [_destructiveButton addTarget:self action:@selector(buttonClicked:) forControlEvents:UIControlEventTouchUpInside];
            _destructiveButtonIndex = idx++;
        } else {
            _destructiveButtonIndex = -1;
        }
    }
    return self;
}

- (void) dealloc {
    [_title release];
    [_fadeView release];
    [_bgView release];
    [_otherButtons release];
    [_destructiveButton release];
    [_constructiveButton release];
    [_cancelButton release];
    
    [super dealloc];
}

- (NSInteger) cancelButtonIndex {
    return _cancelButtonIndex;
}

- (NSInteger) destructiveButtonIndex {
    return _destructiveButtonIndex;
}

- (NSInteger) constructiveButtonIndex {
    return _constructiveButtonIndex;
}

- (void) buttonClicked:(id)sender {
    NSInteger idx = -1;
    if (sender == _cancelButton) {
        idx = _cancelButtonIndex;
    } else if (sender == _constructiveButton) {
        idx = _constructiveButtonIndex;
    } else if (sender == _destructiveButton) {
        idx = _destructiveButtonIndex;
    } else {
        idx = [_otherButtons indexOfObject:sender];
    }
    [self removeViewAndPerformBlock:^{
        [_delegate actionSheet:self didDismissWithButtonIndex:idx];
    }];
}

- (void) showInViewController:(UIViewController *)viewController {
    _viewController = viewController;
    [self addView];
}

- (void) hideNavigationItemButtons {
    [_viewController.navigationItem setHidesBackButton:YES animated:YES];
    _oldLeftBarButtonItem = [[_viewController.navigationItem leftBarButtonItem] retain];
    [_viewController.navigationItem setLeftBarButtonItem:nil animated:YES];
    _oldRightBarButtonItem = [[_viewController.navigationItem rightBarButtonItem] retain];
    [_viewController.navigationItem setRightBarButtonItem:nil animated:YES];
}

- (void) showNavigationItemButtons {
    [_viewController.navigationItem setHidesBackButton:NO animated:YES];
    [_viewController.navigationItem setRightBarButtonItem:_oldRightBarButtonItem animated:YES];
    [_oldRightBarButtonItem release];
    [_viewController.navigationItem setLeftBarButtonItem:_oldLeftBarButtonItem animated:NO];
    [_oldLeftBarButtonItem release];
}

- (CGFloat) _viewHeightForTitleLabelHeight:(CGFloat)titleHeight {
    CGFloat padding = 10;
    CGFloat buttonHeight = 48;
    CGFloat viewHeight = 0;
    
    if (titleHeight > 0) {
        viewHeight += 1;
    }
    
    // Title adjustment
    viewHeight += padding + titleHeight + padding;
    
    // Group buttons (without cancel button)
    NSInteger numButtons = [_otherButtons count];
    if (_destructiveButton) {
        numButtons++;
    }
    if (_constructiveButton) {
        numButtons++;
    }
    viewHeight += ((buttonHeight + padding) * numButtons);
    
    // Cancel button
    viewHeight += padding + buttonHeight + 2*padding;
    
    return viewHeight;
}

- (void) addView {
    const CGFloat padding = 10;
    
    // Add a reference, so consumers of
    // the MUActionSheet can release it as soon
    // it is shown, just like UIActionSheet.
    [self retain];
    
    // Disable scrolling if we're added to something
    // that looks like a UIScrollView.
    CGPoint scrollViewOffset = CGPointMake(0, 0);
    if ([_viewController.view respondsToSelector:@selector(isScrollEnabled)]) {
        UIScrollView *scrollView = (UIScrollView *)_viewController.view;
        _shouldReenableScroll = [scrollView isScrollEnabled];
        [scrollView setScrollEnabled:NO];
        
        scrollViewOffset = [scrollView contentOffset];
    }
    
    // Store the the gesture recognizers on the view controller's view.
    // Gesture recognizers pass through even though we set exclusiveTouch
    // on our action sheet UI elements.
    _oldViewGestureRecognizers = [[[_viewController view] gestureRecognizers] retain];
    [[_viewController view] setGestureRecognizers:nil];
    
    CGFloat titleLabelHeight = 0;
    UILabel *titleLabel = nil;
    if (_title) {
        titleLabel = [[UILabel alloc] init];
        titleLabel.text = _title;
        titleLabel.font = [UIFont systemFontOfSize:[UIFont systemFontSize]];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.shadowColor = [UIColor blackColor];
        titleLabel.shadowOffset = CGSizeMake(0, -1);
        titleLabel.opaque = NO;
        titleLabel.backgroundColor = [UIColor clearColor];

        CGRect textRect = [titleLabel textRectForBounds:CGRectMake(0, 0, 320, 640) limitedToNumberOfLines:1];
        titleLabelHeight = textRect.size.height;
    }
    
    CGFloat viewHeight = [self _viewHeightForTitleLabelHeight:titleLabelHeight];
    
    _fadeView = [[[UIView alloc] initWithFrame:_viewController.view.frame] autorelease];
    _fadeView.backgroundColor = [UIColor clearColor];
    [_fadeView setExclusiveTouch:YES];

    _bgView = [[[MUActionSheetBackgroundView alloc] initWithFrame:CGRectMake(0, _viewController.view.frame.size.height, 320, viewHeight)] autorelease];
    [_bgView setExclusiveTouch:YES];

    [_viewController.view addSubview:_fadeView];
    [_viewController.view addSubview:_bgView];
    
    __block CGFloat ofs = padding;
    
    if (titleLabel) {
        ofs += 1;
        [titleLabel setFrame:CGRectMake(0, ofs, 320, titleLabelHeight)];
        [_bgView addSubview:titleLabel];
    }
    
    ofs += titleLabelHeight + padding;
    
    // Destructive button
    if (_destructiveButton) {
        [_destructiveButton setFrame:CGRectMake(20, ofs, 280, 48)];
        [_bgView addSubview:_destructiveButton];
        ofs += 48 + padding;
    }

    [_otherButtons enumerateObjectsWithOptions:0 usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        MUActionSheetButton *btn = (MUActionSheetButton *)obj;
        [btn setFrame:CGRectMake(20, ofs, 280, 48)];
        [_bgView addSubview:btn];
        ofs += 48 + padding;
    }];
    
    // Constructive button
    if (_constructiveButton) {
        [_constructiveButton setFrame:CGRectMake(20, ofs, 280, 48)];
        [_bgView addSubview:_constructiveButton];
        ofs += 48 + padding;
    }
    
    // Cancel button
    ofs += padding;
    [_cancelButton setFrame:CGRectMake(20, ofs, 280, 48)];
    [_bgView addSubview:_cancelButton];
    
    // Store old UINavigationItem button state
    [self hideNavigationItemButtons];
    
    __block UIView *parentView = _viewController.view;
    [UIView animateWithDuration:0.25f delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^{
        _bgView.frame = CGRectMake(0, (parentView.frame.size.height + scrollViewOffset.y) - viewHeight, 320, viewHeight);
        [_bgView layoutIfNeeded];
        _fadeView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.4f];
    } completion:^(BOOL isfinished) {
        // ...
    }];
}
                             
- (void) removeViewAndPerformBlock:(void(^)())doneBlock {
    __block UIView *parentView = _viewController.view;

    // Restore UINavigationItem button state.
    [self showNavigationItemButtons];

    [UIView animateWithDuration:0.25f delay:0.0f options:UIViewAnimationOptionCurveEaseIn animations:^{
        _bgView.frame = CGRectMake(0, parentView.frame.size.height, 320, _bgView.frame.size.height);
        _fadeView.backgroundColor = [UIColor clearColor];
    } completion:^(BOOL finished) {
        [_bgView removeFromSuperview];
        _bgView = nil;
        [_fadeView removeFromSuperview];
        _fadeView = nil;
        doneBlock();

        // Check if we should try to re-enable scrolling.
        if (_shouldReenableScroll) {
            UIScrollView *scrollView = (UIScrollView *)_viewController.view;
            [scrollView setScrollEnabled:YES];
        }
        
        // Restore the view's gesture recognizers.
        [[_viewController view] setGestureRecognizers:_oldViewGestureRecognizers];
        [_oldViewGestureRecognizers release];

        // Release the reference we added when
        // showing the MUActionSheet.
        [self release];
    }];
}

@end
