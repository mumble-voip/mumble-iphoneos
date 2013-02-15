// Copyright 2009-2012 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

@interface MUTextMessage : NSObject {
    NSString  *_heading;
    NSString  *_msg;
    NSDate    *_date;
    NSArray   *_links;
    NSArray   *_images;
    BOOL      _self;
}
+ (MUTextMessage *) textMessageWithHeading:(NSString *)heading
                                andMessage:(NSString *)msg
                          andEmbeddedLinks:(NSArray *)links
                         andEmbeddedImages:(NSArray *)images
                          andTimestampDate:(NSDate *)timestampDate
                              isSentBySelf:(BOOL)sentBySelf;
- (NSString *) heading;
- (NSString *) message;
- (NSDate *) date;
- (NSArray *) embeddedLinks;
- (NSArray *) embeddedImages;
- (NSInteger) numberOfAttachments;
- (BOOL) hasAttachments;
- (BOOL) isSentBySelf;
@end
