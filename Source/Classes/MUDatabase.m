// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUDatabase.h"
#import "MUFavouriteServer.h"
#import "MUCredentialStore.h"

static FMDatabase *db = nil;
static NSString *credentialNamespace;
static BOOL credentialsPendingMigration;
static void *MUDatabaseQueueKey = &MUDatabaseQueueKey;

static NSString *MUHostnameKey(NSString *hostname) {
    return [hostname stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].lowercaseString;
}

static dispatch_queue_t MUDatabaseQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        queue = dispatch_queue_create("info.mumble.database", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(queue, MUDatabaseQueueKey, MUDatabaseQueueKey, NULL);
    });
    return queue;
}

static void MUDatabasePerform(dispatch_block_t block) {
    if (dispatch_get_specific(MUDatabaseQueueKey) == MUDatabaseQueueKey) {
        block();
    } else {
        dispatch_sync(MUDatabaseQueue(), block);
    }
}

@interface MUDatabase ()
+ (NSString *) filePath;
+ (void) moveOldDatabases;
+ (void) openDatabaseIfNeeded;
+ (void) storeFavouriteOnQueue:(MUFavouriteServer *)favServ;
+ (void)migrateCredentialsOnQueue;
@end

@implementation MUDatabase

+ (NSString *) filePath {
    NSArray *libraryDirectories = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                                                      NSUserDomainMask,
                                                                      YES);
    NSString *library = [libraryDirectories objectAtIndex:0];
    [[NSFileManager defaultManager] createDirectoryAtPath:library withIntermediateDirectories:YES attributes:nil error:nil];
    return [library stringByAppendingPathComponent:@"mumble.sqlite"];
}

+ (void) moveOldDatabases {
    NSArray *documentDirectories = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                                       NSUserDomainMask,
                                                                       YES);
    NSString *docs = [documentDirectories objectAtIndex:0];
    
    NSError *err = nil;
    NSFileManager *manager = [NSFileManager defaultManager];
    
    // Hide the SQLite database from the iTunes document inspector.
    NSString *oldPath = [docs stringByAppendingPathComponent:@"mumble.sqlite"];
    NSString *newPath = [docs stringByAppendingPathComponent:@".mumble.sqlite"];
    if (![manager fileExistsAtPath:newPath] && [manager fileExistsAtPath:oldPath]) {
        if (![manager moveItemAtPath:oldPath toPath:newPath error:&err]) {
            NSLog(@"MUDatabase: unable to move file to new spot (mumble.sqlite -> .mumble.sqlite)");
        }
    }

    // Attempt to move an old database to the new location.
    NSString *correctPath = [MUDatabase filePath];
    if (![manager fileExistsAtPath:correctPath]) {
        oldPath = newPath;
        newPath = correctPath;
        if (![manager fileExistsAtPath:newPath] && [manager fileExistsAtPath:oldPath]) {
            if (![manager moveItemAtPath:oldPath toPath:newPath error:&err]) {
                NSLog(@"MUDatabase: Unable to move file to new spot (~/Documents -> ~/Library)");
            }
        }
    }
}

// Initialize the database.
+ (void) initializeDatabase {
    dispatch_async(MUDatabaseQueue(), ^{
        [self openDatabaseIfNeeded];
    });
}

+ (void)migrateLegacyCredentials {MUDatabasePerform(^{[self openDatabaseIfNeeded];[self migrateCredentialsOnQueue];});}

+ (void) openDatabaseIfNeeded {
    if (db != nil) {
        return;
    }
    NSLog(@"Initializing database with SQLite version: %@", [FMDatabase sqliteLibVersion]);

    // Attempt to move old databases if we find ones
    // in our old locations.
    [MUDatabase moveOldDatabases];
    
    NSString *dbPath = [MUDatabase filePath];
    db = [[FMDatabase alloc] initWithPath:dbPath];
    if (!db)
        return;

    if ([db open]) {
        NSLog(@"MUDatabase: Initialized database at %@", dbPath);
    } else {
        NSLog(@"MUDatabase: Could not open database at %@", dbPath);
        db = nil;
        return;
    }

    [db executeUpdate:@"PRAGMA secure_delete=ON"];
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
    [db executeUpdate:@"CREATE TABLE IF NOT EXISTS `recent_servers` "
                      @"(`id` INTEGER PRIMARY KEY AUTOINCREMENT,"
                      @" `hostname` TEXT NOT NULL COLLATE NOCASE,"
                      @" `port` INTEGER NOT NULL,"
                      @" `name` TEXT,"
                      @" `username` TEXT,"
                      @" UNIQUE(`hostname`,`port`))"];
    [db executeUpdate:@"CREATE TABLE IF NOT EXISTS `usernames` "
                      @"(`id` INTEGER PRIMARY KEY AUTOINCREMENT,"
                      @" `hostname` TEXT,"
                      @" `port` INTEGER,"
                      @" `username` TEXT)"];
    [db executeUpdate:@"CREATE UNIQUE INDEX IF NOT EXISTS `usernames_host_port`"
                      @" on `usernames`(`hostname`,`port`)"];
    [db executeUpdate:@"CREATE TABLE IF NOT EXISTS `tokens` "
                      @"(`id` INTEGER PRIMARY KEY AUTOINCREMENT,"
                      @" `hostname` TEXT,"
                      @" `port` INTEGER,"
                      @" `tokens` BLOB)"];
    [db executeUpdate:@"CREATE UNIQUE INDEX IF NOT EXISTS `tokens_host_port`"
                      @" on `tokens`(`hostname`,`port`)"];

    [db executeUpdate:@"CREATE TABLE IF NOT EXISTS credential_metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)"];
    [db executeUpdate:@"INSERT OR IGNORE INTO credential_metadata (key,value) VALUES ('namespace',?)",NSUUID.UUID.UUIDString];
    FMResultSet *namespaceRow=[db executeQuery:@"SELECT value FROM credential_metadata WHERE key='namespace'"];
    if([namespaceRow next])credentialNamespace=[namespaceRow stringForColumnIndex:0];[namespaceRow close];
    [self migrateCredentialsOnQueue];

    if ([db hadError]) {
        NSLog(@"MUDatabase: Error: %@ (Code: %i)", [db lastErrorMessage], [db lastErrorCode]);
    }
}

// Run on the database queue. Keychain writes are verified before SQL is cleared.
+ (NSString *)passwordAccount:(NSInteger)identifier {
    return [NSString stringWithFormat:@"%@:favourite:%ld",credentialNamespace,(long)identifier];
}
+ (NSString *)tokenAccount:(NSString *)hostname port:(NSInteger)port {
    NSData *endpoint=[NSJSONSerialization dataWithJSONObject:@[hostname.lowercaseString ?: @"",@(port)] options:0 error:nil];
    return [NSString stringWithFormat:@"%@:tokens:%@",credentialNamespace,[endpoint base64EncodedStringWithOptions:0]];
}
+ (BOOL)migrateData:(NSData *)data account:(NSString *)account {
    if(!credentialNamespace.length)return NO;
    OSStatus status;[MUCredentialStore dataForAccount:account status:&status];
    // A previous successful save wins over a stale SQL copy after a crash.
    if(status==errSecItemNotFound)status=[MUCredentialStore setData:data forAccount:account];
    return status==errSecSuccess;
}
+ (void)migrateCredentialsOnQueue {
    credentialsPendingMigration=NO;
    FMResultSet *rows=[db executeQuery:@"SELECT id,password FROM favourites WHERE password IS NOT NULL"];
    NSMutableArray *passwords=[NSMutableArray array];
    while([rows next])[passwords addObject:@[@([rows longLongIntForColumnIndex:0]),[rows stringForColumnIndex:1] ?: @""]];[rows close];
    for(NSArray *row in passwords){
        NSString *password=row[1];
        if(!password.length || [self migrateData:[password dataUsingEncoding:NSUTF8StringEncoding] account:[self passwordAccount:[row[0]integerValue]]]){
            if(![db executeUpdate:@"UPDATE favourites SET password=NULL WHERE id=?",row[0]])credentialsPendingMigration=YES;
        }else credentialsPendingMigration=YES;
    }
    rows=[db executeQuery:@"SELECT id,hostname,port,tokens FROM tokens WHERE tokens IS NOT NULL ORDER BY id DESC"];
    NSMutableArray *tokens=[NSMutableArray array];
    while([rows next])[tokens addObject:@[@([rows longLongIntForColumnIndex:0]),[rows stringForColumnIndex:1] ?: @"",@([rows intForColumnIndex:2]),[rows dataForColumnIndex:3] ?: NSData.data]];[rows close];
    for(NSArray *row in tokens){
        if([self migrateData:row[3] account:[self tokenAccount:row[1] port:[row[2]integerValue]]]){
            if(![db executeUpdate:@"DELETE FROM tokens WHERE id=?",row[0]])credentialsPendingMigration=YES;
        }else credentialsPendingMigration=YES;
    }
    rows=[db executeQuery:@"PRAGMA user_version"];NSInteger version=[rows next] ? [rows intForColumnIndex:0] : 0;[rows close];
    // Rebuild once to remove historical plaintext left in old free pages.
    // Never vacuum/mark migration complete while a Keychain write is unavailable.
    if(!credentialsPendingMigration && version<1 && !db.isInTransaction && [db executeUpdate:@"VACUUM"])[db executeUpdate:@"PRAGMA user_version=1"];
}

// Store a single favourite
+ (void) storeFavourite:(MUFavouriteServer *)favServ {
    MUDatabasePerform(^{
        [self openDatabaseIfNeeded];
        [self storeFavouriteOnQueue:favServ];
    });
}

+ (void)storePassword:(NSString *)password forFavouriteWithPrimaryKey:(NSInteger)primaryKey {
    if(primaryKey<0 || !password.length)return;
    MUDatabasePerform(^{
        [self openDatabaseIfNeeded];
        FMResultSet *row=[db executeQuery:@"SELECT id FROM favourites WHERE id=?",@(primaryKey)];BOOL exists=[row next];[row close];
        if(!exists)return;
        OSStatus status=[MUCredentialStore setData:[password dataUsingEncoding:NSUTF8StringEncoding] forAccount:[self passwordAccount:primaryKey]];
        if(status==errSecSuccess)[db executeUpdate:@"UPDATE favourites SET password=NULL WHERE id=?",@(primaryKey)];
        else [MUCredentialStore reportFailure:status];
    });
}

+ (void)storeFavouriteOnQueue:(MUFavouriteServer *)server {
    BOOL created=!server.hasPrimaryKey;
    if(!credentialNamespace.length){[MUCredentialStore reportFailure:errSecNotAvailable];return;}
    if(created){
        if(![db executeUpdate:@"INSERT INTO favourites (name,hostname,port,username,password) VALUES (?,?,?,?,NULL)",server.displayName,server.hostName,@(server.port),server.userName])return;
        server.primaryKey=(NSInteger)db.lastInsertRowId;
    }
    OSStatus status=[MUCredentialStore setData:[server.password dataUsingEncoding:NSUTF8StringEncoding] forAccount:[self passwordAccount:server.primaryKey]];
    if(status!=errSecSuccess){
        if(created){[db executeUpdate:@"DELETE FROM favourites WHERE id=?",@(server.primaryKey)];server.primaryKey=-1;}
        [MUCredentialStore reportFailure:status];return;
    }
    [db executeUpdate:@"UPDATE favourites SET name=?,hostname=?,port=?,username=?,password=NULL WHERE id=?",server.displayName,server.hostName,@(server.port),server.userName,@(server.primaryKey)];
}

// Delete a particular favourite
+ (void) deleteFavourite:(MUFavouriteServer *)favServ {
    MUDatabasePerform(^{
        [self openDatabaseIfNeeded];
        NSAssert([favServ hasPrimaryKey], @"Cannot delete a FavouriteServer not originated from the database.");
        OSStatus status=[MUCredentialStore setData:nil forAccount:[self passwordAccount:favServ.primaryKey]];
        if(status!=errSecSuccess){[MUCredentialStore reportFailure:status];return;}
        [db executeUpdate:@"DELETE FROM `favourites` WHERE `id`=?", @(favServ.primaryKey)];
    });
}

// Save favourites
+ (void) storeFavourites:(NSArray *)favourites {
    MUDatabasePerform(^{
        [self openDatabaseIfNeeded];
        [db beginTransaction];
        for (MUFavouriteServer *favServ in favourites) {
            [self storeFavouriteOnQueue:favServ];
        }
        [db commit];
    });
}

// Fetch all favourites
+ (NSMutableArray *) fetchAllFavourites {
    __block NSMutableArray *favs = nil;
    MUDatabasePerform(^{
        [self openDatabaseIfNeeded];
        favs = [[NSMutableArray alloc] init];
        if(credentialsPendingMigration)[self migrateCredentialsOnQueue];
        FMResultSet *res = [db executeQuery:@"SELECT `id`, `name`, `hostname`, `port`, `username`, `password` FROM `favourites`"];
        while ([res next]) {
            MUFavouriteServer *fs = [[MUFavouriteServer alloc] init];
            [fs setPrimaryKey:[res intForColumnIndex:0]];
            [fs setDisplayName:[res stringForColumnIndex:1]];
            [fs setHostName:[res stringForColumnIndex:2]];
            [fs setPort:[res intForColumnIndex:3]];
            [fs setUserName:[res stringForColumnIndex:4]];
            OSStatus status;NSData *secret=[MUCredentialStore dataForAccount:[self passwordAccount:fs.primaryKey] status:&status];
            fs.password=status==errSecSuccess ? [[NSString alloc]initWithData:secret encoding:NSUTF8StringEncoding] : [res stringForColumnIndex:5];
            [favs addObject:fs];
        }
        [res close];
    });
    return favs;
}

#pragma mark -
#pragma mark Recent connections

+ (void)recordRecentServerWithHostname:(NSString *)hostname port:(NSUInteger)port displayName:(NSString *)displayName username:(NSString *)username {
    NSString *host = MUHostnameKey(hostname);
    if (!host.length || port == 0 || port > UINT16_MAX) return;
    MUDatabasePerform(^{
        [self openDatabaseIfNeeded];
        [db beginTransaction];
        [db executeUpdate:@"INSERT OR REPLACE INTO `recent_servers` (`hostname`,`port`,`name`,`username`) VALUES (?,?,?,?)",
            host, @(port), displayName.length ? displayName : hostname, username ?: @""];
        [db executeUpdate:@"DELETE FROM `recent_servers` WHERE `id` NOT IN (SELECT `id` FROM `recent_servers` ORDER BY `id` DESC LIMIT 3)"];
        [db commit];
    });
}

+ (NSArray<MUFavouriteServer *> *)recentServers {
    __block NSMutableArray *servers = [NSMutableArray array];
    MUDatabasePerform(^{
        [self openDatabaseIfNeeded];
        FMResultSet *rows = [db executeQuery:@"SELECT `hostname`,`port`,`name`,`username` FROM `recent_servers` ORDER BY `id` DESC LIMIT 3"];
        while ([rows next]) {
            [servers addObject:[[MUFavouriteServer alloc] initWithDisplayName:[rows stringForColumn:@"name"] hostName:[rows stringForColumn:@"hostname"] port:[rows intForColumn:@"port"] userName:[rows stringForColumn:@"username"] password:nil]];
        }
        [rows close];
    });
    return servers;
}

+ (void)deleteRecentServer:(MUFavouriteServer *)server {
    MUDatabasePerform(^{
        [self openDatabaseIfNeeded];
        [db executeUpdate:@"DELETE FROM `recent_servers` WHERE `hostname`=? AND `port`=?", server.hostName.lowercaseString, @(server.port)];
    });
}

#pragma mark Certificate verification

+ (void) storeDigest:(NSString *)hash forServerWithHostname:(NSString *)hostname port:(NSInteger)port {
    NSString *host=MUHostnameKey(hostname);
    if(!host.length || !hash.length || port<=0 || port>UINT16_MAX)return;
    MUDatabasePerform(^{
        [self openDatabaseIfNeeded];
        if(![db beginTransaction])return;
        // SQLite NOCASE only handles ASCII. Match legacy Unicode LAN names
        // with the same normalization used for Recent, then remove variants.
        FMResultSet *rows=[db executeQuery:@"SELECT `hostname` FROM `cert` WHERE `port`=?",@(port)];
        NSMutableArray<NSString *> *variants=[NSMutableArray array];
        BOOL saved=rows!=nil;
        while([rows next]){
            NSString *name=[rows stringForColumnIndex:0];
            if([MUHostnameKey(name) isEqualToString:host])[variants addObject:name];
        }
        [rows close];
        for(NSString *name in variants){
            if(![db executeUpdate:@"DELETE FROM `cert` WHERE `hostname`=? AND `port`=?",name,@(port)]){saved=NO;break;}
        }
        if(saved)saved=[db executeUpdate:@"INSERT INTO `cert` (`hostname`,`port`,`digest`) VALUES (?,?,?)",host,@(port),hash];
        if(!saved || ![db commit])[db rollback];
    });
}

+ (NSString *) digestForServerWithHostname:(NSString *)hostname port:(NSInteger)port {
    NSString *host=MUHostnameKey(hostname);
    if(!host.length || port<=0 || port>UINT16_MAX)return nil;
    __block NSString *digest = nil;
    MUDatabasePerform(^{
        [self openDatabaseIfNeeded];
        // Read legacy mixed-case pins without discarding existing trust.
        FMResultSet *result = [db executeQuery:@"SELECT `hostname`,`digest` FROM `cert` WHERE `port`=?",@(port)];
        while ([result next]) {
            if(![MUHostnameKey([result stringForColumnIndex:0]) isEqualToString:host])continue;
            NSString *candidate=[result stringForColumnIndex:1];
            // Conflicting legacy pins require a fresh explicit decision.
            if(digest && ![digest isEqualToString:candidate]){digest=nil;break;}
            digest=candidate;
        }
        [result close];
    });
    return digest;
}

#pragma mark -
#pragma mark Username rememberer

+ (void) storeUsername:(NSString *)username forServerWithHostname:(NSString *)hostname port:(NSInteger)port {
    MUDatabasePerform(^{
        [self openDatabaseIfNeeded];
        [db executeUpdate:@"REPLACE INTO `usernames` (`hostname`,`port`,`username`) VALUES (?,?,?)",
            hostname, [NSNumber numberWithInteger:port], username];
    });
}

+ (NSString *) usernameForServerWithHostname:(NSString *)hostname port:(NSInteger)port {
    __block NSString *username = nil;
    MUDatabasePerform(^{
        [self openDatabaseIfNeeded];
        FMResultSet *result = [db executeQuery:@"SELECT `username` FROM `usernames` WHERE `hostname` = ? AND `port` = ?",
                               hostname, [NSNumber numberWithInteger:port]];
        if ([result next]) {
            username = [result stringForColumnIndex:0];
        }
        [result close];
    });
    return username;
}

#pragma mark -
#pragma mark Access tokens

+ (void)storeAccessTokens:(NSArray *)tokens forServerWithHostname:(NSString *)hostname port:(NSInteger)port {
    if(!hostname.length || port<=0 || port>UINT16_MAX)return;
    for(id token in tokens)if(![token isKindOfClass:NSString.class])return;
    NSData *data=tokens.count ? [NSJSONSerialization dataWithJSONObject:tokens options:0 error:nil] : nil;
    MUDatabasePerform(^{
        [self openDatabaseIfNeeded];
        OSStatus status=credentialNamespace.length ? [MUCredentialStore setData:data forAccount:[self tokenAccount:hostname port:port]] : errSecNotAvailable;
        if(status==errSecSuccess)[db executeUpdate:@"DELETE FROM tokens WHERE lower(hostname)=lower(?) AND port=?",hostname,@(port)];
        else [MUCredentialStore reportFailure:status];
    });
}
+ (NSArray *)accessTokensForServerWithHostname:(NSString *)hostname port:(NSInteger)port {
    if(!hostname.length)return nil;
    __block NSArray *tokens=nil;
    MUDatabasePerform(^{
        [self openDatabaseIfNeeded];if(credentialsPendingMigration)[self migrateCredentialsOnQueue];
        OSStatus status;NSData *data=[MUCredentialStore dataForAccount:[self tokenAccount:hostname port:port] status:&status];
        if(status!=errSecSuccess){
            FMResultSet *row=[db executeQuery:@"SELECT tokens FROM tokens WHERE lower(hostname)=lower(?) AND port=? ORDER BY id DESC LIMIT 1",hostname,@(port)];
            if([row next])data=[row dataForColumnIndex:0];[row close];
        }
        id decoded=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if([decoded isKindOfClass:NSArray.class]){
            BOOL valid=YES;for(id value in decoded)if(![value isKindOfClass:NSString.class])valid=NO;
            if(valid)tokens=decoded;
        }
    });return tokens;
}
@end
