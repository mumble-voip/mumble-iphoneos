#import "MUCredentialStore.h"

NSNotificationName const MUCredentialStorageDidFailNotification=@"MUCredentialStorageDidFailNotification";
@implementation MUCredentialStore
+ (NSDictionary *)queryForAccount:(NSString *)account {
    return @{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService:[NSBundle.mainBundle.bundleIdentifier ?: @"info.mumble.iphoneos" stringByAppendingString:@".server-credentials.v1"],
        (__bridge id)kSecAttrAccount:account,
        (__bridge id)kSecAttrSynchronizable:@NO};
}
+ (NSData *)dataForAccount:(NSString *)account status:(OSStatus *)status {
    NSMutableDictionary *query=[[self queryForAccount:account]mutableCopy];
    query[(__bridge id)kSecReturnData]=@YES;query[(__bridge id)kSecMatchLimit]=(__bridge id)kSecMatchLimitOne;
    CFTypeRef result=NULL;OSStatus value=SecItemCopyMatching((__bridge CFDictionaryRef)query,&result);
    if(status)*status=value;
    return CFBridgingRelease(result);
}
+ (OSStatus)setData:(NSData *)data forAccount:(NSString *)account {
    NSDictionary *query=[self queryForAccount:account];
    // A locked/unavailable item must never be mistaken for an empty password.
    OSStatus current;NSData *existing=[self dataForAccount:account status:&current];
    if(current!=errSecSuccess && current!=errSecItemNotFound)return current;
    if((data.length && [existing isEqual:data]) || (!data.length && current==errSecItemNotFound))return errSecSuccess;
    if(!data.length){OSStatus result=SecItemDelete((__bridge CFDictionaryRef)query);return result==errSecItemNotFound ? errSecSuccess : result;}
    NSDictionary *attributes=@{(__bridge id)kSecValueData:data,(__bridge id)kSecAttrAccessible:(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly};
    OSStatus result=SecItemUpdate((__bridge CFDictionaryRef)query,(__bridge CFDictionaryRef)attributes);
    if(result==errSecItemNotFound){NSMutableDictionary *item=[query mutableCopy];[item addEntriesFromDictionary:attributes];result=SecItemAdd((__bridge CFDictionaryRef)item,NULL);}
    if(result==errSecSuccess){OSStatus verification;NSData *saved=[self dataForAccount:account status:&verification];if(verification!=errSecSuccess || ![saved isEqual:data])return verification==errSecSuccess ? errSecDecode : verification;}
    return result;
}
+ (void)reportFailure:(OSStatus)status {
    if(status==errSecSuccess)return;
    NSLog(@"Credential storage unavailable (status %d)",(int)status);
    dispatch_async(dispatch_get_main_queue(),^{
        static NSTimeInterval lastNotice=-1000;
        NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;
        if(now-lastNotice<5)return;lastNotice=now;
        [NSNotificationCenter.defaultCenter postNotificationName:MUCredentialStorageDidFailNotification object:nil];
    });
}
@end
