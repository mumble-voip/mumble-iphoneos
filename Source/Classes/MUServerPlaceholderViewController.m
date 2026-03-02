// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUServerPlaceholderViewController.h"
#import "MUColor.h"

@implementation MUServerPlaceholderViewController

- (void) viewDidLoad {
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"Server", nil);
    
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    } else {
        self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    }
    
    UIImageView *iconView = [[UIImageView alloc] init];
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:56 weight:UIImageSymbolWeightLight];
        iconView.image = [UIImage systemImageNamed:@"server.rack" withConfiguration:config];
        iconView.tintColor = [UIColor tertiaryLabelColor];
    }
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:iconView];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = NSLocalizedString(@"Not Connected", nil);
    titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightSemibold];
    if (@available(iOS 13.0, *)) {
        titleLabel.textColor = [UIColor secondaryLabelColor];
    } else {
        titleLabel.textColor = [UIColor grayColor];
    }
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:titleLabel];
    
    UILabel *detailLabel = [[UILabel alloc] init];
    detailLabel.text = NSLocalizedString(@"Connect to a server from the Home tab.", nil);
    detailLabel.font = [UIFont systemFontOfSize:15];
    if (@available(iOS 13.0, *)) {
        detailLabel.textColor = [UIColor tertiaryLabelColor];
    } else {
        detailLabel.textColor = [UIColor lightGrayColor];
    }
    detailLabel.textAlignment = NSTextAlignmentCenter;
    detailLabel.numberOfLines = 0;
    detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:detailLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [iconView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-50],
        
        [titleLabel.topAnchor constraintEqualToAnchor:iconView.bottomAnchor constant:16],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:32],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-32],
        
        [detailLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8],
        [detailLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:32],
        [detailLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-32],
    ]];
}

@end
