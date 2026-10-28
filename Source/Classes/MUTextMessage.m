// Copyright 2009-2012 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUTextMessage.h"

@interface MUTextMessage () {
}
- (id)initWithHeading:(NSString *)heading message:(NSString *)msg date:(NSDate *)date links:(NSArray *)links images:(NSArray *)images sentBySelf:(BOOL)sentBySelf;
@end

@implementation MUTextMessage
@synthesize embeddedImageSizes=_embeddedImageSizes;

- (id)initWithHeading:(NSString *)heading message:(NSString *)msg date:(NSDate *)date links:(NSArray *)links images:(NSArray *)images sentBySelf:(BOOL)sentBySelf {
    if ((self = [super init])) {
        _heading = heading;
        _msg = msg;
        _date = date;
        _self = sentBySelf;
        _links = links;
        _images = images;
        NSMutableArray *sizes=[NSMutableArray array];
        for(UIImage *image in images)[sizes addObject:[NSValue valueWithCGSize:image.size]];
        _embeddedImageSizes=sizes;
    }
    return self;
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
    return [_links count] + [_embeddedImageSizes count];
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
    return [[MUTextMessage alloc] initWithHeading:heading message:msg date:timestampDate links:links images:images sentBySelf:sentBySelf];
}

@end
