// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUAudioBarView.h"

#import "MLClient.h"

@interface MUAudioBarView () {
    CGFloat _below;
    CGFloat _above;
    CGFloat _min;
    CGFloat _max;
    CGFloat _value;
    NSTimer *_timer;
    UIProgressView *_progress;
    UILabel *_levelLabel;
}
@end

@implementation MUAudioBarView

- (id) initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _value = 0.5f;
        _min = 0.0f;
        _max = 1.0f;
        self.backgroundColor = UIColor.clearColor;
        self.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(16, 20, 16, 20);
        self.preservesSuperviewLayoutMargins = YES;
        _levelLabel = [UILabel new];
        _levelLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
        _levelLabel.adjustsFontForContentSizeCategory = YES;
        _levelLabel.textColor = UIColor.secondaryLabelColor;
        _levelLabel.numberOfLines = 0;
        _progress = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        _progress.isAccessibilityElement = YES;
        _progress.accessibilityLabel = NSLocalizedString(@"Microphone Level", nil);
        _levelLabel.accessibilityElementsHidden = YES;
        UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[_levelLabel, _progress]];
        stack.axis = UILayoutConstraintAxisVertical; stack.spacing = 12;
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:stack];
        [NSLayoutConstraint activateConstraints:@[
            [stack.leadingAnchor constraintEqualToAnchor:self.layoutMarginsGuide.leadingAnchor],
            [stack.trailingAnchor constraintEqualToAnchor:self.layoutMarginsGuide.trailingAnchor],
            [stack.topAnchor constraintEqualToAnchor:self.topAnchor constant:16],
            [stack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-16]
        ]];
        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        [center addObserver:self selector:@selector(updateMetering) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [center addObserver:self selector:@selector(updateMetering) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

- (void) dealloc {
    if (_timer) [[MLAudio sharedAudio] endMetering];
    [_timer invalidate];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    [self updateMetering];
}

- (void)updateMetering {
    BOOL visible = self.window && !self.hidden && UIApplication.sharedApplication.applicationState != UIApplicationStateBackground;
    if (!visible) {
        if (_timer) [[MLAudio sharedAudio] endMetering];
        [_timer invalidate]; _timer = nil;
    } else if (!_timer) {
        [[MLAudio sharedAudio] beginMetering];
        __weak MUAudioBarView *weakSelf = self;
        _timer = [NSTimer timerWithTimeInterval:1.0/20 repeats:YES block:^(NSTimer *timer) { [weakSelf tickTock]; }];
        _timer.tolerance = .015;
        [NSRunLoop.mainRunLoop addTimer:_timer forMode:NSRunLoopCommonModes];
        [self tickTock];
    } else {
        [[MLAudio sharedAudio] resumeIfNeeded];
    }
}

- (void)setHidden:(BOOL)hidden { [super setHidden:hidden]; [self updateMetering]; }

- (void) setBelow:(CGFloat)below {
    _below = below;
}

- (void) setAbove:(CGFloat)above {
    _above = above;
}

- (void) tickTock {
    CGFloat previous = _value;
    CGFloat below = [[NSUserDefaults standardUserDefaults] floatForKey:@"AudioVADBelow"];
    CGFloat above = [[NSUserDefaults standardUserDefaults] floatForKey:@"AudioVADAbove"];
    BOOL thresholdsChanged = _below != below || _above != above;
    _below = below; _above = above;
    MLAudio *audio = [MLAudio sharedAudio];
    MLAudioSettings settings;
    [audio readAudioSettings:&settings];
    if (settings.enablePreprocessor && settings.vadKind == MLVADKindSignalToNoise) {
        _value = [audio speechProbablity];
    } else {
        _value = ([audio peakCleanMic] + 96.0)/96.0;
    }
    _value = MIN(1, MAX(0, _value));
    if (thresholdsChanged || fabs(_value-previous)*self.bounds.size.width >= 1 || !_levelLabel.text.length) {
        NSString *state = _value >= _above ? NSLocalizedString(@"Speech Detected", nil) : _value < _below ? NSLocalizedString(@"Below Silence Threshold", nil) : NSLocalizedString(@"Detecting Speech", nil);
        _progress.progress = _value;
        _progress.progressTintColor = _value >= _above ? UIColor.systemGreenColor : _value < _below ? UIColor.systemRedColor : UIColor.systemOrangeColor;
        _progress.accessibilityValue = [NSString stringWithFormat:@"%@, %.0f%%", state, _value * 100];
        _levelLabel.text = state;
    }
}

@end
