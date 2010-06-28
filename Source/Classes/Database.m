/* Copyright (C) 2009-2010 Mikkel Krautz <mikkel@krautz.dk>

   All rights reserved.

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions
   are met:

   - Redistributions of source code must retain the above copyright notice,
     this list of conditions and the following disclaimer.
   - Redistributions in binary form must reproduce the above copyright notice,
     this list of conditions and the following disclaimer in the documentation
     and/or other materials provided with the distribution.
   - Neither the name of the Mumble Developers nor the names of its
     contributors may be used to endorse or promote products derived from this
     software without specific prior written permission.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
   ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
   A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR
   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "Database.h"
#import "FavouriteServer.h"
#import "Identity.h"

static FMDatabase *db = nil;

@implementation Database

//
// Initialize the database.
//
+ (void) initializeDatabase {
	NSArray *documentDirectories = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
																	   NSUserDomainMask,
																	   YES);
	NSString *directory = [documentDirectories objectAtIndex:0];
	NSString *dbPath = [directory stringByAppendingPathComponent:@"mumble.sqlite"];

	db = [[FMDatabase alloc] initWithPath:dbPath];
	if (!db)
		return;

	if ([db open]) {
		NSLog(@"Database: Initialized database at %@", dbPath);
	} else {
		NSLog(@"Database: Could not open database at %@", dbPath);
		[db release];
		db = nil;
		return;
	}

	[db executeUpdate:@"CREATE TABLE IF NOT EXISTS `servers` "
					  @"(`id` INTEGER PRIMARY KEY AUTOINCREMENT,"
					  @" `name` TEXT,"
					  @" `hostname` TEXT,"
					  @" `port` INTEGER DEFAULT 64738,"
					  @" `username` TEXT)"];

	[db executeUpdate:@"CREATE TABLE IF NOT EXISTS `identities` "
	                  @"(`persistent` BLOB PRIMARY KEY,"
					  @" `username` TEXT,"
					  @" `avatar` BLOB)"];
	[db executeUpdate:@"ALTER TABLE `identities` ADD COLUMN `fullname` TEXT"];
	[db executeUpdate:@"ALTER TABLE `identities` ADD COLUMN `email` TEXT"];

	[db executeUpdate:@"VACUUM"];

	if ([db hadError]) {
		NSLog(@"Database: Error: %@ (Code: %i)", [db lastErrorMessage], [db lastErrorCode]);
	}
}

//
// Tear down the database
//
+ (void) teardown {
	[db release];
}

//
// Save single favourite
//
+ (void) saveFavourite:(FavouriteServer *)favServ {
	[db executeUpdate:@"REPLACE INTO `servers` (`name`, `hostname`, `port`, `username`) VALUES (?, ?, ?, ?)",
		[favServ displayName],
		[favServ hostName],
		[NSString stringWithFormat:@"%u", [favServ port]],
		[favServ userName]];
}

//
// Save favourites
//
+ (void) saveFavourites:(NSArray *)favourites {
	[db beginTransaction];

	[db executeUpdate:@"DELETE FROM `servers`"];

	for (FavouriteServer *favServ in favourites) {
		[Database saveFavourite:favServ];
	}

	[db commit];
}

//
// Get list of favourites
//
+ (NSMutableArray *) favourites {
	NSMutableArray *favs = [[NSMutableArray alloc] init];

	FMResultSet *res = [db executeQuery:@"SELECT `name`, `hostname`, `port`, `username` FROM `servers`"];

	while ([res next]) {
		FavouriteServer *fs = [[FavouriteServer alloc] init];
		[fs setDisplayName:[res stringForColumnIndex:0]];
		[fs setHostName:[res stringForColumnIndex:1]];
		[fs setPort:[res intForColumnIndex:2]];
		[fs setUserName:[res stringForColumnIndex:3]];
		[favs addObject:fs];
	}

	[res close];

	return [favs autorelease];
}

//
// Store identity
//

+ (void) saveIdentity:(Identity *)ident {
	[db executeUpdate:@"REPLACE INTO `identities` (`persistent`, `username`, `fullname`, `email`) VALUES (?, ?, ?, ?)",
			ident.persistentId, ident.userName, nil, nil];
}

+ (NSArray *) identities {
	NSMutableArray *idents = [[NSMutableArray alloc] init];
	FMResultSet *res = [db executeQuery:@"SELECT `persistent`, `username`, `fullname`, `email` FROM `identities`"];
	while ([res next]) {
		Identity *ident = [[Identity alloc] init];
		ident.persistentId = [res dataForColumnIndex:0];
		ident.userName = [res stringForColumnIndex:1];
		ident.fullName = [res stringForColumnIndex:2];
		ident.emailAddress = [res stringForColumnIndex:3];
		[idents addObject:ident];
	}
	[res close];
	return [idents autorelease];
}

+ (void) showStoredIdentities {
	FMResultSet *res = [db executeQuery:@"SELECT `username`, `persistent` FROM `identities`"];
	while ([res next]) {
		NSString *boom = [[NSString alloc] initWithData:[res dataForColumnIndex:1] encoding:NSUTF8StringEncoding];
		NSLog(@"username=%@, persistent=%@", [res stringForColumnIndex:0], boom);
		[boom release];
	}
	[res close];
}

@end
