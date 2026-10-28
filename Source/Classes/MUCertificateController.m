// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUCertificateController.h"
#import "MLClient.h"

NSNotificationName const MUCertificatesDidChangeNotification = @"MUCertificatesDidChangeNotification";

@implementation MUCertificateController

// Retrieve a certificate by its persistent reference.
//
// If the value stored in the keychain is of type SecIdentityRef, the
// returned MLCertificate will include both the certificate and the
// private key of the returned identity.
//
// If the value stored in the keychain is of type SecCertificateRef,
// the returned MLCertificate will not include a private key.
+ (MLCertificate *) certificateWithPersistentRef:(NSData *)persistentRef {
    if (!persistentRef.length) return nil;
    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
                           persistentRef,      (__bridge id)kSecValuePersistentRef,
                           (__bridge id)kCFBooleanTrue,     (__bridge id)kSecReturnRef,
                           (__bridge id)kSecMatchLimitOne,  (__bridge id)kSecMatchLimit,
                           nil];
    CFTypeRef thing = NULL;
    MLCertificate *cert = nil;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &thing) == noErr && thing != NULL) {
        CFTypeID receivedType = CFGetTypeID(thing);
        if (receivedType == SecIdentityGetTypeID()) {
            SecIdentityRef identity = (SecIdentityRef) thing;
            SecCertificateRef secCert = NULL;
            if (SecIdentityCopyCertificate(identity, &secCert) == noErr) {
                NSData *secData = CFBridgingRelease(SecCertificateCopyData(secCert));
                SecKeyRef secKey = NULL;
                if (SecIdentityCopyPrivateKey(identity, &secKey) == noErr) {
                    CFTypeRef keyResult = NULL;
                    query = [NSDictionary dictionaryWithObjectsAndKeys:
                             (__bridge id)secKey, (__bridge id)kSecValueRef,
                             (__bridge id)kCFBooleanTrue,     (__bridge id)kSecReturnData,
                             (__bridge id)kSecMatchLimitOne,  (__bridge id)kSecMatchLimit,
                             nil];
                    OSStatus keyStatus = SecItemCopyMatching((__bridge CFDictionaryRef)query, &keyResult);
                    NSData *pkeyData = CFBridgingRelease(keyResult);
                    if (keyStatus == noErr) {
                        cert = [MLCertificate certificateWithCertificate:secData privateKey:pkeyData];
                    }
                    CFRelease(secKey);
                }

                CFRelease(secCert);
            }
        } else if (receivedType == SecCertificateGetTypeID()) {
            SecCertificateRef secCert = (SecCertificateRef) thing;
            NSData *secData = CFBridgingRelease(SecCertificateCopyData(secCert));
            cert = [MLCertificate certificateWithCertificate:secData privateKey:nil];

        } else {
            CFRelease(thing);
            return nil;
        }
    }
    if (thing) CFRelease(thing);
    return cert;
}

// Converts a hex string into a user-readable fingerprint.
+ (NSString *) fingerprintFromHexString:(NSString *)hexDigest {
    NSMutableString *fingerprint = [NSMutableString string];
    for (int i = 0; i < [hexDigest length]; i++) {
        if ((i % 2) == 0 && i > 0 && i < hexDigest.length-1) {
            [fingerprint appendString:@":"];
        }
        [fingerprint appendFormat:@"%C", [hexDigest characterAtIndex:i]];
    }
    return fingerprint;
}

// Delete the certificate referenced by the persistent reference persistentRef.
// todo(mkrautz): Don't leak OSStatus.
+ (OSStatus) deleteCertificateWithPersistentRef:(NSData *)persistentRef {
    // This goes against what the documentation says for this function, but Apple has stated that
    // this is the intended way to delete via a persistent ref through a rdar.
    NSDictionary *op = [NSDictionary dictionaryWithObjectsAndKeys:
                        persistentRef, (__bridge id)kSecValuePersistentRef,
                        nil];
    return SecItemDelete((__bridge CFDictionaryRef)op);
}

// Returns the certificate set as the default or 'active' certificate.
+ (MLCertificate *) defaultCertificate {
    NSData *persistentRef = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultCertificate"];
    return [MUCertificateController certificateWithPersistentRef:persistentRef];
}

// Set the default certificate by its persistent ref.
+ (void) setDefaultCertificateByPersistentRef:(NSData *)persistentRef {
    [[NSUserDefaults standardUserDefaults] setObject:persistentRef forKey:@"DefaultCertificate"];
}

+ (void)notifyCertificatesChanged {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self notifyCertificatesChanged]; });
        return;
    }
    [NSNotificationCenter.defaultCenter postNotificationName:MUCertificatesDidChangeNotification object:nil];
}

// Returns an array of the persistent refs of all SecIdentityRefs
// stored in the application's keychain.
+ (NSArray *) persistentRefsForIdentities {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassIdentity,
        (__bridge id)kSecReturnPersistentRef: (__bridge id)kCFBooleanTrue,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll
    };
    CFTypeRef result = NULL;
    OSStatus err = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    NSArray *array = CFBridgingRelease(result);
    if (err != noErr) {
        return nil;
    }

    return array;
}

@end
