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
