// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import <MumbleKit/MKConnection.h>
#import <MumbleKit/MKCertificate.h>

#import "MUServerCertificateTrustViewController.h"
#import "MUDatabase.h"

@interface MUServerCertificateTrustViewController () {
    NSArray                                             *_certChain;
    id<MUServerCertificateTrustViewControllerProtocol>  _delegate;
}
@end

// This is the modal view controller that's shown to the user
// when iOS doesn't trsut the certificate chain of the server,
// and the user picks "Show Certificates"

@implementation MUServerCertificateTrustViewController

- (void) setDelegate:(id<MUServerCertificateTrustViewControllerProtocol>)delegate {
    _delegate = delegate;
}

- (id<MUServerCertificateTrustViewControllerProtocol>) delegate {
    return _delegate;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    UIBarButtonItem *dismissButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Dismiss", nil)
                                                                      style:UIBarButtonItemStyleBordered
                                                                     target:self
                                                                     action:@selector(dismissClicked:)];
    self.navigationItem.leftBarButtonItem = dismissButton;
    [dismissButton release];
}

#pragma mark -
#pragma mark Actions

- (void) dismissClicked:(id)sender {
    [self dismissModalViewControllerAnimated:YES];
    [_delegate serverCertificateTrustViewControllerDidDismiss:self];
}

@end
