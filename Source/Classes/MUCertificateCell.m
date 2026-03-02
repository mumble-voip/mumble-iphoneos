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
    UIImageView           *_checkBadge;
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

- (void) awakeFromNib {
    [super awakeFromNib];
    self.backgroundColor = [UIColor clearColor];
    self.contentView.backgroundColor = [UIColor clearColor];
    _nameLabel.textColor = [MUColor primaryTextColor];
    _emailLabel.textColor = [MUColor secondaryTextColor];
    _issuerLabel.textColor = [MUColor secondaryTextColor];
    _expiryLabel.textColor = [MUColor secondaryTextColor];
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

- (void) _ensureCheckBadge {
    if (_checkBadge != nil) return;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightBold];
        _checkBadge = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.circle.fill" withConfiguration:config]];
        _checkBadge.tintColor = [UIColor systemGreenColor];
        _checkBadge.backgroundColor = [UIColor whiteColor];
        _checkBadge.layer.cornerRadius = 12;
        _checkBadge.clipsToBounds = YES;
        _checkBadge.frame = CGRectMake(44, 44, 24, 24);
        [_certImage.superview addSubview:_checkBadge];
    }
}

- (void) setIsCurrentCertificate:(BOOL)isCurrent {
    _isCurrentCert = isCurrent;
    if (isCurrent) {
        [_certImage setImage:[UIImage imageNamed:@"certificatecell-selected"]];
        [_nameLabel setTextColor:[UIColor systemBlueColor]];
        [_emailLabel setTextColor:[UIColor systemBlueColor]];
        [self _ensureCheckBadge];
        _checkBadge.hidden = NO;
    } else {
        if (_isIntermediate) {
            [_certImage setImage:[UIImage imageNamed:@"certificatecell-intermediate"]];
        } else {
            [_certImage setImage:[UIImage imageNamed:@"certificatecell"]];   
        }
        [_nameLabel setTextColor:[MUColor primaryTextColor]];
        [_emailLabel setTextColor:[MUColor secondaryTextColor]];
        _checkBadge.hidden = YES;
    }
}

- (BOOL) isCurrentCertificate {
    return _isCurrentCert;
}

@end
