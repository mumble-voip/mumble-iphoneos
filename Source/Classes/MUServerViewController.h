// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MLClient.h"

@interface MUServerViewController : UITableViewController <MLServerModelDelegate>
- (id) initWithServerModel:(MLServerModel *)serverModel;
@property(nonatomic, weak) UIView *voiceControlsHostView;
@property(nonatomic) BOOL showsPaneTitle;
@property(nonatomic) BOOL voiceControlsAtSide;
@property(nonatomic) BOOL voiceControlsInToolbar;
@property(nonatomic, readonly) NSArray<UIBarButtonItem *> *voiceControlBarItems;
- (void)layoutVoiceControls;
- (void)refreshVoiceControls;
- (void)cancelPushToTalk;
- (CGFloat)voiceControlsContentHeight;
@end
