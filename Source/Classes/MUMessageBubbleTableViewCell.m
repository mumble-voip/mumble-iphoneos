// Copyright 2009-2012 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUMessageBubbleTableViewCell.h"
#import <QuartzCore/QuartzCore.h>
static const CGFloat MUMessageInset = 16;
static const CGFloat MUMessagePadding = 12;
static const CGFloat MUMessageTailWidth = 6;
static const CGFloat MUMessageTailDrop = 3;

static UIBezierPath *MUMessageBubblePath(CGSize size, BOOL rightSide) {
    CGFloat left = MUMessageTailWidth;
    CGFloat right = size.width - MUMessageTailWidth;
    CGFloat height = size.height - MUMessageTailDrop;
    CGFloat tailBottom = height + MUMessageTailDrop;
    CGFloat radius = MIN(20, MIN((right - left) / 2, height / 2));
    CGFloat curve = radius * .55228475;
    // One continuous outline keeps the translucent incoming bubble free of overlap seams.
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(left + radius, 0)];
    [path addLineToPoint:CGPointMake(right - radius, 0)];
    [path addCurveToPoint:CGPointMake(right, radius)
           controlPoint1:CGPointMake(right - radius + curve, 0) controlPoint2:CGPointMake(right, radius - curve)];
    [path addLineToPoint:CGPointMake(right, height - 14)];
    [path addCurveToPoint:CGPointMake(right + MUMessageTailWidth, tailBottom)
           controlPoint1:CGPointMake(right, height - 3) controlPoint2:CGPointMake(right + 2, tailBottom - 1)];
    [path addCurveToPoint:CGPointMake(right - 10, height - 4)
           controlPoint1:CGPointMake(right + 1, tailBottom) controlPoint2:CGPointMake(right - 6, height + 1)];
    [path addCurveToPoint:CGPointMake(right - radius, height)
           controlPoint1:CGPointMake(right - 13, height - 1) controlPoint2:CGPointMake(right - radius + 4, height)];
    [path addLineToPoint:CGPointMake(left + radius, height)];
    [path addCurveToPoint:CGPointMake(left, height - radius)
           controlPoint1:CGPointMake(left + radius - curve, height) controlPoint2:CGPointMake(left, height - radius + curve)];
    [path addLineToPoint:CGPointMake(left, radius)];
    [path addCurveToPoint:CGPointMake(left + radius, 0)
           controlPoint1:CGPointMake(left, radius - curve) controlPoint2:CGPointMake(left + radius - curve, 0)];
    [path closePath];
    if (!rightSide) [path applyTransform:CGAffineTransformMake(-1, 0, 0, 1, size.width, 0)];
    return path;
}

@interface MUMessageBubbleBackgroundView : UIView {
    BOOL _rightSide;
    BOOL _pathRightSide;
    CGSize _pathSize;
}
- (void)setFillColor:(UIColor *)color rightSide:(BOOL)rightSide;
@end

@implementation MUMessageBubbleBackgroundView
+ (Class)layerClass { return [CAShapeLayer class]; }

- (void)setFillColor:(UIColor *)color rightSide:(BOOL)rightSide {
    if (_rightSide != rightSide) {
        _rightSide = rightSide;
        [self setNeedsLayout];
    }
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    ((CAShapeLayer *)self.layer).fillColor = [color resolvedColorWithTraitCollection:self.traitCollection].CGColor;
    [CATransaction commit];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGSize size = self.bounds.size;
    if (CGSizeEqualToSize(size, _pathSize) && _rightSide == _pathRightSide) return;
    _pathSize = size;
    _pathRightSide = _rightSide;
    if (size.width <= 2 * MUMessageTailWidth || size.height <= MUMessageTailDrop) {
        ((CAShapeLayer *)self.layer).path = nil;
        return;
    }
    UIBezierPath *path = MUMessageBubblePath(size, _rightSide);
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    ((CAShapeLayer *)self.layer).path = path.CGPath;
    [CATransaction commit];
}
@end

@interface MUMessageLayout : NSObject
@property(nonatomic) CGRect headingRect;
@property(nonatomic) CGRect bubbleRect;
@property(nonatomic) CGRect textBubbleRect;
@property(nonatomic) CGRect messageRect;
@property(nonatomic) CGRect metadataRect;
@property(nonatomic) CGFloat height;
@property(nonatomic, copy) NSArray<NSValue *> *imageRects;
@end
@implementation MUMessageLayout
@end

static UIFont *MUMessageFont(UIFontTextStyle style, UITraitCollection *traits) {
    return [UIFont preferredFontForTextStyle:style compatibleWithTraitCollection:traits];
}

static CGSize MUMessageTextSize(NSString *text, UIFont *font, CGFloat width) {
    if (text.length == 0) return CGSizeZero;
    CGRect rect = [text boundingRectWithSize:CGSizeMake(width, CGFLOAT_MAX)
                                   options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                attributes:@{NSFontAttributeName: font} context:nil];
    return CGSizeMake(ceil(rect.size.width), ceil(rect.size.height));
}

static NSString *MUMessageMetadata(NSString *footer, NSDate *date) {
    static NSDateFormatter *formatter;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ formatter = [NSDateFormatter new]; });
    NSLocale *locale = NSLocale.autoupdatingCurrentLocale;
    NSTimeZone *zone = NSTimeZone.localTimeZone;
    if (![formatter.locale isEqual:locale] || ![formatter.timeZone isEqual:zone]) {
        formatter.locale = locale; formatter.timeZone = zone;
        formatter.dateStyle = NSDateFormatterNoStyle; formatter.timeStyle = NSDateFormatterShortStyle;
    }
    NSString *time = date ? [formatter stringFromDate:date] : nil;
    if (footer.length && time.length) return [NSString stringWithFormat:@"%@ · %@", footer, time];
    return footer.length ? footer : time;
}

// The row measurement and displayed content share the same layout, including Dynamic Type.
static MUMessageLayout *MUMessageMeasure(NSString *heading, NSString *message, NSArray *images,
                                        NSString *metadata, CGFloat width, UITraitCollection *traits, BOOL rightSide) {
    MUMessageLayout *layout = [MUMessageLayout new];
    CGFloat availableWidth = MAX(1, width - 2 * (MUMessageInset + 6));
    CGFloat maxBubbleWidth = MIN(520, availableWidth * 0.80);
    CGFloat maxTextWidth = MAX(1, maxBubbleWidth - 2 * MUMessagePadding);
    CGSize textSize = MUMessageTextSize(message, MUMessageFont(UIFontTextStyleBody, traits), maxTextWidth);
    CGFloat textBubbleWidth = MAX(40, textSize.width + 2 * MUMessagePadding);
    CGFloat contentWidth = textSize.height ? textBubbleWidth : 40;
    NSMutableArray<NSValue *> *imageSizes = [NSMutableArray array];
    for (id image in images) {
        CGSize size = [image isKindOfClass:NSValue.class] ? [image CGSizeValue] : [(UIImage *)image size];
        if (size.width <= 0 || size.height <= 0) { [imageSizes addObject:[NSValue valueWithCGSize:CGSizeZero]]; continue; }
        CGFloat scale = MIN(1, MIN(maxBubbleWidth / size.width, 320 / size.height));
        size = CGSizeMake(MAX(40, floor(size.width * scale)), MAX(36, floor(size.height * scale)));
        contentWidth = MAX(contentWidth, size.width);
        [imageSizes addObject:[NSValue valueWithCGSize:size]];
    }
    CGFloat bubbleWidth = contentWidth;
    CGFloat x = rightSide ? width - MUMessageInset - 6 - bubbleWidth : MUMessageInset + 6;
    CGFloat y = 8;
    CGSize headingSize = MUMessageTextSize(heading, MUMessageFont(UIFontTextStyleCaption1, traits), availableWidth);
    layout.headingRect = CGRectMake(MUMessageInset + 6, y, availableWidth, headingSize.height);
    if (headingSize.height) y += headingSize.height + 4;
    CGFloat bubbleY = y;
    // Captions keep their own text bubble; photos have no colored frame or padding.
    if (textSize.height || !images.count) {
        CGFloat textX = rightSide ? x + bubbleWidth - textBubbleWidth : x;
        CGFloat textHeight = MAX(36, textSize.height + 16);
        layout.textBubbleRect = CGRectMake(textX, y, textBubbleWidth, textHeight);
        layout.messageRect = CGRectMake(textX + MUMessagePadding, y + 8, textBubbleWidth - 2 * MUMessagePadding, textSize.height);
        y += textHeight;
    }
    NSMutableArray<NSValue *> *imageRects = [NSMutableArray array];
    for (NSValue *value in imageSizes) {
        CGSize size = value.CGSizeValue;
        if (y > bubbleY && size.height) y += 8;
        CGFloat imageX = rightSide ? x + bubbleWidth - size.width : x;
        CGRect rect = CGRectMake(imageX, y, size.width, size.height);
        [imageRects addObject:[NSValue valueWithCGRect:rect]];
        y += size.height;
    }
    layout.bubbleRect = CGRectMake(x, bubbleY, bubbleWidth, y - bubbleY);
    CGSize metadataSize = MUMessageTextSize(metadata, MUMessageFont(UIFontTextStyleCaption2, traits), availableWidth);
    if (metadataSize.height) y += 4;
    layout.metadataRect = CGRectMake(MUMessageInset + 6, y, availableWidth, metadataSize.height);
    layout.height = ceil(y + metadataSize.height + 8);
    layout.imageRects = imageRects;
    return layout;
}

@interface MUMessageBubbleView : UIView <UIEditMenuInteractionDelegate, UITextViewDelegate> {
    NSString *_message;
    NSString *_heading;
    NSString *_footer;
    NSDate *_date;
    BOOL _rightSide;
    CGRect _imageRect;
    BOOL _selected;
    NSArray *_shownImages;
    NSArray<NSValue *> *_shownImageSizes;
    __weak MUMessageBubbleTableViewCell *_cell;
    UIEditMenuInteraction *_editMenuInteraction;
    BOOL _editMenuVisible;
    MUMessageBubbleBackgroundView *_bubbleBackground;
    UITextView *_messageLabel;
    UILabel *_headingLabel;
    UILabel *_metadataLabel;
    NSMutableArray<UIImageView *> *_imageViews;
}
- (id)initWithFrame:(CGRect)frame andTableViewCell:(MUMessageBubbleTableViewCell *)cell;
- (void)presentEditMenu;
- (void)dismissEditMenu;
- (BOOL)isEditMenuVisible;
- (void)setHeading:(NSString *)heading;
- (void)setFooter:(NSString *)footer;
- (void)setMessage:(NSString *)msg;
- (void)setDate:(NSDate *)date;
- (void)setShownImages:(NSArray *)shownImages;
- (void)setShownImageSizes:(NSArray<NSValue *> *)sizes;
- (void)updateImageViews;
- (void)setRightSide:(BOOL)rightSide;
- (CGRect)selectionRect;
- (BOOL)attachmentFooterContainsPoint:(CGPoint)point;
- (void)setSelected:(BOOL)selected;
- (BOOL)isSelected;
@end

@implementation MUMessageBubbleView

- (id)initWithFrame:(CGRect)frame andTableViewCell:(MUMessageBubbleTableViewCell *)cell {
    if ((self = [super initWithFrame:frame])) {
        self.opaque = NO;
        _cell = cell;
        _bubbleBackground = [MUMessageBubbleBackgroundView new];
        _bubbleBackground.opaque = NO;
        _bubbleBackground.userInteractionEnabled = NO;
        [self addSubview:_bubbleBackground];
        _headingLabel = [UILabel new];
        _metadataLabel = [UILabel new];
        for (UILabel *label in @[_headingLabel, _metadataLabel]) {
            label.numberOfLines = 0;
            [self addSubview:label];
        }
        _messageLabel = [UITextView new];
        _messageLabel.backgroundColor = [UIColor clearColor];
        _messageLabel.editable = NO;
        _messageLabel.selectable = YES;
        _messageLabel.scrollEnabled = NO;
        _messageLabel.textContainerInset = UIEdgeInsetsZero;
        _messageLabel.textContainer.lineFragmentPadding = 0;
        _messageLabel.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        _messageLabel.dataDetectorTypes = UIDataDetectorTypeLink;
        _messageLabel.delegate = self;
        _messageLabel.adjustsFontForContentSizeCategory = YES;
        [self addSubview:_messageLabel];
        _imageViews = [NSMutableArray array];
        _editMenuInteraction = [[UIEditMenuInteraction alloc] initWithDelegate:self];
        [self addInteraction:_editMenuInteraction];
        self.isAccessibilityElement = YES;
        [self registerForTraitChanges:@[[UITraitUserInterfaceStyle class], [UITraitPreferredContentSizeCategory class], [UITraitAccessibilityContrast class]]
                            withHandler:^(__kindof MUMessageBubbleView *view, UITraitCollection *previousTraits) {
            [view setNeedsLayout];
        }];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    NSString *metadata = MUMessageMetadata(_footer, _date);
    MUMessageLayout *layout = MUMessageMeasure(_heading, _message, _shownImageSizes ?: _shownImages, metadata, self.bounds.size.width, self.traitCollection, _rightSide);
    _imageRect = layout.bubbleRect;
    _headingLabel.font = MUMessageFont(UIFontTextStyleCaption1, self.traitCollection);
    _messageLabel.font = MUMessageFont(UIFontTextStyleBody, self.traitCollection);
    _metadataLabel.font = MUMessageFont(UIFontTextStyleCaption2, self.traitCollection);
    _headingLabel.textColor = [UIColor secondaryLabelColor];
    _metadataLabel.textColor = _footer.length ? [UIColor linkColor] : [UIColor secondaryLabelColor];
    _messageLabel.textColor = _rightSide ? [UIColor whiteColor] : [UIColor labelColor];
    _messageLabel.linkTextAttributes = @{NSForegroundColorAttributeName:_messageLabel.textColor, NSUnderlineStyleAttributeName:@(NSUnderlineStyleSingle)};
    _headingLabel.textAlignment = _metadataLabel.textAlignment = _rightSide ? NSTextAlignmentRight : NSTextAlignmentLeft;
    _headingLabel.text = _heading;
    if (![_messageLabel.text isEqualToString:_message ?: @""]) _messageLabel.text = _message;
    _metadataLabel.text = metadata;
    _headingLabel.frame = layout.headingRect;
    _messageLabel.frame = layout.messageRect;
    _metadataLabel.frame = layout.metadataRect;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (NSUInteger i = 0; i < _imageViews.count; i++) {
        UIImageView *view = _imageViews[i];
        CGRect photoFrame = CGRectInset(layout.imageRects[i].CGRectValue, -MUMessageTailWidth, 0);
        photoFrame.size.height += MUMessageTailDrop;
        view.frame = photoFrame;
        view.alpha = _selected ? .72 : 1;
        CAShapeLayer *mask = (CAShapeLayer *)view.layer.mask;
        if (!mask) { mask = [CAShapeLayer layer]; view.layer.mask = mask; }
        BOOL resized = !CGSizeEqualToSize(mask.bounds.size, view.bounds.size);
        mask.bounds = view.bounds;
        mask.position = CGPointMake(CGRectGetMidX(view.bounds), CGRectGetMidY(view.bounds));
        if (resized || !mask.path) mask.path = MUMessageBubblePath(view.bounds.size, YES).CGPath;
        mask.affineTransform = CGAffineTransformMakeScale(_rightSide ? 1 : -1, 1);
    }
    [CATransaction commit];
    _bubbleBackground.hidden = CGRectIsEmpty(layout.textBubbleRect);
    CGRect backgroundFrame = CGRectZero;
    if (!_bubbleBackground.hidden) {
        backgroundFrame = CGRectInset(layout.textBubbleRect, -MUMessageTailWidth, 0);
        backgroundFrame.size.height += MUMessageTailDrop;
    }
    _bubbleBackground.frame = backgroundFrame;
    [_bubbleBackground setFillColor:_rightSide ? [UIColor systemBlueColor] : [UIColor secondarySystemFillColor] rightSide:_rightSide];
    _bubbleBackground.alpha = _selected ? .72 : 1;
    NSMutableArray *description = [NSMutableArray array];
    for (NSString *text in @[_heading ?: @"", _message ?: @"", metadata ?: @""]) {
        if (text.length) [description addObject:text];
    }
    self.accessibilityLabel = [description componentsJoinedByString:@", "];
    self.accessibilityTraits = (_footer.length || _shownImages.count) ? UIAccessibilityTraitButton : UIAccessibilityTraitStaticText;
}

- (CGRect)selectionRect { return _imageRect; }

- (BOOL)attachmentFooterContainsPoint:(CGPoint)point { return _footer.length && CGRectContainsPoint(_metadataLabel.frame, point); }
- (BOOL)isSelected { return _selected; }
- (void)setSelected:(BOOL)value { _selected = value; [self setNeedsLayout]; }
- (void)setHeading:(NSString *)value { _heading = [value copy]; [self setNeedsLayout]; }
- (void)setFooter:(NSString *)value { _footer = [value copy]; [self setNeedsLayout]; }
- (void)setMessage:(NSString *)value { _message = [value copy]; [self setNeedsLayout]; }
- (void)setDate:(NSDate *)value { _date = value; [self setNeedsLayout]; }
- (void)setRightSide:(BOOL)value { _rightSide = value; [self setNeedsLayout]; }
- (void)setShownImages:(NSArray *)images {
    _shownImages = [images copy];
    [self updateImageViews];
}
- (void)setShownImageSizes:(NSArray<NSValue *> *)sizes {
    _shownImageSizes=[sizes copy];
    [self updateImageViews];
}
- (void)updateImageViews {
    NSUInteger count=_shownImageSizes ? _shownImageSizes.count : _shownImages.count;
    while (_imageViews.count>count) { [_imageViews.lastObject removeFromSuperview];[_imageViews removeLastObject]; }
    while (_imageViews.count<count) {
        UIImageView *view = [UIImageView new];
        view.contentMode = UIViewContentModeScaleAspectFill;
        view.clipsToBounds = YES;
        [self addSubview:view];
        [_imageViews addObject:view];
    }
    for(NSUInteger i=0;i<count;i++) {
        UIImageView *view=_imageViews[i];UIImage *image=i<_shownImages.count ? _shownImages[i] : nil;
        if(view.image!=image)view.image=image;
        view.backgroundColor=image ? UIColor.clearColor : UIColor.tertiarySystemFillColor;
    }
    [self setNeedsLayout];
}

- (BOOL)accessibilityActivate {
    if (!_footer.length && !_shownImages.count) return NO;
    [[_cell delegate] messageBubbleTableViewCellRequestedAttachmentViewer:_cell];
    return YES;
}

- (NSArray<UIAccessibilityCustomAction *> *)accessibilityCustomActions {
    return @[[[UIAccessibilityCustomAction alloc] initWithName:NSLocalizedString(@"Copy", nil) target:self selector:@selector(accessibilityCopy)],
             [[UIAccessibilityCustomAction alloc] initWithName:NSLocalizedString(@"Delete", nil) target:self selector:@selector(accessibilityDelete)]];
}
- (BOOL)accessibilityCopy { [self copy:nil]; return YES; }
- (BOOL)accessibilityDelete { [self delete:nil]; return YES; }

- (BOOL) canBecomeFirstResponder {
    return YES;
}

- (void) presentEditMenu {
    if (![self becomeFirstResponder]) {
        return;
    }
    CGRect rect = [self selectionRect];
    CGPoint point = CGPointMake(CGRectGetMidX(rect), CGRectGetMinY(rect));
    UIEditMenuConfiguration *configuration = [UIEditMenuConfiguration configurationWithIdentifier:nil sourcePoint:point];
    [_editMenuInteraction presentEditMenuWithConfiguration:configuration];
}

- (void) dismissEditMenu {
    [_editMenuInteraction dismissMenu];
    _messageLabel.selectedRange = NSMakeRange(0, 0);
    [_messageLabel resignFirstResponder];
}

- (BOOL) isEditMenuVisible {
    return _editMenuVisible || _messageLabel.selectedRange.length > 0;
}

- (UIMenu *)textView:(UITextView *)textView editMenuForTextInRange:(NSRange)range suggestedActions:(NSArray<UIMenuElement *> *)suggestedActions {
    UIAction *delete = [UIAction actionWithTitle:NSLocalizedString(@"Delete", nil) image:[UIImage systemImageNamed:@"trash"] identifier:nil handler:^(__kindof UIAction *action) { [self delete:nil]; }];
    delete.attributes = UIMenuElementAttributesDestructive;
    return [UIMenu menuWithChildren:[suggestedActions arrayByAddingObject:delete]];
}

- (UIMenu *) editMenuInteraction:(UIEditMenuInteraction *)interaction menuForConfiguration:(UIEditMenuConfiguration *)configuration suggestedActions:(NSArray<UIMenuElement *> *)suggestedActions {
    if ([suggestedActions count] > 0) {
        return [UIMenu menuWithChildren:suggestedActions];
    }
    UIAction *copyAction = [UIAction actionWithTitle:NSLocalizedString(@"Copy", nil) image:nil identifier:nil handler:^(__kindof UIAction *action) {
        [self copy:nil];
    }];
    UIAction *deleteAction = [UIAction actionWithTitle:NSLocalizedString(@"Delete", nil) image:nil identifier:nil handler:^(__kindof UIAction *action) {
        [self delete:nil];
    }];
    return [UIMenu menuWithChildren:@[copyAction, deleteAction]];
}

- (void) editMenuInteraction:(UIEditMenuInteraction *)interaction willPresentMenuForConfiguration:(UIEditMenuConfiguration *)configuration animator:(id<UIEditMenuInteractionAnimating>)animator {
    _editMenuVisible = YES;
}

- (void) editMenuInteraction:(UIEditMenuInteraction *)interaction willDismissMenuForConfiguration:(UIEditMenuConfiguration *)configuration animator:(id<UIEditMenuInteractionAnimating>)animator {
    _editMenuVisible = NO;
    [self setSelected:NO];
    [self resignFirstResponder];
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (_editMenuVisible) {
        [self dismissEditMenu];
    }
}

- (BOOL) canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(copy:)) {
        return YES;
    }
    if (action == @selector(delete:)) {
        return YES;
    }
    return NO;
}

- (void) copy:(id)sender {
    [[_cell delegate] messageBubbleTableViewCellRequestedCopy:_cell];
}

- (void) delete:(id)sender {
    [[_cell delegate] messageBubbleTableViewCellRequestedDeletion:_cell];
}

@end

@interface MUMessageBubbleTableViewCell () <UIGestureRecognizerDelegate> {
    MUMessageBubbleView *_bubbleView;
    UILongPressGestureRecognizer *_longPressRecognizer;
    __weak id<MUMessageBubbleTableViewCellDelegate> _delegate;
}
@end

@implementation MUMessageBubbleTableViewCell

+ (CGFloat)heightForCellWithHeading:(NSString *)heading message:(NSString *)message images:(NSArray *)images footer:(NSString *)footer date:(NSDate *)date width:(CGFloat)width traitCollection:(UITraitCollection *)traits {
    return MUMessageMeasure(heading, message, images, MUMessageMetadata(footer, date), width, traits, NO).height;
}

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor clearColor];
        _bubbleView = [[MUMessageBubbleView alloc] initWithFrame:self.contentView.bounds andTableViewCell:self];
        _bubbleView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.contentView addSubview:_bubbleView];
        _longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(showMenu:)];
        _longPressRecognizer.delegate = self;
        [_bubbleView addGestureRecognizer:_longPressRecognizer];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showAttachments:)];
        tap.delegate = self;
        [tap requireGestureRecognizerToFail:_longPressRecognizer];
        [_bubbleView addGestureRecognizer:tap];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [_bubbleView dismissEditMenu];
    [_bubbleView setSelected:NO];
    [_bubbleView setShownImageSizes:nil];
    [_bubbleView setShownImages:nil];
    _delegate = nil;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    for (UIView *view = touch.view; view && view != self; view = view.superview)
        if ([view isKindOfClass:UITextView.class]) return NO;
    CGPoint point = [touch locationInView:_bubbleView];
    return CGRectContainsPoint(CGRectInset([_bubbleView selectionRect], -6, -4), point) || [_bubbleView attachmentFooterContainsPoint:point];
}

- (void)setDelegate:(id<MUMessageBubbleTableViewCellDelegate>)delegate { _delegate = delegate; }
- (id<MUMessageBubbleTableViewCellDelegate>)delegate { return _delegate; }
- (CGRect)messageBubbleFrame {
    [self layoutIfNeeded];
    [_bubbleView layoutIfNeeded];
    return [_bubbleView convertRect:CGRectInset([_bubbleView selectionRect], -6, 0) toView:self.contentView];
}

- (void)showAttachments:(id)sender {
    if (![_bubbleView isSelected]) [_delegate messageBubbleTableViewCellRequestedAttachmentViewer:self];
}
- (void)showMenu:(id)sender {
    if (_longPressRecognizer.state == UIGestureRecognizerStateBegan) {
        [_bubbleView setSelected:YES];
        [_bubbleView presentEditMenu];
    }
}
- (BOOL)isEditMenuVisible { return [_bubbleView isEditMenuVisible]; }
- (void)dismissEditMenu { [_bubbleView dismissEditMenu]; }
- (void)setSelected:(BOOL)value { [_bubbleView setSelected:value]; }
- (BOOL)isSelected { return [_bubbleView isSelected]; }
- (void)setHeading:(NSString *)value { [_bubbleView setHeading:value]; }
- (void)setMessage:(NSString *)value { [_bubbleView setMessage:value]; }
- (void)setShownImages:(NSArray *)value { [_bubbleView setShownImages:value]; }
- (void)setShownImageSizes:(NSArray<NSValue *> *)sizes { [_bubbleView setShownImageSizes:sizes]; }
- (void)setFooter:(NSString *)value { [_bubbleView setFooter:value]; }
- (void)setDate:(NSDate *)value { [_bubbleView setDate:value]; }
- (void)setRightSide:(BOOL)value { [_bubbleView setRightSide:value]; }
@end
