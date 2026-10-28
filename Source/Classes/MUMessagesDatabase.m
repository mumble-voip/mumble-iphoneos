// Copyright 2009-2026 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by the BSD-style license in LICENSE.

#import "MUMessagesDatabase.h"
#import "MUTextMessage.h"
#import "MUDataURL.h"
#import "MLClient.h"
#import <FMDB/FMDatabase.h>
@import ImageIO;

@interface MUStoredMessage : NSObject
@property(nonatomic) int64_t identifier;
@property(nonatomic,strong) MUTextMessage *metadata;
@property(nonatomic,copy) NSArray<NSData *> *fallbackImages;
@end
@implementation MUStoredMessage
@end
@interface MUPreviewRequest : NSObject
@property(atomic) BOOL cancelled;
@property(nonatomic) BOOL prefetch;
@end
@implementation MUPreviewRequest
@end

static UIImage *MUMessageThumbnail(NSData *data, NSUInteger edge, CGSize *originalSize) {
    CGImageSourceRef source=CGImageSourceCreateWithData((__bridge CFDataRef)data, (__bridge CFDictionaryRef)@{(__bridge NSString *)kCGImageSourceShouldCache:@NO});
    if (!source) return nil;
    NSDictionary *properties=CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source,0,NULL));
    CGFloat width=[properties[(__bridge NSString *)kCGImagePropertyPixelWidth] doubleValue], height=[properties[(__bridge NSString *)kCGImagePropertyPixelHeight] doubleValue];
    NSUInteger orientation=[properties[(__bridge NSString *)kCGImagePropertyOrientation] unsignedIntegerValue];
    NSDictionary *options=@{(__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways:@YES, (__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform:@YES, (__bridge NSString *)kCGImageSourceShouldCacheImmediately:@YES, (__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize:@(edge)};
    CGImageRef thumbnail=CGImageSourceCreateThumbnailAtIndex(source,0,(__bridge CFDictionaryRef)options);
    CFRelease(source);
    if (!thumbnail) return nil;
    UIImage *image=[UIImage imageWithCGImage:thumbnail];CGImageRelease(thumbnail);
    if (originalSize) *originalSize=width>0 && height>0 ? (orientation>=5 && orientation<=8 ? CGSizeMake(height,width) : CGSizeMake(width,height)) : image.size;
    return image;
}
static NSUInteger MUThumbnailEdge(NSUInteger count) {
    // At most 12 MiB of decoded preview pixels per message, including messages
    // containing many attachments. The complete originals remain in SQLite.
    return MAX(1,(NSUInteger)floor(MIN(1280,sqrt(12.0*1024*1024/(4*MAX(count,1))))));
}
static NSUInteger MUMessageImageCost(MUTextMessage *message) {
    NSUInteger cost=0;
    for (UIImage *image in message.embeddedImages) cost+=(NSUInteger)(image.size.width*image.scale*image.size.height*image.scale*4);
    return cost;
}
static MUTextMessage *MUMessageWithImages(MUTextMessage *metadata, NSArray<UIImage *> *images) {
    MUTextMessage *message=[MUTextMessage textMessageWithHeading:metadata.heading andMessage:metadata.message andEmbeddedLinks:metadata.embeddedLinks andEmbeddedImages:images andTimestampDate:metadata.date isSentBySelf:metadata.isSentBySelf];
    message.embeddedImageSizes=metadata.embeddedImageSizes;
    return message;
}

@implementation MUMessagesDatabase {
    dispatch_queue_t _queue;
    FMDatabase *_db;
    NSMutableArray<MUStoredMessage *> *_records;
    NSCache<NSNumber *,MUTextMessage *> *_previewCache;
    NSMutableDictionary<NSNumber *,MUPreviewRequest *> *_previewRequests;
}
- (id)init {
    if ((self=[super init])) {
        _records=[NSMutableArray array];_previewRequests=[NSMutableDictionary dictionary];
        _previewCache=[NSCache new];_previewCache.countLimit=128;_previewCache.totalCostLimit=24*1024*1024;
        _queue=dispatch_queue_create("info.mumble.messages",dispatch_queue_attr_make_with_autorelease_frequency(DISPATCH_QUEUE_SERIAL,DISPATCH_AUTORELEASE_FREQUENCY_WORK_ITEM));
        NSString *path=[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"msg-%@.db",NSUUID.UUID.UUIDString]];
        _db=[[FMDatabase alloc]initWithPath:path];
        dispatch_async(_queue, ^{
            if (![self->_db open]) NSLog(@"Message storage unavailable: %@",self->_db.lastErrorMessage);
            [self->_db executeUpdate:@"CREATE TABLE IF NOT EXISTS msg (id INTEGER PRIMARY KEY AUTOINCREMENT, plist BLOB)"];
            [self->_db executeUpdate:@"PRAGMA journal_mode=MEMORY"];
            [self->_db executeUpdate:@"PRAGMA synchronous=OFF"];
        });
    }
    return self;
}
- (void)dealloc {
    FMDatabase *database=_db;NSString *path=database.databasePath;
    dispatch_async(_queue, ^{ [database close];if(path)[NSFileManager.defaultManager removeItemAtPath:path error:nil]; });
}
- (NSInteger)count { NSAssert(NSThread.isMainThread,@"Message snapshots belong to the UI thread");return _records.count; }
- (void)addMessage:(MLTextMessage *)message withHeading:(NSString *)heading andSentBySelf:(BOOL)selfSent completion:(void (^)(void))completion {
    NSDate *receivedAt=NSDate.date;
    dispatch_async(_queue, ^{
        NSMutableArray<NSData *> *dataImages=[NSMutableArray array];
        NSMutableArray<UIImage *> *previews=[NSMutableArray array];
        NSMutableArray<NSValue *> *sizes=[NSMutableArray array];
        NSUInteger edge=MUThumbnailEdge(message.embeddedImages.count);
        for(NSString *url in message.embeddedImages) {
            @autoreleasepool {
                NSData *data=[MUDataURL dataFromDataURL:url];CGSize size=CGSizeZero;
                UIImage *preview=data ? MUMessageThumbnail(data,edge,&size) : nil;
                if(preview){[dataImages addObject:data];[previews addObject:preview];[sizes addObject:[NSValue valueWithCGSize:size]];}
            }
        }
        NSString *text=[message.plainTextString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
        NSArray *links=message.embeddedLinks ?: @[];
        NSDictionary *record=@{@"heading":heading ?: @"",@"msg":text,@"date":receivedAt,@"links":links,@"images":dataImages,@"selfsent":@(selfSent)};
        NSData *plist=[NSPropertyListSerialization dataWithPropertyList:record format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
        BOOL written=plist && [self->_db executeUpdate:@"INSERT INTO msg (plist) VALUES (?)",plist];
        MUStoredMessage *stored=[MUStoredMessage new];
        stored.identifier=written ? self->_db.lastInsertRowId : -1;
        // Keep receiving messages even if temporary storage is unavailable.
        if(!written){stored.fallbackImages=dataImages;NSLog(@"Message write failed: %@",self->_db.lastErrorMessage);}
        stored.metadata=[MUTextMessage textMessageWithHeading:heading ?: @"" andMessage:text andEmbeddedLinks:links andEmbeddedImages:@[] andTimestampDate:receivedAt isSentBySelf:selfSent];
        stored.metadata.embeddedImageSizes=sizes;
        MUTextMessage *display=MUMessageWithImages(stored.metadata,previews);
        dispatch_async(dispatch_get_main_queue(), ^{
            NSNumber *key=@(self->_records.count);[self->_records addObject:stored];
            if(previews.count)[self->_previewCache setObject:display forKey:key cost:MUMessageImageCost(display)];
            if(completion)completion();
        });
    });
}
// Only called on the serial storage queue. UI callers never query SQLite.
- (NSArray<NSData *> *)imageDataForRecord:(MUStoredMessage *)record {
    if(record.fallbackImages)return record.fallbackImages;
    FMResultSet *result=[_db executeQuery:@"SELECT plist FROM msg WHERE id=?",@(record.identifier)];
    NSData *data=[result next] ? [result dataForColumnIndex:0] : nil;[result close];
    NSDictionary *plist=data ? [NSPropertyListSerialization propertyListWithData:data options:0 format:nil error:nil] : nil;
    return plist[@"images"] ?: @[];
}
- (MUTextMessage *)messageAtIndex:(NSInteger)row {return [self messageAtIndex:row prefetch:NO];}
- (void)prefetchMessagesAtIndexes:(NSIndexSet *)indexes {
    __block NSUInteger count=0;
    [indexes enumerateIndexesUsingBlock:^(NSUInteger row,BOOL *stop){[self messageAtIndex:(NSInteger)row prefetch:YES];*stop=++count>=16;}];
}
- (void)cancelPrefetchAtIndexes:(NSIndexSet *)indexes {
    [indexes enumerateIndexesUsingBlock:^(NSUInteger row,BOOL *stop){
        NSNumber *key=@(row);MUPreviewRequest *request=self->_previewRequests[key];
        if(request.prefetch){request.cancelled=YES;[self->_previewRequests removeObjectForKey:key];}
    }];
}
- (MUTextMessage *)messageAtIndex:(NSInteger)row prefetch:(BOOL)prefetch {
    NSAssert(NSThread.isMainThread,@"Message snapshots belong to the UI thread");
    if(row<0 || row>=(NSInteger)_records.count)return nil;
    MUStoredMessage *stored=_records[row];MUTextMessage *metadata=stored.metadata;
    if(!metadata)return nil;
    NSNumber *key=@(row);MUTextMessage *cached=[_previewCache objectForKey:key];
    if(cached)return cached;
    MUPreviewRequest *pending=_previewRequests[key];
    if(pending && !prefetch)pending.prefetch=NO;
    if(metadata.embeddedImageSizes.count && !pending) {
        MUPreviewRequest *request=[MUPreviewRequest new];request.prefetch=prefetch;_previewRequests[key]=request;
        dispatch_async(_queue, ^{
            if(request.cancelled)return;
            NSArray *dataImages=[self imageDataForRecord:stored];NSMutableArray *previews=[NSMutableArray array];NSUInteger edge=MUThumbnailEdge(dataImages.count);
            for(NSData *data in dataImages){@autoreleasepool{UIImage *image=MUMessageThumbnail(data,edge,NULL);if(image)[previews addObject:image];}}
            MUTextMessage *display=MUMessageWithImages(metadata,previews);
            dispatch_async(dispatch_get_main_queue(), ^{
                if(self->_previewRequests[key]!=request)return;
                [self->_previewRequests removeObjectForKey:key];
                if(request.cancelled || stored.metadata!=metadata)return;
                [self->_previewCache setObject:display forKey:key cost:MUMessageImageCost(display)];
                if(self.messageDidLoad)self.messageDidLoad(row,display);
            });
        });
    }
    return metadata;
}
- (void)clearMessageAtIndex:(NSInteger)row {
    NSAssert(NSThread.isMainThread,@"Message snapshots belong to the UI thread");
    if(row<0 || row>=(NSInteger)_records.count)return;
    MUStoredMessage *stored=_records[row];stored.metadata=nil;[_previewCache removeObjectForKey:@(row)];
    _previewRequests[@(row)].cancelled=YES;[_previewRequests removeObjectForKey:@(row)];
    dispatch_async(_queue, ^{[self->_db executeUpdate:@"UPDATE msg SET plist=NULL WHERE id=?",@(stored.identifier)];stored.fallbackImages=nil;});
}
- (void)loadImagesAtIndex:(NSInteger)row completion:(void (^)(NSArray<UIImage *> *))completion {
    NSAssert(NSThread.isMainThread,@"Message snapshots belong to the UI thread");
    if(row<0 || row>=(NSInteger)_records.count || !_records[row].metadata){completion(@[]);return;}
    MUStoredMessage *stored=_records[row];
    dispatch_async(_queue, ^{
        NSMutableArray *images=[NSMutableArray array];
        for(NSData *data in [self imageDataForRecord:stored]){@autoreleasepool{UIImage *image=[UIImage imageWithData:data];if(image)[images addObject:image];}}
        dispatch_async(dispatch_get_main_queue(), ^{completion(stored.metadata ? images : @[]);});
    });
}
@end
