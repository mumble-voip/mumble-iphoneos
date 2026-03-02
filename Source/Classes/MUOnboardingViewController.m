// Copyright 2009-2024 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUOnboardingViewController.h"
#import "MUCertificateController.h"
#import "MUCertificateCreationProgressView.h"
#import "MUColor.h"

#import <MumbleKit/MKCertificate.h>

@interface MUOnboardingViewController () <UITextFieldDelegate> {
    UIScrollView    *_scrollView;
    UIPageControl   *_pageControl;
    UIButton        *_nextButton;
    UITextField     *_usernameField;
    NSInteger       _currentPage;
    BOOL            _pagesBuilt;
}
@end

@implementation MUOnboardingViewController

- (void) viewDidLoad {
    [super viewDidLoad];
    
    _currentPage = 0;
    _pagesBuilt = NO;
    self.view.backgroundColor = [MUColor backgroundColor];
    
    // Scroll view with Auto Layout
    _scrollView = [[UIScrollView alloc] init];
    _scrollView.pagingEnabled = YES;
    _scrollView.scrollEnabled = NO;
    _scrollView.showsHorizontalScrollIndicator = NO;
    _scrollView.clipsToBounds = YES;
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_scrollView];
    
    _pageControl = [[UIPageControl alloc] init];
    _pageControl.numberOfPages = 3;
    _pageControl.currentPage = 0;
    _pageControl.currentPageIndicatorTintColor = [UIColor systemBlueColor];
    _pageControl.pageIndicatorTintColor = [MUColor tertiaryTextColor];
    _pageControl.translatesAutoresizingMaskIntoConstraints = NO;
    _pageControl.userInteractionEnabled = NO;
    [self.view addSubview:_pageControl];
    
    _nextButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_nextButton setTitle:NSLocalizedString(@"Get Started", nil) forState:UIControlStateNormal];
    _nextButton.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    _nextButton.backgroundColor = [UIColor systemBlueColor];
    [_nextButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _nextButton.layer.cornerRadius = 14;
    _nextButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_nextButton addTarget:self action:@selector(nextButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_nextButton];
    
    // Tap anywhere to dismiss keyboard
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];
    
    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [_nextButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [_nextButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [_nextButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16],
        [_nextButton.heightAnchor constraintEqualToConstant:52],
        
        [_pageControl.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_pageControl.bottomAnchor constraintEqualToAnchor:_nextButton.topAnchor constant:-12],
    ]];
}

- (void) viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    if (!_pagesBuilt && _scrollView.bounds.size.width > 0) {
        _pagesBuilt = YES;
        [self buildAllPages];
    }
}

- (void) buildAllPages {
    CGFloat w = _scrollView.bounds.size.width;
    CGFloat h = _scrollView.bounds.size.height;
    _scrollView.contentSize = CGSizeMake(w * 3, h);
    
    // Each page is a container view with clipsToBounds, positioned via frame
    UIView *page0 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    UIView *page1 = [[UIView alloc] initWithFrame:CGRectMake(w, 0, w, h)];
    UIView *page2 = [[UIView alloc] initWithFrame:CGRectMake(w * 2, 0, w, h)];
    page0.clipsToBounds = YES;
    page1.clipsToBounds = YES;
    page2.clipsToBounds = YES;
    page0.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    page1.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    page2.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    
    [_scrollView addSubview:page0];
    [_scrollView addSubview:page1];
    [_scrollView addSubview:page2];
    
    [self populateWelcomePage:page0 width:w];
    [self populateIdentityPage:page1 width:w];
    [self populateConnectPage:page2 width:w];
}

#pragma mark - Page builders

- (void) populateWelcomePage:(UIView *)page width:(CGFloat)w {
    CGFloat safeTop = self.view.safeAreaInsets.top;
    CGFloat y = safeTop + 60;
    
    // App icon
    UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectMake((w - 100) / 2, y, 100, 100)];
    UIImage *icon = [UIImage imageNamed:@"WelcomeScreenIcon"];
    if (icon) {
        iconView.image = icon;
    } else if (@available(iOS 13.0, *)) {
        iconView.image = [UIImage systemImageNamed:@"waveform.circle.fill"
                          withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:80 weight:UIImageSymbolWeightMedium]];
        iconView.tintColor = [UIColor systemBlueColor];
    }
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [page addSubview:iconView];
    y += 100 + 24;
    
    // Title
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(24, y, w - 48, 34)];
    titleLabel.text = NSLocalizedString(@"Welcome to Mumble", nil);
    titleLabel.font = [UIFont systemFontOfSize:28 weight:UIFontWeightBold];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.textColor = [MUColor primaryTextColor];
    [page addSubview:titleLabel];
    y += 34 + 8;
    
    // Subtitle
    UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(24, y, w - 48, 50)];
    subtitleLabel.text = NSLocalizedString(@"Free, open-source, low-latency\nhigh-quality voice chat.", nil);
    subtitleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightRegular];
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.textColor = [MUColor secondaryTextColor];
    subtitleLabel.numberOfLines = 0;
    [subtitleLabel sizeToFit];
    CGRect sf = subtitleLabel.frame;
    sf.origin.x = 24;
    sf.size.width = w - 48;
    subtitleLabel.frame = sf;
    [page addSubview:subtitleLabel];
    y += CGRectGetHeight(sf) + 40;
    
    // Feature rows
    y = [self addFeatureRowToPage:page atY:y width:w icon:@"lock.shield"
                            title:NSLocalizedString(@"Encrypted", nil)
                           detail:NSLocalizedString(@"All voice data is encrypted end-to-end", nil)];
    y += 16;
    y = [self addFeatureRowToPage:page atY:y width:w icon:@"bolt"
                            title:NSLocalizedString(@"Low Latency", nil)
                           detail:NSLocalizedString(@"Designed for real-time gaming communication", nil)];
    y += 16;
    [self addFeatureRowToPage:page atY:y width:w icon:@"eye.slash"
                        title:NSLocalizedString(@"Private", nil)
                       detail:NSLocalizedString(@"No tracking, no ads, no data collection", nil)];
}

- (CGFloat) addFeatureRowToPage:(UIView *)page atY:(CGFloat)y width:(CGFloat)w
                           icon:(NSString *)iconName title:(NSString *)title detail:(NSString *)detail {
    CGFloat leftMargin = 32;
    CGFloat iconSize = 28;
    CGFloat textX = leftMargin + iconSize + 14;
    CGFloat textW = w - textX - 32;
    
    UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectMake(leftMargin, y + 2, iconSize, iconSize)];
    if (@available(iOS 13.0, *)) {
        iconView.image = [UIImage systemImageNamed:iconName
                          withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium]];
    }
    iconView.tintColor = [UIColor systemBlueColor];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [page addSubview:iconView];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(textX, y, textW, 20)];
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    titleLabel.textColor = [MUColor primaryTextColor];
    [page addSubview:titleLabel];
    
    UILabel *detailLabel = [[UILabel alloc] initWithFrame:CGRectMake(textX, y + 22, textW, 0)];
    detailLabel.text = detail;
    detailLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    detailLabel.textColor = [MUColor secondaryTextColor];
    detailLabel.numberOfLines = 0;
    [detailLabel sizeToFit];
    CGRect df = detailLabel.frame;
    df.size.width = textW;
    detailLabel.frame = df;
    [page addSubview:detailLabel];
    
    return y + 22 + CGRectGetHeight(df);
}

- (void) populateIdentityPage:(UIView *)page width:(CGFloat)w {
    CGFloat safeTop = self.view.safeAreaInsets.top;
    CGFloat y = safeTop + 80;
    CGFloat margin = 24;
    CGFloat contentW = w - margin * 2;
    
    // Title
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin, y, contentW, 34)];
    titleLabel.text = NSLocalizedString(@"Set Up Your Identity", nil);
    titleLabel.font = [UIFont systemFontOfSize:28 weight:UIFontWeightBold];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.textColor = [MUColor primaryTextColor];
    [page addSubview:titleLabel];
    y += 34 + 8;
    
    // Subtitle
    UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(32, y, w - 64, 0)];
    subtitleLabel.text = NSLocalizedString(@"Choose a display name that others will see when you join a server.", nil);
    subtitleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.textColor = [MUColor secondaryTextColor];
    subtitleLabel.numberOfLines = 0;
    [subtitleLabel sizeToFit];
    CGRect sf = subtitleLabel.frame;
    sf.origin.x = 32;
    sf.size.width = w - 64;
    subtitleLabel.frame = sf;
    [page addSubview:subtitleLabel];
    y += CGRectGetHeight(sf) + 32;
    
    // "Display Name" label
    UILabel *usernameLabel = [[UILabel alloc] initWithFrame:CGRectMake(32, y, contentW, 18)];
    usernameLabel.text = NSLocalizedString(@"Display Name", nil);
    usernameLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    usernameLabel.textColor = [MUColor secondaryTextColor];
    [page addSubview:usernameLabel];
    y += 18 + 6;
    
    // Username text field
    _usernameField = [[UITextField alloc] initWithFrame:CGRectMake(margin, y, contentW, 48)];
    _usernameField.placeholder = @"MumbleUser";
    _usernameField.text = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultUserName"];
    _usernameField.font = [UIFont systemFontOfSize:17];
    _usernameField.borderStyle = UITextBorderStyleNone;
    _usernameField.backgroundColor = [MUColor cellBackgroundColor];
    _usernameField.layer.cornerRadius = 12;
    _usernameField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _usernameField.autocorrectionType = UITextAutocorrectionTypeNo;
    _usernameField.returnKeyType = UIReturnKeyDone;
    _usernameField.delegate = self;
    _usernameField.clearButtonMode = UITextFieldViewModeWhileEditing;
    UIView *paddingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 16, 48)];
    _usernameField.leftView = paddingView;
    _usernameField.leftViewMode = UITextFieldViewModeAlways;
    [page addSubview:_usernameField];
    y += 48 + 24;
    
    // Certificate info card
    CGFloat cardX = margin;
    CGFloat cardW = contentW;
    
    UIView *certCard = [[UIView alloc] init];
    certCard.backgroundColor = [MUColor cellBackgroundColor];
    certCard.layer.cornerRadius = 12;
    
    UIImageView *certIcon = [[UIImageView alloc] initWithFrame:CGRectMake(16, 16, 28, 28)];
    if (@available(iOS 13.0, *)) {
        certIcon.image = [UIImage systemImageNamed:@"checkmark.shield.fill"
                          withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium]];
    }
    certIcon.tintColor = [UIColor systemGreenColor];
    [certCard addSubview:certIcon];
    
    CGFloat certTextX = 16 + 28 + 12;
    CGFloat certTextW = cardW - certTextX - 16;
    
    UILabel *certTitle = [[UILabel alloc] initWithFrame:CGRectMake(certTextX, 16, certTextW, 20)];
    certTitle.text = NSLocalizedString(@"Certificate", nil);
    certTitle.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    certTitle.textColor = [MUColor primaryTextColor];
    [certCard addSubview:certTitle];
    
    UILabel *certDetail = [[UILabel alloc] initWithFrame:CGRectMake(certTextX, 38, certTextW, 0)];
    certDetail.text = NSLocalizedString(@"A certificate will be created automatically. It\u2019s your identity \u2014 it lets servers remember you.", nil);
    certDetail.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    certDetail.textColor = [MUColor secondaryTextColor];
    certDetail.numberOfLines = 0;
    [certDetail sizeToFit];
    CGRect cdf = certDetail.frame;
    cdf.size.width = certTextW;
    certDetail.frame = cdf;
    [certCard addSubview:certDetail];
    
    CGFloat cardH = 38 + CGRectGetHeight(cdf) + 16;
    certCard.frame = CGRectMake(cardX, y, cardW, cardH);
    [page addSubview:certCard];
}

- (void) populateConnectPage:(UIView *)page width:(CGFloat)w {
    CGFloat safeTop = self.view.safeAreaInsets.top;
    CGFloat y = safeTop + 80;
    CGFloat margin = 24;
    CGFloat contentW = w - margin * 2;
    
    // Title
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin, y, contentW, 34)];
    titleLabel.text = NSLocalizedString(@"Join a Server", nil);
    titleLabel.font = [UIFont systemFontOfSize:28 weight:UIFontWeightBold];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.textColor = [MUColor primaryTextColor];
    [page addSubview:titleLabel];
    y += 34 + 8;
    
    // Subtitle
    UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(32, y, w - 64, 0)];
    subtitleLabel.text = NSLocalizedString(@"There are several ways to find and connect to a Mumble server.", nil);
    subtitleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.textColor = [MUColor secondaryTextColor];
    subtitleLabel.numberOfLines = 0;
    [subtitleLabel sizeToFit];
    CGRect sf = subtitleLabel.frame;
    sf.origin.x = 32;
    sf.size.width = w - 64;
    subtitleLabel.frame = sf;
    [page addSubview:subtitleLabel];
    y += CGRectGetHeight(sf) + 32;
    
    // Option cards
    y = [self addConnectOptionToPage:page atY:y width:w icon:@"globe"
                               title:NSLocalizedString(@"Browse Public Servers", nil)
                              detail:NSLocalizedString(@"Discover community servers, like Discord's server browser", nil)];
    y += 12;
    y = [self addConnectOptionToPage:page atY:y width:w icon:@"link"
                               title:NSLocalizedString(@"Join by Address", nil)
                              detail:NSLocalizedString(@"Paste a server address or mumble:// link, like a Discord invite", nil)];
    y += 12;
    [self addConnectOptionToPage:page atY:y width:w icon:@"wifi"
                           title:NSLocalizedString(@"Local Network", nil)
                          detail:NSLocalizedString(@"Find Mumble servers on your Wi-Fi network", nil)];
}

- (CGFloat) addConnectOptionToPage:(UIView *)page atY:(CGFloat)y width:(CGFloat)w
                              icon:(NSString *)iconName title:(NSString *)title detail:(NSString *)detail {
    CGFloat margin = 24;
    CGFloat cardW = w - margin * 2;
    
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [MUColor cellBackgroundColor];
    card.layer.cornerRadius = 12;
    
    CGFloat iconX = 16;
    CGFloat iconSize = 28;
    CGFloat textX = iconX + iconSize + 14;
    CGFloat textW = cardW - textX - 16;
    
    UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectMake(iconX, 0, iconSize, iconSize)];
    if (@available(iOS 13.0, *)) {
        iconView.image = [UIImage systemImageNamed:iconName
                          withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium]];
    }
    iconView.tintColor = [UIColor systemBlueColor];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [card addSubview:iconView];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(textX, 14, textW, 20)];
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    titleLabel.textColor = [MUColor primaryTextColor];
    [card addSubview:titleLabel];
    
    UILabel *detailLabel = [[UILabel alloc] initWithFrame:CGRectMake(textX, 36, textW, 0)];
    detailLabel.text = detail;
    detailLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    detailLabel.textColor = [MUColor secondaryTextColor];
    detailLabel.numberOfLines = 0;
    [detailLabel sizeToFit];
    CGRect df = detailLabel.frame;
    df.size.width = textW;
    detailLabel.frame = df;
    [card addSubview:detailLabel];
    
    CGFloat cardH = 36 + CGRectGetHeight(df) + 14;
    
    // Center icon vertically
    CGRect iconFrame = iconView.frame;
    iconFrame.origin.y = (cardH - iconSize) / 2;
    iconView.frame = iconFrame;
    
    card.frame = CGRectMake(margin, y, cardW, cardH);
    [page addSubview:card];
    
    return y + cardH;
}

#pragma mark - Actions

- (void) nextButtonTapped {
    [self dismissKeyboard];
    if (_currentPage < 2) {
        _currentPage++;
        _pageControl.currentPage = _currentPage;
        
        CGFloat pageWidth = _scrollView.bounds.size.width;
        [_scrollView setContentOffset:CGPointMake(pageWidth * _currentPage, 0) animated:YES];
        
        if (_currentPage == 1) {
            [_nextButton setTitle:NSLocalizedString(@"Continue", nil) forState:UIControlStateNormal];
        } else if (_currentPage == 2) {
            [_nextButton setTitle:NSLocalizedString(@"Start Using Mumble", nil) forState:UIControlStateNormal];
        }
    } else {
        [self finishOnboarding];
    }
}

- (void) finishOnboarding {
    // Save username
    NSString *username = [_usernameField text];
    if (username && [username length] > 0) {
        [[NSUserDefaults standardUserDefaults] setObject:username forKey:@"DefaultUserName"];
    }
    
    // Auto-generate certificate if none exists
    if ([MUCertificateController defaultCertificate] == nil) {
        NSString *name = (username && [username length] > 0) ? username : @"Mumble User";
        [self generateCertificateWithName:name];
    }
    
    // Mark onboarding as completed
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"HasCompletedOnboarding"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    if (self.completionHandler) {
        self.completionHandler();
    }
}

- (void) generateCertificateWithName:(NSString *)name {
    MKCertificate *cert = [MKCertificate selfSignedCertificateWithName:name email:nil];
    NSData *pkcs12 = [cert exportPKCS12WithPassword:@""];
    if (pkcs12 != nil) {
        NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"", kSecImportExportPassphrase, nil];
        CFArrayRef cfItems = NULL;
        OSStatus err = SecPKCS12Import((__bridge CFDataRef)pkcs12, (__bridge CFDictionaryRef)dict, &cfItems);
        if (err == errSecSuccess && cfItems != NULL) {
            NSArray *items = (__bridge_transfer NSArray *)cfItems;
            if ([items count] > 0) {
                NSDictionary *pkcsDict = [items objectAtIndex:0];
                SecIdentityRef identity = (__bridge SecIdentityRef)[pkcsDict objectForKey:(__bridge id)kSecImportItemIdentity];
                NSDictionary *op = [NSDictionary dictionaryWithObjectsAndKeys:
                                    (__bridge id)identity, kSecValueRef,
                                    (__bridge id)kCFBooleanTrue, kSecReturnPersistentRef, nil];
                CFTypeRef cfData = NULL;
                err = SecItemAdd((__bridge CFDictionaryRef)op, &cfData);
                if (err == noErr && cfData != NULL) {
                    NSData *data = (__bridge_transfer NSData *)cfData;
                    [MUCertificateController setDefaultCertificateByPersistentRef:data];
                }
            }
        } else if (cfItems != NULL) {
            CFRelease(cfItems);
        }
    }
}

- (void) dismissKeyboard {
    [self.view endEditing:YES];
}

#pragma mark - UITextFieldDelegate

- (BOOL) textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

@end
