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

#import "MUMessagesDatabase.h"
#import "MUTextMessage.h"
#import "MUDataURL.h"

#import <MumbleKit/MKTextMessage.h>

#import <FMDatabase.h>

@interface MUMessagesDatabase () {
    NSCache    *_msgCache;
    FMDatabase *_db;
    NSInteger  _count;
}
@end

@implementation MUMessagesDatabase

- (id) init {
    if ((self = [super init])) {
        NSFileManager *manager = [NSFileManager defaultManager];
        NSString *directory = NSTemporaryDirectory();
        NSString *dbPath = [directory stringByAppendingPathComponent:@"msg.db"];
        [manager removeItemAtPath:dbPath error:nil];
        _db = [[FMDatabase alloc] initWithPath:dbPath];
        if (![_db open]) {
            NSLog(@"MUMessagesDatabse: Failed to open.");
        }
        
        [_db executeUpdate:@"CREATE TABLE IF NOT EXISTS `msg` "
                           @"(`id` INTEGER PRIMARY KEY AUTOINCREMENT,"
                           @" `rendered` BLOB,"
                           @" `plist` BLOB)"];
        
        _msgCache = [[NSCache alloc] init];
        [_msgCache setCountLimit:10];
    }
    return self;
}

- (void) dealloc {
    [_msgCache release];
    [_db release];
    [super dealloc];
}

- (void) addMessage:(MKTextMessage *)msg withHeading:(NSString *)heading andSentBySelf:(BOOL)selfSent {
    NSError *err = nil;
    NSString *plainMsg = [msg plainTextString];
    plainMsg = [plainMsg stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSMutableArray *imageDataArray = [[[NSMutableArray alloc] initWithCapacity:[[msg embeddedImages] count]] autorelease];
    for (NSString *dataUrl in [msg embeddedImages]) {
        [imageDataArray addObject:[MUDataURL dataFromDataURL:dataUrl]];
    }
    
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                                heading, @"heading",
                                plainMsg, @"msg",
                                [NSDate date], @"date",
                                [msg embeddedLinks], @"links",
                                imageDataArray, @"images",
                                [NSNumber numberWithBool:selfSent], @"selfsent",
                          nil];
    NSData *plist = [NSPropertyListSerialization dataWithPropertyList:dict format:NSPropertyListBinaryFormat_v1_0 options:0 error:&err];
    [_db executeUpdate:@"INSERT INTO `msg` (`rendered`, `plist`) VALUES (?,?)", [NSNull null], plist ? plist : [NSNull null]];
    _count++;
}

- (void) clearMessageAtIndex:(NSInteger)row {
    [_db executeUpdate:@"UPDATE `msg` SET `plist`=NULL, `rendered`=NULL WHERE `id`=?", [NSNumber numberWithInteger:row+1]];
    [_msgCache removeObjectForKey:[NSNumber numberWithInteger:row+1]];
}

- (MUTextMessage *) messageAtIndex:(NSInteger)row {
    MUTextMessage *txtMsg = [_msgCache objectForKey:[NSNumber numberWithInteger:row+1]];
    if (txtMsg != nil)
        return txtMsg;
    
    FMResultSet *result = [_db executeQuery:@"SELECT `plist` FROM `msg` WHERE `id` = ?", [NSNumber numberWithInteger:row+1]];
    if ([result next]) {
        NSData *plistData = [result dataForColumnIndex:0];
        if (plistData) {
            NSDictionary *dict = [NSPropertyListSerialization propertyListWithData:plistData options:0 format:nil error:nil];
            if (dict) {
                NSArray *imgDataArray = [dict objectForKey:@"images"];
                NSMutableArray *imagesArray = [[[NSMutableArray alloc] initWithCapacity:[imgDataArray count]] autorelease];
                for (NSData *data in imgDataArray) {
                    [imagesArray addObject:[UIImage imageWithData:data]];
                }
                txtMsg = [MUTextMessage textMessageWithHeading:[dict objectForKey:@"heading"]
                                                    andMessage:[dict objectForKey:@"msg"]
                                              andEmbeddedLinks:[dict objectForKey:@"links"]
                                             andEmbeddedImages:imagesArray
                                              andTimestampDate:[dict objectForKey:@"date"]
                                                  isSentBySelf:[[dict objectForKey:@"selfsent"] boolValue]];
                [_msgCache setObject:txtMsg forKey:[NSNumber numberWithInteger:row+1]];
                return txtMsg;
            }
        }
    }
    return nil;
}

- (NSInteger) count {
    return _count;
}

@end
