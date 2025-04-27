// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MULegalViewController.h"

#import <WebKit/WKWebView.h>

@interface MULegalViewController () <UIWebViewDelegate> {
    IBOutlet WKWebView *_webView;
}
@end

@implementation MULegalViewController

- (id) init {
    if ((self = [super initWithNibName:@"MULegalViewController" bundle:nil])) {
        // ...
    }
    return self;
}

- (void) viewWillAppear:(BOOL)animated {
    self.navigationItem.title = NSLocalizedString(@"Legal", nil);

    UINavigationBar *navBar = self.navigationController.navigationBar;
    if (@available(iOS 7, *)) {
        navBar.tintColor = [UIColor whiteColor];
        navBar.translucent = NO;
        navBar.backgroundColor = [UIColor blackColor];
    }
    navBar.barStyle = UIBarStyleBlackOpaque;
    
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneButtonClicked:)];
    self.navigationItem.rightBarButtonItem = done;

    NSData *html = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Legal" ofType:@"html"]];
    [_webView loadData:html MIMEType:@"text/html" characterEncodingName:@"utf-8" baseURL:[NSURL URLWithString:@"http://localhost"]];
}

- (void) doneButtonClicked:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
