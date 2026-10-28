// Use of this source code is governed by the BSD-style license in LICENSE.
@import QuickLook;
typedef void (^MUImageLoader)(void (^completion)(NSArray<UIImage *> *images));
@interface MUImageViewController : QLPreviewController
- (id)initWithImages:(NSArray<UIImage *> *)images;
- (id)initWithImageLoader:(MUImageLoader)loader;
@end
