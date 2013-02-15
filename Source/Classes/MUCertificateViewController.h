// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

@class MKCertificate;

@interface MUCertificateViewController : UITableViewController

- (id) initWithPersistentRef:(NSData *)persistentRef;
- (id) initWithCertificate:(MKCertificate *)cert;
- (id) initWithCertificates:(NSArray *)certs;
- (void) dealloc;

- (void) showDataForCertificate:(MKCertificate *)cert;
- (void) updateCertificateDisplay;

@end
