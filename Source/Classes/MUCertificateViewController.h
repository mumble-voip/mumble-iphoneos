// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

@class MLCertificate;

@interface MUCertificateViewController : UITableViewController

- (id) initWithPersistentRef:(NSData *)persistentRef;
- (id) initWithCertificate:(MLCertificate *)cert;
- (id) initWithCertificates:(NSArray *)certs;

- (void) showDataForCertificate:(MLCertificate *)cert;
- (void) updateCertificateDisplay;

@end
