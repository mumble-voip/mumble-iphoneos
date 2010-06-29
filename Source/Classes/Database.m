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
	                  @"(`id` INTEGER PRIMARY KEY AUTOINCREMENT,"
					  @" `username` TEXT,"
					  @" `fullname` TEXT,"
					  @" `email` TEXT,"
					  @" `avatar` BLOB,"
	                  @" `persistent` BLOB)"];

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
// Store a single favourite
//
+ (void) storeFavourite:(FavouriteServer *)favServ {
	// If the favourite already has a private key, update the currently stored entity
	if ([favServ hasPrimaryKey]) {
		[db executeUpdate:@"UPDATE `servers` SET `name`=?, `hostname`=?, `port`=?, `username`=? WHERE `id`=?",
			[favServ displayName],
			[favServ hostName],
			[NSString stringWithFormat:@"%u", [favServ port]],
			[favServ userName],
			[NSNumber numberWithInt:[favServ primaryKey]]];
	// If it isn't already stored, store it and update the object's pkey.
	} else {
		// We're already inside a transaction if we were called from within
		// storeFavourites. If that isn't the case, make sure we start a new
		// transaction.
		BOOL newTransaction = ![db inTransaction];
		if (newTransaction)
			[db beginTransaction];
		[db executeUpdate:@"INSERT INTO `servers` (`name`, `hostname`, `port`, `username`) VALUES (?, ?, ?, ?)",
			[favServ displayName],
			[favServ hostName],
			[NSString stringWithFormat:@"%u", [favServ port]],
			[favServ userName]];
		FMResultSet *res = [db executeQuery:@"SELECT last_insert_rowid()"];
		[res next];
		[favServ setPrimaryKey:[res intForColumnIndex:0]];
		if (newTransaction)
			[db commit];
	}
}

// Delete a particular favourite
+ (void) deleteFavourite:(FavouriteServer *)favServ {
	NSAssert([favServ hasPrimaryKey], @"Cannot delete a FavouriteServer not originated from the database.");
	[db executeUpdate:@"DELETE FROM `servers` WHERE `id`=?", [NSNumber numberWithInt:[favServ primaryKey]]];
}

//
// Save favourites
//
+ (void) storeFavourites:(NSArray *)favourites {
	[db beginTransaction];
	for (FavouriteServer *favServ in favourites) {
		[Database storeFavourite:favServ];
	}
	[db commit];
}

//
// Fetch all favourites
//
+ (NSMutableArray *) fetchAllFavourites {
	NSMutableArray *favs = [[NSMutableArray alloc] init];

	FMResultSet *res = [db executeQuery:@"SELECT `id`, `name`, `hostname`, `port`, `username` FROM `servers`"];

	while ([res next]) {
		FavouriteServer *fs = [[FavouriteServer alloc] init];
		[fs setPrimaryKey:[res intForColumnIndex:0]];
		[fs setDisplayName:[res stringForColumnIndex:1]];
		[fs setHostName:[res stringForColumnIndex:2]];
		[fs setPort:[res intForColumnIndex:3]];
		[fs setUserName:[res stringForColumnIndex:4]];
		[favs addObject:fs];
	}

	[res close];

	return [favs autorelease];
}

//
// Store identity
//
+ (void) storeIdentity:(Identity *)ident {
	NSLog(@"StoreIdentity..");
	// If the favourite already has a private key, update the currently stored entity
	if ([ident hasPrimaryKey]) {
		// If it isn't already stored, store it and update the object's pkey.
		[db executeUpdate:@"UPDATE `identities` SET `username`=?, `fullname`=?, `email`=?, `avatar`=?, `persistent`=? WHERE `id`=?",
			ident.userName, ident.fullName, ident.emailAddress, nil, ident.persistent,
			[NSNumber numberWithInt:[ident primaryKey]]];
	} else {
		// We're already inside a transaction if we were called from within
		// storeIdentities. If that isn't the case, make sure we start a new
		// transaction.
		BOOL newTransaction = ![db inTransaction];
		if (newTransaction)
			[db beginTransaction];
		[db executeUpdate:@"INSERT INTO `identities` (`username`, `fullname`, `email`, `avatar`, `persistent`) VALUES (?, ?, ?, ?, ?)",
			ident.userName, ident.fullName, ident.emailAddress, nil, ident.persistent];
		FMResultSet *res = [db executeQuery:@"SELECT last_insert_rowid()"];
		[res next];
		NSLog(@"pkey = %i", [res intForColumn:0]);
		[ident setPrimaryKey:[res intForColumnIndex:0]];
		if (newTransaction)
			[db commit];
	}
}

//
// Delete identity
//
+ (void) deleteIdentity:(Identity *)ident {
	NSAssert([ident hasPrimaryKey], @"Can only delete objects originated from database");
	[db executeUpdate:@"DELETE FROM `identities` WHERE `id`=?",
		[NSNumber numberWithInt:[ident primaryKey]]];
}

//
// Fetch all identities
//
+ (NSArray *) fetchAllIdentities {
	NSMutableArray *idents = [[NSMutableArray alloc] init];
	FMResultSet *res = [db executeQuery:@"SELECT `persistent`, `username`, `fullname`, `email` FROM `identities`"];
	while ([res next]) {
		Identity *ident = [[Identity alloc] init];
		ident.persistent = [res dataForColumnIndex:0];
		ident.userName = [res stringForColumnIndex:1];
		ident.fullName = [res stringForColumnIndex:2];
		ident.emailAddress = [res stringForColumnIndex:3];
		[idents addObject:ident];
	}
	[res close];
	return [idents autorelease];
}

//
// Save identities
//
+ (void) storeIdentities:(NSArray *)idents {
	[db beginTransaction];
	for (Identity *ident in idents) {
		[Database storeIdentity:ident];
	}
	[db commit];
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
