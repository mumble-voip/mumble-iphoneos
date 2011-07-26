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

#import <MumbleKit/MKConnection.h>
#import <MumbleKit/MKCertificate.h>

#import "MUServerCertificateTrustViewController.h"
#import "MUDatabase.h"

// This is the modal view controller that's shown to the user
// when iOS doesn't trsut the certificate chain of the server,
// and the user picks "Show Certificates"

@implementation MUServerCertificateTrustViewController

- (id) initWithConnection:(MKConnection *)conn {
	NSArray *peerCerts = [conn peerCertificates];
	if (self = [super initWithCertificates:[conn peerCertificates]]) {
		_conn = conn;
	}
	return self;
}

- (void) dealloc {
	[super dealloc];
}

- (void) viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];

	UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelClicked:)];
	self.navigationItem.leftBarButtonItem = cancelButton;
	[cancelButton release];

	UIBarButtonItem *ignoreButton = [[UIBarButtonItem alloc] initWithTitle:@"Ignore" style:UIBarButtonItemStyleBordered target:self action:@selector(ignoreClicked:)];
	UIBarButtonItem *trustButton = [[UIBarButtonItem alloc] initWithTitle:@"Trust" style:UIBarButtonItemStyleDone target:self action:@selector(trustClicked:)];
	UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	[self setToolbarItems:[NSArray arrayWithObjects:ignoreButton, flexSpace, trustButton, nil]];
	[self.navigationController setToolbarHidden:NO animated:YES];
	[trustButton release];
	[ignoreButton release];
	[flexSpace release];
}

#pragma mark -
#pragma mark Actions

- (void) cancelClicked:(id)sender {
	[_conn disconnect];
	[self dismissModalViewControllerAnimated:YES];
}

- (void) ignoreClicked:(id)sender {
	[_conn setIgnoreSSLVerification:YES];
	[_conn reconnect];
	[self dismissModalViewControllerAnimated:YES];
}

- (void) trustClicked:(id)sender {
	NSString *digest = [[[_conn peerCertificates] objectAtIndex:0] hexDigest];
	[MUDatabase storeDigest:digest forServerWithHostname:[_conn hostname] port:[_conn port]];
	[_conn setIgnoreSSLVerification:YES];
	[_conn reconnect];
	[self dismissModalViewControllerAnimated:YES];
}

@end
