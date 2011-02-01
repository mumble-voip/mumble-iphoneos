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

	//[Database dropAllTables];

	[db executeUpdate:@"CREATE TABLE IF NOT EXISTS `favourites` "
					  @"(`id` INTEGER PRIMARY KEY AUTOINCREMENT,"
					  @" `name` TEXT,"
					  @" `hostname` TEXT,"
	                  @" `port` INTEGER DEFAULT 64738,"
	                  @" `username` TEXT,"
	                  @" `password` TEXT)"];

	[db executeUpdate:@"CREATE TABLE IF NOT EXISTS `cert` "
	                  @"(`id` INTEGER PRIMARY KEY AUTOINCREMENT,"
	                  @" `hostname` TEXT,"
	                  @" `port` INTEGER,"
	                  @" `digest` TEXT)"];
	[db executeUpdate:@"CREATE UNIQUE INDEX IF NOT EXISTS `cert_host_port`"
	                  @" on `cert`(`hostname`,`port`)"];

	[db executeUpdate:@"VACUUM"];

	if ([db hadError]) {
		NSLog(@"Database: Error: %@ (Code: %i)", [db lastErrorMessage], [db lastErrorCode]);
	}
}

// Tear down the database
+ (void) teardown {
	[db release];
}

+ (void) dropAllTables {
	[db executeUpdate:@"DROP TABLE `identities`"];
	[db executeUpdate:@"DROP TABLE `servers`"];
	[db executeUpdate:@"DROP TABLE `favourites`"];
}

// Store a single favourite
+ (void) storeFavourite:(FavouriteServer *)favServ {
	// If the favourite already has a primary key, update the currently stored entity
	if ([favServ hasPrimaryKey]) {
		[db executeUpdate:@"UPDATE `favourites` SET `name`=?, `hostname`=?, `port`=?, `username`=?, `password`=? WHERE `id`=?",
			[favServ displayName],
			[favServ hostName],
			[NSString stringWithFormat:@"%u", [favServ port]],
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
		[db executeUpdate:@"INSERT INTO `favourites` (`name`, `hostname`, `port`, `username`, `password`) VALUES (?, ?, ?, ?, ?)",
			[favServ displayName],
			[favServ hostName],
			[NSString stringWithFormat:@"%u", [favServ port]],
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
	[db executeUpdate:@"DELETE FROM `favourites` WHERE `id`=?", [NSNumber numberWithInt:[favServ primaryKey]]];
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
	FMResultSet *res = [db executeQuery:@"SELECT `id`, `name`, `hostname`, `port`, `username`, `password` FROM `favourites`"];
	while ([res next]) {
		FavouriteServer *fs = [[FavouriteServer alloc] init];
		[fs setPrimaryKey:[res intForColumnIndex:0]];
		[fs setDisplayName:[res stringForColumnIndex:1]];
		[fs setHostName:[res stringForColumnIndex:2]];
		[fs setPort:[res intForColumnIndex:3]];
		[fs setUserName:[res stringForColumnIndex:4]];
		[fs setPassword:[res stringForColumnIndex:5]];
		[favs addObject:fs];
	}
	[res close];
	return [favs autorelease];
}

#pragma mark -
#pragma mark Certificate verification

+ (void) storeDigest:(NSString *)hash forServerWithHostname:(NSString *)hostname port:(NSInteger)port {
	[db executeUpdate:@"REPLACE INTO `cert` (`hostname`,`port`,`digest`) VALUES (?,?,?)",
	       hostname, [NSNumber numberWithInteger:port], hash];

}

+ (NSString *) digestForServerWithHostname:(NSString *)hostname port:(NSInteger)port {
	FMResultSet *result = [db executeQuery:@"SELECT `digest` FROM `cert` WHERE `hostname` = ? AND `port` = ?",
	                             hostname, [NSNumber numberWithInteger:port]];
	if ([result next]) {
		return [result stringForColumnIndex:0];
	}
	return nil;
}

@end
