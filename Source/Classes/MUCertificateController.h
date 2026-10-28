// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

@import Foundation;
#import "MLClient.h"

FOUNDATION_EXPORT NSNotificationName const MUCertificatesDidChangeNotification;

@interface MUCertificateController : NSObject
+ (MLCertificate *) certificateWithPersistentRef:(NSData *)persistentRef;
+ (OSStatus) deleteCertificateWithPersistentRef:(NSData *)persistentRef;

+ (NSString *) fingerprintFromHexString:(NSString *)hexDigest;

+ (void) setDefaultCertificateByPersistentRef:(NSData *)persistentRef;
+ (MLCertificate *) defaultCertificate;

+ (NSArray *) persistentRefsForIdentities;
+ (void)notifyCertificatesChanged;
@end
