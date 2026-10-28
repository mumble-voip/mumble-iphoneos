// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import <FMDB/FMDatabase.h>

@class MUFavouriteServer;
@class Identity;

@interface MUDatabase : NSObject

+ (void) initializeDatabase;
+ (void)migrateLegacyCredentials;

// FavouriteServer
+ (void) storeFavourite:(MUFavouriteServer *)favServ;
+ (void)storePassword:(NSString *)password forFavouriteWithPrimaryKey:(NSInteger)primaryKey;
+ (void) deleteFavourite:(MUFavouriteServer *)favServ;
+ (void) storeFavourites:(NSArray *)favourites;
+ (NSMutableArray *) fetchAllFavourites;

// Successful connections, newest first. History never contains passwords.
+ (void)recordRecentServerWithHostname:(NSString *)hostname port:(NSUInteger)port displayName:(NSString *)displayName username:(NSString *)username;
+ (NSArray<MUFavouriteServer *> *)recentServers;
+ (void)deleteRecentServer:(MUFavouriteServer *)server;

// Cert verification. DNS names match case-insensitively; ports remain distinct.
+ (void) storeDigest:(NSString *)hash forServerWithHostname:(NSString *)hostname port:(NSInteger)port;
+ (NSString *) digestForServerWithHostname:(NSString *)hostname port:(NSInteger)port;

// Username-rememberer
+ (void) storeUsername:(NSString *)username forServerWithHostname:(NSString *)hostname port:(NSInteger)port;
+ (NSString *) usernameForServerWithHostname:(NSString *)hostname port:(NSInteger)port;

// Access tokens
+ (void) storeAccessTokens:(NSArray *)tokens forServerWithHostname:(NSString *)hostname port:(NSInteger)port;
+ (NSArray *) accessTokensForServerWithHostname:(NSString *)hostname port:(NSInteger)port;

@end
