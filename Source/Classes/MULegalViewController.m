// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MULegalViewController.h"

@import WebKit.WKWebView;

@interface MULegalViewController () {
    WKWebView *_webView;
}
@end

@implementation MULegalViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedString(@"Legal", nil);
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    _webView = [[WKWebView alloc] initWithFrame:CGRectZero];
    _webView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_webView];
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_webView.topAnchor constraintEqualToAnchor:safe.topAnchor], [_webView.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
        [_webView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor], [_webView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor]
    ]];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneButtonClicked:)];
    NSURL *url = [NSBundle.mainBundle URLForResource:@"Legal" withExtension:@"html"];
    [_webView loadFileURL:url allowingReadAccessToURL:url.URLByDeletingLastPathComponent];
}

- (void) doneButtonClicked:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
