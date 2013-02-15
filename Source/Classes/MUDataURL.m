// Copyright 2009-2012 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUDataURL.h"
#import "GTMStringEncoding.h"

@implementation MUDataURL

// todo(mkrautz): Redo this with our own internal scanning and base64 decoding
// to get rid of the string copying.
+ (NSData *) dataFromDataURL:(NSString *)dataURL {
    GTMStringEncoding *base64decoder = [GTMStringEncoding rfc4648Base64StringEncoding];

    // Read: data:<mimetype>;<encoding>,<data>
    // Expect encoding = base64

    if (![dataURL hasPrefix:@"data:"])
        return nil;
    NSString *mimeStr = [dataURL substringFromIndex:5];
    NSRange r = [mimeStr rangeOfString:@";"];
    if (r.location == NSNotFound)
        return nil;
    NSString *mimeType = [mimeStr substringToIndex:r.location];
    (void) mimeType;
    r.location += 1;
    r.length = 7;
    if ([mimeStr length] < r.location+r.length)
        return nil;
    if (![[mimeStr substringWithRange:r] isEqualToString:@"base64,"])
        return nil;

    NSString *base64data = [mimeStr substringFromIndex:r.location+r.length];
    base64data = [base64data stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    base64data = [base64data stringByReplacingOccurrencesOfString:@" " withString:@""];
    return [base64decoder decode:base64data];
}

+ (UIImage *) imageFromDataURL:(NSString *)dataURL {
    return [UIImage imageWithData:[MUDataURL dataFromDataURL:dataURL]];
}

@end
