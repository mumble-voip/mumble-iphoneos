// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

@import UniformTypeIdentifiers;
@import UserNotifications;
@import PhotosUI;
@import ImageIO;

#import "MUApplicationDelegate.h"

#import "MLClient.h"

#import "MUMessagesViewController.h"
#import "MUTextMessage.h"
#import "MUTextMessageProcessor.h"
#import "MUMessageBubbleTableViewCell.h"
#import "MUMessageRecipientViewController.h"
#import "MUMessageAttachmentViewController.h"
#import "MUImageViewController.h"
#import "MUMessagesDatabase.h"
#import "MUDataURL.h"
#import "MUImage.h"

@interface MUMessagesViewController () <UITableViewDelegate, UITableViewDataSource, UITableViewDataSourcePrefetching, MLServerModelDelegate, UITextViewDelegate, PHPickerViewControllerDelegate, MUMessageBubbleTableViewCellDelegate, MUMessageRecipientViewControllerDelegate> {
    MLServerModel            *_model;
    UITableView              *_tableView;
    UIView                   *_textBarView;
    UITextView               *_textView;
    UILabel                  *_placeholderLabel;
    UIButton                 *_attachmentButton;
    UIImageView              *_photoPreview;
    UIButton                 *_removePhotoButton;
    UIImage                  *_pendingPhoto;
    BOOL                     _loadingPhoto, _preparingPhoto;
    NSUInteger               _photoGeneration;
    NSLayoutConstraint       *_textViewTop;
    NSLayoutConstraint       *_textViewLeading, *_photoPreviewWidth, *_photoPreviewHeight;
    UIView                   *_inputContainer;
    UIButton                 *_sendButton;
    UIButton                 *_recipientButton;
    NSLayoutConstraint       *_recipientHeight;
    NSLayoutConstraint       *_composerHeight;
    NSLayoutConstraint       *_keyboardBottom;
    __weak UIView            *_keyboardHost;
    NSString                 *_receiverName;
    MUMessagesDatabase       *_msgdb;

    MLChannel                *_channel;
    MLChannel                *_tree;
    MLUser                   *_user;
    CGFloat                  _messageLayoutWidth;
    NSMutableDictionary<NSNumber *, NSNumber *> *_messageHeights;
    CGFloat                  _lastTableHeight;
    CGFloat                  _lastComposerInset;
    BOOL                     _followKeyboardChanges;
    BOOL                     _sessionReconnecting;
}
- (void) setReceiverName:(NSString *)receiver symbol:(NSString *)symbolName;
@end

@implementation MUMessagesViewController

- (id) initWithServerModel:(MLServerModel *)model {
    if ((self = [super init])) {
        _model = model;
        [_model addDelegate:self];
        _msgdb = [self makeMessageStore];
        _messageHeights = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void) dealloc {
    [_model removeDelegate:self];
}

- (void) clearAllMessages {
    _msgdb = [self makeMessageStore];
    [_messageHeights removeAllObjects];
    [_tableView reloadData];
}

#pragma mark - View lifecycle

- (MUMessagesDatabase *)makeMessageStore {
    MUMessagesDatabase *store=[MUMessagesDatabase new];
    __weak MUMessagesViewController *weakSelf=self;
    __weak MUMessagesDatabase *weakStore=store;
    store.messageDidLoad=^(NSInteger row,MUTextMessage *message) {
        MUMessagesViewController *controller=weakSelf;
        if(!controller || controller->_msgdb!=weakStore)return;
        MUMessageBubbleTableViewCell *cell=[controller->_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
        [cell setShownImageSizes:message.embeddedImageSizes];[cell setShownImages:message.embeddedImages];
    };
    return store;
}
- (void)storeMessage:(MLTextMessage *)message heading:(NSString *)heading sentBySelf:(BOOL)sentBySelf {
    MUMessagesDatabase *store=_msgdb;
    __weak MUMessagesViewController *weakSelf=self;
    [store addMessage:message withHeading:heading andSentBySelf:sentBySelf completion:^{
        MUMessagesViewController *controller=weakSelf;
        if(controller && controller->_msgdb==store)[controller appendLastMessageSentBySelf:sentBySelf];
    }];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.backgroundColor = [UIColor systemBackgroundColor];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    _tableView.contentInset = UIEdgeInsetsMake(8, 0, 8, 0);
    _tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.prefetchDataSource = self;
    [self.view addSubview:_tableView];

    _textBarView = [UIView new];
    _textBarView.backgroundColor = [UIColor clearColor];
    _textBarView.opaque = NO;
    [self.view addSubview:_textBarView];
    _recipientButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_recipientButton addTarget:self action:@selector(showRecipientPicker:) forControlEvents:UIControlEventTouchUpInside];
    _recipientButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    [_textBarView addSubview:_recipientButton];
    _attachmentButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *add;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) add = [UIButtonConfiguration glassButtonConfiguration];
    else
#endif
        add = [UIButtonConfiguration grayButtonConfiguration];
    add.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    add.buttonSize = UIButtonConfigurationSizeSmall;
    UIImageSymbolConfiguration *addSymbol = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightRegular];
    add.image = [UIImage systemImageNamed:@"plus" withConfiguration:addSymbol];
    add.preferredSymbolConfigurationForImage = addSymbol;
    add.contentInsets = NSDirectionalEdgeInsetsMake(10, 10, 10, 10);
    add.baseForegroundColor = [UIColor labelColor];
    _attachmentButton.configuration = add;
    _attachmentButton.accessibilityLabel = NSLocalizedString(@"Add Photo", nil);
    [_attachmentButton addTarget:self action:@selector(showPhotoPicker:) forControlEvents:UIControlEventTouchUpInside];
    [_textBarView addSubview:_attachmentButton];
    UIVisualEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) effect = [UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular];
#endif
    UIVisualEffectView *inputMaterial = [[UIVisualEffectView alloc] initWithEffect:effect];
    _inputContainer = inputMaterial;
    _inputContainer.backgroundColor = UIColor.clearColor;
    _inputContainer.clipsToBounds = YES;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) _inputContainer.cornerConfiguration = [UICornerConfiguration capsuleConfigurationWithMaximumRadius:24];
    else
#endif
        _inputContainer.layer.cornerRadius = 24;
    [_textBarView addSubview:_inputContainer];
    _textView = [UITextView new];
    _textView.backgroundColor = [UIColor clearColor];
    _textView.textColor = [UIColor labelColor];
    _textView.adjustsFontForContentSizeCategory = YES;
    _textView.textContainerInset = UIEdgeInsetsMake(11, 0, 11, 0);
    _textView.textContainer.lineFragmentPadding = 0;
    _textView.scrollEnabled = NO;
    _textView.delegate = self;
    _textView.accessibilityLabel = NSLocalizedString(@"Message", nil);
    [inputMaterial.contentView addSubview:_textView];
    _placeholderLabel = [UILabel new];
    _placeholderLabel.text = NSLocalizedString(@"Message", nil);
    _placeholderLabel.textColor = [UIColor placeholderTextColor];
    _placeholderLabel.userInteractionEnabled = NO;
    [_textView addSubview:_placeholderLabel];
    _sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _sendButton.accessibilityLabel = NSLocalizedString(@"Send", nil);
    [_sendButton addTarget:self action:@selector(sendMessage:) forControlEvents:UIControlEventTouchUpInside];
    [_textBarView addSubview:_sendButton];
    _photoPreview = [UIImageView new];
    _photoPreview.contentMode = UIViewContentModeScaleAspectFill;
    _photoPreview.clipsToBounds = YES;
    _photoPreview.layer.cornerRadius = 12;
    _photoPreview.hidden = YES;
    [inputMaterial.contentView addSubview:_photoPreview];
    _removePhotoButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *remove = [UIButtonConfiguration plainButtonConfiguration];
    remove.image = [UIImage systemImageNamed:@"xmark" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold]];
    remove.baseForegroundColor = UIColor.labelColor;
    remove.background.backgroundColor = UIColor.systemBackgroundColor;
    remove.background.backgroundInsets = NSDirectionalEdgeInsetsMake(8, 8, 8, 8);
    remove.background.cornerRadius = 14;
    remove.background.strokeColor = UIColor.separatorColor;
    remove.background.strokeWidth = 1;
    remove.cornerStyle = UIButtonConfigurationCornerStyleFixed;
    _removePhotoButton.configuration = remove;
    _removePhotoButton.accessibilityLabel = NSLocalizedString(@"Remove Photo", nil);
    _removePhotoButton.hidden = YES;
    [_removePhotoButton addTarget:self action:@selector(removePhoto:) forControlEvents:UIControlEventTouchUpInside];
    // Keep the opaque close control outside the glass material and its clipping boundary.
    [_textBarView addSubview:_removePhotoButton];

    for (UIView *view in @[_tableView, _textBarView, _recipientButton, _attachmentButton, _inputContainer, _textView, _placeholderLabel, _sendButton, _photoPreview, _removePhotoButton]) view.translatesAutoresizingMaskIntoConstraints = NO;
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    self.view.keyboardLayoutGuide.followsUndockedKeyboard = YES;
    _composerHeight = [_textBarView.heightAnchor constraintEqualToConstant:78];
    _recipientHeight = [_recipientButton.heightAnchor constraintEqualToConstant:44];
    _textViewTop = [_textView.topAnchor constraintEqualToAnchor:_inputContainer.topAnchor];
    _textViewLeading = [_textView.leadingAnchor constraintEqualToAnchor:_inputContainer.leadingAnchor constant:14];
    _photoPreviewWidth = [_photoPreview.widthAnchor constraintEqualToConstant:96];
    _photoPreviewHeight = [_photoPreview.heightAnchor constraintEqualToConstant:96];
    _keyboardHost = self.view;
    _keyboardBottom = [_textBarView.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor];
    _keyboardBottom.priority = 999;
    NSLayoutConstraint *composerWidth = [_textBarView.widthAnchor constraintEqualToAnchor:safe.widthAnchor];
    composerWidth.priority = UILayoutPriorityDefaultHigh;
    composerWidth.active = YES;
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        // The history continues behind the floating glass instead of ending at an opaque strip.
        [_tableView.bottomAnchor constraintEqualToAnchor:_textBarView.bottomAnchor],
        [_textBarView.leadingAnchor constraintGreaterThanOrEqualToAnchor:safe.leadingAnchor],
        [_textBarView.trailingAnchor constraintLessThanOrEqualToAnchor:safe.trailingAnchor],
        [_textBarView.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
        [_textBarView.widthAnchor constraintLessThanOrEqualToConstant:720],
        _keyboardBottom,
        // A folded arrangement may place the conversation above the division
        // while its enclosing keyboard guide remains on the lower display.
        [_textBarView.bottomAnchor constraintLessThanOrEqualToAnchor:safe.bottomAnchor],
        [_textBarView.topAnchor constraintGreaterThanOrEqualToAnchor:safe.topAnchor],
        _composerHeight,
        _recipientHeight,
        [_recipientButton.leadingAnchor constraintEqualToAnchor:_inputContainer.leadingAnchor constant:12],
        [_recipientButton.trailingAnchor constraintLessThanOrEqualToAnchor:_inputContainer.trailingAnchor],
        [_recipientButton.topAnchor constraintEqualToAnchor:_textBarView.topAnchor constant:4],
        [_inputContainer.topAnchor constraintEqualToAnchor:_recipientButton.bottomAnchor constant:5],
        [_inputContainer.leadingAnchor constraintEqualToAnchor:_textBarView.leadingAnchor constant:60],
        [_inputContainer.trailingAnchor constraintEqualToAnchor:_sendButton.leadingAnchor constant:-8],
        [_inputContainer.bottomAnchor constraintEqualToAnchor:_textBarView.bottomAnchor constant:-8],
        [_attachmentButton.leadingAnchor constraintEqualToAnchor:_textBarView.leadingAnchor constant:8],
        [_attachmentButton.centerYAnchor constraintEqualToAnchor:_sendButton.centerYAnchor],
        [_attachmentButton.widthAnchor constraintEqualToConstant:44],
        [_attachmentButton.heightAnchor constraintEqualToConstant:44],
        [_sendButton.trailingAnchor constraintEqualToAnchor:_textBarView.trailingAnchor constant:-8],
        [_sendButton.bottomAnchor constraintEqualToAnchor:_textBarView.bottomAnchor constant:-9],
        [_sendButton.widthAnchor constraintEqualToConstant:44],
        [_sendButton.heightAnchor constraintEqualToConstant:44],
        _textViewLeading,
        [_textView.trailingAnchor constraintEqualToAnchor:_inputContainer.trailingAnchor constant:-14],
        _textViewTop,
        [_textView.bottomAnchor constraintEqualToAnchor:_inputContainer.bottomAnchor],
        [_placeholderLabel.leadingAnchor constraintEqualToAnchor:_textView.leadingAnchor],
        [_placeholderLabel.topAnchor constraintEqualToAnchor:_textView.topAnchor constant:11],
        [_placeholderLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_textView.trailingAnchor],
        [_photoPreview.leadingAnchor constraintEqualToAnchor:_inputContainer.leadingAnchor constant:12],
        [_photoPreview.topAnchor constraintEqualToAnchor:_inputContainer.topAnchor constant:10],
        _photoPreviewWidth,
        _photoPreviewHeight,
        [_removePhotoButton.centerXAnchor constraintEqualToAnchor:_photoPreview.trailingAnchor constant:-14],
        [_removePhotoButton.centerYAnchor constraintEqualToAnchor:_photoPreview.topAnchor constant:14],
        [_removePhotoButton.widthAnchor constraintEqualToConstant:44],
        [_removePhotoButton.heightAnchor constraintEqualToConstant:44]
    ]];
    [self updateComposerAppearance];
    [self setReceiverName:_model.connectedUser.channel.channelName symbol:@"person.2.circle.fill"];
    [self registerForTraitChanges:@[[UITraitPreferredContentSizeCategory class], [UITraitUserInterfaceStyle class], [UITraitAccessibilityContrast class]]
                     withHandler:^(__kindof MUMessagesViewController *controller, UITraitCollection *previousTraits) {
        [controller updateComposerAppearance];
        [controller->_messageHeights removeAllObjects];
        [controller->_tableView reloadData];
    }];
}

- (void)updateComposerAppearance {
    _textView.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody compatibleWithTraitCollection:self.traitCollection];
    _placeholderLabel.font = _textView.font;
    _recipientButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1 compatibleWithTraitCollection:self.traitCollection];
    _recipientHeight.constant = MAX(44, ceil(_recipientButton.titleLabel.font.lineHeight) + 12);
    [self updateComposerHeight];
    [self updateSendButton];
}

- (void)updateComposerHeight {
    CGFloat minimum = MAX(46, ceil(_textView.font.lineHeight) + 22);
    CGFloat available = CGFLOAT_MAX;
    if (self.view.window && !CGRectIsEmpty(self.view.bounds)) {
        UIView *host = _keyboardHost ?: self.view;
        CGRect keyboard = [host convertRect:host.keyboardLayoutGuide.layoutFrame toView:self.view];
        CGRect safe = self.view.safeAreaLayoutGuide.layoutFrame;
        available = MAX(0, MIN(CGRectGetMaxY(safe), CGRectGetMinY(keyboard)) - CGRectGetMinY(safe));
    }
    CGFloat fixedHeight = _recipientHeight.constant + 17;
    BOOL inlinePhoto = _pendingPhoto && available < minimum + 114 + fixedHeight;
    _textViewLeading.constant = inlinePhoto ? 78 : 14;
    _textViewTop.constant = _pendingPhoto && !inlinePhoto ? 114 : 0;
    _photoPreviewWidth.constant = _photoPreviewHeight.constant = inlinePhoto ? 44 : 96;
    if (inlinePhoto) minimum = MAX(minimum, 64);
    CGFloat width = _inputContainer.bounds.size.width - _textViewLeading.constant - 14;
    if (width < 1) width = MAX(100, self.view.bounds.size.width - 150 - (_textViewLeading.constant - 14));
    CGFloat measured = ceil([_textView sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height);
    CGFloat maximum = MAX(minimum, MIN(160, ceil(_textView.font.lineHeight * 5) + 22));
    CGFloat textHeight = MAX(minimum, MIN(maximum, measured));
    if (available > 0) textHeight = MAX(44, MIN(textHeight, available - fixedHeight - _textViewTop.constant));
    _textView.scrollEnabled = measured > textHeight;
    _composerHeight.constant = textHeight + _textViewTop.constant + fixedHeight;
}

- (void)textViewDidChange:(UITextView *)textView {
    [self updateComposerHeight];
    [self updateSendButton];
}

- (void)textViewDidBeginEditing:(UITextView *)textView {
    _followKeyboardChanges = _tableView.contentOffset.y >= [self bottomMessageOffset].y - 80;
}

- (void)updateSendButton {
    BOOL hasContent = [_textView.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length > 0 || _pendingPhoto != nil;
    _sendButton.enabled = !_sessionReconnecting && hasContent && _receiverName.length > 0 && !_loadingPhoto && !_preparingPhoto;
    _placeholderLabel.hidden = _textView.text.length > 0;
    _attachmentButton.enabled = !_loadingPhoto && !_preparingPhoto;
    _recipientButton.enabled = !_preparingPhoto;
    _removePhotoButton.enabled = !_preparingPhoto;
    UIButtonConfiguration *add = _attachmentButton.configuration;
    add.showsActivityIndicator = _loadingPhoto;
    _attachmentButton.configuration = add;
    UIButtonConfiguration *send;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) {
        send = [UIButtonConfiguration prominentGlassButtonConfiguration];
        send.baseBackgroundColor = [UIColor systemBlueColor];
        send.baseForegroundColor = [UIColor whiteColor];
    } else
#endif
    {
        send = [UIButtonConfiguration filledButtonConfiguration];
        send.baseBackgroundColor = [UIColor systemBlueColor];
        send.baseForegroundColor = [UIColor whiteColor];
    }
    send.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    send.buttonSize = UIButtonConfigurationSizeSmall;
    UIImageSymbolConfiguration *sendSymbol = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
    send.image = [UIImage systemImageNamed:@"arrow.up" withConfiguration:sendSymbol];
    send.preferredSymbolConfigurationForImage = sendSymbol;
    send.contentInsets = NSDirectionalEdgeInsetsMake(10, 10, 10, 10);
    _sendButton.configuration = send;
    _sendButton.accessibilityHint = _receiverName;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    // Native split panes can retain the previous keyboard geometry after a fold.
    // The enclosing navigation controller has the current scene's keyboard guide.
    UIView *keyboardHost = self.navigationController.view ?: self.view;
    if ([self.view isDescendantOfView:keyboardHost] && (_keyboardHost != keyboardHost || !_keyboardBottom.active)) {
        _keyboardBottom.active = NO;
        _keyboardHost = keyboardHost;
        keyboardHost.keyboardLayoutGuide.followsUndockedKeyboard = YES;
        _keyboardBottom = [_textBarView.bottomAnchor constraintEqualToAnchor:keyboardHost.keyboardLayoutGuide.topAnchor];
        _keyboardBottom.priority = 999;
        _keyboardBottom.active = YES;
    }
    [self updateComposerHeight];
    CGFloat width = CGRectGetWidth(_tableView.bounds) - _tableView.safeAreaInsets.left - _tableView.safeAreaInsets.right;
    if (width > 0 && width != _messageLayoutWidth) {
        BOOL atBottom = _tableView.contentOffset.y >= [self bottomMessageOffset].y - 80;
        NSIndexPath *anchor = _tableView.indexPathsForVisibleRows.firstObject;
        CGFloat distance = anchor ? _tableView.contentOffset.y - [_tableView rectForRowAtIndexPath:anchor].origin.y : 0;
        _messageLayoutWidth = width;
        [_messageHeights removeAllObjects];
        [_tableView reloadData];
        [_tableView layoutIfNeeded];
        if (atBottom) [_tableView setContentOffset:[self bottomMessageOffset] animated:NO];
        else if (anchor && anchor.row < [_tableView numberOfRowsInSection:0]) {
            CGFloat offset = [_tableView rectForRowAtIndexPath:anchor].origin.y + distance;
            offset = MIN([self bottomMessageOffset].y, MAX(-_tableView.adjustedContentInset.top, offset));
            [_tableView setContentOffset:CGPointMake(0, offset) animated:NO];
        }
    }
    CGFloat height = _tableView.bounds.size.height;
    CGFloat composerInset = _textBarView.bounds.size.height + 8;
    if (height != _lastTableHeight || composerInset != _lastComposerInset) {
        _lastTableHeight = height;
        _lastComposerInset = composerInset;
        _tableView.contentInset = UIEdgeInsetsMake(8, 0, composerInset, 0);
        _tableView.verticalScrollIndicatorInsets = UIEdgeInsetsMake(0, 0, composerInset, 0);
        if (_followKeyboardChanges && _textView.isFirstResponder && !_tableView.isDragging && !_tableView.isDecelerating)
            [_tableView setContentOffset:[self bottomMessageOffset] animated:NO];
    }
}

- (void)setReceiverName:(NSString *)receiver symbol:(NSString *)symbolName {
    if (_preparingPhoto) { ++_photoGeneration; _preparingPhoto = NO; _textView.editable = YES; }
    _receiverName = [receiver copy];
    [_recipientButton setTitle:receiver.length ? [NSString stringWithFormat:NSLocalizedString(@"To %@", @"Message recipient title"), receiver] : NSLocalizedString(@"Choose Recipient", nil) forState:UIControlStateNormal];
    [_recipientButton setImage:[MUImage symbolNamed:@"chevron.down" pointSize:9] forState:UIControlStateNormal];
    _recipientButton.tintColor = [UIColor secondaryLabelColor];
    _recipientButton.accessibilityLabel = NSLocalizedString(@"Choose Recipient", nil);
    _recipientButton.accessibilityValue = receiver;
    [self updateSendButton];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [_tableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_textView resignFirstResponder];
}

- (BOOL) editMenuIsVisible {
    for (UITableViewCell *cell in [_tableView visibleCells]) {
        if ([cell isKindOfClass:[MUMessageBubbleTableViewCell class]] && [(MUMessageBubbleTableViewCell *)cell isEditMenuVisible]) {
            return YES;
        }
    }
    return NO;
}

- (void) dismissVisibleEditMenus {
    for (UITableViewCell *cell in [_tableView visibleCells]) {
        if ([cell isKindOfClass:[MUMessageBubbleTableViewCell class]]) {
            [(MUMessageBubbleTableViewCell *)cell dismissEditMenu];
        }
    }
}

- (void) scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView.isDragging || scrollView.isDecelerating) [self dismissVisibleEditMenus];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    _followKeyboardChanges = NO;
}

#pragma mark - Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_msgdb count];
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"MUMessageViewCell";
    MUMessageBubbleTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[MUMessageBubbleTableViewCell alloc] initWithReuseIdentifier:CellIdentifier];
    }

    [self configureMessageCell:cell message:[_msgdb messageAtIndex:indexPath.row]];
    return cell;
}

- (void)configureMessageCell:(MUMessageBubbleTableViewCell *)cell message:(MUTextMessage *)txtMsg {
    [cell setHeading:[txtMsg heading]];
    [cell setMessage:[txtMsg message]];
    [cell setShownImageSizes:txtMsg.embeddedImageSizes];
    [cell setShownImages:[txtMsg embeddedImages]];
    [cell setDate:[txtMsg date]];
    if ([txtMsg embeddedLinks].count) {
        NSString *footer = nil;
        if ([txtMsg numberOfAttachments] > 1) {
            footer = [NSString stringWithFormat:NSLocalizedString(@"%li attachments", nil), (long int)[txtMsg numberOfAttachments]];
        } else {
            footer = NSLocalizedString(@"1 attachment", nil);
        }
        [cell setFooter:footer];
    } else {
        [cell setFooter:nil];
    }
    [cell setRightSide:[txtMsg isSentBySelf]];
    [cell setSelected:NO];
    [cell setDelegate:self];
}

- (void)tableView:(UITableView *)tableView prefetchRowsAtIndexPaths:(NSArray<NSIndexPath *> *)paths {
    NSMutableIndexSet *rows=[NSMutableIndexSet indexSet];for(NSIndexPath *path in paths)[rows addIndex:path.row];[_msgdb prefetchMessagesAtIndexes:rows];
}
- (void)tableView:(UITableView *)tableView cancelPrefetchingForRowsAtIndexPaths:(NSArray<NSIndexPath *> *)paths {
    NSMutableIndexSet *rows=[NSMutableIndexSet indexSet];for(NSIndexPath *path in paths)[rows addIndex:path.row];[_msgdb cancelPrefetchAtIndexes:rows];
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSNumber *cached = _messageHeights[@(indexPath.row)];
    if (cached) return cached.doubleValue;
    MUTextMessage *txtMsg = [_msgdb messageAtIndex:[indexPath row]];
    if (txtMsg == nil)
        return 0.0f;
    NSString *footer = nil;
    if ([txtMsg embeddedLinks].count) {
        if ([txtMsg numberOfAttachments] > 1) {
            footer = [NSString stringWithFormat:NSLocalizedString(@"%li attachments", nil), (long int)[txtMsg numberOfAttachments]];
        } else {
            footer = NSLocalizedString(@"1 attachment", nil);
        }
    }
    CGFloat height = [MUMessageBubbleTableViewCell heightForCellWithHeading:[txtMsg heading] message:[txtMsg message] images:txtMsg.embeddedImageSizes footer:footer date:[txtMsg date] width:CGRectGetWidth(tableView.bounds) - tableView.safeAreaInsets.left - tableView.safeAreaInsets.right traitCollection:tableView.traitCollection];
    _messageHeights[@(indexPath.row)] = @(height);
    return height;
}

#pragma mark - Sending and message animation

- (void)sendMessage:(id)sender {
    if (_sessionReconnecting || _preparingPhoto || _loadingPhoto) return;
    [_textView unmarkText];
    NSString *text = _textView.text ?: @"";
    if (!_pendingPhoto && ![text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length) return;
    NSString *html = [MUTextMessageProcessor processedHTMLFromPlainTextMessage:text] ?: @"";
    if (!_pendingPhoto) { [self sendPreparedMessage:[MLTextMessage messageWithHTML:html]]; return; }
    if (!_model.allowsHTMLMessages) { [self showPhotoError:NSLocalizedString(@"This server does not allow photos.", nil)]; return; }
    NSUInteger limit = _model.maximumImageMessageLength ?: 262144;
    limit = MIN(limit, 262144);
    UIImage *photo = _pendingPhoto;
    NSUInteger generation = ++_photoGeneration;
    BOOL restoreKeyboard = _textView.isFirstResponder;
    _preparingPhoto = YES;
    _textView.editable = NO;
    [self updateSendButton];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *body = [self HTMLForPhoto:photo text:html maximumLength:limit];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation != self->_photoGeneration) return;
            self->_preparingPhoto = NO;
            self->_textView.editable = YES;
            if (restoreKeyboard && self.view.window) [self->_textView becomeFirstResponder];
            [self updateSendButton];
            if (!body || !self->_model.allowsHTMLMessages || (self->_model.maximumImageMessageLength && [body lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > self->_model.maximumImageMessageLength)) {
                [self showPhotoError:NSLocalizedString(@"This photo and message cannot fit within the server’s image size limit. Try a shorter message or a different photo.", nil)];
                return;
            }
            [self sendPreparedMessage:[MLTextMessage messageWithHTML:body]];
        });
    });
}

- (void)sendPreparedMessage:(MLTextMessage *)message {
    if(_sessionReconnecting)return;
    NSString *destination = nil;
    if (_user) { destination = _user.userName; [_model sendTextMessage:message toUser:_user]; }
    else if (_channel) { destination = _channel.channelName; [_model sendTextMessage:message toChannel:_channel]; }
    else if (_tree) { destination = _tree.channelName; [_model sendTextMessage:message toTree:_tree]; }
    else {
        MLChannel *channel = _model.connectedUser.channel;
        destination = channel.channelName;
        if (channel) [_model sendTextMessage:message toChannel:channel];
    }
    if (!destination.length) return;
    [self storeMessage:message heading:[NSString stringWithFormat:NSLocalizedString(@"To %@", @"Message recipient title"), destination] sentBySelf:YES];
    _textView.text = nil;
    [self removePhoto:nil];
    [self updateComposerHeight];
    [self updateSendButton];
    _followKeyboardChanges = YES;
}

- (void)showPhotoPicker:(id)sender {
    if (_loadingPhoto || _preparingPhoto) return;
    if (!_model.allowsHTMLMessages) { [self showPhotoError:NSLocalizedString(@"This server does not allow photos.", nil)]; return; }
    PHPickerConfiguration *configuration = [[PHPickerConfiguration alloc] init];
    configuration.filter = [PHPickerFilter imagesFilter];
    configuration.selectionLimit = 1;
    configuration.preferredAssetRepresentationMode = PHPickerConfigurationAssetRepresentationModeCompatible;
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:configuration];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    NSItemProvider *provider = results.firstObject.itemProvider;
    [picker dismissViewControllerAnimated:YES completion:^{
        [self->_textView becomeFirstResponder];
        if (provider) [self loadPhotoFromProvider:provider];
    }];
}

- (void)loadPhotoFromProvider:(NSItemProvider *)provider {
    _loadingPhoto = YES;
    NSUInteger generation = ++_photoGeneration;
    [self updateSendButton];
    [provider loadFileRepresentationForTypeIdentifier:UTTypeImage.identifier completionHandler:^(NSURL *url, NSError *error) {
        UIImage *image = nil;
        if (url) {
            CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
            if (source) {
                NSDictionary *options = @{(__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways:@YES, (__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform:@YES, (__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize:@1024};
                CGImageRef thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
                if (thumbnail) { image = [UIImage imageWithCGImage:thumbnail]; CGImageRelease(thumbnail); }
                CFRelease(source);
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation != self->_photoGeneration) return;
            self->_loadingPhoto = NO;
            if (image) { self->_pendingPhoto = image; self->_photoPreview.image = image; self->_photoPreview.hidden = self->_removePhotoButton.hidden = NO; }
            else [self showPhotoError:NSLocalizedString(@"The photo could not be loaded. Please try again.", nil)];
            [self updateComposerHeight]; [self updateSendButton];
        });
    }];
}

- (void)removePhoto:(id)sender {
    _pendingPhoto = nil; _photoPreview.image = nil;
    _photoPreview.hidden = _removePhotoButton.hidden = YES;
    [self updateComposerHeight]; [self updateSendButton];
}

- (void)showPhotoError:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Photo", nil) message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
    if (!self.presentedViewController) [self presentViewController:alert animated:YES completion:nil];
}

- (NSString *)HTMLForPhoto:(UIImage *)photo text:(NSString *)text maximumLength:(NSUInteger)limit {
    if (photo.size.width <= 0 || photo.size.height <= 0) return nil;
    NSString *prefix = [NSString stringWithFormat:@"%@%@<img src=\"data:image/jpeg;base64,", text, text.length ? @"<br/>" : @""];
    if ([prefix lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 3 >= limit) return nil;
    for (CGFloat edge = MAX(128, MIN(1024, MAX(photo.size.width, photo.size.height))); edge >= 128; edge *= .75) {
        CGFloat scale = MIN(1, edge / MAX(photo.size.width, photo.size.height));
        UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat]; format.scale = 1; format.opaque = YES;
        CGSize resizedSize = CGSizeMake(MAX(1, floor(photo.size.width * scale)), MAX(1, floor(photo.size.height * scale)));
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:resizedSize format:format];
        UIImage *resized = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) { [[UIColor whiteColor] setFill]; CGRect bounds = CGRectMake(0, 0, resizedSize.width, resizedSize.height); UIRectFill(bounds); [photo drawInRect:bounds]; }];
        for (NSNumber *quality in @[@.8, @.6, @.4, @.25]) {
            NSData *jpeg = UIImageJPEGRepresentation(resized, quality.doubleValue);
            if (!jpeg) continue;
            NSString *html = [NSString stringWithFormat:@"%@%@\"/>", prefix, [jpeg base64EncodedStringWithOptions:0]];
            if ([html lengthOfBytesUsingEncoding:NSUTF8StringEncoding] <= limit) return html;
        }
    }
    return nil;
}

- (CGPoint)bottomMessageOffset {
    CGFloat bottom = _tableView.contentSize.height - CGRectGetHeight(_tableView.bounds) + _tableView.adjustedContentInset.bottom;
    return CGPointMake(0, MAX(-_tableView.adjustedContentInset.top, bottom));
}

- (void)appendLastMessageSentBySelf:(BOOL)sentBySelf {
    if (!_tableView || !self.view.window || CGRectIsEmpty(_tableView.bounds)) { [_tableView reloadData]; return; }
    BOOL follow = sentBySelf || (!_tableView.isDragging && !_tableView.isDecelerating && ![self editMenuIsVisible] &&
                                _tableView.contentOffset.y >= [self bottomMessageOffset].y - 80);
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:_msgdb.count - 1 inSection:0];
    if([_tableView numberOfRowsInSection:0]!=indexPath.row) {
        [_tableView reloadData];
        if(follow){[_tableView layoutIfNeeded];[_tableView setContentOffset:[self bottomMessageOffset] animated:NO];}
        return;
    }
    BOOL animate = !UIAccessibilityIsReduceMotionEnabled();
    [_tableView performBatchUpdates:^{
        [self->_tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:animate ? UITableViewRowAnimationBottom : UITableViewRowAnimationNone];
    } completion:^(BOOL finished) {
        if (follow && (sentBySelf || (!self->_tableView.isDragging && !self->_tableView.isDecelerating && ![self editMenuIsVisible])))
            [self->_tableView setContentOffset:[self bottomMessageOffset] animated:animate];
    }];
}

#pragma mark - Actions

- (void) showRecipientPicker:(id)sender {
    MUMessageRecipientViewController *recipientViewController = [[MUMessageRecipientViewController alloc] initWithServerModel:_model];
    [recipientViewController setDelegate:self];
    UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:recipientViewController];

    [self presentViewController:navCtrl animated:YES completion:nil];
}

#pragma mark - MUMessageBubbleTableViewCellDelegate

- (void) messageBubbleTableViewCellRequestedCopy:(MUMessageBubbleTableViewCell *)cell {
    NSIndexPath *indexPath = [_tableView indexPathForCell:cell];
    if(!indexPath)return;
    MUTextMessage *txtMsg = [_msgdb messageAtIndex:[indexPath row]];
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    [pasteboard setValue:[txtMsg message] forPasteboardType:UTTypeUTF8PlainText.identifier];
}

- (void) messageBubbleTableViewCellRequestedDeletion:(MUMessageBubbleTableViewCell *)cell {
    NSIndexPath *indexPath = [_tableView indexPathForCell:cell];
    if(!indexPath)return;
    [_msgdb clearMessageAtIndex:[indexPath row]];
    [_messageHeights removeObjectForKey:@(indexPath.row)];
    [_tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
}

- (void) messageBubbleTableViewCellRequestedAttachmentViewer:(MUMessageBubbleTableViewCell *)cell {
    NSIndexPath *indexPath = [_tableView indexPathForCell:cell];
    if(!indexPath)return;
    MUTextMessage *txtMsg = [_msgdb messageAtIndex:[indexPath row]];
    if ([txtMsg hasAttachments]) {
        [self.view endEditing:YES];
        [cell setSelected:YES];
        MUMessagesDatabase *store=_msgdb;
        MUImageLoader loader=txtMsg.embeddedImageSizes.count ? ^(void (^completion)(NSArray<UIImage *> *)) { [store loadImagesAtIndex:indexPath.row completion:completion]; } : nil;
        if ([[txtMsg embeddedLinks] count] > 0) {
            MUMessageAttachmentViewController *attachmentViewController = [[MUMessageAttachmentViewController alloc] initWithImages:txtMsg.embeddedImages andLinks:txtMsg.embeddedLinks imageCount:txtMsg.embeddedImageSizes.count imageLoader:loader];
            [self.navigationController pushViewController:attachmentViewController animated:YES];
        } else {
            MUImageViewController *imgViewController = [[MUImageViewController alloc] initWithImageLoader:loader];
            [self.navigationController pushViewController:imgViewController animated:YES];
        }
    }
}

#pragma mark - MUMessageRecipientTableViewControllerDelegate

- (void) messageRecipientViewController:(MUMessageRecipientViewController *)viewCtrlr didSelectChannel:(MLChannel *)channel {
    _tree = nil;
    _channel = channel;
    _user = nil;
    
    [self setReceiverName:[channel channelName] symbol:@"person.2.circle.fill"];
}

- (void) messageRecipientViewController:(MUMessageRecipientViewController *)viewCtrlr didSelectUser:(MLUser *)user {
    _tree = nil;
    _channel = nil;
    _user = user;
    
    [self setReceiverName:[user userName] symbol:@"person.circle.fill"];
}

- (void) messageRecipientViewControllerDidSelectCurrentChannel:(MUMessageRecipientViewController *)viewCtrlr {
    _tree = nil;
    _channel = nil;
    _user = nil;

    [self setReceiverName:[[[_model connectedUser] channel] channelName] symbol:@"person.2.circle.fill"];
}

#pragma mark - MLServerModel delegate
- (void)resetRecipientAfterReconnect {
    _sessionReconnecting=NO;
    _user=nil;_channel=nil;_tree=nil;
    [self setReceiverName:_model.connectedUser.channel.channelName symbol:@"person.2.circle.fill"];
    [self updateSendButton];
}
- (void)setConnectionReconnecting:(BOOL)reconnecting {
    _sessionReconnecting=reconnecting;[self updateSendButton];
}

- (void) serverModel:(MLServerModel *)model joinedServerAsUser:(MLUser *)user withWelcomeMessage:(MLTextMessage *)msg {
    if (!_user && !_channel && !_tree) [self setReceiverName:user.channel.channelName symbol:@"person.2.circle.fill"];
    [self storeMessage:msg heading:NSLocalizedString(@"Welcome Message", @"Title for welcome message") sentBySelf:NO];
}

- (void) serverModel:(MLServerModel *)model userMoved:(MLUser *)user toChannel:(MLChannel *)chan fromChannel:(MLChannel *)prevChan byUser:(MLUser *)mover {
    if (user == [_model connectedUser]) {
        // Are we in 'send to default channel mode'?
        if (_user == nil && _channel == nil && _tree == nil) {
            [self setReceiverName:[[[_model connectedUser] channel] channelName] symbol:@"person.2.circle.fill"];
        }
    }
}

- (void) serverModel:(MLServerModel *)model userLeft:(MLUser *)user {
    if (user == _user) {
        _user = nil;
        [self setReceiverName:[[[_model connectedUser] channel] channelName] symbol:@"person.2.circle.fill"];
    }
}

- (void) serverModel:(MLServerModel *)model channelRenamed:(MLChannel *)channel {
    if (channel == _tree) {
        [self setReceiverName:[channel channelName] symbol:@"person.2.circle.fill"];
    } else if (channel == _channel) {
         [self setReceiverName:[channel channelName] symbol:@"person.2.circle.fill"];
    } else if (_channel == nil && _tree == nil && _user == nil && [[_model connectedUser] channel] == channel) {
        [self setReceiverName:[[[_model connectedUser] channel] channelName] symbol:@"person.2.circle.fill"];
    }
}

- (void) serverModel:(MLServerModel *)model channelRemoved:(MLChannel *)channel {
    if (channel == _tree) {
        _tree = nil;
        [self setReceiverName:[[[_model connectedUser] channel] channelName] symbol:@"person.2.circle.fill"];
    } else if (channel == _channel) {
        _channel = nil;
        [self setReceiverName:[[[_model connectedUser] channel] channelName] symbol:@"person.2.circle.fill"];
    }
}

- (void) serverModel:(MLServerModel *)model textMessageReceived:(MLTextMessage *)msg fromUser:(MLUser *)user {
    NSString *heading = NSLocalizedString(@"Server Message", @"A message sent from the server itself");
    if (user != nil) {
        heading = [NSString stringWithFormat:NSLocalizedString(@"From %@", @"Message sender title"), [user userName]];
    }
    [self storeMessage:msg heading:heading sentBySelf:NO];
   
    UIApplication *app = [UIApplication sharedApplication];
    if ([app applicationState] == UIApplicationStateBackground) {
        NSMutableCharacterSet *trimSet = [[NSMutableCharacterSet alloc] init];
        [trimSet formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
        [trimSet formUnionWithCharacterSet:[NSCharacterSet newlineCharacterSet]];
    
        NSString *msgText = [[msg plainTextString] stringByTrimmingCharactersInSet:trimSet];
        NSUInteger numImages = [[msg embeddedImages] count];
        if ([msgText length] == 0) {
            if (numImages == 0) {
                msgText = NSLocalizedString(@"(Empty body)", nil);
            } else if (numImages == 1) {
                msgText = NSLocalizedString(@"(Message with image attachment)", nil);
            } else if (numImages > 1) {
                msgText = NSLocalizedString(@"(Message with image attachments)", nil);
            }
        } else {
            msgText = [msg plainTextString];
        }
        
        UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
        content.body = msgText;
        if (user) {
            content.title = [user userName];
        }
        
        UNNotificationRequest *notificationReq = [UNNotificationRequest requestWithIdentifier:@"com.blakebill.mumble.TextMessageNotification"
                                                                                     content:content
                                                                                     trigger:nil];
        [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:notificationReq withCompletionHandler:nil];
        [MUApplicationDelegate incrementApplicationBadgeCount];
    }
}

@end
