// Copyright 2009-2026 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import <MumbleKit/MKConnection.h>
#import <MumbleKit/MKServerModel.h>

@interface MUCallController : NSObject <MKServerModelDelegate>
- (id) init;
- (void) connectionEstablished:(MKConnection *)conn serverModel:(MKServerModel *)model;
- (void) connectionTornDown;
@end