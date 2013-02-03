/* Copyright (C) 2013 Mikkel Krautz <mikkel@krautz.dk>

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
