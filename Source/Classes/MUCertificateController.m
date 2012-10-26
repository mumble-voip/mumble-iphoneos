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
//
// If the value stored in the keychain is of type SecIdentityRef, the
// returned MKCertificate will include both the certificate and the
// private key of the returned identity.
//
// If the value stored in the keychain is of type SecCertificateRef,
// the returned MKCertificate will not include a private key.
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
                SecKeyRef secKey = NULL;
                if (SecIdentityCopyPrivateKey(identity, &secKey) == noErr) {
                    NSData *pkeyData = nil;
                    query = [NSDictionary dictionaryWithObjectsAndKeys:
                             (CFTypeRef) secKey, kSecValueRef,
                             kCFBooleanTrue,     kSecReturnData,
                             kSecMatchLimitOne,  kSecMatchLimit,
                             nil];
                    if (SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&pkeyData) == noErr) {
                        cert = [MKCertificate certificateWithCertificate:secData privateKey:pkeyData];
                        [pkeyData release];
                    }
                    CFRelease(secKey);
                }
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

// Returns an array of the persistent refs of all SecIdentityRefs
// stored in the application's keychain.
+ (NSArray *) persistentRefsForIdentities {
    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
                           kSecClassIdentity,    kSecClass,
                           kCFBooleanTrue,       kSecReturnPersistentRef,
                           kSecMatchLimitAll,    kSecMatchLimit,
                           nil];
    NSArray *array = nil;
    OSStatus err = SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&array);
    if (err != noErr) {
        [array release];
        return nil;
    }

    return [array autorelease];
}

@end
