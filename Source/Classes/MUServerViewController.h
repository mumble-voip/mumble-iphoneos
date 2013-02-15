// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import <MumbleKit/MKServerModel.h>

typedef enum {
    MUServerViewControllerViewModeServer = 0,
    MUServerViewControllerViewModeChannel = 1,
} MUServerViewControllerViewMode;

@interface MUServerViewController : UITableViewController
- (id) initWithServerModel:(MKServerModel *)serverModel;
- (void) toggleMode;
@end