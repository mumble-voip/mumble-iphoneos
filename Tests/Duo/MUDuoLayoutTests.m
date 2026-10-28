// Loaded only by the isolated Simulator host. No network or microphone is used.
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "MLClient.h"
#import "MUServerRootViewController.h"
#import "MUServerViewController.h"
#import "MUMessagesViewController.h"
#import "MUOnboardingViewController.h"

@interface NSObject (DuoTests)
- (void)serverModel:(MLServerModel *)model textMessageReceived:(MLTextMessage *)message fromUser:(MLUser *)user;
- (void)updateComposerHeight;
- (void)updateSendButton;
- (void)setAudioTransmitMethod:(NSString *)method;
- (void)serverModel:(MLServerModel *)model channelAdded:(MLChannel *)channel;
- (void)continueClicked:(id)sender;
- (void)notify:(void (^)(id<MLServerModelDelegate>))block;
@end
static NSUInteger audioStarts;
static void NoAudioStart(id self, SEL selector) { audioStarts++; }
static NSString *Path(NSString *name) {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:name];
}
static NSString *MUDuoRect(CGRect rect) { return NSStringFromCGRect(rect); }

@interface MUDuoServerModel : MLServerModel
@end
@implementation MUDuoServerModel
- (void)setSelfMuted:(BOOL)muted andSelfDeafened:(BOOL)deafened {
    self.connectedUser.selfMuted = muted || deafened;
    self.connectedUser.selfDeafened = deafened;
    [self notify:^(id<MLServerModelDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(serverModel:userSelfMuteDeafenStateChanged:)])
            [delegate serverModel:self userSelfMuteDeafenStateChanged:self.connectedUser];
    }];
}
@end

@interface MUDuoPresentationRoot : MUServerRootViewController
@property(nonatomic, copy) NSArray<NSString *> *initialLayoutFailures;
@end
@implementation MUDuoPresentationRoot
- (void)viewIsAppearing:(BOOL)animated {
    [super viewIsAppearing:animated];
    NSMutableArray *failures = [NSMutableArray array];
    BOOL needsSide = self.traitCollection.verticalBarEdge == UIVerticalBarEdgeUnspecified &&
        self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular;
    if (needsSide && ![[self valueForKey:@"_usingSideVoiceControls"] boolValue])
        [failures addObject:@"First appearance uses the compact voice controls before adapting"];
    for (UIViewReservedRegion *region in [self.view reservedRegionsOfKind:UIViewReservedRegionKind.divisionRegionKind]) {
        if (region.frame.size.width > region.frame.size.height && self.view.bounds.size.width >= 669 && self.view.bounds.size.height >= 669 &&
            ![[self valueForKey:@"_usingFoldedControls"] boolValue])
            [failures addObject:@"First appearance delays the tabletop arrangement until presentation finishes"];
    }
    self.initialLayoutFailures = failures;
}
@end

static void RunOnboarding(UIWindow *window) {
    MUOnboardingViewController *welcome = [[MUOnboardingViewController alloc] initWithCompletion:^{}];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:welcome];
    window.rootViewController = navigation;
    [window makeKeyAndVisible];
    __block NSString *lastState;
    [NSTimer scheduledTimerWithTimeInterval:.4 repeats:YES block:^(NSTimer *timer) {
        @try {
            NSString *command = [NSString stringWithContentsOfFile:Path(@"duo-command.txt") encoding:NSUTF8StringEncoding error:nil];
            if (command.length) {
                [NSFileManager.defaultManager removeItemAtPath:Path(@"duo-command.txt") error:nil];
                if ([command isEqual:@"next"]) [(id)navigation.topViewController continueClicked:nil];
                else if ([command isEqual:@"back"]) [navigation popViewControllerAnimated:YES];
                else if ([command isEqual:@"large"]) navigation.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;
                else if ([command isEqual:@"standard"]) navigation.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryLarge;
            }
            MUOnboardingViewController *page = (id)navigation.topViewController;
            if (![page isKindOfClass:MUOnboardingViewController.class]) return;
            CGRect safe = [page.view convertRect:page.view.safeAreaLayoutGuide.layoutFrame toView:window];
            CGRect table = [page.tableView convertRect:page.tableView.bounds toView:window];
            UIView *footer = [page valueForKey:@"_footerStack"];
            CGRect action = [footer convertRect:footer.bounds toView:window];
            UIStackView *header = [page valueForKey:@"_headerStack"];
            CGRect heading = [header convertRect:header.bounds toView:window];
            NSMutableArray *failures = [NSMutableArray array];
            if (!CGRectContainsRect(CGRectInset(safe, -1, -1), table)) [failures addObject:@"Setup table extends into the system bar/camera area"];
            if (!CGRectContainsRect(CGRectInset(safe, -1, -1), action)) [failures addObject:@"Setup action is outside the content safe area"];
            if (page.tableView.tableHeaderView && (CGRectGetMinX(heading) < CGRectGetMinX(safe) - 1 || CGRectGetMaxX(heading) > CGRectGetMaxX(safe) + 1)) [failures addObject:@"Setup heading extends underneath the vertical bar"];
            if (!CGRectIsEmpty(CGRectIntersection(table, action))) [failures addObject:@"Setup action covers the scrollable options"];
            if (action.size.width > 561) [failures addObject:@"Setup action stretches across the inner display"];
            if (CGRectGetMaxY(action) > CGRectGetMaxY(safe) - 7 || CGRectGetMaxY(action) < CGRectGetMaxY(safe) - 9) [failures addObject:@"Setup action moved away from its bottom anchor"];
            NSDictionary *state = @{@"setup":@YES, @"step":[page valueForKey:@"_step"], @"window":MUDuoRect(window.bounds), @"safe":MUDuoRect(safe), @"table":MUDuoRect(table), @"heading":MUDuoRect(heading), @"action":MUDuoRect(action), @"verticalBarEdge":@(navigation.traitCollection.verticalBarEdge), @"failures":failures};
            NSData *data = [NSJSONSerialization dataWithJSONObject:state options:NSJSONWritingPrettyPrinted error:nil];
            NSString *signature = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (![lastState isEqual:signature]) {
                lastState = signature;
                [data writeToFile:Path(@"duo-state.json") atomically:YES];
                UIImage *snapshot = [[[UIGraphicsImageRenderer alloc] initWithBounds:window.bounds] imageWithActions:^(UIGraphicsImageRendererContext *context) { [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:NO]; }];
                [UIImagePNGRepresentation(snapshot) writeToFile:Path(@"duo-layout.png") atomically:YES];
            }
        } @catch (NSException *exception) {
            [exception.reason writeToFile:Path(@"duo-failure.txt") atomically:YES encoding:NSUTF8StringEncoding error:nil]; [timer invalidate];
        }
    }];
}

static void Run(void) {
    method_setImplementation(class_getInstanceMethod(MLAudio.class, @selector(start)), (IMP)NoAudioStart);
    UIWindowScene *scene = (id)UIApplication.sharedApplication.connectedScenes.allObjects.firstObject;
    UIWindow *window = [(id)scene.delegate valueForKey:@"window"];
    if ([NSProcessInfo.processInfo.environment[@"MU_DUO_TEST_ONBOARDING"] boolValue]) { RunOnboarding(window); return; }
    MLConnection *connection = [MLConnection new];
    MLServerModel *model = [[MUDuoServerModel alloc] initWithConnection:nil];
    model.rootChannel.channelName = @"Mumble community";
    MLUser *me = [MLUser new]; me.session = 1; me.userName = @"Me"; me.channel = model.rootChannel;
    [[model.rootChannel valueForKey:@"userStorage"] addObject:me]; [model setValue:me forKey:@"_connectedUser"];
    MLUser *alice = [MLUser new]; alice.session = 2; alice.userName = @"Alice"; alice.channel = model.rootChannel;
    alice.talkState = MLTalkStateTalking; [[model.rootChannel valueForKey:@"userStorage"] addObject:alice];
    for (NSUInteger i = 1; i <= 24; i++) {
        MLChannel *room = [MLChannel new]; room.channelId = i; room.channelName = [NSString stringWithFormat:@"Voice room %02lu", (unsigned long)i]; room.parent = model.rootChannel;
        [[model.rootChannel valueForKey:@"childStorage"] addObject:room];
    }
    MUDuoPresentationRoot *root = [[MUDuoPresentationRoot alloc] initWithConnection:connection andServerModel:model];
    MUMessagesViewController *messages = [root valueForKey:@"_messagesView"];
    MUServerViewController *server = [root valueForKey:@"_serverView"];
    for (NSUInteger i = 0; i < 20; i++) [messages serverModel:model textMessageReceived:[MLTextMessage messageWithPlainText:i == 19 ? @"Channels and messages stay together as the display changes. The connection and microphone are independent of this layout." : [NSString stringWithFormat:@"Message %lu — keeping the current channel and conversation.", (unsigned long)i + 1]] fromUser:alice];
    [NSUserDefaults.standardUserDefaults setObject:@"vad" forKey:@"AudioTransmitMethod"];
    MLAudioSettings settings; [MLAudio.sharedAudio readAudioSettings:&settings]; settings.transmitType = MLTransmitTypeVAD; [MLAudio.sharedAudio updateAudioSettings:&settings];
    UIViewController *presenter = [UIViewController new];
    window.rootViewController = presenter; [window makeKeyAndVisible];
    root.modalPresentationStyle = UIModalPresentationFullScreen;
    __block BOOL presentationFinished = NO;
    [presenter presentViewController:root animated:YES completion:^{ presentationFinished = YES; }];
    __block NSString *lastState;
    __block BOOL armed = NO;
    __block UIImage *draftPhoto;
    __block BOOL changedHiddenTree = NO;
    __block BOOL hiddenTreeCaughtUp = NO;
    __block CGRect systemKeyboardFrame = CGRectNull;
    __block CGRect dockBeforeDirectionChange = CGRectNull;
    for (NSString *name in @[UIKeyboardWillChangeFrameNotification, UIKeyboardWillShowNotification, UIKeyboardWillHideNotification])
        [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *notification) {
            systemKeyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
        }];
    [NSTimer scheduledTimerWithTimeInterval:.4 repeats:YES block:^(NSTimer *timer) {
        @try {
            if (!presentationFinished) return;
            NSString *command = [NSString stringWithContentsOfFile:Path(@"duo-command.txt") encoding:NSUTF8StringEncoding error:nil];
            if (command.length) {
                [NSFileManager.defaultManager removeItemAtPath:Path(@"duo-command.txt") error:nil];
                if ([command isEqual:@"messages"] || [command isEqual:@"draft"] || [command isEqual:@"keyboard"]) {
                    UISegmentedControl *segments = [root valueForKey:@"_segmentedControl"];
                    segments.selectedSegmentIndex = 1; [segments sendActionsForControlEvents:UIControlEventValueChanged];
                    [messages loadViewIfNeeded];
                    UITextView *field = [messages valueForKey:@"_textView"];
                    if ([command isEqual:@"draft"]) {
                        armed = YES; field.text = @"Draft survives folding and resizing";
                        draftPhoto = [[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(96, 96)] imageWithActions:^(UIGraphicsImageRendererContext *context) { [UIColor.systemBlueColor setFill]; UIRectFill(CGRectMake(0, 0, 96, 96)); }];
                        [messages setValue:draftPhoto forKey:@"_pendingPhoto"];
                        UIImageView *preview = [messages valueForKey:@"_photoPreview"]; preview.image = draftPhoto; preview.hidden = NO;
                        [(UIButton *)[messages valueForKey:@"_removePhotoButton"] setHidden:NO];
                        [messages updateComposerHeight];
                        [messages updateSendButton];
                    }
                    if ([command isEqual:@"keyboard"]) [field becomeFirstResponder];
                } else if ([command isEqual:@"ptt"] || [command isEqual:@"vad"]) {
                    [(id)UIApplication.sharedApplication.delegate setAudioTransmitMethod:command];
                    UISegmentedControl *segments = [root valueForKey:@"_segmentedControl"];
                    segments.selectedSegmentIndex = 0; [segments sendActionsForControlEvents:UIControlEventValueChanged];
                } else if ([command isEqual:@"server"]) {
                    UISegmentedControl *segments = [root valueForKey:@"_segmentedControl"];
                    segments.selectedSegmentIndex = 0; [segments sendActionsForControlEvents:UIControlEventValueChanged];
                } else if ([command isEqual:@"rtl"] || [command isEqual:@"ltr"]) {
                    [window endEditing:YES];
                    UIView *dock = [server valueForKey:@"_voiceDock"];
                    dockBeforeDirectionChange = [command isEqual:@"rtl"] && dock ? [dock convertRect:dock.bounds toView:window] : CGRectNull;
                    UISemanticContentAttribute direction = [command isEqual:@"rtl"] ? UISemanticContentAttributeForceRightToLeft : UISemanticContentAttributeForceLeftToRight;
                    UITraitEnvironmentLayoutDirection traitDirection = [command isEqual:@"rtl"] ? UITraitEnvironmentLayoutDirectionRightToLeft : UITraitEnvironmentLayoutDirectionLeftToRight;
                    window.traitOverrides.layoutDirection = traitDirection;
                    root.traitOverrides.layoutDirection = traitDirection;
                    window.semanticContentAttribute = direction;
                    root.view.semanticContentAttribute = direction;
                    [root.view setNeedsLayout];
                } else if ([command isEqual:@"hold"]) {
                    UIButton *talk = [server valueForKey:@"_talkButton"]; [talk sendActionsForControlEvents:UIControlEventTouchDown];
                } else if ([command isEqual:@"release"]) {
                    UIButton *talk = [server valueForKey:@"_talkButton"]; [talk sendActionsForControlEvents:UIControlEventTouchUpInside];
                } else if ([command isEqual:@"dismissKeyboard"]) [window endEditing:YES];
                else if ([command isEqual:@"hiddenUpdate"] && CGRectIsEmpty(server.view.bounds)) {
                    MLChannel *room = [MLChannel new]; room.channelId = 50; room.channelName = @"Added while hidden"; room.parent = model.rootChannel;
                    [[model.rootChannel valueForKey:@"childStorage"] addObject:room];
                    [server serverModel:model channelAdded:room]; changedHiddenTree = YES;
                }
            }
            BOOL wide = [[root valueForKey:@"_showingBothPanes"] boolValue];
            BOOL book = [[root valueForKey:@"_usingBookLayout"] boolValue];
            BOOL folded = [[root valueForKey:@"_usingFoldedControls"] boolValue];
            UIView *controls = server.voiceControlsHostView;
            CGRect controlsRect = controls ? [controls convertRect:controls.bounds toView:window] : CGRectZero;
            UIView *dock = [server valueForKey:@"_voiceDock"];
            CGRect serverRect = [server.view convertRect:server.view.bounds toView:window];
            CGRect messageRect = [messages.view convertRect:messages.view.bounds toView:window];
            CGRect dockRect = dock ? [dock convertRect:dock.bounds toView:window] : CGRectZero;
            CGRect messageContent = [messages.view convertRect:messages.view.safeAreaLayoutGuide.layoutFrame toView:window];
            NSMutableArray *failures = [NSMutableArray array];
            if (!root.initialLayoutFailures) [failures addObject:@"Initial appearance was not checked"];
            [failures addObjectsFromArray:root.initialLayoutFailures ?: @[]];
            NSMutableArray *occlusions = [NSMutableArray array];
            for (UIViewReservedRegion *region in [root.view reservedRegionsOfKind:UIViewReservedRegionKind.occlusionRegionKind]) {
                CGRect rect = [root.view convertRect:region.frame toView:window];
                [occlusions addObject:MUDuoRect(rect)];
                if (!CGRectIsEmpty(CGRectIntersection(rect, dockRect))) [failures addObject:@"Voice controls overlap a camera or system occlusion"];
            }
            BOOL sideVoiceControls = [[root valueForKey:@"_usingSideVoiceControls"] boolValue];
            UIViewController *container = [root valueForKey:@"_conversationContainer"];
            BOOL nativeVoiceControls = [[root valueForKey:@"_usingNativeVoiceControls"] boolValue];
            BOOL nativePTT = nativeVoiceControls && [[NSUserDefaults.standardUserDefaults stringForKey:@"AudioTransmitMethod"] isEqualToString:@"ptt"];
            if (root.traitCollection.verticalBarEdge != UIVerticalBarEdgeUnspecified &&
                (!nativeVoiceControls || root.isToolbarHidden || container.toolbarItems.count != 2 || (dock && !nativePTT)))
                [failures addObject:@"Vertical voice controls are missing from the system toolbar or duplicated in content"];
            if (nativePTT && (!dock || ![server valueForKey:@"_talkButton"] || [server valueForKey:@"_speakerButton"]))
                [failures addObject:@"Native mute controls lost their separate hold-to-speak target or duplicated the speaker button"];
            if (!container.navigationItem.additionalOverflowItems)
                [failures addObject:@"Server actions are missing from the native overflow menu"];
            if (!wide && !folded && root.traitCollection.verticalBarEdge != UIVerticalBarEdgeUnspecified &&
                (!container.navigationItem.rightBarButtonItem || container.navigationItem.titleView))
                [failures addObject:@"Compact vertical navigation has no native Server/Messages switcher"];
            if (sideVoiceControls) {
                CGRect safe = [root.view convertRect:root.view.safeAreaLayoutGuide.layoutFrame toView:window];
                if (!CGRectContainsRect(CGRectInset(safe, -1, -1), dockRect))
                    [failures addObject:@"Custom voice controls intrude into the system navigation/status bar"];
                BOOL onLeft = root.traitCollection.verticalBarEdge != UIVerticalBarEdgeUnspecified &&
                    ((root.traitCollection.verticalBarEdge == UIVerticalBarEdgeLeading) !=
                     (root.view.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft));
                if (onLeft ? CGRectGetMidX(dockRect) > CGRectGetMidX(safe) : CGRectGetMidX(dockRect) < CGRectGetMidX(safe))
                    [failures addObject:@"Voice controls do not follow the system bar edge"];
            }
            if (sideVoiceControls && (!dock || !server.voiceControlsAtSide || !controls))
                [failures addObject:@"Side voice controls disappear during a posture or pane change"];
            if (sideVoiceControls && !CGRectIsNull(dockBeforeDirectionChange) &&
                fabs(CGRectGetMidX(dockRect) - CGRectGetMidX(dockBeforeDirectionChange)) > 1)
                [failures addObject:@"Changing reading direction moved controls away from the hardware-aligned bar"];
            if (sideVoiceControls && ![(UITextView *)[messages valueForKey:@"_textView"] isFirstResponder] && CGRectGetMinY(dockRect) < CGRectGetMidY([root.view convertRect:root.view.safeAreaLayoutGuide.layoutFrame toView:window]))
                [failures addObject:@"Side voice controls moved into the upper half of the display"];
            if ([root valueForKey:@"_connection"] != connection || [root valueForKey:@"_model"] != model) [failures addObject:@"Connection/model replaced during layout"];
            if (audioStarts) [failures addObject:@"Layout started microphone capture"];
            if (changedHiddenTree && ![[server valueForKey:@"_modelRefreshScheduled"] boolValue]) {
                NSUInteger rows = [[server valueForKey:@"_modelItems"] count];
                if (!CGRectIsEmpty(server.view.bounds) && rows == 28) hiddenTreeCaughtUp = YES;
                if (rows != (CGRectIsEmpty(server.view.bounds) && !hiddenTreeCaughtUp ? 27 : 28)) [failures addObject:@"Hidden channel tree refreshed early or failed to catch up"];
            }
            if (wide && (!server.view.window || !messages.view.window || CGRectIntersection(serverRect, messageRect).size.width > 1)) [failures addObject:@"Native panes overlap or disappear"];
            UISegmentedControl *segments = [root valueForKey:@"_segmentedControl"];
            if (folded && (messages.view.hidden || CGRectIsEmpty(messages.view.bounds) || !CGRectIsEmpty(CGRectIntersection(messageContent, controlsRect)))) [failures addObject:@"Folded messages and controls overlap or disappear"];
            if (folded && (!dock || CGRectIsEmpty(controlsRect) || !CGRectIsEmpty(CGRectIntersection(serverRect, controlsRect)))) [failures addObject:@"Folded channels and controls overlap or disappear"];
            if (!wide && !folded && !(segments.selectedSegmentIndex == 1 ? messages.view.window : server.view.window)) [failures addObject:@"Compact content disappeared during reparenting"];
            UIViewController *arrangement = [root valueForKey:@"_arrangementController"];
            CGRect usable = [arrangement.view convertRect:arrangement.view.bounds toView:window];
            if ([(UITextView *)[messages valueForKey:@"_textView"] isFirstResponder] && !CGRectIsNull(systemKeyboardFrame)) {
                CGRect keyboard = [window convertRect:systemKeyboardFrame fromCoordinateSpace:window.windowScene.screen.coordinateSpace];
                if (!CGRectIsEmpty(CGRectIntersection(usable, keyboard)) && keyboard.size.width >= usable.size.width * .5)
                    usable.size.height = MAX(0, CGRectGetMinY(keyboard) - CGRectGetMinY(usable));
            }
            CGRect selected = segments.selectedSegmentIndex == 1 ? messageRect : serverRect;
            if (!wide && !folded) for (UIViewReservedRegion *region in [root.view reservedRegionsOfKind:UIViewReservedRegionKind.divisionRegionKind]) {
                CGRect division = [root.view convertRect:region.frame toView:window];
                if (division.size.width > division.size.height) {
                    if (CGRectGetMaxY(selected) <= CGRectGetMinY(division) + 1) usable.size.height = MIN(CGRectGetMaxY(usable), CGRectGetMinY(division)) - CGRectGetMinY(usable);
                    else if (CGRectGetMinY(selected) >= CGRectGetMaxY(division) - 1) { CGFloat bottom = CGRectGetMaxY(usable); usable.origin.y = MAX(usable.origin.y, CGRectGetMaxY(division)); usable.size.height = MAX(0, bottom - usable.origin.y); }
                } else {
                    if (CGRectGetMaxX(selected) <= CGRectGetMinX(division) + 1) usable.size.width = MIN(CGRectGetMaxX(usable), CGRectGetMinX(division)) - CGRectGetMinX(usable);
                    else if (CGRectGetMinX(selected) >= CGRectGetMaxX(division) - 1) { CGFloat right = CGRectGetMaxX(usable); usable.origin.x = MAX(usable.origin.x, CGRectGetMaxX(division)); usable.size.width = MAX(0, right - usable.origin.x); }
                }
            }
            if (!messages.view.hidden && !CGRectIsEmpty(messageRect)) {
                UIView *composer = [messages valueForKey:@"_textBarView"];
                CGRect composerRect = [composer convertRect:composer.bounds toView:window];
                if (!CGRectContainsRect(CGRectInset(messageRect, -1, -1), composerRect)) [failures addObject:@"Message composer escapes the visible conversation pane"];
            }
            if (!wide && !folded && !CGRectContainsRect(CGRectInset(selected, -2, -2), usable)) [failures addObject:@"Compact content does not fill the usable display"];
            if (dock && !CGRectContainsRect(CGRectInset(controls ? controlsRect : serverRect, -2, -2), dockRect)) [failures addObject:@"Voice controls escape their assigned pane"];
            if (armed && (![[[messages valueForKey:@"_textView"] text] isEqual:@"Draft survives folding and resizing"] || [messages valueForKey:@"_pendingPhoto"] != draftPhoto)) [failures addObject:@"Draft text/photo lost during reparenting"];
            for (UIViewReservedRegion *region in [root.view reservedRegionsOfKind:UIViewReservedRegionKind.divisionRegionKind]) {
                CGRect rect = [root.view convertRect:region.frame toView:window];
                if (rect.size.width > rect.size.height && segments.selectedSegmentIndex == 0 && window.bounds.size.width >= 669 && window.bounds.size.height >= 669 && !folded) [failures addObject:@"Initial presentation failed to configure the folded message/control surface"];
                if (folded && rect.size.width > rect.size.height && (CGRectGetMaxY(serverRect) > CGRectGetMinY(rect) + 1 || CGRectGetMinY(controlsRect) < CGRectGetMaxY(rect) - 1)) [failures addObject:@"Folded controls are not below the channel pane"];
                if (rect.size.height > rect.size.width && book) {
                    BOOL rtl = root.view.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
                    CGRect leading = rtl ? messageRect : serverRect, trailing = rtl ? serverRect : messageRect;
                    if (CGRectGetMaxX(leading) > CGRectGetMinX(rect) + 1 || CGRectGetMinX(trailing) < CGRectGetMaxX(rect) - 1) [failures addObject:@"Book panes do not follow leading Server / trailing Messages order"];
                    if (folded) [failures addObject:@"Book posture moved server controls into Messages"];
                }
                if (!CGRectIsEmpty(CGRectIntersection(rect, dockRect))) [failures addObject:@"Voice controls cross the active fold"];
            }
            if (wide || folded) {
                UIViewController *container = [root valueForKey:@"_conversationContainer"];
                if (container.navigationItem.titleView) [failures addObject:@"Split panes retain a shared selector across the fold"];
                UILabel *serverTitle = [server valueForKey:@"_paneTitleLabel"];
                CGRect serverTitleRect = [serverTitle convertRect:serverTitle.bounds toView:window];
                CGRect serverSafe = [server.view convertRect:server.view.safeAreaLayoutGuide.layoutFrame toView:window];
                if (CGRectGetMinX(serverTitleRect) < CGRectGetMinX(serverSafe) - 1 || CGRectGetMaxX(serverTitleRect) > CGRectGetMaxX(serverSafe) + 1) [failures addObject:@"Server heading extends beneath a vertical system bar"];
                if (!server.showsPaneTitle) [failures addObject:@"Split Server title is missing"];
                UIViewController *secondary = [root valueForKey:@"_secondaryView"];
                UILabel *title = [secondary valueForKey:@"_paneTitleLabel"];
                if (title.hidden || !title.text.length) [failures addObject:@"Split Messages title is missing"];
                CGRect titleRect = [title convertRect:title.bounds toView:window];
                CGRect paneRect = [secondary.view convertRect:secondary.view.bounds toView:window];
                if (!CGRectContainsRect(CGRectInset(paneRect, -1, -1), titleRect)) [failures addObject:@"Messages title escapes its pane"];
            }
            if (dock && [(UITextView *)[messages valueForKey:@"_textView"] isFirstResponder]) {
                CGRect keyboard = [dock.superview convertRect:dock.superview.keyboardLayoutGuide.layoutFrame toView:window];
                if (!CGRectIsEmpty(CGRectIntersection(keyboard, dockRect))) [failures addObject:@"Voice controls overlap the keyboard"];
            }
            if ([(UITextView *)[messages valueForKey:@"_textView"] isFirstResponder]) {
                if (CGRectIsNull(systemKeyboardFrame)) [failures addObject:@"Software keyboard has not published a frame; enable it in Device Hub before validating keyboard avoidance"];
                UIButton *send = [messages valueForKey:@"_sendButton"];
                CGRect button = [send convertRect:send.bounds toView:window];
                CGRect keyboard = [messages.view convertRect:messages.view.keyboardLayoutGuide.layoutFrame toView:window];
                if (!CGRectIsNull(systemKeyboardFrame)) keyboard = [window convertRect:systemKeyboardFrame fromCoordinateSpace:window.windowScene.screen.coordinateSpace];
                if (CGRectGetMaxY(button) > CGRectGetMinY(keyboard) + 1) [failures addObject:@"Message composer is covered by the keyboard"];
            }
            NSDictionary *state = @{@"verticalBarEdge":@(root.traitCollection.verticalBarEdge), @"serverVerticalBarEdge":@(server.traitCollection.verticalBarEdge), @"sideVoiceControls":@(sideVoiceControls), @"window":MUDuoRect(window.bounds), @"orientation":@(window.windowScene.effectiveGeometry.interfaceOrientation), @"safe":MUDuoRect(root.view.safeAreaLayoutGuide.layoutFrame), @"wide":@(wide), @"foldedControls":@(folded), @"book":@(book), @"rtl":@(root.view.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft), @"controls":MUDuoRect(controlsRect), @"messagesHidden":@(messages.view.hidden), @"presented":@(root.presentingViewController != nil), @"server":MUDuoRect(serverRect), @"messages":MUDuoRect(messageRect), @"dock":MUDuoRect(dockRect), @"draft":@(armed), @"keyboardFrame":MUDuoRect(systemKeyboardFrame), @"rootKeyboardFrame":MUDuoRect(root.view.keyboardLayoutGuide.layoutFrame), @"messageKeyboardFrame":MUDuoRect(messages.view.keyboardLayoutGuide.layoutFrame), @"appState":@(UIApplication.sharedApplication.applicationState), @"sceneState":@(window.windowScene.activationState), @"rootHasKeyboardFrame":[root valueForKey:@"_hasKeyboardFrame"], @"selection":@(segments.selectedSegmentIndex), @"rows":@([[server valueForKey:@"_modelItems"] count]), @"forceTransmit":@(MLAudio.sharedAudio.forceTransmit), @"keyboard":@([(UITextView *)[messages valueForKey:@"_textView"] isFirstResponder]), @"failures":failures};
            NSMutableDictionary *geometry = [state mutableCopy];
            geometry[@"occlusions"] = occlusions;
            geometry[@"nativeOverflow"] = @(container.navigationItem.additionalOverflowItems != nil);
            geometry[@"nativeVoiceControls"] = @(nativeVoiceControls);
            geometry[@"microphoneMuted"] = @(model.connectedUser.isSelfMuted);
            geometry[@"speakerMuted"] = @(model.connectedUser.isSelfDeafened);
            NSData *json = [NSJSONSerialization dataWithJSONObject:geometry options:NSJSONWritingPrettyPrinted error:nil];
            NSString *signature = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
            if (![signature isEqual:lastState]) {
                lastState = signature; [json writeToFile:Path(@"duo-state.json") atomically:YES];
                UIImage *image = [[[UIGraphicsImageRenderer alloc] initWithBounds:window.bounds] imageWithActions:^(UIGraphicsImageRendererContext *context) { [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:NO]; }];
                [UIImagePNGRepresentation(image) writeToFile:Path(@"duo-layout.png") atomically:YES];
            }
        } @catch (NSException *exception) {
            [exception.reason writeToFile:Path(@"duo-failure.txt") atomically:YES encoding:NSUTF8StringEncoding error:nil]; [timer invalidate];
        }
    }];
}
__attribute__((constructor)) static void Schedule(void) { dispatch_async(dispatch_get_main_queue(), ^{ [NSTimer scheduledTimerWithTimeInterval:1 repeats:NO block:^(NSTimer *timer) { Run(); }]; }); }
