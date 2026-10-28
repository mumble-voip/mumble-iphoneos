// Use of this source code is governed by the BSD-style license in LICENSE.
#import "MUCertificateCell.h"

@interface MUCertificateCell () {
    NSString *_subject, *_email, *_issuer, *_expiry;
    BOOL _isCurrentCert, _isExpired, _isIntermediate;
}
@end

@implementation MUCertificateCell
+ (MUCertificateCell *)certificateCell {
    return [[self alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"CertificateCell"];
}
- (void)updateContent {
    UIListContentConfiguration *content = [UIListContentConfiguration subtitleCellConfiguration];
    content.text = _subject.length ? _subject : NSLocalizedString(@"Certificate", nil);
    content.textProperties.numberOfLines = 0;
    NSMutableArray *details = [NSMutableArray array];
    for (NSString *value in @[_email ?: @"", _issuer ?: @"", _expiry ?: @""])
        if (value.length) [details addObject:value];
    if (_isCurrentCert) [details insertObject:NSLocalizedString(@"Current Certificate", nil) atIndex:0];
    content.secondaryText = [details componentsJoinedByString:@"\n"];
    content.secondaryTextProperties.numberOfLines = 0;
    content.secondaryTextProperties.color = _isExpired ? UIColor.systemRedColor : UIColor.secondaryLabelColor;
    content.image = [UIImage systemImageNamed:_isCurrentCert ? @"checkmark.seal.fill" : (_isIntermediate ? @"doc.on.doc" : @"checkmark.seal")];
    content.imageProperties.tintColor = _isCurrentCert ? UIColor.systemBlueColor : UIColor.secondaryLabelColor;
    content.imageProperties.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:24 weight:UIImageSymbolWeightRegular];
    content.imageProperties.reservedLayoutSize = CGSizeMake(32, 32);
    self.contentConfiguration = content;
}
- (void)setSubjectName:(NSString *)value { _subject = [value copy]; [self updateContent]; }
- (void)setEmail:(NSString *)value { _email = [value copy]; [self updateContent]; }
- (void)setIssuerText:(NSString *)value { _issuer = [value copy]; [self updateContent]; }
- (void)setExpiryText:(NSString *)value { _expiry = [value copy]; [self updateContent]; }
- (void)setIsIntermediate:(BOOL)value { _isIntermediate = value; [self updateContent]; }
- (BOOL)isIntermediate { return _isIntermediate; }
- (void)setIsExpired:(BOOL)value { _isExpired = value; [self updateContent]; }
- (BOOL)isExpired { return _isExpired; }
- (void)setIsCurrentCertificate:(BOOL)value { _isCurrentCert = value; [self updateContent]; }
- (BOOL)isCurrentCertificate { return _isCurrentCert; }
@end
