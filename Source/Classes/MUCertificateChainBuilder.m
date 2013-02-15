// Copyright 2012 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUCertificateChainBuilder.h"
#include <MumbleKit/MKCertificate.h>

static NSArray *FindValidParentsForCert(SecCertificateRef cert);
static NSDictionary *GetAttrsForCert(SecCertificateRef cert);
static BOOL CertIsSelfSignedAndValid(SecCertificateRef cert);
static NSArray *BuildCertChainFromCert(SecCertificateRef cert);
static NSArray *BuildCertChainFromCertInternal(SecCertificateRef cert, BOOL *isFullChain);

// Finds any certificates in the valid parents of the `cert' certficiate.
// A valid parent is a parent that:
// 
//  1. Has signed the `cert' certificate's signature.
//  2. Is valid at the current system time.
//
// The function will search the app's own keychain, and all system keychains
// when looking for parents.
static NSArray *FindValidParentsForCert(SecCertificateRef cert) {
    NSDictionary *attrs = GetAttrsForCert(cert);
    NSData *issuer = [attrs objectForKey:(id)kSecAttrIssuer];
    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
                kSecClassCertificate, kSecClass,
                issuer,               kSecAttrSubject,
                kCFBooleanTrue,       kSecReturnAttributes,
                kCFBooleanTrue,       kSecReturnRef,
                kSecMatchLimitAll,    kSecMatchLimit,                        
            nil];
    NSArray *allAttrs = nil;
    OSStatus err = SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *) &allAttrs);
    if (err != noErr) {
        return nil;
    }

    NSMutableArray *validParents = [[NSMutableArray alloc] init];
    for (NSDictionary *parentAttr in allAttrs) {
        SecCertificateRef parentCertRef = (SecCertificateRef) [parentAttr objectForKey:(id)kSecValueRef];
        NSData *parentData = (NSData *) SecCertificateCopyData(parentCertRef);
        MKCertificate *parent = [MKCertificate certificateWithCertificate:parentData privateKey:nil];
        [parentData release];
        
        NSData *childData = (NSData *) SecCertificateCopyData(cert);
        MKCertificate *child = [MKCertificate certificateWithCertificate:childData privateKey:nil];
    
        if ([parent isValidOnDate:[NSDate date]] && [child isSignedBy:parent]) {
            [validParents addObject:(id)parentCertRef];
        }
    
        CFRelease(parentCertRef);
    }
    if ([validParents count] == 0) {
        return nil;
    }

    return [validParents autorelease];
}

// Extracts attributes from the `cert' certificate, along with a
// reference to the passed-in certificate.
//
// The certificate itself can be acquired by looking up the object
// with the kSecValueRef key.
static NSDictionary *GetAttrsForCert(SecCertificateRef cert) {
    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
                            (id)cert,          kSecValueRef,
                            kCFBooleanTrue,    kSecReturnRef,
                            kCFBooleanTrue,    kSecReturnAttributes,
                            kSecMatchLimitOne, kSecMatchLimit,
                           nil];
    NSDictionary *attrs = nil;
    OSStatus err = SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *) &attrs);
    if (err != noErr) {
        return nil;
    }
    return [attrs autorelease];
}

// Checks whether the `cert' certificate is self-signed and valid.
static BOOL CertIsSelfSignedAndValid(SecCertificateRef cert) {
    NSDictionary *attrs = GetAttrsForCert(cert);
    NSData *subject = [attrs objectForKey:(id)kSecAttrSubject];
    NSData *issuer = [attrs objectForKey:(id)kSecAttrIssuer]; 
    if ([subject isEqualToData:issuer]) {
        NSData *data = (NSData *) SecCertificateCopyData(cert);
        MKCertificate *selfSigned = [MKCertificate certificateWithCertificate:data privateKey:nil];
        [data release];
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
        SecCertificateRef parent = (SecCertificateRef) obj;

        BOOL isFull = NO;
        NSArray *allParents = BuildCertChainFromCertInternal(parent, &isFull);
        if (isFullChain)
            *isFullChain = isFull;

        // Is this a root certificate?
        if (isFull && allParents == nil) {
            return [NSArray arrayWithObject:(id)parent];
        // Or a regular intermediate?
        } else if (isFull && [allParents count] > 0) {
            NSMutableArray *parents = [[NSMutableArray alloc] init];
            [parents addObject:(id)parent];
            [parents addObjectsFromArray:allParents];
            return [parents autorelease];
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
    CFTypeRef thing = NULL;
    OSStatus err;

    NSMutableArray *chain = [[[NSMutableArray alloc] initWithCapacity:1] autorelease];

    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
                           persistentRef,      kSecValuePersistentRef,
                           kCFBooleanTrue,     kSecReturnRef,
                           kSecMatchLimitOne,  kSecMatchLimit,
                           nil];
    err = SecItemCopyMatching((CFDictionaryRef)query, &thing);
    if (err != noErr) {
        return nil;
    }

    CFTypeID typeID = CFGetTypeID(thing);
    if (typeID == SecIdentityGetTypeID()) {
        SecIdentityRef identity = (SecIdentityRef) thing;
        
        [chain addObject:(id)identity];
        CFRelease(identity);
        
        SecCertificateRef cert = NULL;
        SecIdentityCopyCertificate(identity, &cert);

        NSArray *firstValidChain = BuildCertChainFromCert(cert);
        [chain addObjectsFromArray:firstValidChain];

        CFRelease(cert);
    } else if (typeID == SecCertificateGetTypeID()) {
        SecCertificateRef cert = (SecCertificateRef) thing;
        [chain addObject:(id)cert];
        CFRelease(cert);

        NSArray *firstValidChain = BuildCertChainFromCert(cert);
        [chain addObjectsFromArray:firstValidChain];
    }

    return chain;
}

@end
