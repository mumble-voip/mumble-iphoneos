// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUServerViewController.h"
#import "MUUserStateAcessoryView.h"
#import "MUNotificationController.h"
#import "MUImage.h"
#import "MUServerTableViewCell.h"
#import "MUApplicationDelegate.h"

#import "MLClient.h"

static UIFont *MUServerFont(UIFontTextStyle style, BOOL bold, UITraitCollection *traits) {
    UIFont *font = [UIFont preferredFontForTextStyle:style compatibleWithTraitCollection:traits];
    return bold ? [UIFont fontWithDescriptor:[font.fontDescriptor fontDescriptorWithSymbolicTraits:font.fontDescriptor.symbolicTraits | UIFontDescriptorTraitBold] size:0] : font;
}

#pragma mark -
#pragma mark MUChannelNavigationItem

@interface MUChannelNavigationItem : NSObject {
    id         _object;
    NSInteger  _indentLevel;
}

+ (MUChannelNavigationItem *) navigationItemWithObject:(id)obj indentLevel:(NSInteger)indentLevel;
- (id) initWithObject:(id)obj indentLevel:(NSInteger)indentLevel;
- (id) object;
- (NSInteger) indentLevel;
@end

@implementation MUChannelNavigationItem

+ (MUChannelNavigationItem *) navigationItemWithObject:(id)obj indentLevel:(NSInteger)indentLevel {
    return [[MUChannelNavigationItem alloc] initWithObject:obj indentLevel:indentLevel];
}

- (id) initWithObject:(id)obj indentLevel:(NSInteger)indentLevel {
    if (self = [super init]) {
        _object = obj;
        _indentLevel = indentLevel;
    }
    return self;
}

- (id) object {
    return _object;
}

- (NSInteger) indentLevel {
    return _indentLevel;
}

@end

#pragma mark -
#pragma mark MUChannelNavigationViewController

@interface MUServerViewController () {
    MLServerModel                    *_serverModel;
    NSMutableArray                   *_modelItems;
    NSMutableDictionary              *_userIndexMap;
    NSMutableDictionary              *_channelIndexMap;
    BOOL                             _pttState;
    BOOL                             _viewIsVisible;
    CGSize                           _lastPaneSize;
    CGSize                           _lastVoiceHostSize;
    __weak UIView                    *_voiceControlsHostView;
    UIButton                         *_talkButton;
    UIStackView                      *_muteControls;
    UIButton                         *_microphoneButton, *_speakerButton;
    UIVisualEffectView               *_voiceDock;
    UILabel                         *_voiceStatusLabel;
    UIView                          *_channelHeader;
    UILabel                         *_paneTitleLabel, *_serverNameLabel, *_channelTitleLabel, *_channelMetaLabel;
    NSInteger                       _maximumIndent;
    BOOL                            _modelRefreshScheduled;
    NSArray<UIBarButtonItem *>       *_voiceControlBarItems;
}
- (NSInteger) indexForUser:(MLUser *)user;
- (void) reloadUser:(MLUser *)user;
- (void) rebuildModelArrayFromChannel:(MLChannel *)channel;
- (void) addChannelTreeToModel:(MLChannel *)channel indentLevel:(NSInteger)indentLevel;
- (void)scheduleModelRefresh;
- (BOOL)hasVisibleChannelPane;
- (void)configureCell:(MUServerTableViewCell *)cell item:(MUChannelNavigationItem *)item;
@end

@implementation MUServerViewController
@synthesize voiceControlsHostView = _voiceControlsHostView;

#pragma mark -
#pragma mark Initialization and lifecycle

- (id) initWithServerModel:(MLServerModel *)serverModel {
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        _serverModel = serverModel;
        [_serverModel addDelegate:self];
    }
    return self;
}

- (void) dealloc {
    [_serverModel removeDelegate:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = UIColor.systemBackgroundColor;
    self.tableView.separatorColor = UIColor.separatorColor;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 56;
    self.tableView.selfSizingInvalidation = UITableViewSelfSizingInvalidationEnabledIncludingConstraints;
    _channelHeader = [UIView new];
    _paneTitleLabel = [UILabel new];
    _paneTitleLabel.text = NSLocalizedString(@"Server", nil);
    _paneTitleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    _paneTitleLabel.hidden = !_showsPaneTitle;
    _serverNameLabel = [UILabel new];
    _channelTitleLabel = [UILabel new];
    _channelMetaLabel = [UILabel new];
    for (UILabel *label in @[_paneTitleLabel, _serverNameLabel, _channelTitleLabel, _channelMetaLabel]) {
        label.adjustsFontForContentSizeCategory = YES;
        [_channelHeader addSubview:label];
    }
    UIStackView *summary = [[UIStackView alloc] initWithArrangedSubviews:@[_paneTitleLabel, _serverNameLabel, _channelTitleLabel, _channelMetaLabel]];
    summary.axis = UILayoutConstraintAxisVertical; summary.spacing = 6; summary.translatesAutoresizingMaskIntoConstraints = NO;
    [_channelHeader addSubview:summary];
    for (UILabel *label in @[_paneTitleLabel, _serverNameLabel, _channelTitleLabel, _channelMetaLabel]) label.numberOfLines = 0;
    NSLayoutConstraint *summaryBottom = [summary.bottomAnchor constraintEqualToAnchor:_channelHeader.bottomAnchor constant:-16];
    // UITableView may temporarily impose a zero header height during updates.
    // Its encapsulated size takes precedence until the header is measured.
    summaryBottom.priority = UILayoutPriorityRequired - 1;
    [NSLayoutConstraint activateConstraints:@[
        [summary.leadingAnchor constraintEqualToAnchor:_channelHeader.safeAreaLayoutGuide.leadingAnchor constant:20], [summary.trailingAnchor constraintEqualToAnchor:_channelHeader.safeAreaLayoutGuide.trailingAnchor constant:-20],
        [summary.topAnchor constraintEqualToAnchor:_channelHeader.topAnchor constant:16], summaryBottom
    ]];
    [self updateChannelSummary];
    [self resizeChannelHeader];
    [self registerForTraitChanges:@[[UITraitPreferredContentSizeCategory class]] withHandler:^(__kindof MUServerViewController *controller, UITraitCollection *previousTraits) {
        [controller updateChannelSummary];
        [controller.tableView reloadData];
        if (controller.view.window) { [controller removeVoiceDock]; [controller installVoiceDock]; }
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _modelRefreshScheduled = NO;
    [self rebuildModelArrayFromChannel:_serverModel.rootChannel];
    [self.tableView reloadData];
    [self updateChannelSummary];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    _viewIsVisible = YES;
    [self layoutVoiceControls];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(appDidEnterBackground:) name:UISceneWillDeactivateNotification object:self.view.window.windowScene];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(audioSettingsUpdated:) name:MLAudioDidRestartNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(audioSettingsUpdated:) name:MUAudioTransmissionModeDidChangeNotification object:nil];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    // Resizing can cancel a touch without delivering its old control's release event.
    CGSize size = self.view.bounds.size;
    if (!CGSizeEqualToSize(size, _lastPaneSize)) {
        BOOL wasCollapsed = _lastPaneSize.width < 1 || _lastPaneSize.height < 1;
        _lastPaneSize = size;
        if (_pttState) [self talkOff:_talkButton];
        if (wasCollapsed && _viewIsVisible) [self scheduleModelRefresh];
    }
    [self layoutVoiceControls];
    [self resizeChannelHeader];
    CGFloat bottom = _voiceDock && !_voiceControlsHostView ? ceil(_voiceDock.bounds.size.height) + 12 : 0;
    if (self.tableView.contentInset.bottom != bottom) {
        UIEdgeInsets insets = self.tableView.contentInset;
        insets.bottom = bottom;
        self.tableView.contentInset = insets;
        self.tableView.verticalScrollIndicatorInsets = UIEdgeInsetsMake(0, 0, bottom, 0);
    }
}

- (void)resizeChannelHeader {
    CGFloat width = self.tableView.bounds.size.width;
    if (width < 1) return;
    // Measure native labels independently of UITableView's current header
    // height; an encapsulated height of zero must not become the fitting result.
    CGFloat contentWidth = MAX(1, width - _channelHeader.safeAreaInsets.left - _channelHeader.safeAreaInsets.right - 40);
    CGFloat height = 32;
    NSUInteger visibleLabels = 0;
    for (UILabel *label in @[_paneTitleLabel, _serverNameLabel, _channelTitleLabel, _channelMetaLabel]) {
        if (label.hidden) continue;
        visibleLabels++;
        height += ceil([label sizeThatFits:CGSizeMake(contentWidth, CGFLOAT_MAX)].height);
    }
    if (visibleLabels > 1) height += (visibleLabels - 1) * 6;
    CGRect frame = CGRectMake(0, 0, width, height);
    BOOL changed = !CGRectEqualToRect(_channelHeader.frame, frame);
    if (changed) _channelHeader.frame = frame;
    if (changed || self.tableView.tableHeaderView != _channelHeader)
        self.tableView.tableHeaderView = _channelHeader;
}

- (void)setShowsPaneTitle:(BOOL)showsPaneTitle {
    if (_showsPaneTitle == showsPaneTitle) return;
    _showsPaneTitle = showsPaneTitle;
    _paneTitleLabel.hidden = !showsPaneTitle;
    [self.viewIfLoaded setNeedsLayout];
}

- (void)updateChannelSummary {
    if (!self.isViewLoaded) return;
    _paneTitleLabel.font = MUServerFont(UIFontTextStyleTitle2, NO, self.traitCollection);
    MLChannel *channel = _serverModel.connectedUser.channel ?: _serverModel.rootChannel;
    _serverNameLabel.text = _serverModel.hostname.length ? _serverModel.hostname : NSLocalizedString(@"Current Channel", nil);
    _serverNameLabel.font = MUServerFont(UIFontTextStyleCaption1, NO, self.traitCollection);
    _serverNameLabel.textColor = UIColor.secondaryLabelColor;
    _channelTitleLabel.text = channel.channelName;
    _channelTitleLabel.font = MUServerFont(UIFontTextStyleTitle2, YES, self.traitCollection);
    _channelTitleLabel.textColor = UIColor.labelColor;
    NSString *members = channel.users.count == 1 ? NSLocalizedString(@"1 member", nil) : [NSString stringWithFormat:NSLocalizedString(@"%lu members", nil), (unsigned long)channel.users.count];
    _channelMetaLabel.text = [NSString stringWithFormat:@"%@ · %@", members, [self transmissionModeTitle]];
    _channelMetaLabel.font = MUServerFont(UIFontTextStyleSubheadline, NO, self.traitCollection);
    _channelMetaLabel.textColor = UIColor.secondaryLabelColor;
    [self.view setNeedsLayout];
}

- (NSString *)transmissionModeTitle {
    switch (MLAudio.sharedAudio.transmitType) {
        case MLTransmitTypeToggle: return NSLocalizedString(@"Push-to-talk", nil);
        case MLTransmitTypeContinuous: return NSLocalizedString(@"Continuous", nil);
        default: return NSLocalizedString(@"Voice Activated", nil);
    }
}

- (void)setVoiceControlsHostView:(UIView *)host {
    if (_voiceControlsHostView == host) return;
    [self removeVoiceDock];
    _voiceControlsHostView = host;
    [self layoutVoiceControls];
    [self.viewIfLoaded setNeedsLayout];
}

- (void)layoutVoiceControls {
    if (_voiceControlsInToolbar && !_voiceControlsHostView) {
        if (_voiceDock) [self removeVoiceDock];
        return;
    }
    UIView *host = _voiceControlsHostView ?: self.viewIfLoaded.superview;
    BOOL side = (_voiceControlsAtSide || _voiceControlsInToolbar) && _voiceControlsHostView.window;
    if ((!side && (!_viewIsVisible || ![self hasVisibleChannelPane])) || CGRectIsEmpty(host.bounds)) {
        if (_voiceDock) [self removeVoiceDock];
        return;
    }
    if (!CGSizeEqualToSize(host.bounds.size, _lastVoiceHostSize)) {
        _lastVoiceHostSize = host.bounds.size;
        if (_pttState) [self talkOff:_talkButton];
    }
    if (_voiceDock && _voiceDock.superview != host) [self removeVoiceDock];
    if (!_voiceDock) [self installVoiceDock];
}

- (CGFloat)voiceControlsContentHeight {
    if (!_voiceDock) return 0;
    return ceil([_voiceDock systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height);
}

- (void)setVoiceControlsAtSide:(BOOL)voiceControlsAtSide {
    if (_voiceControlsAtSide == voiceControlsAtSide) return;
    _voiceControlsAtSide = voiceControlsAtSide;
    [self removeVoiceDock];
    [self layoutVoiceControls];
    [self.viewIfLoaded setNeedsLayout];
}

- (void)installVoiceDock {
    if (_voiceControlsInToolbar && (!_voiceControlsHostView || ![[NSUserDefaults.standardUserDefaults stringForKey:@"AudioTransmitMethod"] isEqualToString:@"ptt"])) return;
    UIView *host = _voiceControlsHostView ?: self.view.superview;
    if (_voiceDock || !host.window || (!_voiceControlsAtSide && !_voiceControlsInToolbar && CGRectIsEmpty(self.view.bounds)) || CGRectIsEmpty(host.bounds)) return;
    UIVisualEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    BOOL supportsGlass = NO;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) {
        UIGlassContainerEffect *glass = [UIGlassContainerEffect new];
        glass.spacing = 12;
        effect = glass;
        supportsGlass = YES;
    }
#endif
    _voiceDock = [[UIVisualEffectView alloc] initWithEffect:effect];
    _voiceDock.translatesAutoresizingMaskIntoConstraints = NO;
    if (!supportsGlass) {
        _voiceDock.layer.cornerRadius = 24;
        _voiceDock.clipsToBounds = YES;
    }
    _voiceDock.traitOverrides.preferredContentSizeCategory = self.traitCollection.preferredContentSizeCategory;
    BOOL pushToTalk = MLAudio.sharedAudio.transmitType == MLTransmitTypeToggle;
    _voiceStatusLabel = [UILabel new];
    _voiceStatusLabel.font = MUServerFont(UIFontTextStyleFootnote, YES, self.traitCollection);
    _voiceStatusLabel.textAlignment = NSTextAlignmentCenter;
    _voiceStatusLabel.textColor = UIColor.secondaryLabelColor;
    _voiceStatusLabel.adjustsFontForContentSizeCategory = YES;
    _voiceStatusLabel.numberOfLines = 0;
    _voiceStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UIView *statusRow = [UIView new];
    statusRow.hidden = _voiceControlsAtSide || _voiceControlsInToolbar;
    [statusRow addSubview:_voiceStatusLabel];
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[statusRow]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = pushToTalk ? UIStackViewAlignmentFill : UIStackViewAlignmentCenter;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [_voiceDock.contentView addSubview:stack];
    if (pushToTalk) {
        _talkButton = [UIButton buttonWithType:UIButtonTypeSystem];
        UIButtonConfiguration *configuration;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
        if (@available(iOS 26.0, *)) configuration = [UIButtonConfiguration glassButtonConfiguration];
        else
#endif
            configuration = [UIButtonConfiguration grayButtonConfiguration];
        configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        CGFloat symbolSize = _voiceControlsAtSide ? 20 : 22;
        configuration.image = [MUImage symbolNamed:@"mic.fill" pointSize:symbolSize];
        configuration.preferredSymbolConfigurationForImage = [UIImageSymbolConfiguration configurationWithPointSize:symbolSize weight:UIImageSymbolWeightMedium];
        configuration.title = _voiceControlsAtSide ? nil : NSLocalizedString(@"Hold to speak", nil);
        configuration.imagePadding = _voiceControlsAtSide ? 0 : 10;
        configuration.contentInsets = _voiceControlsAtSide ? NSDirectionalEdgeInsetsMake(10, 8, 10, 8) : NSDirectionalEdgeInsetsMake(16, 20, 16, 20);
        configuration.titleLineBreakMode = NSLineBreakByWordWrapping;
        UIFont *titleFont = MUServerFont(UIFontTextStyleHeadline, NO, self.traitCollection);
        configuration.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey, id> *(NSDictionary<NSAttributedStringKey, id> *attributes) {
            NSMutableDictionary *updated = [attributes mutableCopy];
            updated[NSFontAttributeName] = titleFont;
            return updated;
        };
        configuration.baseForegroundColor = UIColor.labelColor;
        _talkButton.configuration = configuration;
        _talkButton.accessibilityLabel = NSLocalizedString(@"Push to Talk", nil);
        _talkButton.accessibilityHint = NSLocalizedString(@"Hold to speak", nil);
        __weak MUServerViewController *weakSelf = self;
        _talkButton.configurationUpdateHandler = ^(UIButton *button) {
            MUServerViewController *controller = weakSelf;
            BOOL active = button.highlighted || (controller && controller->_pttState);
            UIButtonConfiguration *updated = button.configuration;
            MLUser *user = controller ? controller->_serverModel.connectedUser : nil;
            BOOL muted = user.isSelfMuted || user.isMuted || user.isSuppressed;
            updated.baseForegroundColor = active ? UIColor.systemGreenColor : muted ? UIColor.systemRedColor : UIColor.labelColor;
            button.configuration = updated;
        };
        [_talkButton setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
        if (!_voiceControlsInToolbar) {
            _speakerButton = [UIButton buttonWithType:UIButtonTypeSystem];
            _speakerButton.configuration = [self muteButtonConfigurationWithSymbol:@"speaker.wave.2.fill" muted:NO];
            [_speakerButton addTarget:self action:@selector(toggleSpeaker:) forControlEvents:UIControlEventTouchUpInside];
        }
        _muteControls = [[UIStackView alloc] initWithArrangedSubviews:_speakerButton ? @[_talkButton, _speakerButton] : @[_talkButton]];
        _muteControls.axis = _voiceControlsAtSide ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
        _muteControls.alignment = UIStackViewAlignmentCenter;
        _muteControls.spacing = 12;
        [stack addArrangedSubview:_muteControls];
        [_talkButton.heightAnchor constraintGreaterThanOrEqualToConstant:(_voiceControlsAtSide || _voiceControlsInToolbar) ? 44 : 64].active = YES;
        if (_speakerButton) [NSLayoutConstraint activateConstraints:@[
            [_speakerButton.widthAnchor constraintEqualToConstant:_voiceControlsAtSide ? 44 : 64],
            [_speakerButton.heightAnchor constraintEqualToConstant:_voiceControlsAtSide ? 44 : 64]
        ]];
        if (_voiceControlsAtSide) {
            [_talkButton.widthAnchor constraintEqualToConstant:44].active = YES;
            [_talkButton.heightAnchor constraintEqualToConstant:44].active = YES;
        }
        [_talkButton addTarget:self action:@selector(talkOn:) forControlEvents:UIControlEventTouchDown];
        [_talkButton addTarget:self action:@selector(talkOff:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
    } else {
        _microphoneButton = [self floatingMuteButtonWithSymbol:@"mic.fill" action:@selector(toggleMicrophone:)];
        _speakerButton = [self floatingMuteButtonWithSymbol:@"speaker.wave.2.fill" action:@selector(toggleSpeaker:)];
        _muteControls = [[UIStackView alloc] initWithArrangedSubviews:@[_microphoneButton, _speakerButton]];
        _muteControls.axis = _voiceControlsAtSide ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
        _muteControls.alignment = UIStackViewAlignmentCenter;
        _muteControls.spacing = _voiceControlsAtSide ? 12 : 8;
        [stack addArrangedSubview:_muteControls];
    }
    [host addSubview:_voiceDock];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) {
        if (!_voiceControlsHostView) {
            // Include the controls and labels in the channel pane's scroll edge.
            UIScrollEdgeElementContainerInteraction *edge = [UIScrollEdgeElementContainerInteraction new];
            edge.scrollView = self.tableView;
            edge.edge = UIRectEdgeBottom;
            [_voiceDock addInteraction:edge];
            self.tableView.bottomEdgeEffect.style = UIScrollEdgeEffectStyle.softStyle;
        }
    }
#endif
    if (pushToTalk && !_voiceControlsAtSide) {
        NSLayoutConstraint *fill = [_voiceDock.widthAnchor constraintEqualToAnchor:host.safeAreaLayoutGuide.widthAnchor constant:-32];
        fill.priority = UILayoutPriorityDefaultHigh;
        fill.active = YES;
        [NSLayoutConstraint activateConstraints:@[
            [_voiceDock.widthAnchor constraintLessThanOrEqualToConstant:600]
        ]];
    }
    if (_voiceControlsAtSide) {
        [NSLayoutConstraint activateConstraints:@[
            [_voiceDock.centerYAnchor constraintEqualToAnchor:host.centerYAnchor],
            [_voiceDock.topAnchor constraintGreaterThanOrEqualToAnchor:host.topAnchor constant:8],
            [_voiceDock.bottomAnchor constraintLessThanOrEqualToAnchor:host.bottomAnchor constant:-8]
        ]];
    } else if (_voiceControlsHostView) {
        [NSLayoutConstraint activateConstraints:@[
            [_voiceDock.centerYAnchor constraintEqualToAnchor:host.safeAreaLayoutGuide.centerYAnchor],
            [_voiceDock.topAnchor constraintGreaterThanOrEqualToAnchor:host.safeAreaLayoutGuide.topAnchor constant:12],
            [_voiceDock.bottomAnchor constraintLessThanOrEqualToAnchor:host.safeAreaLayoutGuide.bottomAnchor constant:-12]
        ]];
    } else {
        [_speakerButton.bottomAnchor constraintEqualToAnchor:host.keyboardLayoutGuide.topAnchor constant:-4].active = YES;
        [_voiceDock.bottomAnchor constraintLessThanOrEqualToAnchor:host.keyboardLayoutGuide.topAnchor constant:-2].active = YES;
    }
    [NSLayoutConstraint activateConstraints:@[
        [_voiceDock.centerXAnchor constraintEqualToAnchor:_voiceControlsAtSide ? host.centerXAnchor : host.safeAreaLayoutGuide.centerXAnchor],
        [_voiceDock.leadingAnchor constraintGreaterThanOrEqualToAnchor:_voiceControlsAtSide ? host.leadingAnchor : host.safeAreaLayoutGuide.leadingAnchor constant:_voiceControlsAtSide ? 0 : 16],
        [_voiceDock.trailingAnchor constraintLessThanOrEqualToAnchor:_voiceControlsAtSide ? host.trailingAnchor : host.safeAreaLayoutGuide.trailingAnchor constant:_voiceControlsAtSide ? 0 : -16],
        [stack.leadingAnchor constraintEqualToAnchor:_voiceDock.contentView.leadingAnchor constant:10],
        [stack.trailingAnchor constraintEqualToAnchor:_voiceDock.contentView.trailingAnchor constant:-10],
        [stack.topAnchor constraintEqualToAnchor:_voiceDock.contentView.topAnchor constant:10],
        [stack.bottomAnchor constraintEqualToAnchor:_voiceDock.contentView.bottomAnchor constant:(_voiceControlsAtSide || _voiceControlsHostView) ? -10 : -2],
        [statusRow.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [_voiceStatusLabel.leadingAnchor constraintEqualToAnchor:statusRow.leadingAnchor],
        [_voiceStatusLabel.trailingAnchor constraintEqualToAnchor:statusRow.trailingAnchor],
        [_voiceStatusLabel.topAnchor constraintEqualToAnchor:statusRow.topAnchor],
        [_voiceStatusLabel.bottomAnchor constraintEqualToAnchor:statusRow.bottomAnchor]
    ]];
    [self updateMuteControls];
    [self.view setNeedsLayout];
    if (_voiceControlsHostView) [_voiceControlsHostView.superview setNeedsLayout];
}

- (void)removeVoiceDock {
    if (!_voiceDock && _voiceControlsInToolbar) return;
    if (_talkButton) [self talkOff:_talkButton];
    [_voiceDock removeFromSuperview];
    _voiceDock = nil; _muteControls = nil; _talkButton = nil;
    _microphoneButton = nil; _speakerButton = nil; _voiceStatusLabel = nil;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    _viewIsVisible = NO;
    _modelRefreshScheduled = NO;
    if (!_voiceControlsAtSide && !_voiceControlsInToolbar) [self removeVoiceDock];
    UIEdgeInsets insets = self.tableView.contentInset; insets.bottom = 0;
    self.tableView.contentInset = insets;
    self.tableView.verticalScrollIndicatorInsets = UIEdgeInsetsZero;
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)audioSettingsUpdated:(NSNotification *)notification {
    if (_voiceControlsAtSide || _voiceControlsInToolbar || ![self hasVisibleChannelPane]) return;
    [self refreshVoiceControls];
}

- (void)refreshVoiceControls {
    if (_voiceControlsInToolbar) {
        [self cancelPushToTalk];
        [self removeVoiceDock];
        _voiceControlBarItems = nil;
        [self layoutVoiceControls];
        [self updateChannelSummary];
        return;
    }
    [self removeVoiceDock];
    [self installVoiceDock];
    [self updateChannelSummary];
}

- (void)cancelPushToTalk {
    if (_pttState) [self talkOff:_talkButton];
}

- (void)setVoiceControlsInToolbar:(BOOL)value {
    if (_voiceControlsInToolbar == value) return;
    [self cancelPushToTalk];
    [self removeVoiceDock];
    _voiceControlsInToolbar = value;
    _voiceControlBarItems = nil;
    _talkButton = nil;
    [self layoutVoiceControls];
    [self.viewIfLoaded setNeedsLayout];
}

- (NSArray<UIBarButtonItem *> *)voiceControlBarItems {
    if (!_voiceControlBarItems) {
        UIBarButtonItem *microphone = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Mute Microphone", nil) image:[UIImage systemImageNamed:@"mic.fill"] target:self action:@selector(toggleMicrophone:) menu:nil];
        UIBarButtonItem *speaker = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Mute Speaker", nil) image:[UIImage systemImageNamed:@"speaker.wave.2.fill"] target:self action:@selector(toggleSpeaker:) menu:nil];
        _voiceControlBarItems = @[microphone, speaker];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 270100
        if (@available(iOS 27.1, *)) for (UIBarButtonItem *item in _voiceControlBarItems) {
            item.axisBehavior = UIBarButtonItemAxisBehaviorVerticalPreferred;
            item.visibilityPriority = UIBarButtonItemVisibilityPriorityHigh;
        }
#endif
        [self updateMuteControls];
    }
    return _voiceControlBarItems;
}

- (UIButton *)floatingMuteButtonWithSymbol:(NSString *)symbol action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.configuration = [self muteButtonConfigurationWithSymbol:symbol muted:NO];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    NSLayoutConstraint *preferredWidth = [button.widthAnchor constraintEqualToConstant:_voiceControlsAtSide ? 44 : 96];
    preferredWidth.priority = _voiceControlsAtSide ? UILayoutPriorityRequired : UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        preferredWidth,
        [button.widthAnchor constraintGreaterThanOrEqualToConstant:44],
        [button.heightAnchor constraintEqualToConstant:_voiceControlsAtSide ? 44 : 64]
    ]];
    return button;
}

- (UIButtonConfiguration *)muteButtonConfigurationWithSymbol:(NSString *)symbol muted:(BOOL)muted {
    UIButtonConfiguration *configuration;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) configuration = muted ? [UIButtonConfiguration prominentGlassButtonConfiguration] : [UIButtonConfiguration glassButtonConfiguration];
    else
#endif
        configuration = muted ? [UIButtonConfiguration filledButtonConfiguration] : [UIButtonConfiguration grayButtonConfiguration];
    configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    configuration.baseBackgroundColor = muted ? [UIColor systemRedColor] : nil;
    configuration.baseForegroundColor = muted ? [UIColor whiteColor] : [UIColor labelColor];
    CGFloat symbolSize = _voiceControlsAtSide ? 20 : 22;
    configuration.image = [MUImage symbolNamed:symbol pointSize:symbolSize];
    configuration.preferredSymbolConfigurationForImage = [UIImageSymbolConfiguration configurationWithPointSize:symbolSize weight:UIImageSymbolWeightMedium];
    configuration.contentInsets = _voiceControlsAtSide ? NSDirectionalEdgeInsetsMake(10, 8, 10, 8) : NSDirectionalEdgeInsetsMake(10, 12, 10, 12);
    return configuration;
}

- (void)updateMuteControls {
    if (!_muteControls && !_voiceControlBarItems) return;
    MLUser *user = _serverModel.connectedUser;
    BOOL microphoneMuted = user.isSelfMuted || user.isMuted || user.isSuppressed;
    BOOL speakerMuted = user.isSelfDeafened || user.isDeafened;
    _microphoneButton.enabled = user && !user.isMuted && !user.isSuppressed;
    _speakerButton.enabled = user && !user.isDeafened;
    _microphoneButton.selected = microphoneMuted;
    _speakerButton.selected = speakerMuted;
    if (_microphoneButton) _microphoneButton.configuration = [self muteButtonConfigurationWithSymbol:microphoneMuted ? @"mic.slash.fill" : @"mic.fill" muted:microphoneMuted];
    if (_speakerButton) _speakerButton.configuration = [self muteButtonConfigurationWithSymbol:speakerMuted ? @"speaker.slash.fill" : @"speaker.wave.2.fill" muted:speakerMuted];
    _microphoneButton.accessibilityLabel = microphoneMuted ? NSLocalizedString(@"Unmute Microphone", nil) : NSLocalizedString(@"Mute Microphone", nil);
    _speakerButton.accessibilityLabel = speakerMuted ? NSLocalizedString(@"Unmute Speaker", nil) : NSLocalizedString(@"Mute Speaker", nil);
    _microphoneButton.accessibilityValue = microphoneMuted ? NSLocalizedString(@"Muted", nil) : NSLocalizedString(@"On", nil);
    _speakerButton.accessibilityValue = speakerMuted ? NSLocalizedString(@"Muted", nil) : NSLocalizedString(@"On", nil);
    _talkButton.enabled = user && !microphoneMuted && !speakerMuted;
    if (_talkButton && !_talkButton.enabled && _pttState) [self talkOff:_talkButton];
    if (_voiceControlBarItems) {
        UIBarButtonItem *microphone = _voiceControlBarItems[0], *speaker = _voiceControlBarItems[1];
        microphone.title = microphoneMuted ? NSLocalizedString(@"Unmute Microphone", nil) : NSLocalizedString(@"Mute Microphone", nil);
        microphone.image = [UIImage systemImageNamed:microphoneMuted ? @"mic.slash.fill" : @"mic.fill"];
        microphone.enabled = user && !user.isMuted && !user.isSuppressed;
        microphone.tintColor = microphoneMuted ? UIColor.systemRedColor : UIColor.labelColor;
        speaker.title = speakerMuted ? NSLocalizedString(@"Unmute Speaker", nil) : NSLocalizedString(@"Mute Speaker", nil);
        speaker.image = [UIImage systemImageNamed:speakerMuted ? @"speaker.slash.fill" : @"speaker.wave.2.fill"];
        speaker.enabled = user && !user.isDeafened;
        speaker.tintColor = speakerMuted ? UIColor.systemRedColor : UIColor.labelColor;
    }
    [_talkButton setNeedsUpdateConfiguration];
    MLTalkState state = [self talkStateForUser:user];
    _voiceStatusLabel.text = speakerMuted ? NSLocalizedString(@"Audio off", nil) : microphoneMuted ? NSLocalizedString(@"Microphone muted", nil) : state != MLTalkStatePassive ? NSLocalizedString(@"Speaking", nil) : [self transmissionModeTitle];
    _voiceStatusLabel.textColor = speakerMuted || microphoneMuted ? UIColor.systemRedColor : state != MLTalkStatePassive ? UIColor.systemGreenColor : UIColor.secondaryLabelColor;
}

- (void)toggleMicrophone:(id)sender {
    MLUser *user = _serverModel.connectedUser;
    if (!user || user.isMuted || user.isSuppressed) return;
    BOOL mute = !user.isSelfMuted;
    [_serverModel setSelfMuted:mute andSelfDeafened:mute && user.isSelfDeafened];
}

- (void)toggleSpeaker:(id)sender {
    MLUser *user = _serverModel.connectedUser;
    if (!user || user.isDeafened) return;
    if (user.isSelfDeafened) {
        [_serverModel setSelfMuted:NO andSelfDeafened:NO];
    } else {
        [_serverModel setSelfMuted:user.isSelfMuted andSelfDeafened:YES];
    }
}

- (NSInteger) indexForUser:(MLUser *)user {
    NSNumber *number = [_userIndexMap objectForKey:[NSNumber numberWithInteger:[user session]]];
    if (number) {
        return [number integerValue];
    }
    return NSNotFound;
}

- (NSInteger) indexForChannel:(MLChannel *)channel {
    NSNumber *number = [_channelIndexMap objectForKey:[NSNumber numberWithInteger:[channel channelId]]];
    if (number) {
        return [number integerValue];
    }
    return NSNotFound;
}

- (void) reloadUser:(MLUser *)user {
    if (user == _serverModel.connectedUser) [self updateMuteControls];
    if (![self hasVisibleChannelPane]) return;
    NSInteger userIndex = [self indexForUser:user];
    if (userIndex != NSNotFound) {
        MUServerTableViewCell *cell = (id)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:userIndex inSection:0]];
        if (cell) [self configureCell:cell item:_modelItems[userIndex]];
    }
}

- (BOOL)hasVisibleChannelPane {
    UIView *view = self.viewIfLoaded;
    return view.window && !CGRectIsEmpty(view.bounds);
}

- (void)scheduleModelRefresh {
    // Initial protocol events arrive before this controller is presented and
    // may change several tree rows at once. Do not create a table for them or
    // infer insert/delete counts from individual callbacks.
    if (![self hasVisibleChannelPane] || _modelRefreshScheduled) return;
    _modelRefreshScheduled = YES;
    __weak MUServerViewController *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        MUServerViewController *controller = weakSelf;
        if (!controller || !controller->_modelRefreshScheduled) return;
        controller->_modelRefreshScheduled = NO;
        if (![controller hasVisibleChannelPane]) return;
        [controller rebuildModelArrayFromChannel:controller->_serverModel.rootChannel];
        [controller.tableView reloadData];
        [controller updateMuteControls];
    });
}

- (void) rebuildModelArrayFromChannel:(MLChannel *)channel {
    _maximumIndent = 0;
    _modelItems = [[NSMutableArray alloc] init];

    _userIndexMap = [[NSMutableDictionary alloc] init];

    _channelIndexMap = [[NSMutableDictionary alloc] init];

    [self addChannelTreeToModel:channel indentLevel:0];
    [self updateChannelSummary];
}



- (void) addChannelTreeToModel:(MLChannel *)channel indentLevel:(NSInteger)indentLevel {
    _maximumIndent = MAX(_maximumIndent, indentLevel + (channel.users.count ? 1 : 0));
    [_channelIndexMap setObject:[NSNumber numberWithUnsignedInteger:[_modelItems count]] forKey:[NSNumber numberWithInteger:[channel channelId]]];
    [_modelItems addObject:[MUChannelNavigationItem navigationItemWithObject:channel indentLevel:indentLevel]];

    for (MLUser *user in [channel users]) {
        [_userIndexMap setObject:[NSNumber numberWithUnsignedInteger:[_modelItems count]] forKey:[NSNumber numberWithUnsignedInteger:[user session]]];
        [_modelItems addObject:[MUChannelNavigationItem navigationItemWithObject:user indentLevel:indentLevel+1]];
    }
    for (MLChannel *chan in [channel channels]) {
        [self addChannelTreeToModel:chan indentLevel:indentLevel+1];
    }
}

#pragma mark - Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_modelItems count];
}

- (UIView *)channelAccessory:(MLChannel *)channel current:(BOOL)current {
    UILabel *count = [UILabel new];
    count.font = MUServerFont(UIFontTextStyleCaption1, NO, self.traitCollection);
    count.textColor = UIColor.secondaryLabelColor;
    count.text = [NSString stringWithFormat:@"%lu", (unsigned long)channel.users.count];
    NSMutableArray *views = [NSMutableArray array];
    if (current) {
        UIImageView *check = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.circle.fill"]];
        check.tintColor = UIColor.labelColor;
        check.contentMode = UIViewContentModeScaleAspectFit;
        [NSLayoutConstraint activateConstraints:@[[check.widthAnchor constraintEqualToConstant:18], [check.heightAnchor constraintEqualToConstant:18]]];
        [views addObject:check];
    }
    [views addObject:count];
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:views];
    stack.spacing = 8;
    stack.alignment = UIStackViewAlignmentCenter;
    CGSize textSize = [count sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
    CGSize size = CGSizeMake(ceil(textSize.width) + (current ? 26 : 0), MAX(ceil(textSize.height), current ? 18 : 0));
    stack.frame = (CGRect){CGPointZero, size};
    stack.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    // UITableView briefly reuses the old accessory size while changing rows.
    // Keep that encapsulated size off the stack's fixed-size checkmark.
    UIView *accessory = [[UIView alloc] initWithFrame:stack.frame];
    [accessory addSubview:stack];
    accessory.accessibilityElementsHidden = YES;
    return accessory;
}

- (MLTalkState)talkStateForUser:(MLUser *)user {
    if (user == _serverModel.connectedUser && MLAudio.sharedAudio.transmitType == MLTransmitTypeToggle && MLAudio.sharedAudio.forceTransmit)
        return MLTalkStateTalking;
    return user.talkState;
}

- (NSString *)statusForUser:(MLUser *)user {
    if (user.isSelfDeafened || user.isDeafened) return NSLocalizedString(@"Audio off", nil);
    if (user.isMuted || user.isSuppressed) return NSLocalizedString(@"Muted by server", nil);
    if (user.isSelfMuted) return NSLocalizedString(@"Microphone muted", nil);
    if (user.isLocalMuted) return NSLocalizedString(@"Locally muted", nil);
    switch ([self talkStateForUser:user]) {
        case MLTalkStateWhispering: return NSLocalizedString(@"Whispering", nil);
        case MLTalkStateShouting: return NSLocalizedString(@"Shouting", nil);
        case MLTalkStateTalking: return NSLocalizedString(@"Speaking", nil);
        default: return NSLocalizedString(@"Listening", nil);
    }
}

- (void)updateUserAppearance:(UITableViewCell *)cell user:(MLUser *)user {
    if (!cell) return;
    MLTalkState state = [self talkStateForUser:user];
    UIListContentConfiguration *content = [(UIListContentConfiguration *)cell.contentConfiguration copy];
    content.image = [MUImage userTalkSymbolForState:state];
    content.imageProperties.tintColor = [MUImage userTalkColorForState:state];
    NSString *status = [self statusForUser:user];
    content.secondaryText = user == _serverModel.connectedUser ? [NSString stringWithFormat:@"%@ · %@", NSLocalizedString(@"You", nil), status] : status;
    content.secondaryTextProperties.color = state != MLTalkStatePassive ? UIColor.systemGreenColor : UIColor.secondaryLabelColor;
    cell.contentConfiguration = content;
    NSMutableArray *values = [NSMutableArray arrayWithObject:content.secondaryText];
    if (user.isAuthenticated) [values addObject:NSLocalizedString(@"Authenticated", nil)];
    if (user.isPrioritySpeaker) [values addObject:NSLocalizedString(@"Priority speaker", nil)];
    cell.accessibilityValue = [values componentsJoinedByString:@", "];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MUServerTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ChannelNavigationCell"];
    if (!cell) cell = [[MUServerTableViewCell alloc] initWithReuseIdentifier:@"ChannelNavigationCell"];
    MUChannelNavigationItem *item = _modelItems[indexPath.row];
    [self configureCell:cell item:item];
    return cell;
}

- (void)configureCell:(MUServerTableViewCell *)cell item:(MUChannelNavigationItem *)item {
    id object = item.object;
    BOOL channelRow = [object isKindOfClass:MLChannel.class];
    cell.channelRow = channelRow;
    CGFloat indent = MIN(14, MAX(4, (self.tableView.bounds.size.width - 220) / MAX(1, _maximumIndent)));
    UIListContentConfiguration *content = [UIListContentConfiguration subtitleCellConfiguration];
    content.textProperties.font = MUServerFont(UIFontTextStyleBody, channelRow || object == _serverModel.connectedUser, self.traitCollection);
    content.textProperties.numberOfLines = 0;
    content.secondaryTextProperties.font = MUServerFont(UIFontTextStyleCaption1, NO, self.traitCollection);
    content.secondaryTextProperties.numberOfLines = 0;
    content.imageProperties.maximumSize = CGSizeMake(40, 24);
    content.imageProperties.reservedLayoutSize = CGSizeMake(40, 24);
    content.imageToTextPadding = 8;
    content.textToSecondaryTextVerticalPadding = 2;
    content.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(10, 16 + item.indentLevel * indent, 10, 16);
    cell.backgroundColor = channelRow ? UIColor.secondarySystemGroupedBackgroundColor : UIColor.systemBackgroundColor;
    if (channelRow) {
        MLChannel *channel = object;
        BOOL current = channel == _serverModel.connectedUser.channel;
        content.image = [MUImage channelSymbolForCurrentChannel:current];
        content.imageProperties.tintColor = UIColor.secondaryLabelColor;
        content.text = channel.channelName;
        cell.accessoryView = [self channelAccessory:channel current:current];
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        cell.accessibilityTraits = UIAccessibilityTraitButton;
        cell.accessibilityValue = [NSString stringWithFormat:@"%@%lu", current ? [NSLocalizedString(@"Current Channel", nil) stringByAppendingString:@", "] : @"", (unsigned long)channel.users.count];
    } else {
        MLUser *user = object;
        content.text = user.userName;
        cell.accessoryView = [MUUserStateAcessoryView viewForUser:user];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessibilityTraits = UIAccessibilityTraitStaticText;
    }
    cell.contentConfiguration = content;
    cell.accessibilityLabel = content.text;
    if (!channelRow) [self updateUserAppearance:cell user:object];
}

#pragma mark - Table view delegate

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    MUChannelNavigationItem *navItem = [_modelItems objectAtIndex:[indexPath row]];
    id object = [navItem object];
    if ([object class] == [MLChannel class]) {
        [_serverModel joinChannel:object];
    }

    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath { return UITableViewAutomaticDimension; }

#pragma mark - MLServerModel delegate

- (void) serverModel:(MLServerModel *)model joinedServerAsUser:(MLUser *)user {
    [self scheduleModelRefresh];
}

- (void) serverModel:(MLServerModel *)model userJoined:(MLUser *)user {
    [self scheduleModelRefresh];
}

- (void) serverModel:(MLServerModel *)model userDisconnected:(MLUser *)user {
}

- (void) serverModel:(MLServerModel *)model userLeft:(MLUser *)user {
    [self scheduleModelRefresh];
}

- (void)serverModel:(MLServerModel *)model userTalkStateChanged:(MLUser *)user {
    if (user == model.connectedUser) [self updateMuteControls];
    if (![self hasVisibleChannelPane]) return;
    NSInteger row = [self indexForUser:user];
    if (row == NSNotFound) return;
    [self updateUserAppearance:[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]] user:user];
}

- (void) serverModel:(MLServerModel *)model channelAdded:(MLChannel *)channel {
    [self scheduleModelRefresh];
}

- (void) serverModel:(MLServerModel *)model channelRemoved:(MLChannel *)channel {
    [self scheduleModelRefresh];
}

- (void) serverModel:(MLServerModel *)model channelMoved:(MLChannel *)channel {
    [self scheduleModelRefresh];
}

- (void) serverModel:(MLServerModel *)model channelRenamed:(MLChannel *)channel {
    [self scheduleModelRefresh];
}

- (void)serverModel:(MLServerModel *)model channelPositionChanged:(MLChannel *)channel {
    [self scheduleModelRefresh];
}

- (void)serverModel:(MLServerModel *)model userRenamed:(MLUser *)user {
    [self scheduleModelRefresh];
}

- (void) serverModel:(MLServerModel *)model userMoved:(MLUser *)user toChannel:(MLChannel *)chan fromChannel:(MLChannel *)prevChan byUser:(MLUser *)mover {
    [self scheduleModelRefresh];
}

- (void) serverModel:(MLServerModel *)model userSelfMuted:(MLUser *)user {
}

- (void) serverModel:(MLServerModel *)model userRemovedSelfMute:(MLUser *)user {
}

- (void) serverModel:(MLServerModel *)model userSelfMutedAndDeafened:(MLUser *)user {
}

- (void) serverModel:(MLServerModel *)model userRemovedSelfMuteAndDeafen:(MLUser *)user {
}

- (void) serverModel:(MLServerModel *)model userSelfMuteDeafenStateChanged:(MLUser *)user {
    [self reloadUser:user];
}

// --

- (void) serverModel:(MLServerModel *)model userMutedAndDeafened:(MLUser *)user byUser:(MLUser *)actor {
    [self reloadUser:user];
}

- (void) serverModel:(MLServerModel *)model userUnmutedAndUndeafened:(MLUser *)user byUser:(MLUser *)actor {
    [self reloadUser:user];
}

- (void) serverModel:(MLServerModel *)model userMuted:(MLUser *)user byUser:(MLUser *)actor {
    [self reloadUser:user];
}

- (void) serverModel:(MLServerModel *)model userUnmuted:(MLUser *)user byUser:(MLUser *)actor {
    [self reloadUser:user];
}

- (void) serverModel:(MLServerModel *)model userDeafened:(MLUser *)user byUser:(MLUser *)actor {
    [self reloadUser:user];
}

- (void) serverModel:(MLServerModel *)model userUndeafened:(MLUser *)user byUser:(MLUser *)actor {
    [self reloadUser:user];
}

- (void) serverModel:(MLServerModel *)model userSuppressed:(MLUser *)user byUser:(MLUser *)actor {
    [self reloadUser:user];
}

- (void) serverModel:(MLServerModel *)model userUnsuppressed:(MLUser *)user byUser:(MLUser *)actor {
    [self reloadUser:user];
}

- (void) serverModel:(MLServerModel *)model userMuteStateChanged:(MLUser *)user {
   [self reloadUser:user];
}

- (void) serverModel:(MLServerModel *)model userAuthenticatedStateChanged:(MLUser *)user {
    [self reloadUser:user];
}

- (void) serverModel:(MLServerModel *)model userPrioritySpeakerChanged:(MLUser *)user {
    [self reloadUser:user];
}

#pragma mark - PushToTalk

- (void) talkOn:(UIButton *)button {
    MLUser *user = _serverModel.connectedUser;
    if (!user || user.isSelfMuted || user.isMuted || user.isSuppressed || user.isSelfDeafened || user.isDeafened) return;
    _pttState = YES;
    [[MLAudio sharedAudio] setForceTransmit:YES];
    [button setNeedsUpdateConfiguration];
    [self reloadUser:_serverModel.connectedUser];
}

- (void) talkOff:(UIButton *)button {
    _pttState = NO;
    [[MLAudio sharedAudio] setForceTransmit:NO];
    [button setNeedsUpdateConfiguration];
    [self reloadUser:_serverModel.connectedUser];
}

#pragma mark - Background notification

- (void)appDidEnterBackground:(NSNotification *)notification {
    if (_talkButton) [self talkOff:_talkButton];
}

@end

