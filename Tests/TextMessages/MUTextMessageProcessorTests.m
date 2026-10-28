// Run with Scripts/test-text-messages.sh; no obsolete OCUnit/SenTestingKit host.
#import <Foundation/Foundation.h>
#import "MUTextMessageProcessor.h"

static void Check(NSString *plain, NSString *expected) {
    NSString *actual = [MUTextMessageProcessor processedHTMLFromPlainTextMessage:plain];
    if (![actual isEqualToString:expected]) {
        NSLog(@"FAIL input=%@ expected=%@ actual=%@", plain, expected, actual);
        exit(EXIT_FAILURE);
    }
}
int main(void) {
    @autoreleasepool {
        Check(@"Hello there. Here's a link: http://www.google.com",
              @"<p>Hello there. Here's a link: <a href=\"http://www.google.com\">http://www.google.com</a></p>");
        Check(@"Hello there. Here's a link: http://www.google.com, and a trailer!",
              @"<p>Hello there. Here's a link: <a href=\"http://www.google.com\">http://www.google.com</a>, and a trailer!</p>");
        Check(@"1st: http://www.a.com, 2nd: http://www.b.com",
              @"<p>1st: <a href=\"http://www.a.com\">http://www.a.com</a>, 2nd: <a href=\"http://www.b.com\">http://www.b.com</a></p>");
        NSString *url = @"http://www.example.com/%20a%20lot%20of%20spaces";
        Check(url, [NSString stringWithFormat:@"<p><a href=\"%@\">%@</a></p>", url, url]);
        Check(@"<script>alert('message')</script>", @"<p>&lt;script&gt;alert('message')&lt;/script&gt;</p>");
        Check(@"", @"<p></p>");
        puts("PASS message links, punctuation, multiple links, percent encoding, HTML tags and empty messages");
    }
    return EXIT_SUCCESS;
}
