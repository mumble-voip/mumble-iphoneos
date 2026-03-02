// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

@import CoreServices;
@import UserNotifications;

#import <MumbleKit/MKServerModel.h>
#import <MumbleKit/MKTextMessage.h>

#import "MUMessagesViewController.h"
#import "MUTextMessage.h"
#import "MUTextMessageProcessor.h"
#import "MUMessageBubbleTableViewCell.h"
#import "MUMessageRecipientViewController.h"
#import "MUMessageAttachmentViewController.h"
#import "MUImageViewController.h"
#import "MUMessagesDatabase.h"
#import "MUDataURL.h"
#import "MUColor.h"
#import "MUImage.h"

#pragma mark - MUConsistentTextField

@interface MUConsistentTextField : UITextField
@end

@implementation MUConsistentTextField

- (CGRect) textRectForBounds:(CGRect)bounds {
    return [self editingRectForBounds:bounds];
}

- (CGRect) editingRectForBounds:(CGRect)bounds {
    CGRect leftRect = [super leftViewRectForBounds:bounds];
    CGRect rect = [super editingRectForBounds:bounds];
    CGFloat minx = leftRect.size.width + 13;
    if (rect.origin.x < minx) {
        CGFloat delta = minx - rect.origin.x;
        rect.origin.x += delta;
    }
    return rect;
}

@end

#pragma mark - MUMessageReceiverButton

@interface MUMessageReceiverButton : UIControl {
    UILabel *_label;
}
@end

@implementation MUMessageReceiverButton

- (id) initWithText:(NSString *)str {
    if ((self = [super initWithFrame:CGRectZero])) {
        NSString *displayStr;
        if ([str length] >= 15) {
            displayStr = [NSString stringWithFormat:@"%@…", [str substringToIndex:11]];
        } else {
            displayStr = [str copy];
        }

        _label = [[UILabel alloc] init];
        _label.text = displayStr;
        _label.font = [UIFont systemFontOfSize:13.0f weight:UIFontWeightMedium];
        _label.textColor = [UIColor whiteColor];
        _label.textAlignment = NSTextAlignmentCenter;
        [_label sizeToFit];

        CGFloat hPad = 10.0f;
        CGFloat vPad = 4.0f;
        CGFloat w = _label.frame.size.width + 2 * hPad;
        CGFloat h = _label.frame.size.height + 2 * vPad;
        self.frame = CGRectMake(0, 0, w, h);
        _label.frame = CGRectMake(hPad, vPad, _label.frame.size.width, _label.frame.size.height);
        [self addSubview:_label];

        self.backgroundColor = [UIColor systemBlueColor];
        self.layer.cornerRadius = h / 2.0f;
        self.clipsToBounds = YES;
    }
    return self;
}

- (void) setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.alpha = highlighted ? 0.6 : 1.0;
}

@end

#pragma mark - MUMessagesViewController

@interface MUMessagesViewController () <UITableViewDelegate, UITableViewDataSource, MKServerModelDelegate, UITextFieldDelegate, MUMessageBubbleTableViewCellDelegate, MUMessageRecipientViewControllerDelegate> {
    MKServerModel            *_model;
    UITableView              *_tableView;
    UIView                   *_textBarView;
    MUConsistentTextField    *_textField;
    BOOL                     _autoCorrectGuard;
    MUMessagesDatabase       *_msgdb;

    MKChannel                *_channel;
    MKChannel                *_tree;
    MKUser                   *_user;
}
- (void) setReceiverName:(NSString *)receiver andImage:(NSString *)imageName;
@end

@implementation MUMessagesViewController

- (id) initWithServerModel:(MKServerModel *)model {
    if ((self = [super init])) {
        _model = model;
        [_model addDelegate:self];
        _msgdb = [[MUMessagesDatabase alloc] init];
    }
    return self;
}

- (void) dealloc {
    [_model removeDelegate:self];
}

- (void) clearAllMessages {
    _msgdb = [[MUMessagesDatabase alloc] init];
    [_tableView reloadData];
}

#pragma mark - View lifecycle

- (void) viewDidLoad {
    [super viewDidLoad];
}

- (void) setReceiverName:(NSString *)receiver andImage:(NSString *)imageName {
    MUMessageReceiverButton *receiverView = [[MUMessageReceiverButton alloc] initWithText:receiver];
    [receiverView addTarget:self action:@selector(showRecipientPicker:) forControlEvents:UIControlEventTouchUpInside];

    CGRect paddedRect = CGRectMake(0, 0, CGRectGetWidth(receiverView.frame) + 12, CGRectGetHeight(receiverView.frame));
    UIView *paddedView = [[UIView alloc] initWithFrame:paddedRect];
    CGRect rFrame = receiverView.frame;
    rFrame.origin.x = 6;
    receiverView.frame = rFrame;
    [paddedView addSubview:receiverView];
    _textField.leftView = paddedView;

    UIImage *img = [UIImage imageNamed:imageName];
    if (img) {
        UIImageView *imgView = [[UIImageView alloc] initWithImage:img];
        imgView.contentMode = UIViewContentModeScaleAspectFit;
        CGRect paddedImgFrame = CGRectMake(0, 0, CGRectGetWidth(imgView.frame) + 10, CGRectGetHeight(imgView.frame));
        UIView *paddedImgView = [[UIView alloc] initWithFrame:paddedImgFrame];
        [paddedImgView addSubview:imgView];
        _textField.rightView = paddedImgView;
        _textField.rightViewMode = UITextFieldViewModeAlways;
    }
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];

    [_tableView reloadData];
}

- (void) viewIsAppearing:(BOOL)animated {
    [super viewIsAppearing:animated];

    if (_tableView) return;

    CGFloat textBarHeight = 50.0f;
    UIEdgeInsets safeInsets = self.view.safeAreaInsets;
    CGFloat bottomInset = safeInsets.bottom;
    CGRect viewFrame = self.view.frame;

    // Table view
    CGRect tableViewFrame = CGRectMake(0, 0, viewFrame.size.width, viewFrame.size.height - textBarHeight - bottomInset);
    _tableView = [[UITableView alloc] initWithFrame:tableViewFrame style:UITableViewStylePlain];
    if (@available(iOS 13.0, *)) {
        _tableView.backgroundColor = [UIColor systemBackgroundColor];
    } else {
        _tableView.backgroundColor = [UIColor whiteColor];
    }
    [_tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    [_tableView setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.estimatedRowHeight = 80.0f;
    _tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [_tableView setDelegate:self];
    [_tableView setDataSource:self];
    [self.view addSubview:_tableView];

    // Swipe gestures for keyboard
    UISwipeGestureRecognizer *swipeDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(hideKeyboard:)];
    [swipeDown setDirection:UISwipeGestureRecognizerDirectionDown];
    [self.view addGestureRecognizer:swipeDown];

    UISwipeGestureRecognizer *swipeUp = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(showKeyboard:)];
    [swipeUp setDirection:UISwipeGestureRecognizerDirectionUp];
    [self.view addGestureRecognizer:swipeUp];

    // Input bar
    CGRect textBarFrame = CGRectMake(0, tableViewFrame.size.height, tableViewFrame.size.width, textBarHeight);
    _textBarView = [[UIView alloc] initWithFrame:textBarFrame];
    [_textBarView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin];
    if (@available(iOS 13.0, *)) {
        _textBarView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    } else {
        _textBarView.backgroundColor = [UIColor colorWithWhite:0.97 alpha:1.0];
    }

    // Separator at top of input bar
    UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(0, 0, textBarFrame.size.width, 1.0 / [UIScreen mainScreen].scale)];
    separator.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    if (@available(iOS 13.0, *)) {
        separator.backgroundColor = [UIColor separatorColor];
    } else {
        separator.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    }
    [_textBarView addSubview:separator];

    // Text field
    CGFloat tfMargin = 8.0f;
    CGFloat tfHeight = textBarHeight - 2 * tfMargin;
    _textField = [[MUConsistentTextField alloc] initWithFrame:CGRectMake(tfMargin, tfMargin, tableViewFrame.size.width - 2 * tfMargin, tfHeight)];
    _textField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _textField.leftViewMode = UITextFieldViewModeAlways;
    _textField.rightViewMode = UITextFieldViewModeAlways;
    _textField.borderStyle = UITextBorderStyleNone;
    _textField.textColor = [MUColor primaryTextColor];
    _textField.font = [UIFont systemFontOfSize:16.0];
    _textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    _textField.returnKeyType = UIReturnKeySend;
    _textField.layer.cornerRadius = tfHeight / 2.0f;
    _textField.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        _textField.backgroundColor = [UIColor tertiarySystemFillColor];
    } else {
        _textField.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
    }
    [_textField setDelegate:self];
    [_textBarView addSubview:_textField];
    [self.view addSubview:_textBarView];

    [self setReceiverName:[[[_model connectedUser] channel] channelName] andImage:@"channelmsg"];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_textField resignFirstResponder];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

- (void) scrollViewDidScroll:(UIScrollView *)scrollView {
    if ([[UIMenuController sharedMenuController] isMenuVisible]) {
        [[UIMenuController sharedMenuController] setMenuVisible:NO animated:YES];
    }
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

    MUTextMessage *txtMsg = [_msgdb messageAtIndex:[indexPath row]];
    [cell setHeading:[txtMsg heading]];
    [cell setMessage:[txtMsg message]];
    [cell setShownImages:[txtMsg embeddedImages]];
    [cell setDate:[txtMsg date]];
    if ([txtMsg hasAttachments]) {
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
    [cell setBackgroundColor:[UIColor clearColor]];
    return cell;
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

- (CGFloat) tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 80.0f;
}

#pragma mark - UIKeyboard notifications, UIView gesture recognizer

- (void) showKeyboard:(id)sender {
    [_textField becomeFirstResponder];
}

- (void) hideKeyboard:(id)sender {
    [_textField resignFirstResponder];
}

- (void) keyboardWillShow:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    if (_autoCorrectGuard)
        return;

    NSValue *val = [userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    NSTimeInterval t;
    [val getValue:&t];

    val = [userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey];
    UIViewAnimationCurve c;
    [val getValue:&c];

    val = [userInfo objectForKey:UIKeyboardFrameEndUserInfoKey];
    CGRect r;
    [val getValue:&r];
    r = [self.view convertRect:r fromView:nil];

    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:t];
    [UIView setAnimationCurve:c];
    _tableView.contentInset = UIEdgeInsetsMake(0.0f, 0.0f, r.size.height, 0.0f);
    _tableView.scrollIndicatorInsets = _tableView.contentInset;
    _textBarView.frame = CGRectMake(0, r.origin.y - 50.0f, _tableView.frame.size.width, 50.0f);
    [UIView commitAnimations];

    if ([_msgdb count] > 0)
        [_tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:[_msgdb count]-1 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}

- (void) keyboardWillHide:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    if (_autoCorrectGuard)
        return;

    NSValue *val = [userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    NSTimeInterval t;
    [val getValue:&t];

    val = [userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey];
    UIViewAnimationCurve c;
    [val getValue:&c];

    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:t];
    [UIView setAnimationCurve:c];
    _tableView.contentInset = UIEdgeInsetsZero;
    _tableView.scrollIndicatorInsets = UIEdgeInsetsZero;
    _textBarView.frame = CGRectMake(0, _tableView.frame.size.height, _tableView.frame.size.width, 50.0f);
    [UIView commitAnimations];

    if ([_msgdb count] > 0)
        [_tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:[_msgdb count]-1 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}

- (BOOL) textFieldShouldReturn:(UITextField *)textField {
    if ([[textField text] length] == 0)
        return NO;

    _autoCorrectGuard = YES;
    [textField resignFirstResponder];
    [textField becomeFirstResponder];
    _autoCorrectGuard = NO;

    NSString *originalStr = [textField text];
    if ([originalStr length] > 0) {
        NSString *htmlText = [MUTextMessageProcessor processedHTMLFromPlainTextMessage:originalStr];
        if (htmlText != nil) {
            MKTextMessage *txtMsg = [MKTextMessage messageWithHTML:htmlText];
            NSString *destName = nil;
            if (txtMsg != nil) {
                if (_tree == nil && _channel == nil && _user == nil) {
                    [_model sendTextMessage:txtMsg toChannel:[[_model connectedUser] channel]];
                    destName = [[[_model connectedUser] channel] channelName];
                } else if (_user != nil) {
                    [_model sendTextMessage:txtMsg toUser:_user];
                    destName = [_user userName];
                } else if (_channel != nil) {
                    [_model sendTextMessage:txtMsg toChannel:_channel];
                    destName = [_channel channelName];
                } else if (_tree != nil) {
                    [_model sendTextMessage:txtMsg toTree:_tree];
                    destName = [_tree channelName];
                }

                if (destName != nil) {
                    [_msgdb addMessage:txtMsg withHeading:[NSString stringWithFormat:NSLocalizedString(@"To %@", @"Message recipient title"), destName] andSentBySelf:YES];

                    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[_msgdb count]-1 inSection:0];
                    [_tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
                    [_tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
                }
            }
        }
    }

    [textField setText:nil];

    return NO;
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
    MUTextMessage *txtMsg = [_msgdb messageAtIndex:[indexPath row]];
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    [pasteboard setValue:[txtMsg message] forPasteboardType:(NSString *) kUTTypeUTF8PlainText];
}

- (void) messageBubbleTableViewCellRequestedDeletion:(MUMessageBubbleTableViewCell *)cell {
    NSIndexPath *indexPath = [_tableView indexPathForCell:cell];
    [_msgdb clearMessageAtIndex:[indexPath row]];
    [_tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
}

- (void) messageBubbleTableViewCellRequestedAttachmentViewer:(MUMessageBubbleTableViewCell *)cell {
    NSIndexPath *indexPath = [_tableView indexPathForCell:cell];
    MUTextMessage *txtMsg = [_msgdb messageAtIndex:[indexPath row]];
    if ([txtMsg hasAttachments]) {
        [cell setSelected:YES];
        if ([[txtMsg embeddedLinks] count] > 0) {
            MUMessageAttachmentViewController *attachmentViewController = [[MUMessageAttachmentViewController alloc] initWithImages:[txtMsg embeddedImages] andLinks:[txtMsg embeddedLinks]];
            [self.navigationController pushViewController:attachmentViewController animated:YES];
        } else {
            MUImageViewController *imgViewController = [[MUImageViewController alloc] initWithImages:[txtMsg embeddedImages]];
            [self.navigationController pushViewController:imgViewController animated:YES];
        }
    }
}

#pragma mark - MUMessageRecipientTableViewControllerDelegate

- (void) messageRecipientViewController:(MUMessageRecipientViewController *)viewCtrlr didSelectChannel:(MKChannel *)channel {
    _tree = nil;
    _channel = channel;
    _user = nil;

    [self setReceiverName:[channel channelName] andImage:@"channelmsg"];
}

- (void) messageRecipientViewController:(MUMessageRecipientViewController *)viewCtrlr didSelectUser:(MKUser *)user {
    _tree = nil;
    _channel = nil;
    _user = user;

    [self setReceiverName:[user userName] andImage:@"usermsg"];
}

- (void) messageRecipientViewControllerDidSelectCurrentChannel:(MUMessageRecipientViewController *)viewCtrlr {
    _tree = nil;
    _channel = nil;
    _user = nil;

    [self setReceiverName:[[[_model connectedUser] channel] channelName] andImage:@"channelmsg"];
}

#pragma mark - MKServerModel delegate

- (void) serverModel:(MKServerModel *)model joinedServerAsUser:(MKUser *)user withWelcomeMessage:(MKTextMessage *)msg {
   [_msgdb addMessage:msg withHeading:NSLocalizedString(@"Welcome Message", @"Title for welcome message") andSentBySelf:NO];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[_msgdb count]-1 inSection:0];
    [_tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    if (![_tableView isDragging] && ![[UIMenuController sharedMenuController] isMenuVisible]) {
        [_tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }
}

- (void) serverModel:(MKServerModel *)model userMoved:(MKUser *)user toChannel:(MKChannel *)chan fromChannel:(MKChannel *)prevChan byUser:(MKUser *)mover {
    if (user == [_model connectedUser]) {
        if (_user == nil && _channel == nil && _tree == nil) {
            [self setReceiverName:[[[_model connectedUser] channel] channelName] andImage:@"channelmsg"];
        }
    }
}

- (void) serverModel:(MKServerModel *)model userLeft:(MKUser *)user {
    if (user == _user) {
        _user = nil;
    }

    [self setReceiverName:[[[_model connectedUser] channel] channelName] andImage:@"channelmsg"];
}

- (void) serverModel:(MKServerModel *)model channelRenamed:(MKChannel *)channel {
    if (channel == _tree) {
        [self setReceiverName:[channel channelName] andImage:@"channelmsg"];
    } else if (channel == _channel) {
         [self setReceiverName:[channel channelName] andImage:@"channelmsg"];
    } else if (_channel == nil && _tree == nil && _user == nil && [[_model connectedUser] channel] == channel) {
        [self setReceiverName:[[[_model connectedUser] channel] channelName] andImage:@"channelmsg"];
    }
}

- (void) serverModel:(MKServerModel *)model channelRemoved:(MKChannel *)channel {
    if (channel == _tree) {
        _tree = nil;
        [self setReceiverName:[[[_model connectedUser] channel] channelName] andImage:@"channelmsg"];
    } else if (channel == _channel) {
        _channel = nil;
        [self setReceiverName:[[[_model connectedUser] channel] channelName] andImage:@"channelmsg"];
    }
}

- (void) serverModel:(MKServerModel *)model textMessageReceived:(MKTextMessage *)msg fromUser:(MKUser *)user {
    NSString *heading = NSLocalizedString(@"Server Message", @"A message sent from the server itself");
    if (user != nil) {
        heading = [NSString stringWithFormat:NSLocalizedString(@"From %@", @"Message sender title"), [user userName]];
    }
    [_msgdb addMessage:msg withHeading:heading andSentBySelf:NO];

    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[_msgdb count]-1 inSection:0];
    [_tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    if (![_tableView isDragging] && ![[UIMenuController sharedMenuController] isMenuVisible]) {
        [_tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }

    UIApplication *app = [UIApplication sharedApplication];
    if ([app applicationState] == UIApplicationStateBackground
        && [[NSUserDefaults standardUserDefaults] boolForKey:@"NotificationsEnabled"]) {
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

        UNNotificationRequest *notificationReq = [UNNotificationRequest requestWithIdentifier:@"info.mumble.Mumble.TextMessageNotification"
                                                                                     content:content
                                                                                     trigger:nil];
        [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
            if (settings.authorizationStatus == UNAuthorizationStatusAuthorized) {
                [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:notificationReq withCompletionHandler:nil];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [app setApplicationIconBadgeNumber:[app applicationIconBadgeNumber]+1];
                });
            }
        }];
    }
}

@end
