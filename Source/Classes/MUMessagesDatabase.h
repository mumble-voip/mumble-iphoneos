// Copyright 2009-2012 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

@class MLTextMessage;
@class MUTextMessage;

@interface MUMessagesDatabase : NSObject
@property(nonatomic,copy) void (^messageDidLoad)(NSInteger row, MUTextMessage *message);
- (void)addMessage:(MLTextMessage *)msg withHeading:(NSString *)heading andSentBySelf:(BOOL)selfSent completion:(void (^)(void))completion;
- (MUTextMessage *) messageAtIndex:(NSInteger)row;
- (void)prefetchMessagesAtIndexes:(NSIndexSet *)indexes;
- (void)cancelPrefetchAtIndexes:(NSIndexSet *)indexes;
- (void)loadImagesAtIndex:(NSInteger)row completion:(void (^)(NSArray<UIImage *> *images))completion;
- (void) clearMessageAtIndex:(NSInteger)row;
- (NSInteger) count;
@end
