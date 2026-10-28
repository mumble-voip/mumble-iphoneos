// Shared UIKit defaults for forms and ordinary settings/list cells.
#import <UIKit/UIKit.h>

static inline void MUConfigureServerActionSheet(UIAlertController *sheet, UIView *sourceView) {
    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    popover.sourceView = sourceView;
    popover.sourceRect = CGRectNull;
    // The arrow points down to the selected row, so the menu opens above it.
    popover.permittedArrowDirections = UIPopoverArrowDirectionDown;
}

static inline void MUApplyRootLargeTitle(UIViewController *controller) {
    BOOL verticalBar = NO;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 270100
    if (@available(iOS 27.1, *))
        verticalBar = controller.traitCollection.verticalBarEdge != UIVerticalBarEdgeUnspecified;
#endif
    controller.navigationItem.largeTitleDisplayMode = verticalBar ? UINavigationItemLargeTitleDisplayModeNever : UINavigationItemLargeTitleDisplayModeInline;
}
static inline void MUConfigureTable(UITableView *table) {
    table.rowHeight = UITableViewAutomaticDimension;
    table.estimatedRowHeight = 56;
    table.selfSizingInvalidation = UITableViewSelfSizingInvalidationEnabledIncludingConstraints;
    table.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
}
static inline void MUConfigureStandardCell(UITableViewCell *cell) {
    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    cell.textLabel.adjustsFontForContentSizeCategory = YES;
    cell.textLabel.numberOfLines = 0;
    cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    cell.detailTextLabel.adjustsFontForContentSizeCategory = YES;
    cell.detailTextLabel.numberOfLines = 0;
}
static inline void MUConfigureFormCell(UITableViewCell *cell, NSString *title, UITextField *field) {
    cell.textLabel.text = nil;
    UILabel *label = [UILabel new];
    label.text = title; label.numberOfLines = 0;
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    label.adjustsFontForContentSizeCategory = YES; label.textColor = UIColor.labelColor;
    field.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    field.adjustsFontForContentSizeCategory = YES; field.accessibilityLabel = title;
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[label, field]];
    stack.spacing = 12; stack.translatesAutoresizingMaskIntoConstraints = NO;
    [label setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    NSLayoutConstraint *labelWidth = [label.widthAnchor constraintLessThanOrEqualToAnchor:stack.widthAnchor multiplier:.4];
    void (^update)(UIView *) = ^(UIView *view) {
        BOOL vertical = UIContentSizeCategoryIsAccessibilityCategory(view.traitCollection.preferredContentSizeCategory);
        labelWidth.active = !vertical;
        stack.axis = vertical ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
        stack.alignment = vertical ? UIStackViewAlignmentFill : UIStackViewAlignmentCenter;
        field.textAlignment = vertical ? NSTextAlignmentNatural : NSTextAlignmentRight;
    };
    // The handler receives its view; weak captures avoid retaining the stack.
    __weak UIStackView *weakStack = stack;
    __weak UILabel *weakLabel = label;
    __weak UITextField *weakField = field;

    [stack registerForTraitChanges:@[UITraitPreferredContentSizeCategory.class] withHandler:^(__kindof UIView *view, UITraitCollection *previous) {
        BOOL vertical = UIContentSizeCategoryIsAccessibilityCategory(view.traitCollection.preferredContentSizeCategory);
        labelWidth.active = !vertical;
        weakStack.axis = vertical ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
        weakStack.alignment = vertical ? UIStackViewAlignmentFill : UIStackViewAlignmentCenter;
        weakField.textAlignment = vertical ? NSTextAlignmentNatural : NSTextAlignmentRight;
        weakLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody compatibleWithTraitCollection:view.traitCollection];
    }];
    [cell.contentView addSubview:stack];
    UILayoutGuide *margins = cell.contentView.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor], [stack.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:margins.topAnchor], [stack.bottomAnchor constraintEqualToAnchor:margins.bottomAnchor],
        [cell.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:52]
    ]];
    update(stack);
}
