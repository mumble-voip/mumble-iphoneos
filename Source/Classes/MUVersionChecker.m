// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUVersionChecker.h"

@interface MUVersionChecker () {
    NSURLConnection *_conn;
    NSMutableData   *_buf;
}
- (void) connection:(NSURLConnection *)conn didReceiveData:(NSData *)data;
- (void) connection:(NSURLConnection *)conn didFailWithError:(NSError *)error;
- (void) connectionDidFinishLoading:(NSURLConnection *)conn;
- (void) newBuildAvailable;
@end

@implementation MUVersionChecker

- (id) init {
    self = [super init];
    if (!self)
        return nil;

    NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://mumble-ios.appspot.com/latest.plist"]];
    _conn = [[NSURLConnection alloc] initWithRequest:req delegate:self];
    _buf = [[NSMutableData alloc] init];

    return self;
}

- (void) dealloc {
    [_conn cancel];
    [_conn release];
    [_buf release];
    [super dealloc];
}

- (void) connection:(NSURLConnection *)conn didReceiveData:(NSData *)data {
    [_buf appendData:data];
}

- (void) connection:(NSURLConnection *)conn didFailWithError:(NSError *)error {
    NSLog(@"MUversionChecker: failed to fetch latest version info.");
}

- (void) connectionDidFinishLoading:(NSURLConnection *)conn {
    NSPropertyListFormat fmt = NSPropertyListXMLFormat_v1_0;
    NSDictionary *dict = [NSPropertyListSerialization propertyListWithData:_buf options:0 format:&fmt error:nil];
    if (dict) {
        NSBundle *mainBundle = [NSBundle mainBundle];
        NSString *ourRev = [mainBundle objectForInfoDictionaryKey:@"MumbleGitRevision"];
        NSString *latestRev = [dict objectForKey:@"MumbleGitRevision"];
        if (![ourRev isEqualToString:latestRev]) {
            NSDate *ourBuildDate = [mainBundle objectForInfoDictionaryKey:@"MumbleBuildDate"];
            NSDate *latestBuildDate = [dict objectForKey:@"MumbleBuildDate"];
            if (![ourBuildDate isEqualToDate:latestBuildDate]) {
                NSDate *latest = [ourBuildDate laterDate:latestBuildDate];
                if (latestBuildDate == latest) {
                    [self newBuildAvailable];
                }
            }
        }
    }
}

- (void) newBuildAvailable {
    NSString *title = NSLocalizedString(@"New beta build available", nil);
    NSString *msg = NSLocalizedString(@"Do you want to upgrade?", nil);
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                     message:msg
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                          otherButtonTitles:NSLocalizedString(@"Upgrade", nil), nil];
    [alert show];
    [alert release];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) { // Upgrade
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"itms-services://?action=download-manifest&url=https://mumble-ios.appspot.com/wdist/manifest"]];
    }
}

@end
