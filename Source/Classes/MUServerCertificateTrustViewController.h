// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUCertificateViewController.h"

@class MKConnection;
@class MUServerCertificateTrustViewController;

@protocol MUServerCertificateTrustViewControllerProtocol
- (void) serverCertificateTrustViewControllerDidDismiss:(MUServerCertificateTrustViewController *)trustView;
@end

@interface MUServerCertificateTrustViewController : MUCertificateViewController
- (id<MUServerCertificateTrustViewControllerProtocol>) delegate;
- (void) setDelegate:(id<MUServerCertificateTrustViewControllerProtocol>)delegate;
@end
