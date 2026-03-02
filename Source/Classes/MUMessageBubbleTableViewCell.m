// Copyright 2009-2012 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUMessageBubbleTableViewCell.h"
#import "MUTextMessage.h"
#import "MUColor.h"

static const CGFloat kBubbleCornerRadius    = 18.0f;
static const CGFloat kBubblePaddingH        = 12.0f;
static const CGFloat kBubblePaddingV        = 8.0f;
static const CGFloat kBubbleMarginH         = 12.0f;
static const CGFloat kBubbleMarginV         = 2.0f;
static const CGFloat kBubbleMaxWidthFrac    = 0.78f;

#pragma mark - MUBubbleContainerView

@interface MUBubbleContainerView : UIView
@property (nonatomic, weak) MUMessageBubbleTableViewCell *cell;
@end

@implementation MUBubbleContainerView

- (BOOL) canBecomeFirstResponder {
    return YES;
}

- (BOOL) canPerformAction:(SEL)action withSender:(id)sender {
    return (action == @selector(copy:) || action == @selector(delete:));
}

- (void) copy:(id)sender {
    [[_cell delegate] messageBubbleTableViewCellRequestedCopy:_cell];
}

- (void) delete:(id)sender {
    [[_cell delegate] messageBubbleTableViewCellRequestedDeletion:_cell];
}

@end

#pragma mark - MUMessageBubbleTableViewCell

@interface MUMessageBubbleTableViewCell () {
    MUBubbleContainerView                     *_bubbleView;
    UIStackView                               *_contentStack;
    UIStackView                               *_headerStack;
    UIStackView                               *_imageStack;
    UILabel                                   *_headingLabel;
    UILabel                                   *_timestampLabel;
    UILabel                                   *_messageLabel;
    UILabel                                   *_footerLabel;

    UILongPressGestureRecognizer              *_longPressRecognizer;
    UITapGestureRecognizer                    *_tapRecognizer;
    id<MUMessageBubbleTableViewCellDelegate>  _delegate;

    NSLayoutConstraint                        *_bubbleLeadingConstraint;
    NSLayoutConstraint                        *_bubbleTrailingConstraint;

    BOOL                                      _rightSide;
    BOOL                                      _isSelected;
}
@end

@implementation MUMessageBubbleTableViewCell

+ (CGFloat) heightForCellWithHeading:(NSString *)heading message:(NSString *)msg images:(NSArray *)images footer:(NSString *)footer date:(NSDate *)date {
    return UITableViewAutomaticDimension;
}

- (id) initWithReuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        _rightSide = NO;
        _isSelected = NO;

        [self _mu_setupViews];
        [self _mu_setupConstraints];
        [self _mu_setupGestures];
        [self _mu_applyColors];
    }
    return self;
}

- (void) prepareForReuse {
    [super prepareForReuse];
    _headingLabel.text = nil;
    _messageLabel.text = nil;
    _timestampLabel.text = nil;
    _footerLabel.text = nil;
    _footerLabel.hidden = YES;
    _messageLabel.hidden = NO;
    _isSelected = NO;

    for (UIView *v in [_imageStack.arrangedSubviews copy]) {
        [_imageStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    _imageStack.hidden = YES;
}

#pragma mark - View setup

- (void) _mu_setupViews {
    _bubbleView = [[MUBubbleContainerView alloc] init];
    _bubbleView.cell = self;
    _bubbleView.translatesAutoresizingMaskIntoConstraints = NO;
    _bubbleView.layer.cornerRadius = kBubbleCornerRadius;
    if (@available(iOS 13.0, *)) {
        _bubbleView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    _bubbleView.clipsToBounds = YES;
    _bubbleView.userInteractionEnabled = YES;
    [self.contentView addSubview:_bubbleView];

    _headingLabel = [[UILabel alloc] init];
    _headingLabel.font = [UIFont systemFontOfSize:13.0f weight:UIFontWeightSemibold];
    _headingLabel.numberOfLines = 1;
    _headingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_headingLabel setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [_headingLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    _timestampLabel = [[UILabel alloc] init];
    _timestampLabel.font = [UIFont monospacedDigitSystemFontOfSize:11.0f weight:UIFontWeightRegular];
    _timestampLabel.numberOfLines = 1;
    _timestampLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_timestampLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_timestampLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    _headerStack = [[UIStackView alloc] initWithArrangedSubviews:@[_headingLabel, _timestampLabel]];
    _headerStack.axis = UILayoutConstraintAxisHorizontal;
    _headerStack.spacing = 6.0f;
    _headerStack.alignment = UIStackViewAlignmentFirstBaseline;
    _headerStack.translatesAutoresizingMaskIntoConstraints = NO;

    _messageLabel = [[UILabel alloc] init];
    _messageLabel.font = [UIFont systemFontOfSize:16.0f];
    _messageLabel.numberOfLines = 0;
    _messageLabel.lineBreakMode = NSLineBreakByWordWrapping;
    _messageLabel.translatesAutoresizingMaskIntoConstraints = NO;

    _imageStack = [[UIStackView alloc] init];
    _imageStack.axis = UILayoutConstraintAxisVertical;
    _imageStack.spacing = 4.0f;
    _imageStack.alignment = UIStackViewAlignmentFill;
    _imageStack.translatesAutoresizingMaskIntoConstraints = NO;
    _imageStack.hidden = YES;

    _footerLabel = [[UILabel alloc] init];
    _footerLabel.font = [UIFont italicSystemFontOfSize:11.0f];
    _footerLabel.numberOfLines = 1;
    _footerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _footerLabel.hidden = YES;

    _contentStack = [[UIStackView alloc] initWithArrangedSubviews:@[_headerStack, _messageLabel, _imageStack, _footerLabel]];
    _contentStack.axis = UILayoutConstraintAxisVertical;
    _contentStack.spacing = 2.0f;
    _contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    [_bubbleView addSubview:_contentStack];
}

- (void) _mu_setupConstraints {
    UIView *content = self.contentView;

    [NSLayoutConstraint activateConstraints:@[
        [_contentStack.topAnchor constraintEqualToAnchor:_bubbleView.topAnchor constant:kBubblePaddingV],
        [_contentStack.bottomAnchor constraintEqualToAnchor:_bubbleView.bottomAnchor constant:-kBubblePaddingV],
        [_contentStack.leadingAnchor constraintEqualToAnchor:_bubbleView.leadingAnchor constant:kBubblePaddingH],
        [_contentStack.trailingAnchor constraintEqualToAnchor:_bubbleView.trailingAnchor constant:-kBubblePaddingH],
    ]];

    NSLayoutConstraint *top = [_bubbleView.topAnchor constraintEqualToAnchor:content.topAnchor constant:kBubbleMarginV];
    NSLayoutConstraint *bottom = [_bubbleView.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-kBubbleMarginV];
    bottom.priority = UILayoutPriorityDefaultHigh; // allow table view to win in ambiguous cases
    NSLayoutConstraint *maxW = [_bubbleView.widthAnchor constraintLessThanOrEqualToAnchor:content.widthAnchor multiplier:kBubbleMaxWidthFrac];

    [NSLayoutConstraint activateConstraints:@[top, bottom, maxW]];

    _bubbleLeadingConstraint = [_bubbleView.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:kBubbleMarginH];
    _bubbleTrailingConstraint = [_bubbleView.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-kBubbleMarginH];

    _bubbleLeadingConstraint.active = YES;
    _bubbleTrailingConstraint.active = NO;
}

- (void) _mu_setupGestures {
    _longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_mu_longPress:)];
    [_bubbleView addGestureRecognizer:_longPressRecognizer];

    _tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_mu_tap:)];
    [_bubbleView addGestureRecognizer:_tapRecognizer];
}

- (void) _mu_applyColors {
    if (_isSelected) {
        if (@available(iOS 13.0, *)) {
            _bubbleView.backgroundColor = [UIColor systemGray3Color];
        } else {
            _bubbleView.backgroundColor = [UIColor lightGrayColor];
        }
        _headingLabel.textColor = [UIColor whiteColor];
        _timestampLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.7];
        _messageLabel.textColor = [UIColor whiteColor];
        _footerLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.7];
        return;
    }

    if (_rightSide) {
        _bubbleView.backgroundColor = [UIColor systemBlueColor];
        _headingLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.85];
        _timestampLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.6];
        _messageLabel.textColor = [UIColor whiteColor];
        _footerLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.6];
    } else {
        if (@available(iOS 13.0, *)) {
            _bubbleView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
                if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
                    return [UIColor colorWithRed:0.17 green:0.17 blue:0.18 alpha:1.0];
                }
                return [UIColor colorWithRed:0.898 green:0.898 blue:0.918 alpha:1.0];
            }];
        } else {
            _bubbleView.backgroundColor = [UIColor colorWithRed:0.898 green:0.898 blue:0.918 alpha:1.0];
        }
        _headingLabel.textColor = [MUColor primaryTextColor];
        _timestampLabel.textColor = [MUColor secondaryTextColor];
        _messageLabel.textColor = [MUColor primaryTextColor];
        _footerLabel.textColor = [MUColor secondaryTextColor];
    }
}

#pragma mark - Public setters

- (void) setHeading:(NSString *)heading {
    _headingLabel.text = heading;
}

- (void) setMessage:(NSString *)msg {
    _messageLabel.text = msg;
    _messageLabel.hidden = (msg.length == 0);
}

- (void) setShownImages:(NSArray *)shownImages {
    for (UIView *v in [_imageStack.arrangedSubviews copy]) {
        [_imageStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }

    if (shownImages.count == 0) {
        _imageStack.hidden = YES;
        return;
    }

    _imageStack.hidden = NO;
    for (UIImage *image in shownImages) {
        UIImageView *imgView = [[UIImageView alloc] initWithImage:image];
        imgView.contentMode = UIViewContentModeScaleAspectFit;
        imgView.clipsToBounds = YES;
        imgView.layer.cornerRadius = 8.0f;
        imgView.translatesAutoresizingMaskIntoConstraints = NO;

        if (image.size.width > 0) {
            CGFloat ratio = image.size.height / image.size.width;
            NSLayoutConstraint *aspect = [imgView.heightAnchor constraintEqualToAnchor:imgView.widthAnchor multiplier:ratio];
            aspect.priority = UILayoutPriorityDefaultHigh;
            aspect.active = YES;
        }
        [imgView.heightAnchor constraintLessThanOrEqualToConstant:300.0f].active = YES;
        [_imageStack addArrangedSubview:imgView];
    }
}

- (void) setFooter:(NSString *)footer {
    _footerLabel.text = footer;
    _footerLabel.hidden = (footer.length == 0);
}

- (void) setDate:(NSDate *)date {
    if (date) {
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        [fmt setDateFormat:@"HH:mm"];
        _timestampLabel.text = [fmt stringFromDate:date];
    } else {
        _timestampLabel.text = nil;
    }
}

- (void) setRightSide:(BOOL)rightSide {
    _rightSide = rightSide;
    if (rightSide) {
        _bubbleLeadingConstraint.active = NO;
        _bubbleTrailingConstraint.active = YES;
    } else {
        _bubbleTrailingConstraint.active = NO;
        _bubbleLeadingConstraint.active = YES;
    }
    [self _mu_applyColors];
}

- (void) setSelected:(BOOL)selected {
    _isSelected = selected;
    [self _mu_applyColors];
}

- (BOOL) isSelected {
    return _isSelected;
}

- (void) setDelegate:(id<MUMessageBubbleTableViewCellDelegate>)delegate {
    _delegate = delegate;
}

- (id<MUMessageBubbleTableViewCellDelegate>) delegate {
    return _delegate;
}

#pragma mark - Gesture handling

- (void) _mu_longPress:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        [_bubbleView becomeFirstResponder];
        _isSelected = YES;
        [self _mu_applyColors];

        UIMenuController *menu = [UIMenuController sharedMenuController];
        [menu setTargetRect:_bubbleView.bounds inView:_bubbleView];
        [menu setMenuVisible:YES animated:YES];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(_mu_menuWillHide:)
                                                     name:UIMenuControllerWillHideMenuNotification
                                                   object:nil];
    }
}

- (void) _mu_tap:(UITapGestureRecognizer *)recognizer {
    if (!_isSelected) {
        [_delegate messageBubbleTableViewCellRequestedAttachmentViewer:self];
    }
}

- (void) _mu_menuWillHide:(NSNotification *)notification {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIMenuControllerWillHideMenuNotification object:nil];
    [_bubbleView resignFirstResponder];
    _isSelected = NO;
    [self _mu_applyColors];
}

@end
