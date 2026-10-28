#import <Foundation/Foundation.h>
#import <Security/Security.h>

FOUNDATION_EXPORT NSNotificationName const MUCredentialStorageDidFailNotification;
// Accounts are scoped to the database installation, never to a UI row index.
@interface MUCredentialStore : NSObject
+ (NSData *)dataForAccount:(NSString *)account status:(OSStatus *)status;
+ (OSStatus)setData:(NSData *)data forAccount:(NSString *)account;
+ (void)reportFailure:(OSStatus)status;
@end
