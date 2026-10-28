// Use of this source code is governed by the BSD-style license in LICENSE.

#import "MUAppMenuViewController.h"
#import "MUPreferencesViewController.h"
#import "MUInterface.h"

@interface MUAppMenuViewController () {
    MUPreferencesViewController *_preferences;
    UITableView *_tableView;
    UILabel *_versionLabel;
}
@end

@implementation MUAppMenuViewController

- (id)init {
    if ((self = [super init])) {
        self.title = NSLocalizedString(@"Settings", nil);
        MUApplyRootLargeTitle(self);
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedString(@"Settings", nil);
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    _preferences = [MUPreferencesViewController new];
    _preferences.showsAppInformation = YES;
    [self addChildViewController:_preferences];
    [self.view addSubview:_preferences.view];
    [_preferences didMoveToParentViewController:self];
    _tableView = _preferences.tableView;
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.estimatedRowHeight = 52;

    NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    _versionLabel = [UILabel new];
    _versionLabel.text = version;
    _versionLabel.textColor = UIColor.secondaryLabelColor;
    _versionLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    _versionLabel.adjustsFontForContentSizeCategory = YES;
    _versionLabel.textAlignment = NSTextAlignmentCenter;
    _versionLabel.accessibilityLabel = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Version", nil), version];
    [self.view addSubview:_versionLabel];

    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:_versionLabel.topAnchor constant:-16],
        [_versionLabel.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:24],
        [_versionLabel.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-24],
        [_versionLabel.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-16]
    ]];
    [self setContentScrollView:_tableView forEdge:NSDirectionalRectEdgeTop];
    [self updateRootLargeTitle];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 270100
    if (@available(iOS 27.1, *)) {
        [self registerForTraitChanges:UITraitCollection.systemTraitsAffectingVerticalBarEdge withHandler:^(__kindof MUAppMenuViewController *controller, UITraitCollection *previousTraits) {
            [controller updateRootLargeTitle];
        }];
    }
#endif
}

- (void)updateRootLargeTitle {
    MUApplyRootLargeTitle(self);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateRootLargeTitle];
    [_tableView deselectRowAtIndexPath:_tableView.indexPathForSelectedRow animated:animated];
}

@end
