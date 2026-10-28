// Copyright 2009-2012 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MLClient.h"

@class MUMessageRecipientViewController;

@protocol MUMessageRecipientViewControllerDelegate
- (void) messageRecipientViewControllerDidSelectCurrentChannel:(MUMessageRecipientViewController *)viewCtrlr;
- (void) messageRecipientViewController:(MUMessageRecipientViewController *)viewCtrlr didSelectUser:(MLUser *)user;
- (void) messageRecipientViewController:(MUMessageRecipientViewController *)viewCtrlr didSelectChannel:(MLChannel *)channel;
@end

@interface MUMessageRecipientViewController : UITableViewController <MLServerModelDelegate>
- (id) initWithServerModel:(MLServerModel *)serverModel;
- (id<MUMessageRecipientViewControllerDelegate>) delegate;
- (void) setDelegate:(id<MUMessageRecipientViewControllerDelegate>)delegate;
@end
