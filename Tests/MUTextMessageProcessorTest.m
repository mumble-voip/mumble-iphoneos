// Copyright 2013 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUTextMessageProcessorTest.h"
#import "MUTextMessageProcessor.h"

@interface MUTextMessageProcessorTest ()
+ (NSString *) plainStringFromLinks:(NSArray *)links;
+ (NSString *) htmlStringFromLinks:(NSArray *)links;
@end

@implementation MUTextMessageProcessorTest

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void) testSingleLink {
    NSString *plain = @"Hello there. Here's a link: http://www.google.com";
    NSString *expected = @"<p>Hello there. Here's a link: <a href=\"http://www.google.com\">http://www.google.com</a></p>";
    NSString *html = [MUTextMessageProcessor processedHTMLFromPlainTextMessage:plain];
    STAssertEqualObjects(html, expected, nil);
}

- (void) testSingleLinkWithTrailer {
    NSString *plain = @"Hello there. Here's a link: http://www.google.com, and a trailer!";
    NSString *expected = @"<p>Hello there. Here's a link: <a href=\"http://www.google.com\">http://www.google.com</a>, and a trailer!</p>";
    NSString *html = [MUTextMessageProcessor processedHTMLFromPlainTextMessage:plain];
    STAssertEqualObjects(html, expected, nil);
}

- (void) testMultiLink {
    NSString *plain = @"1st: http://www.a.com, 2nd: http://www.b.com";
    NSString *expected = @"<p>1st: <a href=\"http://www.a.com\">http://www.a.com</a>, 2nd: <a href=\"http://www.b.com\">http://www.b.com</a></p>";
    NSString *html = [MUTextMessageProcessor processedHTMLFromPlainTextMessage:plain];
    STAssertEqualObjects(html, expected, nil);
}

- (void) testPercentEncoding {
    NSString *plain = @"Hello there. Here's a link: http://www.example.com/%20a%20lot%20of%20spaces";
    NSString *expected = @"<p>Hello there. Here's a link: <a href=\"http://www.example.com/%20a%20lot%20of%20spaces\">http://www.example.com/%20a%20lot%20of%20spaces</a></p>";
    NSString *html = [MUTextMessageProcessor processedHTMLFromPlainTextMessage:plain];
    STAssertEqualObjects(html, expected, nil);
}

+ (NSString *) plainStringFromLinks:(NSArray *)links {
    NSMutableString *str = [NSMutableString string];
    for (NSString *url in links) {
        [str appendString:url];
        [str appendString:@" "];
    }
    return str;
}

+ (NSString *) htmlStringFromLinks:(NSArray *)links {
    NSMutableString *str = [NSMutableString string];
    [str appendString:@"<p>"];
    for (NSString *url in links) {
        [str appendString:@"<a href=\""];
        [str appendString:url];
        [str appendString:@"\">"];
        [str appendString:url];
        [str appendString:@"</a> "];
    }
    [str appendString:@"</p>"];
    return str;
}

- (void) testManyLinks {
    NSArray *links = @[
        @"http://www.google.com",
        @"http://www.facebook.com",
        @"https://www.yahoo.com",
        @"mumble://test.mumble.info:64738",
        @"mumble://test.mumble.info:64738/Test/Some/Channel?version=1.2.0"
        @"steam://43145",
        @"mailto:test@example.com",
        @"file:///Users/luser/Documents/test.html",
        @"http://www.google.dk/#hl=en&safe=off&tbo=d&output=search&sclient=psy-ab&q=hello+world&oq=hello+world",
        @"http://www.bing.com/%20%20already%20%20percent%20%20encoded",
        @"http://www.nonascii.com/æøæåæøæåææøæåæø",
        @"http://pctenc.info/%26%25%26%25",
    ];
    NSString *plain = [MUTextMessageProcessorTest plainStringFromLinks:links];
    NSString *expected = [MUTextMessageProcessorTest htmlStringFromLinks:links];
    NSString *html = [MUTextMessageProcessor processedHTMLFromPlainTextMessage:plain];
    STAssertEqualObjects(html, expected, nil);
}

- (void) testInvalidURLs {
    NSArray *links = @[
        @"http://currency.eu/€€€",
        @"http://bah/?hello#hey#ho",
    ];
    for (NSString *url in links) {
        NSString *plain = [MUTextMessageProcessorTest plainStringFromLinks:links];
        NSString *expected = [MUTextMessageProcessorTest htmlStringFromLinks:links];
        NSString *html = [MUTextMessageProcessor processedHTMLFromPlainTextMessage:plain];
        STAssertFalse([html isEqualToString:expected], @"got '%@', did not expect '%@'", html, expected);
    }
}

@end
