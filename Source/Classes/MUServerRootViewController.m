// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUServerRootViewController.h"
#import "MUApplicationDelegate.h"
#import "MUServerViewController.h"
#import "MUServerCertificateTrustViewController.h"
#import "MUAccessTokenViewController.h"
#import "MUCertificateViewController.h"
#import "MUNotificationController.h"
#import "MUConnectionController.h"
#import "MUMessagesViewController.h"
#import "MUDatabase.h"

#import "MLClient.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 270100
static BOOL MUVoiceControlsOnLeft(UITraitCollection *traits, UIUserInterfaceLayoutDirection direction) API_AVAILABLE(ios(27.1)) {
    // The bar edge is directional, but Duo's hardware-aligned bar does not
    // physically switch sides when the interface language changes.
    return traits.verticalBarEdge != UIVerticalBarEdgeUnspecified &&
        ((traits.verticalBarEdge == UIVerticalBarEdgeLeading) != (direction == UIUserInterfaceLayoutDirectionRightToLeft));
}
#endif

// Keep the message controller attached while the secondary display becomes a
// shared message/control surface. Folding never transfers a live conversation.
@interface MUServerSecondaryViewController : UIViewController
@property(nonatomic) BOOL showsVoiceControls;
@property(nonatomic) BOOL showsPaneTitle;
- (instancetype)initWithMessages:(MUMessagesViewController *)messages server:(MUServerViewController *)server;
@end

@implementation MUServerSecondaryViewController {
    MUMessagesViewController *_messages;
    __weak MUServerViewController *_server;
    UIView *_controlsView;
    UILabel *_paneTitleLabel;
    CGFloat _controlsHeight;
}
- (instancetype)initWithMessages:(MUMessagesViewController *)messages server:(MUServerViewController *)server {
    if ((self = [super init])) { _messages = messages; _server = server; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.clipsToBounds = YES;
    [self addChildViewController:_messages];
    [self.view addSubview:_messages.view];
    [_messages didMoveToParentViewController:self];
    _paneTitleLabel = [UILabel new];
    _paneTitleLabel.text = NSLocalizedString(@"Messages", nil);
    _paneTitleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    _paneTitleLabel.adjustsFontForContentSizeCategory = YES;
    _paneTitleLabel.numberOfLines = 0;
    [self.view addSubview:_paneTitleLabel];
    [self registerForTraitChanges:@[[UITraitPreferredContentSizeCategory class]] withHandler:^(__kindof MUServerSecondaryViewController *controller, UITraitCollection *previousTraits) {
        [controller.view setNeedsLayout];
    }];
    _controlsView = [UIView new];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    _controlsHeight = 220;
    [self.view addSubview:_controlsView];
    [self updateContent];
}
- (void)setShowsVoiceControls:(BOOL)showsVoiceControls {
    if (_showsVoiceControls == showsVoiceControls) return;
    _showsVoiceControls = showsVoiceControls;
    if (self.isViewLoaded) [self updateContent];
}
- (void)setShowsPaneTitle:(BOOL)showsPaneTitle {
    if (_showsPaneTitle == showsPaneTitle) return;
    _showsPaneTitle = showsPaneTitle;
    [self.viewIfLoaded setNeedsLayout];
}
- (void)updateContent {
    _controlsView.hidden = !_showsVoiceControls;
    if (_showsVoiceControls) _server.voiceControlsHostView = _controlsView;
    else if (_server.voiceControlsHostView == _controlsView) _server.voiceControlsHostView = nil;
    [self.view setNeedsLayout];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect content = self.view.bounds;
    CGRect safe = self.view.safeAreaLayoutGuide.layoutFrame;
    _paneTitleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle2 compatibleWithTraitCollection:self.traitCollection];
    _paneTitleLabel.hidden = !_showsPaneTitle || CGRectIsEmpty(content);
    CGFloat heading = _showsPaneTitle ? ceil([_paneTitleLabel sizeThatFits:CGSizeMake(MAX(1, safe.size.width - 40), CGFLOAT_MAX)].height) : 0;
    _paneTitleLabel.frame = CGRectMake(CGRectGetMinX(safe) + 20, CGRectGetMinY(safe) + 16, MAX(0, safe.size.width - 40), heading);
    CGFloat messageTop = _showsPaneTitle ? MIN(content.size.height, CGRectGetMaxY(_paneTitleLabel.frame) + 12) : 0;
    CGFloat footer = _showsVoiceControls ? MIN(_controlsHeight, content.size.height) : 0;
    _messages.view.frame = CGRectMake(0, messageTop, content.size.width, MAX(0, content.size.height - messageTop - footer));
    _controlsView.frame = _showsVoiceControls ? CGRectMake(0, content.size.height - footer, content.size.width, footer) : CGRectZero;
    [_server layoutVoiceControls];
    if (_showsVoiceControls) {
        CGFloat height = [_server voiceControlsContentHeight];
        if (height > 0) {
            CGFloat preferred = ceil(height + 24 + _controlsView.safeAreaInsets.top + _controlsView.safeAreaInsets.bottom);
            if (fabs(preferred - _controlsHeight) > .5) {
                _controlsHeight = preferred;
                [self.view setNeedsLayout];
            }
        }
    }
}
@end

@interface MUServerRootViewController () <MLConnectionDelegate, MLServerModelDelegate> {
    NSString *_reconnectStatus;
    MLConnection                *_connection;
    MLServerModel               *_model;
    
    NSInteger                   _segmentIndex;
    UISegmentedControl          *_segmentedControl;
    UIBarButtonItem             *_menuButton;
    UIBarButtonItem             *_paneButton;
    UIDeferredMenuElement       *_menuActions;
    UIBarButtonItem             *_disconnectButton;
    UIView                      *_sideVoiceControls;
    UIView                      *_nativePTTHost;

    MUServerViewController      *_serverView;
    MUMessagesViewController    *_messagesView;
    
    NSInteger                   _unreadMessages;
    UIViewController            *_conversationContainer;
    UIViewController            *_arrangementController;
    NSLayoutConstraint          *_arrangementBottom;
    MUServerSecondaryViewController *_secondaryView;
    BOOL                         _showingBothPanes, _usingFoldedControls, _usingBookLayout, _usingVerticalLayout, _usingSideVoiceControls, _usingNativeVoiceControls, _updatingLayout;
    NSInteger                    _lastVerticalBarEdge;
    CGRect                       _keyboardFrameInScreen;
    BOOL                         _hasKeyboardFrame;

}
- (NSArray<UIMenuElement *> *)serverMenuActions;
- (void)updateConversationLayout;
- (void)updateNativeArrangement;
- (void)layoutSideVoiceControls;
- (void)updateVoiceToolbar;
- (CGFloat)nativePTTHeight;
@end

@implementation MUServerRootViewController

- (id) initWithConnection:(MLConnection *)conn andServerModel:(MLServerModel *)model {
    if ((self = [super init])) {
        _connection = conn;
        _model = model;
        [_model addDelegate:self];
        
        _unreadMessages = 0;
        
        _serverView = [[MUServerViewController alloc] initWithServerModel:_model];
        _messagesView = [[MUMessagesViewController alloc] initWithServerModel:_model];
        

    }
    return self;
}

- (void) dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [_model removeDelegate:self];
}

#pragma mark - View lifecycle

- (void) viewDidLoad {
    [super viewDidLoad];
    self.view.keyboardLayoutGuide.followsUndockedKeyboard = YES;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboardFrameWillChange:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboardFrameWillChange:) name:UIKeyboardWillShowNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboardFrameWillChange:) name:UIKeyboardWillHideNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(voiceModeDidChange:) name:MUAudioTransmissionModeDidChangeNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(voiceModeDidChange:) name:MLAudioDidRestartNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(voiceSceneWillDeactivate:) name:UISceneWillDeactivateNotification object:nil];
    [self registerForTraitChanges:@[[UITraitHorizontalSizeClass class]] withHandler:^(__kindof MUServerRootViewController *controller, UITraitCollection *previousTraits) {
        [controller.view setNeedsLayout];
    }];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 270100
    if (@available(iOS 27.1, *)) {
        [self registerForTraitChanges:UITraitCollection.systemTraitsAffectingVerticalBarEdge withHandler:^(__kindof MUServerRootViewController *controller, UITraitCollection *previousTraits) {
            [controller.view setNeedsLayout];
        }];
    }
#endif

    _segmentedControl = [[UISegmentedControl alloc] initWithItems:
                         [NSArray arrayWithObjects:
                            NSLocalizedString(@"Server", nil),
                            NSLocalizedString(@"Messages", nil),
                          nil]];
    
    _segmentIndex = 0;
    
    _segmentedControl.selectedSegmentIndex = _segmentIndex;
    [_segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    
    __weak MUServerRootViewController *weakSelf = self;
    UIDeferredMenuElement *actions = [UIDeferredMenuElement elementWithUncachedProvider:^(void (^completion)(NSArray<UIMenuElement *> *)) {
        completion([weakSelf serverMenuActions] ?: @[]);
    }];
    _menuActions = actions;
    _menuButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"ellipsis.circle"] menu:[UIMenu menuWithChildren:@[actions]]];
    _menuButton.accessibilityLabel = NSLocalizedString(@"Server", nil);
    UIDeferredMenuElement *panes = [UIDeferredMenuElement elementWithUncachedProvider:^(void (^completion)(NSArray<UIMenuElement *> *)) {
        MUServerRootViewController *controller = weakSelf;
        if (!controller) { completion(@[]); return; }
        NSMutableArray<UIMenuElement *> *items = [NSMutableArray array];
        for (NSInteger index = 0; index < 2; index++) {
            UIAction *action = [UIAction actionWithTitle:[controller->_segmentedControl titleForSegmentAtIndex:index]
                image:[UIImage systemImageNamed:index == 0 ? @"list.bullet" : @"bubble.left.and.bubble.right"] identifier:nil handler:^(UIAction *action) {
                MUServerRootViewController *owner = weakSelf;
                if (!owner) return;
                owner->_segmentedControl.selectedSegmentIndex = index;
                [owner segmentChanged:nil];
            }];
            action.state = controller->_segmentedControl.selectedSegmentIndex == index ? UIMenuElementStateOn : UIMenuElementStateOff;
            [items addObject:action];
        }
        completion(items);
    }];
    _paneButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"rectangle.split.2x1"] menu:[UIMenu menuWithChildren:@[panes]]];
    _paneButton.title = [NSString stringWithFormat:@"%@ / %@", NSLocalizedString(@"Server", nil), NSLocalizedString(@"Messages", nil)];
    
    _disconnectButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"xmark"] style:UIBarButtonItemStylePlain target:self action:@selector(disconnectButtonClicked:)];
    _disconnectButton.tintColor = UIColor.systemRedColor;
    _disconnectButton.accessibilityLabel = NSLocalizedString(@"Disconnect", nil);
    _disconnectButton.title = NSLocalizedString(@"Disconnect", nil);
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 270100
    if (@available(iOS 27.1, *)) {
        _disconnectButton.axisBehavior = UIBarButtonItemAxisBehaviorVerticalPreferred;
        _disconnectButton.visibilityPriority = UIBarButtonItemVisibilityPriorityHigh;
    }
#endif
    
    [_segmentedControl sizeToFit];
    CGRect segmentFrame = _segmentedControl.frame;
    segmentFrame.size.width = MAX(segmentFrame.size.width, 200.0f);
    segmentFrame.size.height = 32.0f;
    _segmentedControl.frame = segmentFrame;
    [self updateUnreadMessageCount];

    
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 270100
    if (@available(iOS 27.1, *)) {
        UIArrangementViewController *arrangement = [UIArrangementViewController new];
        _arrangementController = arrangement;
        // Keep navigation outside the arrangement and constrain its actual
        // bounds to usable content, including the software keyboard. Insets
        // alone leave a folded secondary pane underneath a full-half keyboard.
        _conversationContainer = [UIViewController new];
        _conversationContainer.view.backgroundColor = UIColor.systemBackgroundColor;
        _conversationContainer.view.keyboardLayoutGuide.followsUndockedKeyboard = YES;
        [_conversationContainer addChildViewController:arrangement];
        [_conversationContainer.view addSubview:arrangement.view];
        [arrangement didMoveToParentViewController:_conversationContainer];
        arrangement.view.translatesAutoresizingMaskIntoConstraints = NO;
        UILayoutGuide *content = _conversationContainer.view.safeAreaLayoutGuide;
        _arrangementBottom = [arrangement.view.bottomAnchor constraintEqualToAnchor:content.bottomAnchor];
        [NSLayoutConstraint activateConstraints:@[
            [arrangement.view.topAnchor constraintEqualToAnchor:content.topAnchor],
            [arrangement.view.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
            [arrangement.view.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
            _arrangementBottom
        ]];
        _secondaryView = [[MUServerSecondaryViewController alloc] initWithMessages:_messagesView server:_serverView];
        [self updateNativeArrangement];
        [arrangement setViewController:_serverView forPlacement:UIArrangementViewControllerViewPlacementPrimary animated:NO];
        [arrangement setViewController:_secondaryView forPlacement:UIArrangementViewControllerViewPlacementSecondary animated:NO];
        [self applyNavigationItemsToViewController:_conversationContainer];
        [self setViewControllers:@[_conversationContainer] animated:NO];
    } else
#endif
    {
        [self applyNavigationItemsToViewController:_serverView];
        [self setViewControllers:@[_serverView] animated:NO];
    }

    self.toolbar.barStyle = UIBarStyleDefault;
}

- (void)viewIsAppearing:(BOOL)animated {
    [super viewIsAppearing:animated];
    // UIKit has installed the scene's traits, safe area and reserved regions
    // before the first visible frame. Resolve the arrangement during entry,
    // rather than switching from the compact layout after presentation.
    [self updateConversationLayout];
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
}

- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    [self.view setNeedsLayout];
}

// Resolve layout from this scene's available space, including vertical system bars.
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self updateConversationLayout];
    [self updateVoiceToolbar];
    [self layoutSideVoiceControls];
}

static UIView *MUFirstResponderInView(UIView *view) {
    if (view.isFirstResponder) return view;
    for (UIView *child in view.subviews) {
        UIView *responder = MUFirstResponderInView(child);
        if (responder) return responder;
    }
    return nil;
}

- (void)keyboardFrameWillChange:(NSNotification *)notification {
    if (!self.viewIfLoaded.window || [notification.userInfo[UIKeyboardIsLocalUserInfoKey] isEqual:@NO]) return;
    _keyboardFrameInScreen = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    _hasKeyboardFrame = YES;
    [self.view setNeedsLayout];
}

- (void)voiceModeDidChange:(NSNotification *)notification {
    if (_usingSideVoiceControls || _usingNativeVoiceControls) [_serverView refreshVoiceControls];
    [self updateVoiceToolbar];
    [self.viewIfLoaded setNeedsLayout];
}

- (void)voiceSceneWillDeactivate:(NSNotification *)notification {
    if (notification.object == self.viewIfLoaded.window.windowScene) [_serverView cancelPushToTalk];
}

- (void)updateConversationLayout {
    if (_updatingLayout || !self.view.window || self.viewControllers.count != 1) return;
    BOOL wide = NO, foldedControls = NO, bookLayout = NO, verticalLayout = NO, sideVoiceControls = NO, nativeVoiceControls = NO;
    NSInteger verticalBarEdge = 0;
    UIView *responder = MUFirstResponderInView(_messagesView.viewIfLoaded);
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 270100
    if (@available(iOS 27.1, *)) {
        verticalBarEdge = self.traitCollection.verticalBarEdge;
        nativeVoiceControls = verticalBarEdge != UIVerticalBarEdgeUnspecified;
        BOOL controlsOnLeft = MUVoiceControlsOnLeft(self.traitCollection, self.view.effectiveUserInterfaceLayoutDirection);
        sideVoiceControls = !nativeVoiceControls && self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular;
        CGFloat railInset = sideVoiceControls ? 84 : 0;
        CGFloat pttHeight = nativeVoiceControls && [[NSUserDefaults.standardUserDefaults stringForKey:@"AudioTransmitMethod"] isEqualToString:@"ptt"] ? [self nativePTTHeight] : 0;
        CGRect usable = self.view.safeAreaLayoutGuide.layoutFrame;
        if (controlsOnLeft) usable.origin.x += railInset;
        usable.size.width = MAX(0, usable.size.width - railInset);
        usable.size.height = MAX(0, usable.size.height - pttHeight);
        CGFloat availableBottom = CGRectGetMaxY(usable);
        if (responder) {
            availableBottom = MIN(availableBottom, CGRectGetMinY(self.view.keyboardLayoutGuide.layoutFrame) - pttHeight);
            // A keyboard on the lower display may not invalidate the navigation
            // container's guide. Resolve its system frame in this scene as well.
            if (_hasKeyboardFrame) {
                CGRect keyboard = [self.view convertRect:_keyboardFrameInScreen fromCoordinateSpace:self.view.window.windowScene.screen.coordinateSpace];
                if (!CGRectIsEmpty(CGRectIntersection(usable, keyboard)) && keyboard.size.width >= usable.size.width * .5)
                    availableBottom = MIN(availableBottom, CGRectGetMinY(keyboard) - pttHeight);
            }
        }
        // Reconcile pane visibility and keyboard geometry in one layout pass.
        // Resizing the native arrangement directly from a child keyboard guide
        // can hide its focused secondary pane before this controller can react.
        _arrangementBottom.constant = MIN(0, availableBottom - (CGRectGetMaxY(self.view.safeAreaLayoutGuide.layoutFrame) - pttHeight));
        // These are content minima for the two panes, not display dimensions.
        verticalLayout = usable.size.height > usable.size.width;
        wide = self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular &&
            (verticalLayout ? usable.size.width >= 360 && availableBottom - CGRectGetMinY(usable) >= 240 + 240 :
             usable.size.width >= 280 + 280 && availableBottom - CGRectGetMinY(usable) >= 280);
        for (UIViewReservedRegion *region in [self.view reservedRegionsOfKind:UIViewReservedRegionKind.divisionRegionKind]) {
            CGRect division = region.frame;
            if (CGRectIsEmpty(CGRectIntersection(usable, division))) continue;
            sideVoiceControls = !nativeVoiceControls;
            if (!nativeVoiceControls && railInset == 0) {
                railInset = 84;
                if (controlsOnLeft) usable.origin.x += railInset;
                usable.size.width = MAX(0, usable.size.width - railInset);
            }
            if (division.size.width > division.size.height) {
                verticalLayout = YES;
                // Tabletop: visible channels above, conversation and controls below.
                wide = NO;
                // Keep the hierarchy unless the keyboard leaves no usable
                // conversation area on the lower side of the fold.
                foldedControls = usable.size.width >= 360 &&
                    CGRectGetMinY(division) - CGRectGetMinY(usable) >= 260 &&
                    availableBottom - CGRectGetMaxY(division) >= 260;
                if (!foldedControls && responder) _segmentedControl.selectedSegmentIndex = 1;
            } else {
                verticalLayout = NO;
                // Book: retain the same leading Server / trailing Messages hierarchy
                // as the unfolded split. The shared voice controls follow the bar edge.
                BOOL rtl = self.view.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
                CGFloat leading = rtl ? CGRectGetMaxX(usable) - CGRectGetMaxX(division) : CGRectGetMinX(division) - CGRectGetMinX(usable);
                CGFloat trailing = rtl ? CGRectGetMinX(division) - CGRectGetMinX(usable) : CGRectGetMaxX(usable) - CGRectGetMaxX(division);
                bookLayout = leading >= 280 && trailing >= 280 && availableBottom - CGRectGetMinY(usable) >= 280;
                wide = bookLayout;
                if (!wide && responder) _segmentedControl.selectedSegmentIndex = 1;
            }
            break;
        }
        UIEdgeInsets insets = _conversationContainer.additionalSafeAreaInsets;
        CGFloat leftInset = controlsOnLeft ? railInset : 0;
        CGFloat rightInset = controlsOnLeft ? 0 : railInset;
        if (insets.left != leftInset || insets.right != rightInset) {
            insets.left = leftInset;
            insets.right = rightInset;
            _conversationContainer.additionalSafeAreaInsets = insets;
        }

    }
#endif
    if (wide == _showingBothPanes && foldedControls == _usingFoldedControls && bookLayout == _usingBookLayout &&
        verticalLayout == _usingVerticalLayout &&
        sideVoiceControls == _usingSideVoiceControls && nativeVoiceControls == _usingNativeVoiceControls && verticalBarEdge == _lastVerticalBarEdge &&
        _segmentIndex == _segmentedControl.selectedSegmentIndex) return;
    _updatingLayout = YES;
    [MLAudio.sharedAudio setForceTransmit:NO];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 270100
    if (@available(iOS 27.1, *)) {
        _showingBothPanes = wide;
        _usingFoldedControls = foldedControls;
        _usingBookLayout = bookLayout;
        _usingVerticalLayout = verticalLayout;
        _usingSideVoiceControls = sideVoiceControls;
        _usingNativeVoiceControls = nativeVoiceControls;
        _lastVerticalBarEdge = verticalBarEdge;
        [self applyNavigationItemsToViewController:_conversationContainer];
        if (wide || foldedControls) {
            _conversationContainer.navigationItem.titleView = nil;
            _conversationContainer.navigationItem.title = nil;
            _conversationContainer.navigationItem.rightBarButtonItem = nil;
        } else {
            if (responder) _segmentedControl.selectedSegmentIndex = 1;
            [self applyNavigationItemsToViewController:_conversationContainer];
        }
        if (wide || foldedControls || _segmentedControl.selectedSegmentIndex == 1) {
            _unreadMessages = 0;
            [self updateUnreadMessageCount];
            [MUApplicationDelegate setApplicationBadgeCount:0];
        }
        _segmentIndex = _segmentedControl.selectedSegmentIndex;
        [self updateNativeArrangement];
    }
#endif
    _updatingLayout = NO;
    if (responder) {
        __weak UIView *weakResponder = responder;
        dispatch_async(dispatch_get_main_queue(), ^{ if (weakResponder.window) [weakResponder becomeFirstResponder]; });
    }
}

// Both children keep their placement for the lifetime of the connection. Collapsing
// a placement through its native dimensions avoids a controller handoff during folds.
- (void)updateNativeArrangement {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 270100
    if (@available(iOS 27.1, *)) {
        _serverView.voiceControlsInToolbar = _usingNativeVoiceControls;
        _serverView.voiceControlsAtSide = _usingSideVoiceControls;
        if (_usingSideVoiceControls && !_sideVoiceControls) {
            _sideVoiceControls = [UIView new];
            [self.view addSubview:_sideVoiceControls];
        }
        _sideVoiceControls.hidden = !_usingSideVoiceControls;
        _secondaryView.showsVoiceControls = _usingFoldedControls && !_usingSideVoiceControls && !_usingNativeVoiceControls;
        _serverView.voiceControlsHostView = _usingSideVoiceControls ? _sideVoiceControls : nil;
        [self layoutSideVoiceControls];
        [self updateVoiceToolbar];
        BOOL splitPanes = _showingBothPanes || _usingFoldedControls;
        _secondaryView.showsPaneTitle = splitPanes;
        _serverView.showsPaneTitle = splitPanes;
        UISplitArrangement *split = [UISplitArrangement splitArrangement];
        split.axes = (_usingFoldedControls || _usingVerticalLayout) ? UIAxisVertical : UIAxisHorizontal;
        for (NSUInteger index = 0; index < 2; index++) {
            BOOL visible = splitPanes || _segmentedControl.selectedSegmentIndex == index;
            UISplitArrangementViewProperties *properties = [UISplitArrangementViewProperties new];
            properties.layoutPriority = visible ? 1 : 0;
            if (splitPanes) {
                properties.width.minimum = [UISplitArrangementDimension absoluteDimension:280];
                properties.height.minimum = [UISplitArrangementDimension absoluteDimension:240];
                if (index == 0 && !_usingBookLayout) properties.width.preferred = [UISplitArrangementDimension fractionalDimension:.42];
            } else {
                UISplitArrangementDimension *zero = [UISplitArrangementDimension absoluteDimension:0];
                properties.width.minimum = zero;
                properties.height.minimum = zero;
                properties.width.preferred = visible ? [UISplitArrangementDimension fractionalDimension:1] : zero;
                properties.height.preferred = visible ? [UISplitArrangementDimension fractionalDimension:1] : zero;
                if (!visible) { properties.width.maximum = zero; properties.height.maximum = zero; }
            }
            [split setViewProperties:properties forPlacement:index == 0 ? UIArrangementViewControllerViewPlacementPrimary : UIArrangementViewControllerViewPlacementSecondary];
        }
        // A compact conversation above a horizontal fold still uses that axis.
        if (!splitPanes) split.axes = UIAxisHorizontal | UIAxisVertical;
        [(UIArrangementViewController *)_arrangementController updateArrangement:split animated:NO];
    }
#endif
}

- (void)updateVoiceToolbar {
    if (!_conversationContainer) return;
    NSArray *items = _usingNativeVoiceControls ? _serverView.voiceControlBarItems : nil;
    NSArray *current = _conversationContainer.toolbarItems;
    if (current != items && ![current isEqualToArray:items]) _conversationContainer.toolbarItems = items;
    if (self.isToolbarHidden == _usingNativeVoiceControls) [self setToolbarHidden:!_usingNativeVoiceControls animated:NO];
    BOOL ptt = _usingNativeVoiceControls && [[NSUserDefaults.standardUserDefaults stringForKey:@"AudioTransmitMethod"] isEqualToString:@"ptt"];
    CGFloat height = ptt ? [self nativePTTHeight] : 0;
    UIEdgeInsets insets = _conversationContainer.additionalSafeAreaInsets;
    if (insets.bottom != height) { insets.bottom = height; _conversationContainer.additionalSafeAreaInsets = insets; }
    if (ptt && !_nativePTTHost) {
        _nativePTTHost = [UIView new];
        [self.view addSubview:_nativePTTHost];
    }
    _nativePTTHost.hidden = !ptt;
    if (ptt) {
        CGRect area = self.view.safeAreaLayoutGuide.layoutFrame;
        CGFloat bottom = CGRectGetMaxY(area);
        if (MUFirstResponderInView(_messagesView.viewIfLoaded)) {
            bottom = MIN(bottom, CGRectGetMinY(self.view.keyboardLayoutGuide.layoutFrame));
            if (_hasKeyboardFrame) {
                CGRect keyboard = [self.view convertRect:_keyboardFrameInScreen fromCoordinateSpace:self.view.window.windowScene.screen.coordinateSpace];
                if (!CGRectIsEmpty(CGRectIntersection(area, keyboard))) bottom = MIN(bottom, CGRectGetMinY(keyboard));
            }
        }
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 270100
        if (@available(iOS 27.1, *)) for (UIViewReservedRegion *region in [self.view reservedRegionsOfKind:UIViewReservedRegionKind.divisionRegionKind]) {
            CGRect division = region.frame;
            if (division.size.height <= division.size.width) continue;
            if (MUVoiceControlsOnLeft(self.traitCollection, self.view.effectiveUserInterfaceLayoutDirection))
                area.size.width = MAX(0, CGRectGetMinX(division) - CGRectGetMinX(area));
            else {
                CGFloat right = CGRectGetMaxX(area);
                area.origin.x = MAX(area.origin.x, CGRectGetMaxX(division));
                area.size.width = MAX(0, right - area.origin.x);
            }
        }
#endif
        _nativePTTHost.frame = CGRectMake(area.origin.x, MAX(area.origin.y, bottom - height), area.size.width, height);
        _serverView.voiceControlsHostView = _nativePTTHost;
        [self.view bringSubviewToFront:_nativePTTHost];
        [_serverView layoutVoiceControls];
    } else if (_serverView.voiceControlsHostView == _nativePTTHost) {
        _serverView.voiceControlsHostView = _usingSideVoiceControls ? _sideVoiceControls : nil;
    }
}

- (CGFloat)nativePTTHeight {
    return ceil(MAX(96, [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline compatibleWithTraitCollection:self.traitCollection].lineHeight + 76));
}

// Keep the shared controls near the lower system bar edge, inside the content
// safe area. Never place custom controls in UIKit's navigation/status bar strip.
- (void)layoutSideVoiceControls {
    if (!_usingSideVoiceControls || !_sideVoiceControls) return;
    CGRect safe = self.view.safeAreaLayoutGuide.layoutFrame;
    CGFloat bottom = CGRectGetMaxY(safe) - 8;
    if (MUFirstResponderInView(_messagesView.viewIfLoaded)) {
        bottom = MIN(bottom, CGRectGetMinY(self.view.keyboardLayoutGuide.layoutFrame) - 8);
        if (_hasKeyboardFrame) {
            CGRect keyboard = [self.view convertRect:_keyboardFrameInScreen fromCoordinateSpace:self.view.window.windowScene.screen.coordinateSpace];
            if (!CGRectIsEmpty(CGRectIntersection(safe, keyboard))) bottom = MIN(bottom, CGRectGetMinY(keyboard) - 8);
        }
    }
    CGFloat height = 136;
    BOOL controlsOnLeft = NO;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 270100
    if (@available(iOS 27.1, *)) controlsOnLeft = MUVoiceControlsOnLeft(self.traitCollection, self.view.effectiveUserInterfaceLayoutDirection);
#endif
    CGFloat x = controlsOnLeft ? CGRectGetMinX(safe) + 10 : CGRectGetMaxX(safe) - 74;
    CGRect controls = CGRectMake(x, MAX(CGRectGetMinY(safe) + 8, bottom - height), 64, height);
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 270100
    if (@available(iOS 27.1, *)) {
        // Also respect camera and fold regions that intersect content.
        NSArray<UIViewReservedRegion *> *obstacles = [[self.view reservedRegionsOfKind:UIViewReservedRegionKind.occlusionRegionKind]
            arrayByAddingObjectsFromArray:[self.view reservedRegionsOfKind:UIViewReservedRegionKind.divisionRegionKind]];
        for (NSUInteger pass = 0; pass < obstacles.count; pass++) {
            BOOL moved = NO;
            for (UIViewReservedRegion *region in obstacles) {
                if (CGRectIsEmpty(CGRectIntersection(controls, region.frame))) continue;
                controls.origin.y = CGRectGetMinY(region.frame) - 8 - height;
                moved = YES;
            }
            if (!moved) break;
        }
    }
#endif
    _sideVoiceControls.frame = controls;
    [self.view bringSubviewToFront:_sideVoiceControls];
    [_serverView layoutVoiceControls];
}

- (void) applyNavigationItemsToViewController:(UIViewController *)controller {
    controller.navigationItem.prompt=_reconnectStatus;
    controller.navigationItem.titleView = _segmentedControl;
    controller.navigationItem.leftBarButtonItem = _disconnectButton;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 270100
    if (@available(iOS 27.1, *)) {
        // A custom title view cannot become a vertical bar item. Keep both
        // destinations available using a native, labelled symbol menu instead.
        BOOL vertical = self.traitCollection.verticalBarEdge != UIVerticalBarEdgeUnspecified;
        controller.navigationItem.titleView = vertical ? nil : _segmentedControl;
        controller.navigationItem.rightBarButtonItem = vertical ? _paneButton : nil;
        controller.navigationItem.additionalOverflowItems = _menuActions;
    } else
#endif
    {
        controller.navigationItem.rightBarButtonItem = _menuButton;
    }
}

- (void) disconnectButtonClicked:(id)sender {
    UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Disconnect", nil)
                                                                       message:NSLocalizedString(@"Leave this server?", nil)
                                                                preferredStyle:UIAlertControllerStyleAlert];
    [alertCtrl addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                   style:UIAlertActionStyleCancel
                                                 handler:nil]];
    [alertCtrl addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Disconnect", nil)
                                                   style:UIAlertActionStyleDestructive
                                                 handler:^(UIAlertAction *action) {
        [self requestDisconnectWithTitle:nil message:nil];
    }]];
    UIViewController *presenter = [self visibleViewController];
    if (presenter == nil) {
        presenter = self;
    }
    [presenter presentViewController:alertCtrl animated:YES completion:nil];
}

- (void) segmentChanged:(id)sender {
    if (_segmentedControl.selectedSegmentIndex == 0) [_messagesView.viewIfLoaded endEditing:YES];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 270100
    if (@available(iOS 27.1, *)) {
        [self updateConversationLayout];
    } else
#endif
    {
        UIViewController *selected = _segmentedControl.selectedSegmentIndex == 1 ? _messagesView : _serverView;
        [self applyNavigationItemsToViewController:selected];
        [self setViewControllers:@[selected] animated:NO];
    }
    
    if (_segmentedControl.selectedSegmentIndex == 1) { // Messages view
        _unreadMessages = 0;
        [self updateUnreadMessageCount];
        [MUApplicationDelegate setApplicationBadgeCount:0];
    }


    [[MLAudio sharedAudio] setForceTransmit:NO];
}

#pragma mark - MLConnection delegate

- (void)connection:(MLConnection *)connection willReconnectAfterDelay:(NSTimeInterval)delay attempt:(NSUInteger)attempt {
    NSString *status=[NSString stringWithFormat:NSLocalizedString(@"Reconnecting… (attempt %lu)",nil),(unsigned long)attempt];
    _reconnectStatus=status;self.topViewController.navigationItem.prompt=status;
    [_messagesView setConnectionReconnecting:YES];
    [_serverView cancelPushToTalk];
}
- (void)connectionDidRestoreSession:(MLConnection *)connection {
    _reconnectStatus=nil;self.topViewController.navigationItem.prompt=nil;
    [_messagesView resetRecipientAfterReconnect];
    [_serverView refreshVoiceControls];[MLAudio.sharedAudio resumeIfNeeded];
}
- (void)requestDisconnectWithTitle:(NSString *)title message:(NSString *)message {
    if(self.disconnectHandler)self.disconnectHandler(title,message);
    else [[MUConnectionController sharedController]disconnectFromServer];
}

#pragma mark - MLServerModel delegate

- (void) serverModel:(MLServerModel *)model userKicked:(MLUser *)user byUser:(MLUser *)actor forReason:(NSString *)reason {
    if (user == [model connectedUser]) {
        NSString *reasonMsg = reason ? reason : NSLocalizedString(@"(No reason)", nil);
        NSString *title = NSLocalizedString(@"You were kicked", nil);
        NSString *alertMsg = [NSString stringWithFormat:
                                NSLocalizedString(@"Kicked by %@ for reason: \"%@\"", @"Kicked by user for reason"),
                                    [actor userName], reasonMsg];
        
        [self requestDisconnectWithTitle:title message:alertMsg];
    }
}

- (void) serverModel:(MLServerModel *)model userBanned:(MLUser *)user byUser:(MLUser *)actor forReason:(NSString *)reason {
    if (user == [model connectedUser]) {
        NSString *reasonMsg = reason ? reason : NSLocalizedString(@"(No reason)", nil);
        NSString *title = NSLocalizedString(@"You were banned", nil);
        NSString *alertMsg = [NSString stringWithFormat:
                                NSLocalizedString(@"Banned by %@ for reason: \"%@\"", nil),
                                    [actor userName], reasonMsg];
        
        [self requestDisconnectWithTitle:title message:alertMsg];
    }
}

- (void) serverModel:(MLServerModel *)model permissionDenied:(MLPermission)perm forUser:(MLUser *)user inChannel:(MLChannel *)channel {
    [[MUNotificationController sharedController] addNotification:NSLocalizedString(@"Permission denied", nil) fromViewController:self];
}

- (void) serverModelInvalidChannelNameError:(MLServerModel *)model {
    [[MUNotificationController sharedController] addNotification:NSLocalizedString(@"Invalid channel name", nil) fromViewController:self];
}

- (void) serverModelModifySuperUserError:(MLServerModel *)model {
    [[MUNotificationController sharedController] addNotification:NSLocalizedString(@"Cannot modify SuperUser", nil) fromViewController:self];
}

- (void) serverModelTextMessageTooLongError:(MLServerModel *)model {
    [[MUNotificationController sharedController] addNotification:NSLocalizedString(@"Message too long", nil) fromViewController:self];
}

- (void) serverModelTemporaryChannelError:(MLServerModel *)model {
    [[MUNotificationController sharedController] addNotification:NSLocalizedString(@"Not permitted in temporary channel", nil) fromViewController:self];
}

- (void) serverModel:(MLServerModel *)model missingCertificateErrorForUser:(MLUser *)user {
    if (user == nil) {
        [[MUNotificationController sharedController] addNotification:NSLocalizedString(@"Missing certificate", nil) fromViewController:self];
    } else {
        [[MUNotificationController sharedController] addNotification:NSLocalizedString(@"Missing certificate for user", nil) fromViewController:self];
    }
}

- (void) serverModel:(MLServerModel *)model invalidUsernameErrorForName:(NSString *)name {
    if (name == nil) {
        [[MUNotificationController sharedController] addNotification:NSLocalizedString(@"Invalid username", nil) fromViewController:self];
    } else {
        [[MUNotificationController sharedController] addNotification:[NSString stringWithFormat:NSLocalizedString(@"Invalid username: %@", nil), name] fromViewController:self];
    }
}

- (void) serverModelChannelFullError:(MLServerModel *)model {
    [[MUNotificationController sharedController] addNotification:NSLocalizedString(@"Channel is full", nil) fromViewController:self];
}

- (void) serverModel:(MLServerModel *)model permissionDeniedForReason:(NSString *)reason {
    if (reason == nil) {
        [[MUNotificationController sharedController] addNotification:NSLocalizedString(@"Permission denied", nil) fromViewController:self];
    } else {
        [[MUNotificationController sharedController] addNotification:[NSString stringWithFormat:
                                                                        NSLocalizedString(@"Permission denied: %@",
                                                                                          @"Permission denied with reason"),
                                                                        reason] fromViewController:self];
    }
}

- (void) serverModel:(MLServerModel *)model textMessageReceived:(MLTextMessage *)msg fromUser:(MLUser *)user {
    if (!_showingBothPanes && !_usingFoldedControls && _segmentedControl.selectedSegmentIndex != 1) { // When not in messages view
        _unreadMessages++;
        [self updateUnreadMessageCount];
    }
}

- (void)updateUnreadMessageCount {
    NSString *title = NSLocalizedString(@"Messages", nil);
    if (_unreadMessages) {
        NSString *count = _unreadMessages > 99 ? @"99+" : [NSString stringWithFormat:@"%ld", (long)_unreadMessages];
        title = [NSString stringWithFormat:@"%@ (%@)", title, count];
    }
    [_segmentedControl setTitle:title forSegmentAtIndex:1];
}

#pragma mark - Actions

- (NSArray<UIMenuElement *> *)serverMenuActions {
    MLUser *connUser = [_model connectedUser];
    BOOL inMessagesView = _showingBothPanes || _usingFoldedControls || _segmentedControl.selectedSegmentIndex == 1;
    __weak MUServerRootViewController *weakSelf = self;
    NSMutableArray<UIMenuElement *> *actions = [NSMutableArray array];
    NSArray<NSString *> *methods = @[@"vad", @"ptt", @"continuous"];
    NSArray<NSString *> *titles = @[NSLocalizedString(@"Voice Activated", nil), NSLocalizedString(@"Push-to-talk", nil), NSLocalizedString(@"Continuous", nil)];
    NSArray<NSString *> *symbols = @[@"waveform", @"hand.tap", @"mic.fill"];
    NSMutableArray<UIAction *> *modeActions = [NSMutableArray array];
    NSString *current = [NSUserDefaults.standardUserDefaults stringForKey:@"AudioTransmitMethod"] ?: @"vad";
    for (NSUInteger index = 0; index < methods.count; index++) {
        NSString *method = methods[index];
        UIAction *mode = [UIAction actionWithTitle:titles[index] image:[UIImage systemImageNamed:symbols[index]] identifier:method handler:^(UIAction *action) {
            [(MUApplicationDelegate *)UIApplication.sharedApplication.delegate setAudioTransmitMethod:method];
        }];
        mode.state = [method isEqualToString:current] ? UIMenuElementStateOn : UIMenuElementStateOff;
        [modeActions addObject:mode];
    }
    [actions addObject:[UIMenu menuWithTitle:NSLocalizedString(@"Transmission", nil) image:[UIImage systemImageNamed:@"mic"] identifier:nil options:UIMenuOptionsSingleSelection children:modeActions]];

    [actions addObject:[UIAction actionWithTitle:NSLocalizedString(@"Access Tokens", nil) image:[UIImage systemImageNamed:@"key"] identifier:nil handler:^(UIAction *action) {
        MUServerRootViewController *controller = weakSelf;
        if (!controller) return;
        MUAccessTokenViewController *tokenViewController = [[MUAccessTokenViewController alloc] initWithServerModel:controller->_model];
        UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:tokenViewController];
        [controller presentViewController:navCtrl animated:YES completion:nil];
    }]];
    
    if (_showingBothPanes || _usingFoldedControls || !inMessagesView) {
        [actions addObject:[UIAction actionWithTitle:NSLocalizedString(@"Certificates", nil) image:[UIImage systemImageNamed:@"checkmark.seal"] identifier:nil handler:^(UIAction *action) {
            MUServerRootViewController *controller = weakSelf;
            if (!controller) return;
            MUCertificateViewController *certView = [[MUCertificateViewController alloc] initWithCertificates:[controller->_model serverCertificates]];
            UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:certView];
            UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                        target:controller
                                                                                        action:@selector(childDoneButton:)];
            certView.navigationItem.leftBarButtonItem = doneButton;
            [controller presentViewController:navCtrl animated:YES completion:nil];
        }]];
    }
    
    if (connUser && !connUser.isAuthenticated) {
        [actions addObject:[UIAction actionWithTitle:NSLocalizedString(@"Self-Register", nil) image:[UIImage systemImageNamed:@"person.crop.circle.badge.checkmark"] identifier:nil handler:^(UIAction *action) {
            MUServerRootViewController *controller = weakSelf;
            if (!controller) return;
            NSString *title = NSLocalizedString(@"User Registration", nil);
            NSString *msg = [NSString stringWithFormat:
                             NSLocalizedString(@"You are about to register yourself on this server. "
                                               @"This cannot be undone, and your username cannot be changed once this is done. "
                                               @"You will forever be known as '%@' on this server.\n\n"
                                               @"Are you sure you want to register yourself?",
                                               @"Self-registration with given username"),
                             [connUser userName]];
            UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                                               message:msg
                                                                        preferredStyle:UIAlertControllerStyleAlert];
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"No", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil]];
            [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
                [controller->_model registerConnectedUser];
            }]];
            
            [controller presentViewController:alertCtrl animated:YES completion:nil];
        }]];
    }
    
    if (inMessagesView) {
        [actions addObject:[UIAction actionWithTitle:NSLocalizedString(@"Clear Messages", nil) image:[UIImage systemImageNamed:@"trash"] identifier:nil handler:^(UIAction *action) {
            MUServerRootViewController *controller = weakSelf;
            if (controller) [controller->_messagesView clearAllMessages];
        }]];
    }
    return actions;
}

- (void) childDoneButton:(id)sender {
    [[self presentedViewController] dismissViewControllerAnimated:YES completion:nil];
}

@end
