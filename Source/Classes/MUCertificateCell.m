// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUCertificateCell.h"
#import "MUColor.h"

@interface MUCertificateCell () {
    IBOutlet UIImageView  *_certImage;
    IBOutlet UILabel      *_nameLabel;
    IBOutlet UILabel      *_emailLabel;
    IBOutlet UILabel      *_issuerLabel;
    IBOutlet UILabel      *_expiryLabel;
    BOOL                  _isCurrentCert;
    BOOL                  _isExpired;
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

- (void) setIsExpired:(BOOL)isExpired {
    _isExpired = isExpired;
    _expiryLabel.textColor = [UIColor redColor];
}

- (BOOL) isExpired {
    return _isExpired;
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
