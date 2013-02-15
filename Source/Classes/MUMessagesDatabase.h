// Copyright 2009-2012 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

@class MKTextMessage;
@class MUTextMessage;

@interface MUMessagesDatabase : NSObject
- (void) addMessage:(MKTextMessage *)msg withHeading:(NSString *)heading andSentBySelf:(BOOL)selfSent;
- (MUTextMessage *) messageAtIndex:(NSInteger)row;
- (void) clearMessageAtIndex:(NSInteger)row;
- (NSInteger) count;
@end
