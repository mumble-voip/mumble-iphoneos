// Copyright 2012 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUCertificateChainBuilder.h"
#include "MLClient.h"

static NSArray *FindValidParentsForCert(SecCertificateRef cert);
static NSDictionary *GetAttrsForCert(SecCertificateRef cert);
static BOOL CertIsSelfSignedAndValid(SecCertificateRef cert);
static NSArray *BuildCertChainFromCert(SecCertificateRef cert);
static NSArray *BuildCertChainFromCertInternal(SecCertificateRef cert, BOOL *isFullChain);

// Finds any certificates in the valid parents of the `cert' certificate.
// A valid parent is a parent that:
//
//  1. Has signed the `cert' certificate's signature.
//  2. Is valid at the current system time.
//
// The function will search the app's own keychain, and all system keychains
// when looking for parents.
static NSArray *FindValidParentsForCert(SecCertificateRef cert) {
    NSDictionary *attrs = GetAttrsForCert(cert);
    NSData *issuer = [attrs objectForKey:(__bridge id)kSecAttrIssuer];
    if (!issuer) return nil;
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassCertificate,
        (__bridge id)kSecAttrSubject: issuer,
        (__bridge id)kSecReturnAttributes: (__bridge id)kCFBooleanTrue,
        (__bridge id)kSecReturnRef: (__bridge id)kCFBooleanTrue,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll
    };
    CFTypeRef result = NULL;
    OSStatus err = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    NSArray *allAttrs = CFBridgingRelease(result);
    if (err != noErr) {
        return nil;
    }

    NSMutableArray *validParents = [[NSMutableArray alloc] init];
    for (NSDictionary *parentAttr in allAttrs) {
        id parentCertificate = [parentAttr objectForKey:(__bridge id)kSecValueRef];

        NSData *parentData = CFBridgingRelease(SecCertificateCopyData((__bridge SecCertificateRef)parentCertificate));
        MLCertificate *parent = [MLCertificate certificateWithCertificate:parentData privateKey:nil];

        NSData *childData = CFBridgingRelease(SecCertificateCopyData(cert));
        MLCertificate *child = [MLCertificate certificateWithCertificate:childData privateKey:nil];

        if ([parent isValidOnDate:[NSDate date]] && [child isSignedBy:parent]) {
            [validParents addObject:parentCertificate];
        }
    }
    if ([validParents count] == 0) {
        return nil;
    }

    return validParents;
}

// Extracts attributes from the `cert' certificate, along with a
// reference to the passed-in certificate.
//
// The certificate itself can be acquired by looking up the object
// with the kSecValueRef key.
static NSDictionary *GetAttrsForCert(SecCertificateRef cert) {
    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
                            (__bridge id)cert,          (__bridge id)kSecValueRef,
                            (__bridge id)kCFBooleanTrue,    (__bridge id)kSecReturnRef,
                            (__bridge id)kCFBooleanTrue,    (__bridge id)kSecReturnAttributes,
                            (__bridge id)kSecMatchLimitOne, (__bridge id)kSecMatchLimit,
                           nil];
    CFTypeRef result = NULL;
    OSStatus err = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    NSDictionary *attrs = CFBridgingRelease(result);
    if (err != noErr) {
        return nil;
    }
    return attrs;
}

// Checks whether the `cert' certificate is self-signed and valid.
static BOOL CertIsSelfSignedAndValid(SecCertificateRef cert) {
    NSDictionary *attrs = GetAttrsForCert(cert);
    NSData *subject = [attrs objectForKey:(__bridge id)kSecAttrSubject];
    NSData *issuer = [attrs objectForKey:(__bridge id)kSecAttrIssuer];
    if ([subject isEqualToData:issuer]) {
        NSData *data = CFBridgingRelease(SecCertificateCopyData(cert));
        MLCertificate *selfSigned = [MLCertificate certificateWithCertificate:data privateKey:nil];

        if ([selfSigned isValidOnDate:[NSDate date]] && [selfSigned isSignedBy:selfSigned]) {
            return YES;
        }
    }
    return NO;
}

// BuildCertChainFromCert attempts to build a full certificate chain
// starting from `cert'.
static NSArray *BuildCertChainFromCert(SecCertificateRef cert) {
    return BuildCertChainFromCertInternal(cert, NULL);
}

// BuildCertChainFromCertInternal is an internal helper function for recursively
// finding a valid certificate chain starting from `cert'.
//
// The function will recurse until a full chain is found, or no full chain was
// available to be built. (In both cases, the BuildCertChainFromCertInternal
// function returns a nil NSArray to signal to the caller that further chain
// construction is impossible.)
//
// If a full chain is found, the `isFullChain' parameter will be set to YES, and
// the function will return nil as described above.
//
// Once a full chain has been found, all recursive invocations of the function will
// return a certificate chain starting at whichever certificate they were invoked
// with, resulting in a full certificate chain being available in the outermost
// invocation.
static NSArray *BuildCertChainFromCertInternal(SecCertificateRef cert, BOOL *isFullChain) {
    // When we reach a root certificate, return nil and set isFullChain = YES.
    if (CertIsSelfSignedAndValid(cert)) {
        if (isFullChain)
            *isFullChain = YES;
        return nil;
    } else {
        if (isFullChain)
            *isFullChain = NO;
    }

    NSArray *parents = FindValidParentsForCert(cert);
    for (id obj in parents) {
        SecCertificateRef parent = (__bridge SecCertificateRef)obj;

        BOOL isFull = NO;
        NSArray *allParents = BuildCertChainFromCertInternal(parent, &isFull);
        if (isFullChain)
            *isFullChain = isFull;

        // Is this a root certificate?
        if (isFull && allParents == nil) {
            return [NSArray arrayWithObject:(__bridge id)parent];
        // Or a regular intermediate?
        } else if (isFull && [allParents count] > 0) {
            NSMutableArray *parents = [[NSMutableArray alloc] init];
            [parents addObject:(__bridge id)parent];
            [parents addObjectsFromArray:allParents];
            return parents;
        }
    }

    return nil;
}

@implementation MUCertificateChainBuilder

// Attempts to build a valid certificate chain from the SecIdentityRef
// or SecCertificateRef identified by persistentRef.
//
// The first item in the returned array will be the item identitied by
// persistentRef (either a SecIdentityRef or a SecCertificateRef).
+ (NSArray *) buildChainFromPersistentRef:(NSData *)persistentRef {
    if (!persistentRef.length) return nil;
    CFTypeRef thing = NULL;
    OSStatus err;

    NSMutableArray *chain = [[NSMutableArray alloc] initWithCapacity:1];

    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
                           persistentRef,      (__bridge id)kSecValuePersistentRef,
                           (__bridge id)kCFBooleanTrue,     (__bridge id)kSecReturnRef,
                           (__bridge id)kSecMatchLimitOne,  (__bridge id)kSecMatchLimit,
                           nil];
    err = SecItemCopyMatching((__bridge CFDictionaryRef)query, &thing);
    if (err != noErr) {
        return nil;
    }

    CFTypeID typeID = CFGetTypeID(thing);
    if (typeID == SecIdentityGetTypeID()) {
        SecIdentityRef identity = (SecIdentityRef) thing;

        [chain addObject:(__bridge id)identity];

        SecCertificateRef cert = NULL;
        if (SecIdentityCopyCertificate(identity, &cert) == errSecSuccess && cert) {
            NSArray *firstValidChain = BuildCertChainFromCert(cert);
            if (firstValidChain.count) [chain addObjectsFromArray:firstValidChain];
            CFRelease(cert);
        }
    } else if (typeID == SecCertificateGetTypeID()) {
        SecCertificateRef cert = (SecCertificateRef) thing;
        [chain addObject:(__bridge id)cert];

        NSArray *firstValidChain = BuildCertChainFromCert(cert);
        if (firstValidChain.count) [chain addObjectsFromArray:firstValidChain];
    }

    CFRelease(thing);
    return chain;
}

@end
