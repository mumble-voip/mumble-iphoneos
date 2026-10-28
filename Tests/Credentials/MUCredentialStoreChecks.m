#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <sqlite3.h>
#import "MUCredentialStore.h"
#import "MUFavouriteServer.h"
@interface MUDatabase : NSObject
+ (NSString *)filePath;
+ (NSArray *)fetchAllFavourites;
+ (void)storeFavourite:(MUFavouriteServer *)server;
+ (void)deleteFavourite:(MUFavouriteServer *)server;
+ (void)storeAccessTokens:(NSArray *)tokens forServerWithHostname:(NSString *)hostname port:(NSInteger)port;
+ (NSArray *)accessTokensForServerWithHostname:(NSString *)hostname port:(NSInteger)port;
+ (void)migrateLegacyCredentials;
+ (void)storeDigest:(NSString *)digest forServerWithHostname:(NSString *)hostname port:(NSInteger)port;
+ (NSString *)digestForServerWithHostname:(NSString *)hostname port:(NSInteger)port;
@end
@interface MUCredentialStore (Checks)
+ (NSDictionary *)queryForAccount:(NSString *)account;
@end
static void Check(BOOL condition,NSString *reason){if(!condition)@throw [NSException exceptionWithName:@"CredentialStoreFailure" reason:reason userInfo:nil];}
static sqlite3 *database;
static sqlite3_stmt *Query(NSString *sql,NSArray *values){
    sqlite3_stmt *statement=NULL;Check(sqlite3_prepare_v2(database,sql.UTF8String,-1,&statement,NULL)==SQLITE_OK,@"Cannot prepare credential fixture SQL");
    for(NSUInteger i=0;i<values.count;i++){
        id value=values[i];int column=(int)i+1;
        if([value isKindOfClass:NSData.class])sqlite3_bind_blob(statement,column,[value bytes],(int)[value length],SQLITE_TRANSIENT);
        else if([value isKindOfClass:NSNumber.class])sqlite3_bind_int64(statement,column,[value longLongValue]);
        else sqlite3_bind_text(statement,column,[value UTF8String],-1,SQLITE_TRANSIENT);
    }return statement;
}
static void Execute(NSString *sql,NSArray *values){sqlite3_stmt *query=Query(sql,values);int result=sqlite3_step(query);sqlite3_finalize(query);Check(result==SQLITE_DONE,@"Cannot update credential fixture SQL");}
static NSString *Text(NSString *sql,NSArray *values){sqlite3_stmt *query=Query(sql,values);NSString *text=nil;if(sqlite3_step(query)==SQLITE_ROW && sqlite3_column_type(query,0)!=SQLITE_NULL)text=@((const char *)sqlite3_column_text(query,0));sqlite3_finalize(query);return text;}
static void Migrate(){
    __block BOOL finished=NO;dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{[MUDatabase migrateLegacyCredentials];dispatch_async(dispatch_get_main_queue(),^{finished=YES;});});
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:5];while(!finished && deadline.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]];Check(finished,@"Credential migration did not finish");
}
static OSStatus DeniedWrite(id object,SEL command,NSData *data,NSString *account){return errSecInteractionNotAllowed;}
static NSData *DeniedRead(id object,SEL command,NSString *account,OSStatus *status){if(status)*status=errSecInteractionNotAllowed;return nil;}
void MUCredentialStoreChecks(NSMutableArray<NSString *> *results){
    [MUDatabase fetchAllFavourites];Check(sqlite3_open([MUDatabase filePath].fileSystemRepresentation,&database)==SQLITE_OK,@"Cannot open isolated credential fixture database");sqlite3_busy_timeout(database,3000);
    NSString *namespace=Text(@"SELECT value FROM credential_metadata WHERE key='namespace'",@[]);Check(namespace.length>0,@"Missing credential installation namespace");
    NSString *host=[NSUUID.UUID.UUIDString.lowercaseString stringByAppendingString:@".invalid"];
    NSString *trustHost=[@"LÄN-" stringByAppendingString:host],*trustKey=trustHost.lowercaseString;
    MUFavouriteServer *server=[[MUFavouriteServer alloc]initWithDisplayName:@"Credential fixture" hostName:host port:64738 userName:@"Fixture" password:@"Fixture password"];
    @try{
        Execute(@"INSERT INTO cert (hostname,port,digest) VALUES (?,64738,'legacy-pin')",@[trustHost]);
        Check([[MUDatabase digestForServerWithHostname:trustKey port:64738]isEqual:@"legacy-pin"],@"Legacy mixed-case LAN trust is lost through canonical Recent lookup");
        Check(![MUDatabase digestForServerWithHostname:trustKey port:64739] && ![MUDatabase digestForServerWithHostname:host port:64738],@"Trust leaks to another hostname or port");
        Execute(@"INSERT INTO cert (hostname,port,digest) VALUES (?,64738,'conflicting-pin')",@[trustKey]);
        Check(![MUDatabase digestForServerWithHostname:trustKey port:64738],@"Conflicting legacy trust records are silently accepted");
        Execute(@"CREATE TRIGGER mumble_trust_write_fixture BEFORE INSERT ON cert BEGIN SELECT RAISE(ABORT,'Fixture'); END",@[]);
        @try{[MUDatabase storeDigest:@"replacement-pin" forServerWithHostname:trustHost port:64738];}
        @finally{Execute(@"DROP TRIGGER mumble_trust_write_fixture",@[]);}
        Check([Text(@"SELECT count(*) FROM cert WHERE hostname IN (?,?) AND port=64738",@[trustHost,trustKey])isEqual:@"2"],@"Failed trust save discards existing certificate pins");
        [MUDatabase storeDigest:@"replacement-pin" forServerWithHostname:[@"  " stringByAppendingString:trustHost] port:64738];
        Check([[MUDatabase digestForServerWithHostname:trustHost port:64738]isEqual:@"replacement-pin"] && [Text(@"SELECT count(*) FROM cert WHERE hostname IN (?,?) AND port=64738",@[trustHost,trustKey])isEqual:@"1"],@"Explicit trust does not replace legacy case variants atomically");
        [results addObject:@"PASS legacy Unicode LAN trust, canonical Recent keys, host/port isolation, conflicting pins and failed-write rollback"];
        [MUDatabase storeFavourite:server];Check(server.hasPrimaryKey,@"Saving a favourite with a Keychain password failed");
        Check(Text(@"SELECT password FROM favourites WHERE id=?",@[@(server.primaryKey)])==nil,@"A newly saved password is still present in SQLite");
        NSString *account=[NSString stringWithFormat:@"%@:favourite:%ld",namespace,(long)server.primaryKey];OSStatus status;
        NSData *data=[MUCredentialStore dataForAccount:account status:&status];Check(status==errSecSuccess && [[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]isEqual:@"Fixture password"],@"Password was not persisted in Keychain");
        NSMutableDictionary *query=[[MUCredentialStore queryForAccount:account]mutableCopy];query[(__bridge id)kSecReturnAttributes]=@YES;
        CFTypeRef value=NULL;Check(SecItemCopyMatching((__bridge CFDictionaryRef)query,&value)==errSecSuccess,@"Cannot verify credential attributes");NSDictionary *attributes=CFBridgingRelease(value);
        Check([attributes[(__bridge id)kSecAttrAccessible]isEqual:(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly],@"Credentials use the wrong background/device accessibility");
        server.hostName=[@"renamed." stringByAppendingString:host];server.password=@"Updated password";[MUDatabase storeFavourite:server];
        MUFavouriteServer *loaded=nil;for(MUFavouriteServer *item in [MUDatabase fetchAllFavourites])if(item.primaryKey==server.primaryKey)loaded=item;
        Check([loaded.password isEqual:@"Updated password"],@"Editing a favourite endpoint loses its password");
        [MUDatabase storeAccessTokens:@[@"Fixture token"] forServerWithHostname:host port:64738];
        Check([[MUDatabase accessTokensForServerWithHostname:host.uppercaseString port:64738]isEqual:@[@"Fixture token"]],@"Endpoint normalization loses access tokens");
        Check(Text(@"SELECT hex(tokens) FROM tokens WHERE hostname=?",@[host])==nil,@"Access tokens are still present in SQLite");
        Method read=class_getClassMethod(MUCredentialStore.class,@selector(dataForAccount:status:));IMP originalRead=method_setImplementation(read,(IMP)DeniedRead);
        @try{Check([MUCredentialStore setData:nil forAccount:account]==errSecInteractionNotAllowed,@"An unavailable Keychain item is treated as an empty password");}@finally{method_setImplementation(read,originalRead);}
        Check([MUCredentialStore dataForAccount:account status:&status].length>0,@"A locked credential was deleted");
        [MUDatabase deleteFavourite:server];[MUCredentialStore dataForAccount:account status:&status];Check(status==errSecItemNotFound,@"Deleting a favourite leaves its password behind");
        [MUDatabase storeAccessTokens:@[] forServerWithHostname:host port:64738];Check(![MUDatabase accessTokensForServerWithHostname:host port:64738].count,@"Clearing access tokens leaves credentials behind");
        [results addObject:@"PASS Keychain-only password/token writes, endpoint edits, accessibility, unavailable-item protection and deletion"];

        NSString *legacyPassword=[@"Legacy-password-" stringByAppendingString:NSUUID.UUID.UUIDString];
        Execute(@"INSERT INTO favourites (name,hostname,port,username,password) VALUES ('Legacy',?,64738,'Fixture',?)",@[host,legacyPassword]);
        sqlite3_int64 identifier=sqlite3_last_insert_rowid(database);
        NSData *legacyTokens=[NSJSONSerialization dataWithJSONObject:@[@"Legacy token"] options:0 error:nil];
        Execute(@"INSERT INTO tokens (hostname,port,tokens) VALUES (?,64738,?)",@[host,legacyTokens]);Execute(@"PRAGMA user_version=0",@[]);
        Method write=class_getClassMethod(MUCredentialStore.class,@selector(setData:forAccount:));IMP originalWrite=method_setImplementation(write,(IMP)DeniedWrite);
        @try{Migrate();Check([Text(@"SELECT password FROM favourites WHERE id=?",@[@(identifier)])isEqual:legacyPassword] && Text(@"SELECT hex(tokens) FROM tokens WHERE hostname=?",@[host]).length>0,@"Failed migration destroys the only copy of credentials");}@finally{method_setImplementation(write,originalWrite);}
        Migrate();Migrate();
        MUFavouriteServer *legacy=nil;for(MUFavouriteServer *item in [MUDatabase fetchAllFavourites])if(item.primaryKey==identifier)legacy=item;
        Check([legacy.password isEqual:legacyPassword] && [[MUDatabase accessTokensForServerWithHostname:host port:64738]isEqual:@[@"Legacy token"]],@"Migrated credentials cannot be read after repeated migration");
        Check(Text(@"SELECT password FROM favourites WHERE id=?",@[@(identifier)])==nil && Text(@"SELECT hex(tokens) FROM tokens WHERE hostname=?",@[host])==nil,@"Successful migration leaves plaintext SQL credentials");
        NSData *contents=[NSData dataWithContentsOfFile:[MUDatabase filePath]];
        Check([contents rangeOfData:[legacyPassword dataUsingEncoding:NSUTF8StringEncoding] options:0 range:NSMakeRange(0,contents.length)].location==NSNotFound,@"Historical password bytes remain in the database after migration");
        [MUDatabase deleteFavourite:legacy];[MUDatabase storeAccessTokens:@[] forServerWithHostname:host port:64738];
        [results addObject:@"PASS legacy credential migration, failure preservation, retry/idempotency and removal of plaintext database bytes"];
    }@finally{Execute(@"DELETE FROM cert WHERE hostname IN (?,?)",@[trustHost,trustKey]);sqlite3_close(database);database=NULL;}
}
