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
// Save favourites
//
+ (void) saveFavourites:(NSArray *)favourites {
	[db beginTransaction];

	[db executeUpdate:@"DELETE FROM `servers`"];

	for (FavouriteServer *favServ in favourites) {
		[db executeUpdate:@"REPLACE INTO `servers` (`name`, `hostname`, `port`, `username`) VALUES (?, ?, ?, ?)",
			[favServ displayName],
			[favServ hostName],
			[NSString stringWithFormat:@"%u", [favServ port]],
			[favServ userName]];
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

@end