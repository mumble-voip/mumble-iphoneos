// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

@interface MUCertificateCell : UITableViewCell

+ (MUCertificateCell *) loadFromNib;

- (void) setSubjectName:(NSString *)name;
- (void) setEmail:(NSString *)email;
- (void) setIssuerText:(NSString *)issuerText;
- (void) setExpiryText:(NSString *)expiryText;

- (BOOL) isIntermediate;
- (void) setIsIntermediate:(BOOL)isIntermediate;

- (BOOL) isExpired;
- (void) setIsExpired:(BOOL)isExpired;

- (BOOL) isCurrentCertificate;
- (void) setIsCurrentCertificate:(BOOL)isSelected;

@end
