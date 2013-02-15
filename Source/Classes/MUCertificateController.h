// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import <Foundation/Foundation.h>
#import <MumbleKit/MKCertificate.h>

@interface MUCertificateController : NSObject
+ (MKCertificate *) certificateWithPersistentRef:(NSData *)persistentRef;
+ (OSStatus) deleteCertificateWithPersistentRef:(NSData *)persistentRef;

+ (NSString *) fingerprintFromHexString:(NSString *)hexDigest;

+ (void) setDefaultCertificateByPersistentRef:(NSData *)persistentRef;
+ (MKCertificate *) defaultCertificate;

+ (NSArray *) persistentRefsForIdentities;
@end
