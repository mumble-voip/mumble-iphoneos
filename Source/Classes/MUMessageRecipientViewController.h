// Copyright 2009-2012 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import <MumbleKit/MKServerModel.h>

@class MUMessageRecipientViewController;

@protocol MUMessageRecipientViewControllerDelegate
- (void) messageRecipientViewControllerDidSelectCurrentChannel:(MUMessageRecipientViewController *)viewCtrlr;
- (void) messageRecipientViewController:(MUMessageRecipientViewController *)viewCtrlr didSelectUser:(MKUser *)user;
- (void) messageRecipientViewController:(MUMessageRecipientViewController *)viewCtrlr didSelectChannel:(MKChannel *)channel;
@end

@interface MUMessageRecipientViewController : UITableViewController
- (id) initWithServerModel:(MKServerModel *)serverModel;
- (id<MUMessageRecipientViewControllerDelegate>) delegate;
- (void) setDelegate:(id<MUMessageRecipientViewControllerDelegate>)delegate;
@end
