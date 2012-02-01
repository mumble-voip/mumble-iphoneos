/* Copyright (C) 2009-2012 Mikkel Krautz <mikkel@krautz.dk>

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
