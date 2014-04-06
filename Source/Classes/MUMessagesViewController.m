// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

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
#import "MUOperatingSystem.h"
#import "MUBackgroundView.h"

static UIView *MUMessagesViewControllerFindUIView(UIView *rootView, NSString *prefix) {
    for (UIView *subview in [rootView subviews]) {
        if ([[subview description] hasPrefix:prefix]) {
            return subview;
        }
        UIView *candidate = MUMessagesViewControllerFindUIView(subview, prefix);
        if (candidate) {
            return candidate;
        }
    }
    return nil;
}

@interface MUConsistentTextField : UITextField
@end

@implementation MUConsistentTextField

- (CGRect) textRectForBounds:(CGRect)bounds {
    return [self editingRectForBounds:bounds];
}

- (CGRect) editingRectForBounds:(CGRect)bounds {
    NSInteger padding = 13;

    CGRect leftRect = [super leftViewRectForBounds:bounds];
    CGRect rect = [super editingRectForBounds:bounds];

    NSInteger minx = leftRect.size.width + padding; // 'at least'

    if (rect.origin.x < minx) {
        NSInteger delta = minx - rect.origin.x;
        rect.origin.x += delta;
        if (MUGetOperatingSystemVersion() < MUMBLE_OS_IOS_7) {
            rect.size.width -= delta;
        }
    }

    return rect;
}

@end

@interface MUMessageReceiverButton : UIControl {
    NSString *_str;
}
@end

@implementation MUMessageReceiverButton

- (id) initWithText:(NSString *)str {
    if ((self = [super initWithFrame:CGRectZero])) {
        [self setOpaque:NO];
        if ([str length] >= 15) {
            _str = [[NSString stringWithFormat:@"%@...", [str substringToIndex:11]] retain];
        } else {
            _str = [str copy];
        }
        CGSize size = [_str sizeWithFont:[UIFont boldSystemFontOfSize:14.0f]];
        if (MUGetOperatingSystemVersion() < MUMBLE_OS_IOS_7) {
            size.width += 6*2;
        }
        [self setFrame:CGRectMake(0, 0, size.width, size.height)];
    }
    return self;
}

- (void) drawRect:(CGRect)rect {
    rect = self.bounds;
    CGFloat radius = 6.0f;

    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextClearRect(context, rect);

    CGContextSetLineWidth(context, 1.0f);

    if (self.highlighted)
        [[UIColor lightGrayColor] setFill];
    else
        [[MUColor selectedTextColor] setFill];
    
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, rect.origin.x, rect.origin.y + radius);
    CGContextAddLineToPoint(context, rect.origin.x, rect.origin.y + rect.size.height - radius);
    CGContextAddArc(context, rect.origin.x + radius, rect.origin.y + rect.size.height - radius, 
                    radius, M_PI, M_PI / 2, 1); //STS fixed
    CGContextAddLineToPoint(context, rect.origin.x + rect.size.width - radius, 
                            rect.origin.y + rect.size.height);
    CGContextAddArc(context, rect.origin.x + rect.size.width - radius, 
                    rect.origin.y + rect.size.height - radius, radius, M_PI / 2, 0.0f, 1);
    CGContextAddLineToPoint(context, rect.origin.x + rect.size.width, rect.origin.y + radius);
    CGContextAddArc(context, rect.origin.x + rect.size.width - radius, rect.origin.y + radius, 
                    radius, 0.0f, -M_PI / 2, 1);
    CGContextAddLineToPoint(context, rect.origin.x + radius, rect.origin.y);
    CGContextAddArc(context, rect.origin.x + radius, rect.origin.y + radius, radius, 
                    -M_PI / 2, M_PI, 1);
    CGContextClosePath(context);
    
    CGContextFillPath(context);
    
    rect.origin.x = radius;
    rect.size.width -= radius;
    
    [[UIColor whiteColor] set];
    [_str drawInRect:rect withFont:[UIFont boldSystemFontOfSize:14.0f]];
}

- (void) setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [self setNeedsDisplay];
}

@end

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
        _model = [model retain];
        [_model addDelegate:self];
        _msgdb = [[MUMessagesDatabase alloc] init];
    }
    return self;
}

- (void) dealloc {
    [_msgdb release];
    [_model removeDelegate:self];
    [_model release];
    [_textField release];
    [_tableView release];
    [super dealloc];
}

- (void) clearAllMessages {
    [_msgdb release];
    _msgdb = [[MUMessagesDatabase alloc] init];
    [_tableView reloadData];
}

#pragma mark - View lifecycle

- (void) viewDidLoad {
    [super viewDidLoad];

    CGRect frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height-44);
    _tableView = [[UITableView alloc] initWithFrame:frame style:UITableViewStylePlain];

    [_tableView setBackgroundView:[MUBackgroundView backgroundView]];
    [_tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    [_tableView setAutoresizingMask:UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth];
    [_tableView setDelegate:self];
    [_tableView setDataSource:self];
    [self.view addSubview:_tableView];

    UISwipeGestureRecognizer *swipeGesture = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(hideKeyboard:)];
    [swipeGesture setDirection:UISwipeGestureRecognizerDirectionDown];
    [self.view addGestureRecognizer:swipeGesture];
    [swipeGesture release];

    swipeGesture = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(showKeyboard:)];
    [swipeGesture setDirection:UISwipeGestureRecognizerDirectionUp];
    [self.view addGestureRecognizer:swipeGesture];
    [swipeGesture release];

    CGRect textBarFrame = CGRectMake(0, frame.size.height, frame.size.width, 44);
    _textBarView = [[UIView alloc] initWithFrame:textBarFrame];
    [_textBarView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin];
    _textBarView.backgroundColor = [UIColor yellowColor];

    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        _textBarView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"BlackToolbarPatterniOS7"]];
    } else {
        _textBarView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"BlackToolbarPattern"]];
    }

    _textField = [[[MUConsistentTextField alloc] initWithFrame:CGRectMake(6, 6, frame.size.width-12, 44-12)] autorelease];
    _textField.leftViewMode = UITextFieldViewModeAlways;
    _textField.rightViewMode = UITextFieldViewModeAlways;
    _textField.borderStyle = UITextBorderStyleRoundedRect;
    _textField.textColor = [UIColor blackColor];
    _textField.font = [UIFont systemFontOfSize:17.0];
    _textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    _textField.returnKeyType = UIReturnKeySend;
    [_textField setDelegate:self];
    [_textBarView addSubview:_textField];
    [self.view addSubview:_textBarView];
    
    [self setReceiverName:[[[_model connectedUser] channel] channelName] andImage:@"channelmsg"];
}

- (void) setReceiverName:(NSString *)receiver andImage:(NSString *)imageName {
    MUMessageReceiverButton *receiverView = [[[MUMessageReceiverButton alloc] initWithText:receiver] autorelease];
    [receiverView addTarget:self action:@selector(showRecipientPicker:) forControlEvents:UIControlEventTouchUpInside];

    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        CGRect paddedRect = CGRectMake(0, 0, CGRectGetWidth(receiverView.frame) + 12, CGRectGetHeight(receiverView.frame));
        UIView *paddedView = [[[UIView alloc] initWithFrame:paddedRect] autorelease];
        [paddedView addSubview:receiverView];
        paddedRect.origin.x += 6;
        [receiverView setFrame:paddedRect];
        _textField.leftView = paddedView;
    } else {
        _textField.leftView = receiverView;
    }

    UIImageView *imgView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:imageName]] autorelease];
    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        CGRect paddedFrame = CGRectMake(0, 0, CGRectGetWidth(imgView.frame) + 6, CGRectGetHeight(imgView.frame));
        UIView *paddedView = [[UIView alloc] initWithFrame:paddedFrame];
        [paddedView addSubview:imgView];
        _textField.rightView = paddedView;
    } else {
        _textField.rightView = imgView;
    }
    _textField.rightViewMode = UITextFieldViewModeAlways;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    UINavigationBar *navBar = self.navigationController.navigationBar;
    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        navBar.tintColor = [UIColor whiteColor];
        navBar.translucent = NO;
        navBar.backgroundColor = [UIColor blackColor];
    }
    navBar.barStyle = UIBarStyleBlackOpaque;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    
    [_tableView reloadData];
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

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
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
    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        [cell setBackgroundColor:[UIColor clearColor]];
    }
    return cell;
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    MUTextMessage *txtMsg = [_msgdb messageAtIndex:[indexPath row]];
    if (txtMsg == nil)
        return 0.0f;
    NSString *footer = nil;
    if ([txtMsg hasAttachments]) {
        if ([txtMsg numberOfAttachments] > 1) {
            footer = [NSString stringWithFormat:NSLocalizedString(@"%li attachments", nil), (long int)[txtMsg numberOfAttachments]];
        } else {
            footer = NSLocalizedString(@"1 attachment", nil);
        }
    }
    return [MUMessageBubbleTableViewCell heightForCellWithHeading:[txtMsg heading] message:[txtMsg message] images:[txtMsg embeddedImages] footer:footer date:[txtMsg date]];
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
    
    // Make the keyboard background completely black on iOS 7.
    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100000), dispatch_get_main_queue(), ^{
            for (UIWindow *win in [[UIApplication sharedApplication] windows]) {
                if ([[win description] hasPrefix:@"<UITextEffectsWindow"]) {
                    UIView *possibleUIKBBackdropView = MUMessagesViewControllerFindUIView(win, @"<UIKBBackdropView");
                    if (possibleUIKBBackdropView) {
                        for (UIView *subview in [possibleUIKBBackdropView subviews]) {
                            if ([[subview description] hasPrefix:@"<UIView"]) {
                                [subview setBackgroundColor:[UIColor blackColor]];
                            }
                        }
                    }
                }
            }
        });
    }

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
    _textBarView.frame = CGRectMake(0, r.origin.y-44.0f, _tableView.frame.size.width, 44.0f);
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
    _textBarView.frame = CGRectMake(0, _tableView.frame.size.height, _tableView.frame.size.width, 44.0f);
    [UIView commitAnimations];

    if ([_msgdb count] > 0)
        [_tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:[_msgdb count]-1 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}

- (BOOL) textFieldShouldReturn:(UITextField *)textField {
    if ([[textField text] length] == 0)
        return NO;

    // Hack alert!
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
    [recipientViewController release];

    [self presentModalViewController:navCtrl animated:YES];
    [navCtrl release];
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
            [attachmentViewController release];
        } else {
            MUImageViewController *imgViewController = [[MUImageViewController alloc] initWithImages:[txtMsg embeddedImages]];
            [self.navigationController pushViewController:imgViewController animated:YES];
            [imgViewController release];
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
        // Are we in 'send to default channel mode'?
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
    if ([app applicationState] == UIApplicationStateBackground) {
        UILocalNotification *notification = [[[UILocalNotification alloc] init] autorelease];
        
        NSMutableCharacterSet *trimSet = [[NSMutableCharacterSet alloc] init];
        [trimSet formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
        [trimSet formUnionWithCharacterSet:[NSCharacterSet newlineCharacterSet]];
        [trimSet autorelease];
    
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
        
        if (user == nil) {
            notification.alertBody = msgText;
        } else {
           notification.alertBody = [NSString stringWithFormat:@"%@ - %@", [user userName], msgText]; 
        }

        [notification.userInfo setValue:indexPath forKey:@"indexPath"];
        [app presentLocalNotificationNow:notification];
        [app setApplicationIconBadgeNumber:[app applicationIconBadgeNumber]+1];
    }
}

@end
