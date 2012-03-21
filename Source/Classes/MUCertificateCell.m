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

#import "MUCertificateCell.h"
#import "MUColor.h"

@interface MUCertificateCell () {
    IBOutlet UIImageView  *_certImage;
    IBOutlet UILabel      *_nameLabel;
    IBOutlet UILabel      *_emailLabel;
    IBOutlet UILabel      *_issuerLabel;
    IBOutlet UILabel      *_expiryLabel;
    BOOL                  _isCurrentCert;
    BOOL                  _isIntermediate;
}
@end

@implementation MUCertificateCell

+ (MUCertificateCell *) loadFromNib {
    NSArray *array = [[NSBundle mainBundle] loadNibNamed:@"MUCertificateCell" owner:self options:nil];
    return [array objectAtIndex:0];
}

- (void) setSubjectName:(NSString *)name {
    _nameLabel.text = name;
}

- (void) setEmail:(NSString *)email {
    _emailLabel.text = email;
}

- (void) setIssuerText:(NSString *)issuerText {
    _issuerLabel.text = issuerText;
}

- (void) setExpiryText:(NSString *)expiryText {
    _expiryLabel.text = expiryText;
}

- (void) setIsIntermediate:(BOOL)isIntermediate {
    _isIntermediate = isIntermediate;
    if (_isIntermediate) {
        [_certImage setImage:[UIImage imageNamed:@"certificatecell-intermediate"]];
    } else {
        [_certImage setImage:[UIImage imageNamed:@"certificatecell"]];   
    }
}

- (BOOL) isIntermediate {
    return _isIntermediate;
}

- (void) setIsCurrentCertificate:(BOOL)isCurrent {
    _isCurrentCert = isCurrent;
    if (isCurrent) {
        [_certImage setImage:[UIImage imageNamed:@"certificatecell-selected"]];
        [_nameLabel setTextColor:[MUColor selectedTextColor]];
        [_emailLabel setTextColor:[MUColor selectedTextColor]];
    } else {
        if (_isIntermediate) {
            [_certImage setImage:[UIImage imageNamed:@"certificatecell-intermediate"]];
        } else {
            [_certImage setImage:[UIImage imageNamed:@"certificatecell"]];   
        }
        [_nameLabel setTextColor:[UIColor blackColor]];
        [_emailLabel setTextColor:[UIColor blackColor]];
    }
}

- (BOOL) isCurrentCertificate {
    return _isCurrentCert;
}

@end
