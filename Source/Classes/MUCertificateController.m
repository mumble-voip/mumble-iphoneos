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

#import "MUCertificateController.h"
#import <MumbleKit/MKCertificate.h>

@implementation MUCertificateController

// Retrieve a certificate by its persistent reference.
+ (MKCertificate *) certificateWithPersistentRef:(NSData *)persistentRef {
    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
                           persistentRef,      kSecValuePersistentRef,
                           kCFBooleanTrue,     kSecReturnRef,
                           kSecMatchLimitOne,  kSecMatchLimit,
                           nil];
    CFTypeRef thing = NULL;
    MKCertificate *cert = nil;
    if (SecItemCopyMatching((CFDictionaryRef)query, &thing) == noErr && thing != NULL) {
        CFTypeID receivedType = CFGetTypeID(thing);
        if (receivedType == SecIdentityGetTypeID()) {
            SecIdentityRef identity = (SecIdentityRef) thing;
            SecCertificateRef secCert = NULL;
            if (SecIdentityCopyCertificate(identity, &secCert) == noErr) {
                NSData *secData = (NSData *)SecCertificateCopyData(secCert);
                cert = [MKCertificate certificateWithCertificate:secData privateKey:nil];
                [secData release];
            }
        } else if (receivedType == SecCertificateGetTypeID()) {
            SecCertificateRef secCert = (SecCertificateRef) thing;
            NSData *secData = (NSData *)SecCertificateCopyData(secCert);
            cert = [MKCertificate certificateWithCertificate:secData privateKey:nil];
            [secData release];
        } else {
            return nil;
        }
    }
    return cert;
}

// Retrieve a certificate by its persistent reference.
+ (MKCertificate *) certificateAndPrivateKeyWithPersistentRef:(NSData *)persistentRef {
    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
                           persistentRef,      kSecValuePersistentRef,
                           kCFBooleanTrue,     kSecReturnRef,
                           kSecMatchLimitOne,  kSecMatchLimit,
                           nil];
    CFTypeRef thing = NULL;
    MKCertificate *cert = nil;
    if (SecItemCopyMatching((CFDictionaryRef)query, &thing) == noErr && thing != NULL) {
        // Only identities can have private keys.
        if (CFGetTypeID(thing) != SecIdentityGetTypeID())
            return nil;
        SecCertificateRef secCert;
        if (SecIdentityCopyCertificate((SecIdentityRef) thing, &secCert) == noErr) {
            SecKeyRef secKey;
            if (SecIdentityCopyPrivateKey((SecIdentityRef) thing, &secKey) == noErr) {
                NSData *certData = (NSData *)SecCertificateCopyData(secCert);
                NSData *pkeyData = nil;
                query = [NSDictionary dictionaryWithObjectsAndKeys:
                         (CFTypeRef) secKey, kSecValueRef,
                         kCFBooleanTrue,     kSecReturnData,
                         kSecMatchLimitOne,  kSecMatchLimit,
                         nil];
                if (SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&pkeyData) == noErr) {
                    cert = [MKCertificate certificateWithCertificate:certData privateKey:pkeyData];
                    [pkeyData release];
                }
                [certData release];                
            }
        }
    }
    return cert;
}

// Delete the certificate referenced by the persistent reference persistentRef.
// todo(mkrautz): Don't leak OSStatus.
+ (OSStatus) deleteCertificateWithPersistentRef:(NSData *)persistentRef {
    // This goes against what the documentation says for this function, but Apple has stated that
    // this is the intended way to delete via a persistent ref through a rdar.
    NSDictionary *op = [NSDictionary dictionaryWithObjectsAndKeys:
                        persistentRef, kSecValuePersistentRef,
                        nil];
    return SecItemDelete((CFDictionaryRef)op);
}

// Returns the certificate set as the default or 'active' certificate.
+ (MKCertificate *) defaultCertificate {
    NSData *persistentRef = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultCertificate"];
    return [MUCertificateController certificateWithPersistentRef:persistentRef];
}

// Set the default certificate by its persistent ref.
+ (void) setDefaultCertificateByPersistentRef:(NSData *)persistentRef {
    [[NSUserDefaults standardUserDefaults] setObject:persistentRef forKey:@"DefaultCertificate"];
}

// Returns an NSArray of SecIdentityRefs.
+ (NSArray *) rawCertificates {
    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
                           kSecClassIdentity,    kSecClass,
                           kCFBooleanTrue,       kSecReturnPersistentRef,
                           kSecMatchLimitAll,    kSecMatchLimit,
                           nil];
    NSArray *certs = nil;
    SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&certs);
    return [certs autorelease];
}

+ (NSArray *) allPersistentRefs {
    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
                           kSecClassIdentity,    kSecClass,
                           kCFBooleanTrue,       kSecReturnPersistentRef,
                           kSecMatchLimitAll,    kSecMatchLimit,
                           nil];
    NSArray *array = nil;
    OSStatus err = SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&array);
    if (err != noErr || array == nil) {
        [array release];
        return nil;
    }

    return [array autorelease];
}

// Attempts to build a certificate chain from the SecIdentityRef identified by persistentRef.
// If trust can be established for the chain, the whole trusted chain is returned. If not,
// an array with only the leaf inside it is returned.
+ (NSArray *) buildChainFromPersistentRef:(NSData *)persistentRef {
    CFTypeRef thing = NULL;
    SecIdentityRef leafIdentity = NULL;
    SecCertificateRef leaf = NULL;
    OSStatus err;
    
    NSMutableArray *chain = [[[NSMutableArray alloc] initWithCapacity:1] autorelease];
    
    // First, look up the SecCertificateRef for the leaf certificate's
    // persistent reference.
    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
                           persistentRef,      kSecValuePersistentRef,
                           kCFBooleanTrue,     kSecReturnRef,
                           kSecMatchLimitOne,  kSecMatchLimit,
                           nil];
    err = SecItemCopyMatching((CFDictionaryRef)query, &thing);
    if (err == noErr) {
        if (thing == NULL || CFGetTypeID(thing) != SecIdentityGetTypeID()) {
            if (thing != NULL)
                CFRelease(thing);
            return nil;
        }
        leafIdentity = (SecIdentityRef) thing;
    }

    // Add the leafIdentity to our chain array, and release it.
    [chain addObject:(id)leafIdentity];
    CFRelease(leafIdentity);

    // Look up all other certificates in our keychain
    NSArray *otherCerts = nil;
    query = [NSDictionary dictionaryWithObjectsAndKeys:
             kSecClassCertificate,   kSecClass,
             kCFBooleanTrue,         kSecReturnRef,
             kSecMatchLimitAll,      kSecMatchLimit,
             nil];

    err = SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&otherCerts);
    if (err == noErr && otherCerts != nil) {
        NSMutableArray *certificates = [[NSMutableArray alloc] initWithObjects:(id)leaf, nil];
        [certificates addObjectsFromArray:otherCerts];
        [certificates autorelease];
        
        SecPolicyRef policy = SecPolicyCreateBasicX509();
        SecTrustRef trust = NULL;
        if (SecTrustCreateWithCertificates(certificates, policy, &trust) == noErr && trust != NULL) {
            SecTrustResultType result;
            err = SecTrustEvaluate(trust, &result);
            if (err == noErr) {
                switch (result) {
                    case kSecTrustResultProceed:
                    case kSecTrustResultUnspecified: // System trusts it.
                    {
                        int ncerts = SecTrustGetCertificateCount(trust);
                        for (int i = 0; i < ncerts; i++) {
                            SecCertificateRef cert = SecTrustGetCertificateAtIndex(trust, i);
                            [chain addObject:(id)cert];
                        }
                    }
                }
            }
            CFRelease(trust);
        }
        [otherCerts release];
    }

    return chain;
}

@end
