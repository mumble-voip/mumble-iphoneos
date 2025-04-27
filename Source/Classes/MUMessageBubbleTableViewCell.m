// Copyright 2009-2012 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUMessageBubbleTableViewCell.h"
#import "MUTextMessage.h"
#import "MUColor.h"

#define kBalloonWidth                190.0f
#define kBalloonTopMargin            8.0f
#define kBalloonBottomMargin         10.0f
#define kBalloonMarginTailSide       19.0f
#define kBalloonMarginNonTailSide    11.0f
#define kBalloonTopPadding           3.0f
#define kBalloonBottomPadding        3.0f
#define kBalloonTimestampSpacing     5.0f
#define kBalloonTopInset             14.0f
#define kBalloonBottomInset          17.0f
#define kBalloonTailInset            23.0f
#define kBalloonNoTailInset          16.0f
#define kBalloonFooterTopMargin      2.0f
#define kBalloonFooterBoxPadding     2.0f
#define kBalloonImageTopPadding      2.0f
#define kBalloonImageBottomPadding   2.0f

@interface MUMessageBubbleView : UIView {
    NSString                                  *_message;
    NSString                                  *_heading;
    NSString                                  *_footer;
    NSDate                                    *_date;
    BOOL                                      _rightSide;
    CGRect                                    _imageRect;
    BOOL                                      _selected;
    NSInteger                                 _numAttachments;
    NSArray                                   *_shownImages;
    MUMessageBubbleTableViewCell              *_cell;
}
- (void) setHeading:(NSString *)heading;
- (void) setFooter:(NSString *)footer;
- (void) setMessage:(NSString *)msg;
- (void) setDate:(NSDate *)date;
- (void) setShownImages:(NSArray *)shownImages;
- (void) setRightSide:(BOOL)rightSide;
- (CGRect) selectionRect;
- (void) setSelected:(BOOL)shouldBeSelected;
- (BOOL) isSelected;
+ (CGSize) cellSizeForText:(NSString *)text andHeading:(NSString *)heading andFooter:(NSString *)footer andDate:(NSDate *)date andImages:(NSArray *)images;
@end

@implementation MUMessageBubbleView

- (id) initWithFrame:(CGRect)frame andTableViewCell:(MUMessageBubbleTableViewCell *)cell {
    if ((self = [super initWithFrame:frame])) {
        [self setOpaque:NO];
        _rightSide = YES;
        _cell = cell;
    }
    return self;
}

+ (CGSize) textSizeForText:(NSString *)text {
    CGSize constraintSize = CGSizeMake(kBalloonWidth-(kBalloonMarginTailSide+kBalloonMarginNonTailSide), CGFLOAT_MAX);
    
    CGRect rect = [text boundingRectWithSize:constraintSize
                                  options:NSStringDrawingUsesLineFragmentOrigin
                               attributes:@{ NSFontAttributeName : [UIFont systemFontOfSize:14.0f] }
                                  context:nil];
    return rect.size;
}

+ (CGSize) headingSizeForText:(NSString *)text {
    CGSize constraintSize = CGSizeMake(kBalloonWidth-(kBalloonMarginTailSide+kBalloonMarginNonTailSide), CGFLOAT_MAX);
    CGRect rect = [text boundingRectWithSize:constraintSize
                                  options:NSStringDrawingUsesLineFragmentOrigin
                               attributes:@{ NSFontAttributeName : [UIFont boldSystemFontOfSize:14.0f] }
                                  context:nil];
    return rect.size;
}

+ (CGSize) timestampSizeForText:(NSString *)text {
    CGSize constraintSize = CGSizeMake(kBalloonWidth-(kBalloonMarginTailSide+kBalloonMarginNonTailSide), CGFLOAT_MAX);

    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingHead;

    CGRect rect = [text boundingRectWithSize:constraintSize
                                  options:NSStringDrawingUsesLineFragmentOrigin
                                  attributes:@{ NSFontAttributeName : [UIFont italicSystemFontOfSize:11.0f], NSParagraphStyleAttributeName : paragraphStyle }
                                  context:nil];
    return rect.size;
}

+ (CGSize) footerSizeForText:(NSString *)text {
    if (text == nil)
        return CGSizeZero;
    CGSize constraintSize = CGSizeMake(kBalloonWidth-(kBalloonMarginTailSide+kBalloonMarginNonTailSide), CGFLOAT_MAX);

    CGRect rect = [text boundingRectWithSize:constraintSize
                                  options:NSStringDrawingUsesLineFragmentOrigin
                                  attributes:@{ NSFontAttributeName : [UIFont italicSystemFontOfSize:11.0f] }
                                  context:nil];
    return rect.size;
}

+ (NSString *) stringForDate:(NSDate *)date {
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    [fmt setDateFormat:@"HH:mm"];
    return [fmt stringFromDate:date];
}

+ (CGSize) imageSizeForImages:(NSArray *)images resizedToFitWithinSize:(CGSize)sz andNewImageSizes:(NSArray **)array {
    NSMutableArray *imageSizes = [[NSMutableArray alloc] initWithCapacity:[images count]];
    CGFloat imagesHeight = 0;
    for (UIImage *image in images) {
        CGSize imgSize = [image size];
        if (imgSize.width < (sz.width - 40)) {
            imagesHeight += kBalloonImageTopPadding + imgSize.height + kBalloonImageBottomPadding;
            [imageSizes addObject:NSStringFromCGSize(imgSize)];
        } else {
            CGFloat w = sz.width - 40;
            CGFloat h = imgSize.height * (w / imgSize.width);
            imagesHeight += kBalloonImageTopPadding + h + kBalloonImageBottomPadding;
            [imageSizes addObject:NSStringFromCGSize(CGSizeMake(w, h))];
        }
    }
    if (array) {
        *array = imageSizes;
    }
    return CGSizeMake(sz.width, imagesHeight);
}

+ (CGSize) cellSizeForText:(NSString *)text andHeading:(NSString *)heading andFooter:(NSString *)footer andDate:(NSDate *)date andImages:(NSArray *)images {
    CGSize textSize = [MUMessageBubbleView textSizeForText:text];
    CGSize headingSize = [MUMessageBubbleView headingSizeForText:heading];
    CGSize footerSize = [MUMessageBubbleView footerSizeForText:footer];
    NSString *str = [MUMessageBubbleView stringForDate:date];
    CGSize timestampSize = [MUMessageBubbleView timestampSizeForText:str];

    CGSize sz = CGSizeMake(MAX(textSize.width, headingSize.width + kBalloonTimestampSpacing + timestampSize.width)+(kBalloonMarginTailSide + kBalloonMarginNonTailSide), textSize.height+headingSize.height+footerSize.height+(kBalloonTopMargin+kBalloonBottomMargin)+(kBalloonTopPadding+kBalloonBottomPadding)+(footer?kBalloonFooterTopMargin:0));

    CGSize imgSz = [MUMessageBubbleView imageSizeForImages:images resizedToFitWithinSize:sz andNewImageSizes:nil];
    sz.height += imgSz.height;
    sz.height = ceilf(sz.height);
    
    return sz;
}

- (void) drawRect:(CGRect)rect {

    UIImage *balloon = nil;
    UIImage *stretchableBalloon = nil;

    if (@available(iOS 7, *)) {
        if (_rightSide) {
            if (_selected) {
                balloon = [UIImage imageNamed:@"RightBalloonSelectedMono"];
            } else {
                balloon = [UIImage imageNamed:@"Balloon_2_Right"];
            }
            stretchableBalloon = [balloon resizableImageWithCapInsets:UIEdgeInsetsMake(kBalloonTopInset, kBalloonNoTailInset, kBalloonBottomInset, kBalloonTailInset)];
        } else {
            if (_selected) {
                balloon = [UIImage imageNamed:@"LeftBalloonSelectedMono"];
            } else {
                balloon = [UIImage imageNamed:@"Balloon_2"];
            }
            stretchableBalloon = [balloon resizableImageWithCapInsets:UIEdgeInsetsMake(kBalloonTopInset, kBalloonTailInset, kBalloonBottomInset, kBalloonNoTailInset)];
        }
    } else {
        if (_rightSide) {
            if (_selected) {
                balloon = [UIImage imageNamed:@"RightBalloonSelected"];
            } else {
                balloon = [UIImage imageNamed:@"Balloon_Blue"];
            }
            stretchableBalloon = [balloon resizableImageWithCapInsets:UIEdgeInsetsMake(kBalloonTopInset, kBalloonNoTailInset, kBalloonBottomInset, kBalloonTailInset)];
        } else {
            if (_selected) {
                balloon = [UIImage imageNamed:@"LeftBalloonSelected"];
            } else {
                balloon = [UIImage imageNamed:@"Balloon_2"];
            }
            stretchableBalloon = [balloon resizableImageWithCapInsets:UIEdgeInsetsMake(kBalloonTopInset, kBalloonTailInset, kBalloonBottomInset, kBalloonNoTailInset)];
        }
    }

    NSString *text = _message;
    NSString *heading = _heading;
    NSString *footer = _footer;
    NSArray *images = _shownImages;
    
    CGSize textSize = [MUMessageBubbleView textSizeForText:text];
    CGSize headingSize = [MUMessageBubbleView headingSizeForText:heading];
    CGSize footerSize = [MUMessageBubbleView footerSizeForText:footer];
    NSString *dateStr = [MUMessageBubbleView stringForDate:_date];
    CGSize timestampSize = [MUMessageBubbleView timestampSizeForText:dateStr];

    CGRect imgRect = CGRectMake(
        0.0f,
        kBalloonTopPadding,
        MAX(textSize.width, headingSize.width + kBalloonTimestampSpacing + timestampSize.width)+(kBalloonMarginTailSide + kBalloonMarginNonTailSide) + 10,
        textSize.height+headingSize.height+footerSize.height+(kBalloonTopMargin + kBalloonBottomMargin)+(footer?kBalloonFooterTopMargin:0)
    );
    imgRect = CGRectMake(
        (int) CGRectGetMinX(imgRect),
        (int) CGRectGetMinY(imgRect),
        (int) CGRectGetWidth(imgRect),
        (int) CGRectGetHeight(imgRect)
    );
    
    NSArray *newImageSizes = nil;
    CGSize imagesSize = [MUMessageBubbleView imageSizeForImages:images resizedToFitWithinSize:imgRect.size andNewImageSizes:&newImageSizes];
    imgRect.size.height += imagesSize.height;
    imgRect.size.height = ceilf(imgRect.size.height);
    
    CGRect headerRect = CGRectMake(kBalloonMarginTailSide, kBalloonTopPadding + kBalloonTopMargin, headingSize.width, headingSize.height);
    CGRect timestampRect = CGRectMake(imgRect.size.width - kBalloonMarginNonTailSide - timestampSize.width, headerRect.origin.y, timestampSize.width, timestampSize.height);
    CGRect textRect = CGRectMake(kBalloonMarginTailSide, kBalloonTopPadding + kBalloonTopMargin + headingSize.height, textSize.width, textSize.height);
    if (_rightSide) {
        CGRect frame = [self frame];
        imgRect.origin.x = CGRectGetWidth(frame) - imgRect.size.width;
        headerRect.origin.x = imgRect.origin.x + kBalloonMarginNonTailSide;
        timestampRect.origin.x = CGRectGetWidth(frame) - kBalloonMarginTailSide - timestampRect.size.width;
        textRect.origin.x = imgRect.origin.x + kBalloonMarginNonTailSide;
    }

    [stretchableBalloon drawInRect:imgRect];

    _imageRect = imgRect;

    int i = 0;
    CGFloat maxWidth = (timestampRect.origin.x + timestampRect.size.width) - headerRect.origin.x;
    CGRect shownImgRect = CGRectMake(0, textRect.origin.y+textRect.size.height, 0, 0);
    for (UIImage *shownImage in _shownImages) {
        shownImgRect.origin.y += kBalloonImageTopPadding + shownImgRect.size.height;
        CGSize imgSz = CGSizeFromString([newImageSizes objectAtIndex:i]);
        CGFloat leftPad = floorf((maxWidth - imgSz.width)/2);
        shownImgRect.origin.x = textRect.origin.x + leftPad;
        shownImgRect.size.width = imgSz.width;
        shownImgRect.size.height = imgSz.height;
        [shownImage drawInRect:shownImgRect];
        shownImgRect.size.height += kBalloonImageBottomPadding;
        ++i;
    }

    CGRect footerRect = CGRectMake(textRect.origin.x,
                                   textRect.origin.y + textRect.size.height+imagesSize.height + kBalloonFooterTopMargin,
                                   footerSize.width,
                                   footerSize.height);
    [[UIColor blackColor] set];
    
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
    [footer drawInRect:footerRect withAttributes:@{
        NSFontAttributeName: [UIFont italicSystemFontOfSize:11.0f],
        NSParagraphStyleAttributeName: paragraphStyle
    }];
    
    paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
    [heading drawInRect:headerRect withAttributes:@{
        NSFontAttributeName: [UIFont boldSystemFontOfSize:14.0f],
        NSParagraphStyleAttributeName: paragraphStyle
    }];
    
    paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingHead;
    [dateStr drawInRect:timestampRect withAttributes:@{
        NSFontAttributeName: [UIFont italicSystemFontOfSize:11.0f],
        NSParagraphStyleAttributeName: paragraphStyle
    }];
    
    paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
    [text drawInRect:textRect withAttributes:@{
        NSFontAttributeName: [UIFont systemFontOfSize:14.0f],
        NSParagraphStyleAttributeName: paragraphStyle
    }];
}

- (CGRect) selectionRect {    
    if (_rightSide) {
        return UIEdgeInsetsInsetRect(_imageRect, UIEdgeInsetsMake(kBalloonTopMargin, kBalloonMarginNonTailSide, kBalloonBottomMargin, kBalloonMarginTailSide));
    } else {
        return UIEdgeInsetsInsetRect(_imageRect, UIEdgeInsetsMake(kBalloonTopMargin, kBalloonMarginTailSide, kBalloonBottomMargin, kBalloonMarginNonTailSide));
    }
}

- (BOOL) isSelected {
    return _selected;
}

- (void) setSelected:(BOOL)selected {
    _selected = selected;
    [self setNeedsDisplay];
}

- (void) setHeading:(NSString *)heading {
    _heading = [heading copy];
    [self setNeedsDisplay];
}

- (void) setFooter:(NSString *)footer {
    _footer = [footer copy];
    [self setNeedsDisplay];
}

- (void) setMessage:(NSString *)msg {
    _message = [msg copy];
    [self setNeedsDisplay];
}

- (void) setDate:(NSDate *)date {
    _date = [date copy];
    [self setNeedsDisplay];
}

- (void) setRightSide:(BOOL)rightSide {
    _rightSide = rightSide;
    [self setNeedsDisplay];
}

- (void) setNumberOfAttachments:(NSInteger)numAttachments {
    _numAttachments = numAttachments;
    [self setNeedsDisplay];
}

- (void) setShownImages:(NSArray *)shownImages {
    _shownImages = shownImages;
    [self setNeedsDisplay];
}

- (BOOL) canBecomeFirstResponder {
    return YES;
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if ([self isFirstResponder]) {
        // A bit of a hack. Oh well.
        [[UIMenuController sharedMenuController] setMenuVisible:NO animated:YES];
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

@interface MUMessageBubbleTableViewCell () {
    MUMessageBubbleView                       *_bubbleView;
    UILongPressGestureRecognizer              *_longPressRecognizer;
    UITapGestureRecognizer                    *_tapRecognizer;
    id<MUMessageBubbleTableViewCellDelegate>  _delegate;
}
@end

@implementation MUMessageBubbleTableViewCell

+ (CGFloat) heightForCellWithHeading:(NSString *)heading message:(NSString *)msg images:(NSArray *)images footer:(NSString *)footer date:(NSDate *)date {
    return [MUMessageBubbleView cellSizeForText:msg andHeading:heading andFooter:footer andDate:date andImages:images].height;
}

- (id) initWithReuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier])) {        
        [self setSelectionStyle:UITableViewCellSelectionStyleNone];
    
        _bubbleView = [[MUMessageBubbleView alloc] initWithFrame:self.contentView.frame andTableViewCell:self];
        [_bubbleView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        [_bubbleView setUserInteractionEnabled:YES];
        [[self contentView] addSubview:_bubbleView];
        
        _longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(showMenu:)];
        [_bubbleView addGestureRecognizer:_longPressRecognizer];
        
        _tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showAttachments:)];
        [_bubbleView addGestureRecognizer:_tapRecognizer];
    }
    return self;
}

- (void) setDelegate:(id<MUMessageBubbleTableViewCellDelegate>)delegate {
    _delegate = delegate;
}

- (id<MUMessageBubbleTableViewCellDelegate>) delegate {
    return _delegate;
}

- (void) showAttachments:(id)sender {
    if (![_bubbleView isSelected])
        [_delegate messageBubbleTableViewCellRequestedAttachmentViewer:self];
}

- (void) showMenu:(id)sender {
    if (_longPressRecognizer.state == UIGestureRecognizerStateBegan) {
        if ([_bubbleView canBecomeFirstResponder]) {
            [_bubbleView becomeFirstResponder];
            [_bubbleView setSelected:YES];
            UIMenuController *menuController = [UIMenuController sharedMenuController];
            [menuController setTargetRect:[_bubbleView selectionRect] inView:_bubbleView];
            [menuController setMenuVisible:YES animated:YES];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(menuWillHide:) name:UIMenuControllerWillHideMenuNotification object:nil];
        }
    }
}

- (void) menuWillHide:(NSNotification *)notification {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_bubbleView resignFirstResponder];
    [_bubbleView setSelected:NO];
}

- (void) setSelected:(BOOL)selected {
    [_bubbleView setSelected:selected];
}

- (BOOL) isSelected {
    return [_bubbleView isSelected];
}

- (void) setHeading:(NSString *)heading {
    [_bubbleView setHeading:heading];
}

- (void) setMessage:(NSString *)msg {
    [_bubbleView setMessage:msg];
}

- (void) setShownImages:(NSArray *)shownImages {
    [_bubbleView setShownImages:shownImages];
}

- (void) setFooter:(NSString *)footer {
    [_bubbleView setFooter:footer];
}

- (void) setDate:(NSDate *)date {
    [_bubbleView setDate:date];
}

- (void) setRightSide:(BOOL)rightSide {
    [_bubbleView setRightSide:rightSide];
}

@end
