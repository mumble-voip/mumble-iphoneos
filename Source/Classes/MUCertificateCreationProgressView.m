// Use of this source code is governed by the BSD-style license in LICENSE.
#import "MUCertificateCreationProgressView.h"

@implementation MUCertificateCreationProgressView {
    NSString *_identityName, *_emailAddress;
}
- (id)initWithName:(NSString *)name email:(NSString *)email {
    if ((self = [super init])) { _identityName = [name copy]; _emailAddress = [email copy]; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedString(@"Generating Certificate", nil);
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.navigationItem.hidesBackButton = YES;
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    UIImageView *symbol = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"person.crop.circle.badge.checkmark"]];
    symbol.contentMode = UIViewContentModeScaleAspectFit;
    symbol.tintColor = UIColor.systemBlueColor;
    symbol.accessibilityElementsHidden = YES;
    UIActivityIndicatorView *activity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    [activity startAnimating];
    UILabel *name = [UILabel new], *email = [UILabel new], *status = [UILabel new];
    name.text = _identityName;
    email.text = _emailAddress;
    email.hidden = !_emailAddress.length;
    status.text = NSLocalizedString(@"Please Wait...", nil);
    for (UILabel *label in @[name, email, status]) {
        label.font = [UIFont preferredFontForTextStyle:label == name ? UIFontTextStyleHeadline : UIFontTextStyleBody];
        label.adjustsFontForContentSizeCategory = YES;
        label.numberOfLines = 0;
        label.textAlignment = NSTextAlignmentCenter;
        label.textColor = label == name ? UIColor.labelColor : UIColor.secondaryLabelColor;
    }
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[symbol, name, email, activity, status]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 20;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    UIScrollView *scroll = [UIScrollView new];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scroll]; [scroll addSubview:stack];
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    NSLayoutConstraint *center = [stack.centerYAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.centerYAnchor];
    center.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [scroll.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor], [scroll.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:safe.topAnchor], [scroll.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-24],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-48],
        [stack.topAnchor constraintGreaterThanOrEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:24],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-24], center,
        [symbol.widthAnchor constraintEqualToConstant:80], [symbol.heightAnchor constraintEqualToConstant:80],
        [name.widthAnchor constraintEqualToAnchor:stack.widthAnchor], [email.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [status.widthAnchor constraintEqualToAnchor:stack.widthAnchor]
    ]];
}
@end
