// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

@interface MUFavouriteServer : NSObject <NSCopying>

- (id) initWithDisplayName:(NSString *)displayName hostName:(NSString *)hostName port:(NSUInteger)port userName:(NSString *)userName password:(NSString *)passWord;
- (id) init;
- (void) dealloc;

@property (assign)  NSInteger   primaryKey;
@property (copy)    NSString    *displayName;
@property (copy)    NSString    *hostName;
@property (assign)  NSUInteger  port;
@property (copy)    NSString    *userName;
@property (copy)    NSString    *password;

- (BOOL) hasPrimaryKey;
- (NSComparisonResult) compare:(MUFavouriteServer *)favServ;

@end
