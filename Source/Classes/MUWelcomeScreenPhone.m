// Copyright 2009-2026 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by the BSD-style license in LICENSE.

#import "MUWelcomeScreenPhone.h"
#import "MUInterface.h"
#import "MUPublicServerListController.h"
#import "MUFavouriteServerListController.h"
#import "MULanServerListController.h"
#import "MUConnectionController.h"
#import "MUDatabase.h"
#import "MUFavouriteServer.h"
#import "MUFavouriteServerEditViewController.h"

static const CGFloat MUHomeSplitWidth = 700;
static const CGSize MUHomeSymbolSize = {24, 24};
static BOOL MUHomeServerRowsEqual(NSArray<MUFavouriteServer *> *left, NSArray<MUFavouriteServer *> *right) {
    if(left.count!=right.count)return NO;
    for(NSUInteger i=0;i<left.count;i++) {
        MUFavouriteServer *a=left[i], *b=right[i];
        if(a.port!=b.port || ![(a.hostName ?: @"") isEqualToString:b.hostName ?: @""] || ![(a.displayName ?: @"") isEqualToString:b.displayName ?: @""])return NO;
    }
    return YES;
}
static NSArray *MUHomeLANRows(NSArray<NSNetService *> *services) {
    NSMutableArray *rows=[NSMutableArray arrayWithCapacity:services.count];
    for(NSNetService *service in services)[rows addObject:@[service.name ?: @"",service.hostName ?: @"",@(service.port)]];
    return rows;
}

@interface MUHomeSectionHeader : UITableViewHeaderFooterView
@property(nonatomic, readonly) UIButton *manageButton;
- (void)setTitle:(NSString *)title count:(NSNumber *)count;
@end

@implementation MUHomeSectionHeader {
    UILabel *_titleLabel;
    NSString *_sectionTitle;
    NSNumber *_sectionCount;
    UIView *_space;
    UIStackView *_contentStack;
}
- (instancetype)initWithReuseIdentifier:(NSString *)identifier {
    if ((self = [super initWithReuseIdentifier:identifier])) {
        _titleLabel = [UILabel new];
        _titleLabel.numberOfLines = 0;
        _titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
        _titleLabel.accessibilityTraits |= UIAccessibilityTraitHeader;
        UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
        configuration.title = NSLocalizedString(@"Manage", nil);
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(8, 0, 8, 0);
        _manageButton = [UIButton buttonWithConfiguration:configuration primaryAction:nil];
        _manageButton.accessibilityLabel = NSLocalizedString(@"Manage Favourites", nil);
        _manageButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
        [_manageButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [_manageButton.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
        _space = [UIView new];
        [_space setContentHuggingPriority:UILayoutPriorityDefaultLow-1 forAxis:UILayoutConstraintAxisHorizontal];
        UIStackView *labels = [[UIStackView alloc] initWithArrangedSubviews:@[_titleLabel, _space, _manageButton]];
        _contentStack = labels;
        labels.alignment = UIStackViewAlignmentCenter;
        labels.spacing = 8;
        labels.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:labels];
        self.contentView.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(12, 0, 6, 0);
        UILayoutGuide *margins = self.contentView.layoutMarginsGuide;
        [NSLayoutConstraint activateConstraints:@[
            [labels.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor],
            [labels.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor],
            [labels.topAnchor constraintEqualToAnchor:margins.topAnchor],
            [labels.bottomAnchor constraintEqualToAnchor:margins.bottomAnchor]
        ]];
        [self registerForTraitChanges:@[UITraitPreferredContentSizeCategory.class] withHandler:^(__kindof MUHomeSectionHeader *header, UITraitCollection *previousTraits) {
            [header updateLayoutForTextSize];
        }];
    }
    return self;
}
- (void)setTitle:(NSString *)title count:(NSNumber *)count {
    _sectionTitle = title;
    _sectionCount = count;
    [self updateLayoutForTextSize];
}
- (void)updateLayoutForTextSize {
    BOOL large = UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
    _contentStack.axis = large ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    _contentStack.alignment = large ? UIStackViewAlignmentFill : UIStackViewAlignmentCenter;
    _space.hidden = large;
    UIFont *font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline compatibleWithTraitCollection:self.traitCollection];
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:_sectionTitle ?: @"" attributes:@{NSFontAttributeName:font, NSForegroundColorAttributeName:UIColor.labelColor}];
    if (_sectionCount) {
        NSString *count = [@"  " stringByAppendingString:[NSNumberFormatter localizedStringFromNumber:_sectionCount numberStyle:NSNumberFormatterDecimalStyle]];
        UIFont *countFont = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote compatibleWithTraitCollection:self.traitCollection];
        [text appendAttributedString:[[NSAttributedString alloc] initWithString:count attributes:@{NSFontAttributeName:countFont, NSForegroundColorAttributeName:UIColor.secondaryLabelColor}]];
    }
    _titleLabel.attributedText = text;
}
@end

@interface MUWelcomeScreenPhone () <UITableViewDataSource, UITableViewDelegate> {
    NSArray<MUFavouriteServer *> *_favouriteServers;
    NSArray<MUFavouriteServer *> *_recentServers;
    NSArray<NSNetService *> *_lanServices;
    MULanServerListController *_lanDiscovery;
    UITableView *_lanTable;
    NSLayoutConstraint *_singleColumnTrailing, *_splitColumnTrailing;
    UIStackView *_actions;
    NSLayoutConstraint *_actionsHeight;
    BOOL _homeVisible, _loadingFavourites, _lanDiscoveryFailed, _twoColumns, _rowUpdateInProgress;
    NSUInteger _favouritesGeneration;
    NSArray<MUFavouriteServer *> *_pendingFavourites;
    NSArray<MUFavouriteServer *> *_pendingRecentServers;
    BOOL _pendingLANRefresh;
    NSArray *_lanDisplaySnapshot;
    BOOL _homeUpdateScheduled;
    NSUInteger _homeUpdateGeneration;
}

typedef NS_ENUM(NSInteger, MUHomeList) {
    MUHomeListFavourites,
    MUHomeListLAN,
    MUHomeListRecent
};
@end

@implementation MUWelcomeScreenPhone

- (id)init {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _favouriteServers = @[];
        _recentServers = @[];
        _lanServices = @[];
        _lanDisplaySnapshot=@[];
        self.title = NSLocalizedString(@"Home", nil);
        MUApplyRootLargeTitle(self);
    }
    return self;
}

- (void)loadView {
    UIView *root = [[UIView alloc] init];
    root.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.view = root;

    UIStackView *actions = [[UIStackView alloc] init];
    _actions = actions;
    actions.axis = UILayoutConstraintAxisHorizontal;
    actions.distribution = UIStackViewDistributionFillEqually;
    actions.spacing = 12;
    actions.translatesAutoresizingMaskIntoConstraints = NO;
    UIButton *quick = [self homeButtonWithTitle:NSLocalizedString(@"Quick Connect", nil) subtitle:NSLocalizedString(@"Connect directly", nil) symbol:@"arrow.left.arrow.right" action:@selector(showQuickConnect:)];
    [actions addArrangedSubview:quick];
    UIButton *publicServers = [self homeButtonWithTitle:NSLocalizedString(@"Public Servers", nil) subtitle:NSLocalizedString(@"Browse servers", nil) symbol:@"globe" action:@selector(showPublicServers:)];
    [actions addArrangedSubview:publicServers];
    [root addSubview:actions];

    // Give each table a viewport independent of its scrolling content size.
    // A stack view's fitting pass can remeasure a table during bottom bounce.
    UIView *lists = [[UIView alloc] init];
    lists.translatesAutoresizingMaskIntoConstraints = NO;
    UITableView *favourites = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    UITableView *lan = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _lanTable = lan;
    NSArray<UITableView *> *tables = @[favourites, lan];
    for (UITableView *table in tables) {
        table.dataSource = self;
        table.delegate = self;
        table.rowHeight = UITableViewAutomaticDimension;
        table.estimatedRowHeight = 72;
        table.sectionHeaderHeight = UITableViewAutomaticDimension;
        table.estimatedSectionHeaderHeight = 56;
        table.sectionFooterHeight = 8;
        table.estimatedSectionFooterHeight = 8;
        [table registerClass:MUHomeSectionHeader.class forHeaderFooterViewReuseIdentifier:@"homeHeader"];
        table.backgroundColor = UIColor.clearColor;
        table.sectionHeaderTopPadding = 0;
        table.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        table.insetsLayoutMarginsFromSafeArea = NO;
        table.translatesAutoresizingMaskIntoConstraints = NO;
        [lists addSubview:table];
        [NSLayoutConstraint activateConstraints:@[
            [table.topAnchor constraintEqualToAnchor:lists.topAnchor],
            [table.bottomAnchor constraintEqualToAnchor:lists.bottomAnchor]
        ]];
    }
    self.tableView = favourites;
    _singleColumnTrailing = [favourites.trailingAnchor constraintEqualToAnchor:lists.trailingAnchor];
    _splitColumnTrailing = [favourites.trailingAnchor constraintEqualToAnchor:lists.centerXAnchor constant:-6];
    [NSLayoutConstraint activateConstraints:@[
        [favourites.leadingAnchor constraintEqualToAnchor:lists.leadingAnchor],
        _singleColumnTrailing,
        [lan.leadingAnchor constraintEqualToAnchor:lists.centerXAnchor constant:6],
        [lan.trailingAnchor constraintEqualToAnchor:lists.trailingAnchor]
    ]];
    lan.hidden = YES;
    [root addSubview:lists];

    UILayoutGuide *safe = root.safeAreaLayoutGuide;
    _actionsHeight = [actions.heightAnchor constraintEqualToConstant:76];
    [NSLayoutConstraint activateConstraints:@[
        [actions.topAnchor constraintEqualToAnchor:safe.topAnchor constant:8],
        [actions.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20],
        [actions.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20],
        _actionsHeight,
        [lists.topAnchor constraintEqualToAnchor:actions.bottomAnchor constant:8],
        [lists.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [lists.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [lists.bottomAnchor constraintEqualToAnchor:root.bottomAnchor]
    ]];
}

- (UIButton *)homeButtonWithTitle:(NSString *)title subtitle:(NSString *)subtitle symbol:(NSString *)symbol action:(SEL)action {
    UIButtonConfiguration *configuration;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) configuration = [UIButtonConfiguration glassButtonConfiguration];
    else
#endif
        configuration = [UIButtonConfiguration grayButtonConfiguration];
    configuration.title = title;
    configuration.subtitle = subtitle;
    configuration.titleAlignment = UIButtonConfigurationTitleAlignmentLeading;
    configuration.titlePadding = 4;
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(14, 12, 14, 12);
    configuration.imageColorTransformer = ^UIColor *(UIColor *color) { return UIColor.labelColor; };
    configuration.preferredSymbolConfigurationForImage = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightRegular];
    configuration.image = [UIImage systemImageNamed:symbol];
    configuration.imagePadding = 8;
    configuration.cornerStyle = UIButtonConfigurationCornerStyleFixed;
    UIBackgroundConfiguration *background = configuration.background;
    background.cornerRadius = 20;
    configuration.background = background;
    configuration.titleLineBreakMode = NSLineBreakByWordWrapping;
    configuration.imagePlacement = NSDirectionalRectEdgeLeading;
    configuration.baseForegroundColor = UIColor.labelColor;
    UIButton *button = [UIButton buttonWithConfiguration:configuration primaryAction:nil];
    button.configurationUpdateHandler = ^(UIButton *updated) {
        UIButtonConfiguration *current = updated.configuration;
        UITraitCollection *traits = updated.traitCollection;
        UIFont *titleFont = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold] compatibleWithTraitCollection:traits];
        UIFont *subtitleFont = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1 compatibleWithTraitCollection:traits];
        current.titleTextAttributesTransformer = ^NSDictionary *(NSDictionary *attributes) {
            NSMutableDictionary *result = [attributes mutableCopy];
            result[NSFontAttributeName] = titleFont;
            return result;
        };
        current.subtitleTextAttributesTransformer = ^NSDictionary *(NSDictionary *attributes) {
            NSMutableDictionary *result = [attributes mutableCopy];
            result[NSFontAttributeName] = subtitleFont;
            result[NSForegroundColorAttributeName] = UIColor.secondaryLabelColor;
            return result;
        };
        CGFloat symbolSize = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledValueForValue:20 compatibleWithTraitCollection:traits];
        current.preferredSymbolConfigurationForImage = [UIImageSymbolConfiguration configurationWithPointSize:symbolSize weight:UIImageSymbolWeightRegular];
        updated.configuration = current;
    };
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:76].active = YES;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    button.accessibilityLabel = title;
    button.accessibilityHint = subtitle;
    return button;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setContentScrollView:self.tableView forEdge:NSDirectionalRectEdgeTop];
    [self updateRootLargeTitle];
    [self registerForTraitChanges:@[UITraitPreferredContentSizeCategory.class] withHandler:^(__kindof MUWelcomeScreenPhone *controller, UITraitCollection *previousTraits) {
        for (UIButton *button in controller->_actions.arrangedSubviews) [button setNeedsUpdateConfiguration];
        [controller.view setNeedsLayout];
    }];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(appEnteredBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(appBecameActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 270100
    if (@available(iOS 27.1, *)) {
        [self registerForTraitChanges:UITraitCollection.systemTraitsAffectingVerticalBarEdge withHandler:^(__kindof MUWelcomeScreenPhone *controller, UITraitCollection *previousTraits) {
            [controller updateRootLargeTitle];
        }];
    }
#endif
}

- (void)updateRootLargeTitle {
    MUApplyRootLargeTitle(self);
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    _lanDiscovery.serversChangedHandler = nil;
    [_lanDiscovery stopDiscovery];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    // Both are top-level destinations. Keep their labels readable in narrow
    // windows and at accessibility sizes without nesting one inside a server list.
    CGFloat availableWidth = MAX(1, self.view.safeAreaLayoutGuide.layoutFrame.size.width - 40);
    CGFloat minimumCardWidth = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledValueForValue:168 compatibleWithTraitCollection:self.traitCollection];
    BOOL fitsAcross = availableWidth >= minimumCardWidth * _actions.arrangedSubviews.count + _actions.spacing * (_actions.arrangedSubviews.count - 1);
    UILayoutConstraintAxis axis = !fitsAcross || UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory) ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    if (_actions.axis != axis) _actions.axis = axis;
    CGFloat buttonWidth = axis == UILayoutConstraintAxisVertical ? availableWidth : MAX(1, (availableWidth - _actions.spacing * (_actions.arrangedSubviews.count - 1)) / _actions.arrangedSubviews.count);
    CGFloat buttonHeight = 76;
    for (UIButton *button in _actions.arrangedSubviews) buttonHeight = MAX(buttonHeight, ceil([button sizeThatFits:CGSizeMake(buttonWidth, CGFLOAT_MAX)].height));
    CGFloat actionsHeight = axis == UILayoutConstraintAxisVertical ? buttonHeight * _actions.arrangedSubviews.count + _actions.spacing * (_actions.arrangedSubviews.count - 1) : buttonHeight;
    if (_actionsHeight.constant != actionsHeight) _actionsHeight.constant = actionsHeight;
    BOOL split = self.view.bounds.size.width >= MUHomeSplitWidth;
    if (split == _twoColumns) return;
    _twoColumns = split;
    if (split) {
        _singleColumnTrailing.active = NO;
        _splitColumnTrailing.active = YES;
    } else {
        _splitColumnTrailing.active = NO;
        _singleColumnTrailing.active = YES;
    }
    _lanTable.hidden = !split;
    [self reloadTables];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateRootLargeTitle];
    _homeVisible = YES;
    self.navigationController.toolbarHidden = YES;
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
    [self reloadFavourites];
    [self reloadTables];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self startLANDiscovery];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    _homeVisible = NO;
    ++_favouritesGeneration;
    _pendingFavourites = nil;
    _pendingRecentServers = nil;
    _pendingLANRefresh = NO;
    _homeUpdateScheduled=NO; ++_homeUpdateGeneration;
    [_lanDiscovery stopDiscovery];
}

- (void)appEnteredBackground:(NSNotification *)notification { [_lanDiscovery stopDiscovery]; }
- (void)appBecameActive:(NSNotification *)notification {
    if (_homeVisible) [self startLANDiscovery];
}

- (void)reloadFavourites {
    NSUInteger generation = ++_favouritesGeneration;
    _loadingFavourites = YES;
    __weak MUWelcomeScreenPhone *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray *servers = [[MUDatabase fetchAllFavourites] sortedArrayUsingSelector:@selector(compare:)];
        NSArray *recent = [MUDatabase recentServers];
        dispatch_async(dispatch_get_main_queue(), ^{
            MUWelcomeScreenPhone *controller = weakSelf;
            if (!controller || !controller->_homeVisible || generation != controller->_favouritesGeneration) return;
            controller->_pendingFavourites = servers;
            controller->_pendingRecentServers = recent;
            [controller schedulePendingUpdates];
        });
    });
}

- (void)reloadTables {
    [self.tableView reloadData];
    [_lanTable reloadData];
}

- (void)startLANDiscovery {
    if (!_homeVisible || UIApplication.sharedApplication.applicationState == UIApplicationStateBackground) return;
    if (!_lanDiscovery) {
        _lanDiscovery = [MULanServerListController new];
        __weak MUWelcomeScreenPhone *weakSelf = self;
        _lanDiscovery.serversChangedHandler = ^{
            MUWelcomeScreenPhone *controller = weakSelf;
            if (!controller || !controller->_homeVisible) return;
            controller->_pendingLANRefresh = YES;
            [controller schedulePendingUpdates];
        };
    }
    [_lanDiscovery startDiscovery];
}

- (void)schedulePendingUpdates {
    if(!_homeVisible || _homeUpdateScheduled)return;
    _homeUpdateScheduled=YES;
    NSUInteger generation=++_homeUpdateGeneration;
    __weak MUWelcomeScreenPhone *weakSelf=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,40*NSEC_PER_MSEC),dispatch_get_main_queue(), ^{
        MUWelcomeScreenPhone *controller=weakSelf;
        if(!controller || generation!=controller->_homeUpdateGeneration)return;
        controller->_homeUpdateScheduled=NO;
        [controller drainPendingUpdates];
    });
}
- (void)drainPendingUpdates {
    if (_rowUpdateInProgress || !_homeVisible) return;
    // Discovery can resolve a server while the user is dragging or bouncing.
    // Replacing the table's rows then invalidates its visible cells and estimated
    // content height in the middle of that gesture. Apply the latest snapshot
    // once scrolling finishes instead.
    for (UITableView *table in @[self.tableView, _lanTable]) {
        if (table.isDragging || table.isDecelerating) return;
    }
    _homeUpdateScheduled=NO;++_homeUpdateGeneration;
    BOOL hadRecent=_recentServers.count>0;
    BOOL favouritesChanged=NO, recentChanged=NO, lanChanged=NO;
    if (_pendingFavourites) {
        favouritesChanged=_loadingFavourites || !MUHomeServerRowsEqual(_favouriteServers,_pendingFavourites);
        _favouriteServers = _pendingFavourites;
        _pendingFavourites = nil;
        _loadingFavourites = NO;
    }
    if (_pendingRecentServers) {
        recentChanged=!MUHomeServerRowsEqual(_recentServers,_pendingRecentServers);
        _recentServers = _pendingRecentServers;
        _pendingRecentServers = nil;
    }
    if (_pendingLANRefresh) {
        _pendingLANRefresh = NO;
        _lanServices = _lanDiscovery.discoveredServers ?: @[];
        NSArray *snapshot=MUHomeLANRows(_lanServices);
        lanChanged=![_lanDisplaySnapshot isEqual:snapshot] || _lanDiscoveryFailed!=_lanDiscovery.discoveryFailed;
        _lanDisplaySnapshot=snapshot;
        _lanDiscoveryFailed = _lanDiscovery.discoveryFailed;
    }
    if(!favouritesChanged && !recentChanged && !lanChanged)return;
    _rowUpdateInProgress = YES;
    [UIView performWithoutAnimation:^{
        NSMutableIndexSet *main=[NSMutableIndexSet indexSet], *secondary=[NSMutableIndexSet indexSet];
        if(favouritesChanged)[main addIndex:0];
        if(lanChanged)[(_twoColumns ? secondary : main) addIndex:_twoColumns ? 0 : 1];
        if(recentChanged && self->_recentServers.count)[(_twoColumns ? secondary : main) addIndex:_twoColumns ? 1 : 2];
        UITableView *history=self->_twoColumns ? self->_lanTable : self.tableView;
        for(UITableView *table in self->_twoColumns ? @[self.tableView,self->_lanTable] : @[self.tableView]) {
            NSIndexSet *sections=table==self.tableView ? main : secondary;
            BOOL sectionCountChanged=table==history && hadRecent!=(self->_recentServers.count>0);
            if(sectionCountChanged || (sections.count && (!table.window || CGRectIsEmpty(table.bounds))))[table reloadData];
            else if(sections.count)[table reloadSections:sections withRowAnimation:UITableViewRowAnimationNone];
        }
    }];
    _rowUpdateInProgress = NO;
    if (_pendingFavourites || _pendingRecentServers || _pendingLANRefresh) [self schedulePendingUpdates];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) [self drainPendingUpdates];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self drainPendingUpdates];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    [self drainPendingUpdates];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    // The lists extend behind the floating system tab bar. Keep their last rows
    // and scroll indicators reachable above its safe area.
    CGFloat bottom = self.view.safeAreaInsets.bottom + 12;
    for (UITableView *table in @[self.tableView, _lanTable]) {
        if (fabs(table.contentInset.bottom - bottom) > .5) {
            table.contentInset = UIEdgeInsetsMake(0, 0, bottom, 0);
            table.verticalScrollIndicatorInsets = UIEdgeInsetsMake(0, 0, bottom, 0);
        }
    }
}

- (MUHomeList)listForTable:(UITableView *)tableView section:(NSInteger)section {
    if (tableView == _lanTable) return section == 0 ? MUHomeListLAN : MUHomeListRecent;
    if (section == 0) return MUHomeListFavourites;
    return section == 1 ? MUHomeListLAN : MUHomeListRecent;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (_twoColumns && tableView == self.tableView) return 1;
    return (tableView == _lanTable ? 1 : 2) + (_recentServers.count ? 1 : 0);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch ([self listForTable:tableView section:section]) {
        case MUHomeListFavourites: return MAX(1, _favouriteServers.count);
        case MUHomeListLAN: return MAX(1, _lanServices.count);
        case MUHomeListRecent: return _recentServers.count;
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    MUHomeSectionHeader *header = [tableView dequeueReusableHeaderFooterViewWithIdentifier:@"homeHeader"];
    MUHomeList list = [self listForTable:tableView section:section];
    NSString *title;
    NSNumber *count;
    switch (list) {
        case MUHomeListFavourites: title = NSLocalizedString(@"Favourite Servers", nil); count = @(_favouriteServers.count); break;
        case MUHomeListLAN: title = NSLocalizedString(@"LAN Servers", nil); count = @(_lanServices.count); break;
        case MUHomeListRecent: title = NSLocalizedString(@"Recent", nil); break;
    }
    [header setTitle:title count:count];
    header.manageButton.hidden = list != MUHomeListFavourites;
    [header.manageButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [header.manageButton addTarget:self action:@selector(showFavourites:) forControlEvents:UIControlEventTouchUpInside];
    return header;
}

- (void)applySymbol:(NSString *)symbol toContent:(UIListContentConfiguration *)content {
    content.image = [UIImage systemImageNamed:symbol];
    // Set the list's symbol configuration as well as its reserved slot: the
    // reserved layout size aligns icons, but does not limit their rendered size.
    content.imageProperties.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithTextStyle:UIFontTextStyleTitle3 scale:UIImageSymbolScaleMedium];
    CGFloat size = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledValueForValue:22 compatibleWithTraitCollection:self.traitCollection];
    content.imageProperties.maximumSize = CGSizeMake(size, size);
    content.imageProperties.tintColor = UIColor.labelColor;
    content.imageProperties.reservedLayoutSize = MUHomeSymbolSize;
    content.imageToTextPadding = 14;
}

- (NSString *)addressForHostname:(NSString *)hostname port:(NSUInteger)port {
    NSString *host = [hostname containsString:@":"] && ![hostname hasPrefix:@"["] ? [NSString stringWithFormat:@"[%@]", hostname] : hostname;
    return [NSString stringWithFormat:@"%@:%lu", host, (unsigned long)port];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"homeServerItem"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"homeServerItem"];
        NSLayoutConstraint *height = [cell.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:68];
        height.priority = UILayoutPriorityRequired-1;
        height.active = YES;
    }
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.accessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessibilityTraits = UIAccessibilityTraitButton;
    UIListContentConfiguration *content = [UIListContentConfiguration subtitleCellConfiguration];
    content.textProperties.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    content.textProperties.numberOfLines = 0;
    content.secondaryTextProperties.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    content.secondaryTextProperties.color = UIColor.secondaryLabelColor;
    content.secondaryTextProperties.lineBreakMode = NSLineBreakByTruncatingMiddle;
    content.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(12, 16, 12, 12);
    BOOL empty = NO;
    MUHomeList list = [self listForTable:tableView section:indexPath.section];
    if (list == MUHomeListFavourites || list == MUHomeListRecent) {
        NSArray<MUFavouriteServer *> *servers = list == MUHomeListFavourites ? _favouriteServers : _recentServers;
        empty = servers.count == 0;
        if (!empty) {
            MUFavouriteServer *server = servers[indexPath.row];
            content.text = server.displayName.length ? server.displayName : server.hostName;
            content.secondaryText = [self addressForHostname:server.hostName port:server.port];
        } else {
            content.text = _loadingFavourites ? NSLocalizedString(@"Loading…", nil) : NSLocalizedString(@"No favourite servers", nil);
        }
        [self applySymbol:list == MUHomeListFavourites ? @"star" : @"clock" toContent:content];
    } else {
        empty = _lanServices.count == 0;
        if (!empty) {
            NSNetService *server = _lanServices[indexPath.row];
            content.text = server.name;
            content.secondaryText = server.hostName.length ? [self addressForHostname:server.hostName port:server.port] : NSLocalizedString(@"Resolving…", nil);
        } else {
            content.text = _lanDiscoveryFailed ? NSLocalizedString(@"LAN discovery unavailable", nil) : NSLocalizedString(@"No LAN servers found", nil);
        }
        [self applySymbol:@"wifi" toContent:content];
    }
    if (empty) {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessibilityTraits = UIAccessibilityTraitStaticText;
        content.textProperties.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        content.textProperties.color = UIColor.secondaryLabelColor;
        content.imageProperties.tintColor = UIColor.secondaryLabelColor;
    }
    cell.contentConfiguration = content;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    switch ([self listForTable:tableView section:indexPath.section]) {
        case MUHomeListFavourites:
            if (_favouriteServers.count) [[MUConnectionController sharedController] connectToFavouriteServer:_favouriteServers[indexPath.row] withParentViewController:self];
            break;
        case MUHomeListLAN:
            if (_lanServices.count) [_lanDiscovery presentActionsForServer:_lanServices[indexPath.row] fromViewController:self sourceView:[tableView cellForRowAtIndexPath:indexPath]];
            break;
        case MUHomeListRecent: {
            MUFavouriteServer *recent = _recentServers[indexPath.row];
            for (MUFavouriteServer *favourite in _favouriteServers) {
                if (favourite.port == recent.port && [favourite.hostName caseInsensitiveCompare:recent.hostName] == NSOrderedSame) {
                    [[MUConnectionController sharedController] connectToFavouriteServer:favourite withParentViewController:self];
                    return;
                }
            }
            NSString *username = recent.userName.length ? recent.userName : [NSUserDefaults.standardUserDefaults stringForKey:@"DefaultUserName"];
            [[MUConnectionController sharedController] connectToHostname:recent.hostName port:recent.port withUsername:username andPassword:nil withParentViewController:self];
            break;
        }
    }
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self listForTable:tableView section:indexPath.section] != MUHomeListRecent) return nil;
    MUFavouriteServer *server = _recentServers[indexPath.row];
    __weak MUWelcomeScreenPhone *weakSelf = self;
    UIContextualAction *remove = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:NSLocalizedString(@"Delete", nil) handler:^(UIContextualAction *action, UIView *view, void (^completion)(BOOL)) {
        [MUDatabase deleteRecentServer:server];
        completion(YES);
        [weakSelf reloadFavourites];
    }];
    remove.image = [UIImage systemImageNamed:@"trash"];
    return [UISwipeActionsConfiguration configurationWithActions:@[remove]];
}

- (void)showQuickConnect:(id)sender {
    MUFavouriteServerEditViewController *form = [[MUFavouriteServerEditViewController alloc] initForQuickConnect];
    form.target = self;
    form.doneAction = @selector(quickConnectDone:);
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:form];
    navigation.modalPresentationStyle = UIModalPresentationPageSheet;
    UISheetPresentationController *sheet = navigation.sheetPresentationController;
    sheet.detents = @[UISheetPresentationControllerDetent.mediumDetent, UISheetPresentationControllerDetent.largeDetent];
    sheet.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium;
    sheet.prefersGrabberVisible = YES;
    sheet.prefersScrollingExpandsWhenScrolledToEdge = NO;
    sheet.prefersEdgeAttachedInCompactHeight = YES;
    [self presentViewController:navigation animated:YES completion:nil];
}

- (void)showFavourites:(id)sender {
    [self.navigationController pushViewController:[MUFavouriteServerListController new] animated:YES];
}

- (void)showPublicServers:(id)sender {
    [self.navigationController pushViewController:[MUPublicServerListController new] animated:YES];
}

- (void)quickConnectDone:(MUFavouriteServerEditViewController *)form {
    MUFavouriteServer *server = [form copyFavouriteFromContent];
    [[MUConnectionController sharedController] connectToHostname:server.hostName port:server.port withUsername:server.userName andPassword:server.password withParentViewController:self];
}

@end
