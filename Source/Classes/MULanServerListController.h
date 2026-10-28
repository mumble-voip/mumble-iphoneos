// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

@import UIKit;

@interface MULanServerListController : UITableViewController
- (id) init;
@property(nonatomic, copy, readonly) NSArray<NSNetService *> *discoveredServers;
@property(nonatomic, readonly) BOOL discoveryFailed;
@property(nonatomic, copy) void (^serversChangedHandler)(void);
- (void)startDiscovery;
- (void)stopDiscovery;
- (void)presentActionsForServer:(NSNetService *)server fromViewController:(UIViewController *)parent sourceView:(UIView *)sourceView;
@end
