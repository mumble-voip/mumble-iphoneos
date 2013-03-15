// Copyright 2013 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import <Foundation/Foundation.h>

@class MUActionSheet;

@protocol MUActionSheetDelegate
- (void) actionSheet:(MUActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex;
@end

@interface MUActionSheet : NSObject
- (id) initWithTitle:(NSString *)title delegate:(id<MUActionSheetDelegate>)delegate cancelButtonTitle:(NSString *)cancelButtonTitle destructiveButtonTitle:(NSString *)destructiveButtonTitle constructiveButtonTitle:(NSString *)constructiveButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ... NS_REQUIRES_NIL_TERMINATION;
- (void) showInViewController:(UIViewController *)viewController;
- (NSInteger) destructiveButtonIndex;
- (NSInteger) constructiveButtonIndex;
- (NSInteger) cancelButtonIndex;
@end
