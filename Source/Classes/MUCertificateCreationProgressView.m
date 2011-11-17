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

#import "MUCertificateCreationProgressView.h"

@interface MUCertificateCreationProgressView () {
    IBOutlet UIActivityIndicatorView  *_activityIndicator;
    IBOutlet UILabel                  *_nameLabel;
    IBOutlet UILabel                  *_emailLabel;
    
    NSString                          *_identityName;
    NSString                          *_emailAddress;
    id                                _delegate;
}
@end

@implementation MUCertificateCreationProgressView

- (id) initWithName:(NSString *)name email:(NSString *)email {
    if (self = [super initWithNibName:@"MUCertificateCreationProgressView" bundle:nil]) {
        _identityName = [name retain];
        _emailAddress = [email retain];
        NSLog(@"name = %@, email = %@", _identityName, _emailAddress);
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            [self.view setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
        }
    }
    return self;
}

- (void) dealloc {
    [_identityName release];
    [_emailAddress release];
    [super dealloc];
}

- (void) viewWillAppear:(BOOL)animated {
    [[self navigationItem] setTitle:@"Generating Certificate"];
    [[self navigationItem] setHidesBackButton:YES];

    [_nameLabel    setText:_identityName];

    if (_emailAddress != nil && _emailAddress.length > 0) {
        [_emailLabel setText:[NSString stringWithFormat:@"<%@>", _emailAddress]];
    } else {
        [_emailLabel setText:nil];
    }

    [_activityIndicator startAnimating];
}

@end
