// Use of this source code is governed by the BSD-style license in LICENSE.
#import "MUImageViewController.h"

@interface MUImageViewController () <QLPreviewControllerDataSource> {
    NSURL *_previewDirectory;
    NSArray<NSURL *> *_previewItems;
}
@end
@implementation MUImageViewController
- (id)initWithImages:(NSArray<UIImage *> *)images {
    return [self initWithImageLoader:^(void (^completion)(NSArray<UIImage *> *)){completion(images);}];
}
- (id)initWithImageLoader:(MUImageLoader)loader {
    if ((self = [super init])) {
        _previewDirectory = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES] URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
        _previewItems = @[];
        self.dataSource = self;
        self.contentUnavailableConfiguration = [UIContentUnavailableConfiguration loadingConfiguration];
        NSURL *directory = _previewDirectory;
        __weak MUImageViewController *weakSelf = self;
        loader(^(NSArray<UIImage *> *images) {
          dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSError *error = nil;
            NSMutableArray *items = [NSMutableArray array];
            if ([NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:&error]) {
                for (UIImage *image in images) {
                    @autoreleasepool {
                        UIImage *normalized = image;
                        if (image.imageOrientation != UIImageOrientationUp) {
                            UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
                            format.scale = image.scale;
                            UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:image.size format:format];
                            normalized = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) { [image drawInRect:(CGRect){CGPointZero, image.size}]; }];
                        }
                        NSString *name = [NSString stringWithFormat:@"%@ %lu.png", NSLocalizedString(@"Image", nil), (unsigned long)items.count + 1];
                        NSURL *url = [directory URLByAppendingPathComponent:name];
                        if ([UIImagePNGRepresentation(normalized) writeToURL:url options:NSDataWritingAtomic error:&error]) [items addObject:url];
                    }
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                MUImageViewController *controller = weakSelf;
                if (!controller) { [NSFileManager.defaultManager removeItemAtURL:directory error:nil]; return; }
                controller->_previewItems = [items copy];
                controller.contentUnavailableConfiguration = nil;
                [controller reloadData];
                if (items.count) controller.currentPreviewItemIndex = 0;
            });
          });
        });
        self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    }
    return self;
}
- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller { return _previewItems.count; }
- (id<QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index { return _previewItems[index]; }
- (void)dealloc { if (_previewDirectory) [NSFileManager.defaultManager removeItemAtURL:_previewDirectory error:nil]; }
@end
