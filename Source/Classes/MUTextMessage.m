// Copyright 2009-2012 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUTextMessage.h"

@interface MUTextMessage () {
}
- (id) initWithHeading:(NSString *)heading andMessage:(NSString *)msg andDate:(NSDate *)date andEmbeddedLinks:(NSArray *)links andEmbeddedImages:(NSArray *)images andTimestampDate:(NSDate *)date andSentBySelf:(BOOL)sentBySelf;
@end

@implementation MUTextMessage

- (id) initWithHeading:(NSString *)heading andMessage:(NSString *)msg andDate:(NSDate *)date andEmbeddedLinks:(NSArray *)links andEmbeddedImages:(NSArray *)images andTimestampDate:(NSDate *)timestampDate andSentBySelf:(BOOL)sentBySelf {
    if ((self = [super init])) {
        _heading = [heading retain];
        _msg = [msg retain];
        _date = [date retain];
        _self = sentBySelf;
        _links = [links retain];
        _images = [images retain];
    }
    return self;
}

- (void) dealloc {
    [_heading release];
    [_msg release];
    [_date release];
    [super dealloc];
}

- (NSString *) heading {
    return _heading;
}

- (NSString *) message {
    return _msg;
}

- (NSDate *) date {
    return _date;
}

- (NSInteger) numberOfAttachments {
    return [_links count] + [_images count];
}

- (BOOL) hasAttachments {
    return [self numberOfAttachments] > 0;
}

- (NSArray *) embeddedLinks {
    return _links;
}

- (NSArray *) embeddedImages {
    return _images;
}

- (BOOL) isSentBySelf {
    return _self;
}

+ (MUTextMessage *) textMessageWithHeading:(NSString *)heading andMessage:(NSString *)msg andEmbeddedLinks:(NSArray *)links andEmbeddedImages:(NSArray *)images andTimestampDate:(NSDate *)timestampDate isSentBySelf:(BOOL)sentBySelf {
    return [[[MUTextMessage alloc] initWithHeading:heading andMessage:msg andDate:[NSDate date] andEmbeddedLinks:links andEmbeddedImages:images  andTimestampDate:timestampDate andSentBySelf:sentBySelf] autorelease];
}

@end
