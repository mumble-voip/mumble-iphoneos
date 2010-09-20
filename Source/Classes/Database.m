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

@interface Database (Private)
+ (BOOL) enableForeignKeySupport;
@end

@implementation Database

// Initialize the database.
+ (void) initializeDatabase {

	NSLog(@"Initializing database with SQLite version: %@", [FMDatabase sqliteLibVersion]);

	NSArray *documentDirectories = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
																	   NSUserDomainMask,
																	   YES);
	NSString *directory = [documentDirectories objectAtIndex:0];

	NSError *err = nil;
	NSFileManager *manager = [NSFileManager defaultManager];

	// Hide the SQLite database from the iTunes document inspector.
	NSString *oldPath = [directory stringByAppendingPathComponent:@"mumble.sqlite"];
	NSString *newPath = [directory stringByAppendingPathComponent:@".mumble.sqlite"];
	if (![manager fileExistsAtPath:newPath] && [manager fileExistsAtPath:oldPath]) {
		if (![manager moveItemAtPath:oldPath toPath:newPath error:&err]) {
			NSLog(@"Database: Unable to move file to new spot");
		}
	}

	NSString *dbPath = newPath;
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

	if ([Database enableForeignKeySupport] == NO) {
		NSLog(@"Databse: No foreign key support found in SQLite. Bad things *will* happen.");
	}

	//[Database dropAllTables];

	[db executeUpdate:@"CREATE TABLE IF NOT EXISTS `identities` "
					  @"(`id` INTEGER PRIMARY KEY AUTOINCREMENT,"
					  @" `username` TEXT,"
					  @" `fullname` TEXT,"
					  @" `email` TEXT,"
					  @" `avatar` BLOB,"
					  @" `persistent` BLOB)"];

	[db executeUpdate:@"CREATE TABLE IF NOT EXISTS `servers` "
					  @"(`id` INTEGER PRIMARY KEY AUTOINCREMENT,"
					  @" `name` TEXT,"
					  @" `hostname` TEXT,"
	                  @" `port` INTEGER DEFAULT 64738)"];

	[db executeUpdate:@"ALTER TABLE `servers` ADD `identity` "
					  @"INTEGER DEFAULT NULL REFERENCES identities(id) ON DELETE SET DEFAULT"];

	[db executeUpdate:@"ALTER TABLE `servers` ADD `username` TEXT"];
	[db executeUpdate:@"ALTER TABLE `servers` ADD `password` TEXT"];

	[db executeUpdate:@"VACUUM"];

	if ([db hadError]) {
		NSLog(@"Database: Error: %@ (Code: %i)", [db lastErrorMessage], [db lastErrorCode]);
	}
}

// Enable foreign key support in SQLite
+ (BOOL) enableForeignKeySupport {
	FMResultSet *res;
	BOOL supported;

	// Check for foreign key support in SQLite
	res = [db executeQuery:@"PRAGMA foreign_keys"];
	[res next];
	supported = [res intForColumnIndex:0] == 0;
	[res close];

	if (!supported) {
		return NO;
	}

	[db executeUpdate:@"PRAGMA foreign_keys = ON"];

	// Check for foreign key support in SQLite
	res = [db executeQuery:@"PRAGMA foreign_keys"];
	[res next];
	supported = [res intForColumnIndex:0] == 1;
	[res close];

	return supported;
}

// Tear down the database
+ (void) teardown {
	[db release];
}

+ (void) dropAllTables {
	[db executeUpdate:@"DROP TABLE `identities`"];
	[db executeUpdate:@"DROP TABLE `servers`"];
}

// Store a single favourite
+ (void) storeFavourite:(FavouriteServer *)favServ {
	// If the favourite already has a primary key, update the currently stored entity
	if ([favServ hasPrimaryKey]) {
		[db executeUpdate:@"UPDATE `servers` SET `name`=?, `hostname`=?, `port`=?, `identity`=?, `username`=?, `password`=? WHERE `id`=?",
			[favServ displayName],
			[favServ hostName],
			[NSString stringWithFormat:@"%u", [favServ port]],
			[favServ identityForeignKey] == -1 ? nil : [NSNumber numberWithInt:[favServ identityForeignKey]],
			[favServ userName],
			[favServ password],
			[NSNumber numberWithInt:[favServ primaryKey]]];
	// If it isn't already stored, store it and update the object's pkey.
	} else {
		// We're already inside a transaction if we were called from within
		// storeFavourites. If that isn't the case, make sure we start a new
		// transaction.
		BOOL newTransaction = ![db inTransaction];
		if (newTransaction)
			[db beginTransaction];
		[db executeUpdate:@"INSERT INTO `servers` (`name`, `hostname`, `port`, `identity`, `username`, `password`) VALUES (?, ?, ?, ?, ?, ?)",
			[favServ displayName],
			[favServ hostName],
			[NSString stringWithFormat:@"%u", [favServ port]],
			[favServ identityForeignKey] == -1 ? nil : [NSNumber numberWithInt:[favServ identityForeignKey]],
			[favServ userName],
			[favServ password]];
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

// Save favourites
+ (void) storeFavourites:(NSArray *)favourites {
	[db beginTransaction];
	for (FavouriteServer *favServ in favourites) {
		[Database storeFavourite:favServ];
	}
	[db commit];
}

// Fetch all favourites
+ (NSMutableArray *) fetchAllFavourites {
	NSMutableArray *favs = [[NSMutableArray alloc] init];
	FMResultSet *res = [db executeQuery:@"SELECT `id`, `name`, `hostname`, `port`, `identity`, `username`, `password` FROM `servers`"];
	while ([res next]) {
		FavouriteServer *fs = [[FavouriteServer alloc] init];
		[fs setPrimaryKey:[res intForColumnIndex:0]];
		[fs setDisplayName:[res stringForColumnIndex:1]];
		[fs setHostName:[res stringForColumnIndex:2]];
		[fs setPort:[res intForColumnIndex:3]];
		if ([res columnIndexIsNull:4])
			[fs setIdentityForeignKey:-1];
		else
			[fs setIdentityForeignKey:[res intForColumnIndex:4]];
		[fs setUserName:[res stringForColumnIndex:5]];
		[fs setPassword:[res stringForColumnIndex:6]];
		[favs addObject:fs];
	}
	[res close];
	return [favs autorelease];
}

// Store identity
+ (void) storeIdentity:(Identity *)ident {
	// If the favourite already has a primary key, update the currently stored entity
	if ([ident hasPrimaryKey]) {
		// If it isn't already stored, store it and update the object's pkey.
		[db executeUpdate:@"UPDATE `identities` SET `username`=?, `fullname`=?, `email`=?, `avatar`=?, `persistent`=? WHERE `id`=?",
			ident.userName, ident.fullName, ident.emailAddress, ident.avatarData, ident.persistent,
			[NSNumber numberWithInt:[ident primaryKey]]];
	} else {
		// We're already inside a transaction if we were called from within
		// storeIdentities. If that isn't the case, make sure we start a new
		// transaction.
		BOOL newTransaction = ![db inTransaction];
		if (newTransaction)
			[db beginTransaction];
		[db executeUpdate:@"INSERT INTO `identities` (`username`, `fullname`, `email`, `avatar`, `persistent`) VALUES (?, ?, ?, ?, ?)",
			ident.userName, ident.fullName, ident.emailAddress, ident.avatarData, ident.persistent];
		FMResultSet *res = [db executeQuery:@"SELECT last_insert_rowid()"];
		[res next];
		[ident setPrimaryKey:[res intForColumnIndex:0]];
		if (newTransaction)
			[db commit];
	}
}

// Delete identity
+ (void) deleteIdentity:(Identity *)ident {
	NSAssert([ident hasPrimaryKey], @"Can only delete objects originated from database");
	[db executeUpdate:@"DELETE FROM `identities` WHERE `id`=?",
		[NSNumber numberWithInt:[ident primaryKey]]];
}

// Fetch all identities
+ (NSArray *) fetchAllIdentities {
	NSMutableArray *idents = [[NSMutableArray alloc] init];
	FMResultSet *res = [db executeQuery:@"SELECT `id`, `persistent`, `username`, `fullname`, `email`, `avatar` FROM `identities`"];
	while ([res next]) {
		Identity *ident = [[Identity alloc] init];
		ident.primaryKey = [res intForColumnIndex:0];
		ident.persistent = [res dataForColumnIndex:1];
		ident.userName = [res stringForColumnIndex:2];
		ident.fullName = [res stringForColumnIndex:3];
		ident.emailAddress = [res stringForColumnIndex:4];
		ident.avatarData = [res dataForColumnIndex:5];
		[idents addObject:ident];
	}
	[res close];
	return [idents autorelease];
}

// Fetch an identity by primary key
+ (Identity *) identityWithPrimaryKey:(NSInteger)key {
	FMResultSet *res = [db executeQuery:@"SELECT `id`, `persistent`, `username`, `fullname`, `email`, `avatar` FROM `identities` WHERE `id`=?",
							[NSNumber numberWithInt:key]];
	if (res && [res next]) {
		Identity *ident = [[Identity alloc] init];
		ident.primaryKey = [res intForColumnIndex:0];
		ident.persistent = [res dataForColumnIndex:1];
		ident.userName = [res stringForColumnIndex:2];
		ident.fullName = [res stringForColumnIndex:3];
		ident.emailAddress = [res stringForColumnIndex:4];
		ident.avatarData = [res dataForColumnIndex:5];
		[res close];
		return [ident autorelease];
	}

	return nil;
}

// Save identities
+ (void) storeIdentities:(NSArray *)idents {
	[db beginTransaction];
	for (Identity *ident in idents) {
		[Database storeIdentity:ident];
	}
	[db commit];
}

@end
