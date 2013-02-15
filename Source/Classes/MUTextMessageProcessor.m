// Copyright 2013 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUTextMessageProcessor.h"

@implementation MUTextMessageProcessor

// processedHTMLFromPlainTextMessage converts the plain text-formatted text message
// in plain to a HTML message that can be sent to another Mumble client.
+ (NSString *) processedHTMLFromPlainTextMessage:(NSString *)plain {
    // First, ensure that the plain text string doesn't already contain HTML tags.
    // Replace > with &lt; and < with &gt;
    NSString *str = [plain stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
    str = [str stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
    
    // Use NSDataDetectors to detect any links in the message and
    // automatically convert them to <a>-tags.
    NSError *err = nil;
    NSDataDetector *linkDetector = [NSDataDetector dataDetectorWithTypes:(NSTextCheckingTypeLink &NSTextCheckingAllSystemTypes) error:&err];
    if (err == nil && linkDetector != nil) {
        NSMutableString *output = [NSMutableString stringWithCapacity:[str length]*2];
        NSArray *matches = [linkDetector matchesInString:str options:0 range:NSMakeRange(0, [str length])];
        NSUInteger lastIndex = 0;
        
        [output appendString:@"<p>"];

        for (NSTextCheckingResult *match in matches) {
            NSRange urlRange = [match range];
            NSRange beforeUrlRange = NSMakeRange(lastIndex, urlRange.location-lastIndex);

            // Extract the string that is in front of the URL part and output
            // it to 'output'.
            NSString *beforeURL = [str substringWithRange:beforeUrlRange];
            if (beforeURL == nil) {
                return nil;
            }
            [output appendString:beforeURL];
            
            // Extract the URL and format it as a HTML a-tag.
            NSString *url = [str substringWithRange:urlRange];
            NSString *anchor = [NSString stringWithFormat:@"<a href=\"%@\">%@</a>", url, url];
            if (anchor == nil) {
                return nil;
            }
            [output appendString:anchor];

            // Update the lastIndex to keep track of 
            lastIndex = urlRange.location + urlRange.length;
        }

        // Ensure that any remaining parts of the string are added to the output buffer.
        NSString *lastChunk = [str substringWithRange:NSMakeRange(lastIndex, [str length]-lastIndex)];
        if (lastChunk == nil) {
            return nil;
        }
        [output appendString:lastChunk];

        [output appendString:@"</p>"];

        return output;
    }
    
    return [NSString stringWithFormat:@"<p>%@</p>", str];
}

@end
