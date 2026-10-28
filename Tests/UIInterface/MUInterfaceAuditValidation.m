#import <UIKit/UIKit.h>
void MUCredentialStoreChecks(NSMutableArray<NSString *> *results);
void MUConnectionLifecycleChecks(UIWindow *window,NSMutableArray<NSString *> *results);
#import <objc/runtime.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "MLClient.h"
#import "MUCertificateCell.h"
#import "MUCountryServerListController.h"
#import "MUPublicServerList.h"
#import "MUFavouriteServerEditViewController.h"
#import "MUCertificateCreationProgressView.h"
#import "MUMessageRecipientViewController.h"
#import "MUServerRootViewController.h"
#import "MUNotificationController.h"
#import "MUImageViewController.h"
#import "MUAccessTokenViewController.h"
#import "MUApplicationDelegate.h"
#import "MUServerViewController.h"
#import "MUCertificateViewController.h"
#import "MUCertificateController.h"
#import "MUCertificatePreferencesViewController.h"
#import "MUCertificateCreationView.h"
#import "MUCertificateDiskImportViewController.h"
#import "MUOnboardingViewController.h"
#import "MUConnectionController.h"
#import "MUFavouriteServer.h"
#import "MUWelcomeScreenPhone.h"
// Keep the UI audit independent of FMDB's private build header map.
@interface MUDatabase : NSObject
+ (void)storeFavourite:(MUFavouriteServer *)server;
+ (void)deleteFavourite:(MUFavouriteServer *)server;
+ (NSMutableArray *)fetchAllFavourites;
+ (void)recordRecentServerWithHostname:(NSString *)hostname port:(NSUInteger)port displayName:(NSString *)displayName username:(NSString *)username;
+ (NSArray<MUFavouriteServer *> *)recentServers;
+ (void)deleteRecentServer:(MUFavouriteServer *)server;
@end


@interface NSObject (AuditPrivate)
- (void)importFromFiles:(id)sender;
- (void)addButtonClicked:(id)sender;
- (void)doneButtonClicked:(id)sender;
- (void)doneClicked:(id)sender;
- (void)cancelClicked:(id)sender;
- (void)showQuickConnect:(id)sender;
- (void)drainPendingUpdates;
- (void)vadBelowChanged:(UISlider *)sender;
- (void)vadAboveChanged:(UISlider *)sender;
+ (NSArray *)accessTokensForServerWithHostname:(NSString *)hostname port:(NSInteger)port;
+ (void)storeAccessTokens:(NSArray *)tokens forServerWithHostname:(NSString *)hostname port:(NSInteger)port;
- (void)reloadPreferences;
- (NSArray<UIMenuElement *> *)serverMenuActions;
- (void)updateMuteControls;
- (void)audioSettingsUpdated:(NSNotification *)notification;
- (void)continueClicked:(UIButton *)sender;
- (void)createClicked:(id)sender;
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls;
- (void)tryImportCertificateWithPassword:(NSString *)password;
- (void)connection:(MLConnection *)connection rejectedWithReason:(MLRejectReason)reason explanation:(NSString *)explanation;
- (void)serverModel:(MLServerModel *)model joinedServerAsUser:(MLUser *)user;
- (void)tickTock;
- (void)updateSearchResultsForSearchController:(UISearchController *)search;
- (void)serverModel:(MLServerModel *)model textMessageReceived:(MLTextMessage *)message fromUser:(MLUser *)user;
@end
static NSMutableArray *results;
void MUMessageStoreChecks(UIWindow *window,NSMutableArray<NSString *> *results);
static void Check(BOOL test, NSString *reason) { if (!test) @throw [NSException exceptionWithName:@"AuditFailure" reason:reason userInfo:nil]; }
static void Wait(double duration) { NSDate *end=[NSDate dateWithTimeIntervalSinceNow:duration]; while(end.timeIntervalSinceNow>0) [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]]; }
static void NoAudioStart(id self,SEL command) {}
static NSArray<UIView *> *Subviews(UIView *view) { NSMutableArray *all=[NSMutableArray arrayWithObject:view]; for(UIView *child in view.subviews)[all addObjectsFromArray:Subviews(child)];return all; }
static void Save(UIWindow *window,NSString *name) { UIImage *shot=[[[UIGraphicsImageRenderer alloc]initWithBounds:window.bounds]imageWithActions:^(UIGraphicsImageRendererContext *c){[window drawViewHierarchyInRect:window.bounds afterScreenUpdates:YES];}];[UIImagePNGRepresentation(shot)writeToFile:[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:name]atomically:YES]; }
static UINavigationController *Show(UIWindow *window,UIViewController *vc) { UINavigationController *nav=[[UINavigationController alloc]initWithRootViewController:vc];window.rootViewController=nav;[window makeKeyAndVisible];Wait(.2);[vc.view layoutIfNeeded];return nav; }
static void WaitForSheet(UIViewController *presenter) {
 NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:3];
 while((presenter.presentedViewController.isBeingPresented || presenter.presentedViewController.transitionCoordinator) && deadline.timeIntervalSinceNow>0)Wait(.02);
 Check(presenter.presentedViewController!=nil && !presenter.presentedViewController.isBeingPresented,@"Certificate sheet did not finish presenting");Wait(.15);
}
static void DismissSheet(UIViewController *presenter) {
 WaitForSheet(presenter);__block BOOL dismissed=NO;[presenter dismissViewControllerAnimated:NO completion:^{dismissed=YES;}];NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:3];
 while(!dismissed && deadline.timeIntervalSinceNow>0)Wait(.02);
 Check(dismissed && !presenter.presentedViewController,@"Certificate sheet did not dismiss");Wait(.15);
}
static void NoNetworkConnect(id object,SEL selector,NSString *host,NSUInteger port) {
 [object setValue:host forKey:@"_hostname"];[object setValue:@(port) forKey:@"_port"];
}
static void InvokeAlertAction(UIAlertAction *action) {
 void (^handler)(UIAlertAction *)=[action valueForKey:@"handler"];Check(handler!=nil,@"Alert action has no handler");handler(action);
}
static UIAlertController *WaitForPasswordPrompt(UIViewController *parent,MUConnectionController *controller) {
 NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:4];
 while((parent.presentedViewController != [controller valueForKey:@"_rejectAlertCtrl"] || parent.presentedViewController.isBeingPresented) && deadline.timeIntervalSinceNow>0)Wait(.02);
 UIAlertController *alert=(id)parent.presentedViewController;
 Check([alert isKindOfClass:UIAlertController.class] && alert==[controller valueForKey:@"_rejectAlertCtrl"] && alert.textFields.count==1,@"Password prompt is lost behind the Connecting alert");Wait(.2);return alert;
}
static void PasswordConnectionChecks(UIWindow *window) {
 Method connect=class_getInstanceMethod(MLConnection.class,@selector(connectToHost:port:));IMP original=method_setImplementation(connect,(IMP)NoNetworkConnect);
 NSString *host=[NSUUID.UUID.UUIDString stringByAppendingString:@".password-audit.invalid"];
 MUFavouriteServer *first=[[MUFavouriteServer alloc]initWithDisplayName:@"Password audit" hostName:host port:64738 userName:@"First" password:nil];
 MUFavouriteServer *other=[[MUFavouriteServer alloc]initWithDisplayName:@"Other account" hostName:host port:64738 userName:@"Other" password:@"unchanged-fixture"];
 MUConnectionController *controller=[MUConnectionController new];UIViewController *parent=[UIViewController new];Show(window,parent);
 @try {
  [MUDatabase storeFavourite:first];[MUDatabase storeFavourite:other];Check(first.hasPrimaryKey && other.hasPrimaryKey,@"Unable to create isolated favourite fixtures");
  [controller connectToFavouriteServer:first withParentViewController:parent];
  MLConnection *connection=[controller valueForKey:@"_connection"];
  // Reject immediately while UIKit is still presenting Connecting.
  [(id)controller connection:connection rejectedWithReason:MLRejectReasonWrongServerPassword explanation:nil];
  UIAlertController *alert=WaitForPasswordPrompt(parent,controller);
  Check([alert.title isEqual:NSLocalizedString(@"Password Required",nil)] && alert.textFields.firstObject.secureTextEntry,@"Missing server password does not get a secure, clear prompt");
  Check(alert.actions.count==3 && !alert.actions[1].enabled && !alert.actions[2].enabled,@"Password prompt lacks Cancel/Once/Save or permits empty input");
  UITextField *field=alert.textFields.firstObject;field.text=@"wrong-fixture";[field sendActionsForControlEvents:UIControlEventEditingChanged];Check(alert.actions[1].enabled && alert.actions[2].enabled,@"Entering a password does not enable reconnect actions");
  InvokeAlertAction(alert.actions[2]);Wait(.7);
  for(MUFavouriteServer *recent in [MUDatabase recentServers])Check([recent.hostName caseInsensitiveCompare:host]!=NSOrderedSame,@"A rejected connection appears in recent history");
  for(MUFavouriteServer *saved in [MUDatabase fetchAllFavourites])if(saved.primaryKey==first.primaryKey)Check(!saved.password.length,@"Unverified password is saved before authentication");
  connection=[controller valueForKey:@"_connection"];[(id)controller connection:connection rejectedWithReason:MLRejectReasonWrongServerPassword explanation:nil];alert=WaitForPasswordPrompt(parent,controller);
  Check([alert.title isEqual:NSLocalizedString(@"Incorrect Password",nil)] && !alert.textFields.firstObject.text.length,@"Rejected password is reused instead of prompting again");
  field=alert.textFields.firstObject;field.text=@"correct-fixture";[field sendActionsForControlEvents:UIControlEventEditingChanged];InvokeAlertAction(alert.actions[2]);Wait(.7);
  MLServerModel *model=[controller valueForKey:@"_serverModel"];MLUser *user=[MLUser new];user.session=1;user.userName=@"First";user.channel=model.rootChannel;[[model.rootChannel valueForKey:@"userStorage"]addObject:user];[model setValue:user forKey:@"_connectedUser"];
  [(id)controller serverModel:model joinedServerAsUser:user];Wait(.8);
  MUFavouriteServer *joined=[MUDatabase recentServers].firstObject;
  Check([joined.hostName caseInsensitiveCompare:host]==NSOrderedSame && [joined.displayName isEqual:@"Password audit"] && [joined.userName isEqual:@"First"] && !joined.password,@"Successful connection history loses its name/account or saves a password");
  for(MUFavouriteServer *saved in [MUDatabase fetchAllFavourites]){
   if(saved.primaryKey==first.primaryKey)Check([saved.password isEqual:@"correct-fixture"],@"Successfully verified password does not persist to its favourite");
   if(saved.primaryKey==other.primaryKey)Check([saved.password isEqual:@"unchanged-fixture"],@"Saving password changes another account at the same server");
  }
  [controller disconnectFromServer];Wait(.6);
  [controller connectToFavouriteServer:first withParentViewController:parent];connection=[controller valueForKey:@"_connection"];[(id)controller connection:connection rejectedWithReason:MLRejectReasonWrongServerPassword explanation:nil];alert=WaitForPasswordPrompt(parent,controller);
  field=alert.textFields.firstObject;field.text=@"once-fixture";[field sendActionsForControlEvents:UIControlEventEditingChanged];InvokeAlertAction(alert.actions[1]);Wait(.7);Check(![[controller valueForKey:@"_savePasswordOnJoin"]boolValue],@"Connect Once opts into saving");
  model=[controller valueForKey:@"_serverModel"];user=[MLUser new];user.session=2;user.userName=@"First";user.channel=model.rootChannel;[[model.rootChannel valueForKey:@"userStorage"]addObject:user];[model setValue:user forKey:@"_connectedUser"];[(id)controller serverModel:model joinedServerAsUser:user];Wait(.8);
  for(MUFavouriteServer *saved in [MUDatabase fetchAllFavourites])if(saved.primaryKey==first.primaryKey)Check([saved.password isEqual:@"correct-fixture"],@"Connect Once overwrites the saved password");
  [controller disconnectFromServer];Wait(.6);
  [controller connectToFavouriteServer:first withParentViewController:parent];connection=[controller valueForKey:@"_connection"];[(id)controller connection:connection rejectedWithReason:MLRejectReasonWrongUserPassword explanation:nil];alert=WaitForPasswordPrompt(parent,controller);Save(window,@"native-server-password-prompt.png");InvokeAlertAction(alert.actions[0]);
  Check(!controller.isConnected && ![[controller valueForKey:@"_savePasswordOnJoin"]boolValue] && [controller valueForKey:@"_rejectAlertCtrl"]==nil,@"Cancel retains a retry or save request");
  Wait(.5);Check(!parent.presentedViewController,@"Cancelling authentication leaves its prompt on screen");
  [results addObject:@"PASS immediate password rejection, secure prompt, empty-input guard, wrong-password retry, authenticated exact-favourite save, Connect Once and Cancel"];
 } @finally {
  [controller disconnectFromServer];if(parent.presentedViewController)[parent dismissViewControllerAnimated:NO completion:nil];Wait(.2);window.rootViewController=[UIViewController new];
  for(MUFavouriteServer *saved in [MUDatabase fetchAllFavourites])if([saved.hostName isEqual:host])[MUDatabase deleteFavourite:saved];
  for(MUFavouriteServer *recent in [MUDatabase recentServers])if([recent.hostName caseInsensitiveCompare:host]==NSOrderedSame)[MUDatabase deleteRecentServer:recent];
  method_setImplementation(connect,original);
 }
}
static void CheckContent(UIViewController *vc) {
 for(UIView *view in Subviews(vc.view)) {
  if([view isKindOfClass:UITextField.class]) { UITextField *field=(id)view;CGRect r=[field convertRect:field.bounds toView:vc.view];Check(r.size.width>50 && CGRectGetMinX(r)>=0 && CGRectGetMaxX(r)<=vc.view.bounds.size.width+1,@"Form field is crushed or outside screen");Check(field.font.pointSize>30,@"Form field ignores accessibility text size"); }
 }
 if([vc isKindOfClass:UITableViewController.class]) for(UITableViewCell *cell in ((UITableViewController *)vc).tableView.visibleCells) {
   if(cell.textLabel.text.length) Check(CGRectGetMaxY(cell.textLabel.frame)<=cell.contentView.bounds.size.height+1,@"Standard cell title clips at accessibility size");
 }
}
static void SetupAndCertificateChecks(UIWindow *window) {
 NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
 NSString *suite=[@"mumble-setup-audit." stringByAppendingString:NSUUID.UUID.UUIDString];
 NSUserDefaults *fresh=[[NSUserDefaults alloc]initWithSuiteName:suite];
 Check([MUOnboardingViewController shouldPresentForDefaults:fresh hasExistingInstallation:NO],@"Fresh installation skips setup");
 Check([MUOnboardingViewController shouldPresentForDefaults:fresh hasExistingInstallation:YES],@"Interrupted setup is mistaken for an upgraded installation");
 [fresh setBool:YES forKey:MUInitialSetupCompletedKey];Check(![MUOnboardingViewController shouldPresentForDefaults:fresh hasExistingInstallation:NO],@"Completed setup appears again");
 [fresh removePersistentDomainForName:suite];Check(![MUOnboardingViewController shouldPresentForDefaults:fresh hasExistingInstallation:YES],@"Upgrade interrupts an existing installation with setup");[fresh removePersistentDomainForName:suite];
 NSArray *keys=@[@"DefaultCertificate",@"AudioTransmitMethod",MUInitialSetupCompletedKey,MUInitialSetupStartedKey];NSMutableDictionary *old=[NSMutableDictionary dictionary];
 for(NSString *key in keys)old[key]=[defaults objectForKey:key] ?: NSNull.null;
 NSString *generated=[@"Generated audit " stringByAppendingString:NSUUID.UUID.UUIDString],*imported=[@"Imported audit " stringByAppendingString:NSUUID.UUID.UUIDString];
 NSMutableArray *createdRefs=[NSMutableArray array];NSURL *source=nil;id observer=nil;
 @try {
  [defaults removeObjectForKey:@"DefaultCertificate"];
  __block NSUInteger events=0;__block BOOL notificationsOnMain=YES;
  observer=[NSNotificationCenter.defaultCenter addObserverForName:MUCertificatesDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note){events++;notificationsOnMain &= NSThread.isMainThread;}];
  MUCertificatePreferencesViewController *list=[MUCertificatePreferencesViewController new];Show(window,list);NSUInteger baseline=[list.tableView numberOfRowsInSection:0];
  MUCertificateCreationView *form=[MUCertificateCreationView new];[list presentViewController:[[UINavigationController alloc]initWithRootViewController:form] animated:NO completion:nil];Wait(.2);
  WaitForSheet(list);
  [form setValue:generated forKey:@"_fullName"];[(id)form createClicked:nil];NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:20];
  while(events==0 && deadline.timeIntervalSinceNow>0)Wait(.05);Wait(.5);
  Check(events==1 && notificationsOnMain,[NSString stringWithFormat:@"Certificate generation does not report a saved identity on the main thread; events=%lu, presented=%@",(unsigned long)events,list.presentedViewController]);
  Check([list.tableView numberOfRowsInSection:0]==baseline+1,@"Generated certificate is absent until the list is reopened");
  Check([[MUCertificateController defaultCertificate].subjectName isEqual:generated],@"Generated identity is not available as the default certificate");
  [createdRefs addObject:[defaults dataForKey:@"DefaultCertificate"]];Save(window,@"certificate-list-after-generation.png");
  __weak MUCertificateViewController *retiredViewer=nil;
  @autoreleasepool {
   MUCertificateViewController *viewer=[[MUCertificateViewController alloc]initWithPersistentRef:createdRefs.firstObject];
   retiredViewer=viewer;[viewer loadViewIfNeeded];[viewer viewWillAppear:NO];
   Check([viewer.tableView numberOfRowsInSection:0]>0,@"ARC certificate chain loses the generated Keychain identity");
  }
  Wait(.05);Check(retiredViewer==nil,@"Certificate details retains its controller after the caller releases it");

  MUCertificateDiskImportViewController *files=[MUCertificateDiskImportViewController new];[list presentViewController:[[UINavigationController alloc]initWithRootViewController:files] animated:NO completion:nil];Wait(.2);
  MLCertificate *fixture=[MLCertificate selfSignedCertificateWithName:imported email:nil];NSData *pkcs12=[fixture exportPKCS12WithPassword:@"audit-import-password"];
  source=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingPathExtension:@"p12"]]];Check([pkcs12 writeToURL:source atomically:YES],@"Unable to prepare isolated import fixture");
  [(id)files documentPicker:[[UIDocumentPickerViewController alloc]initForOpeningContentTypes:@[UTTypePKCS12] asCopy:YES] didPickDocumentsAtURLs:@[source]];Wait(.1);
  NSArray *disk=[files valueForKey:@"_diskCertificates"];[files setValue:[NSIndexPath indexPathForRow:disk.count-1 inSection:0] forKey:@"_attemptIndexPath"];
  [(id)files tryImportCertificateWithPassword:@"audit-import-password"];Wait(.2);
  Check(events==2 && [list.tableView numberOfRowsInSection:0]==baseline+2,@"Imported identity does not refresh the still-present certificate list");
  for(NSData *ref in [MUCertificateController persistentRefsForIdentities])if([[MUCertificateController certificateWithPersistentRef:ref].subjectName isEqual:imported])[createdRefs addObject:ref];
  Check(createdRefs.count==2,@"Imported identity is not in the keychain");
  DismissSheet(list);
  [defaults removeObjectForKey:@"DefaultCertificate"];[defaults removeObjectForKey:MUInitialSetupCompletedKey];
  __block NSUInteger completions=0;MUOnboardingViewController *welcome=[[MUOnboardingViewController alloc]initWithCompletion:^{completions++;}];UINavigationController *nav=Show(window,welcome);Save(window,@"setup-welcome.png");
  UIButton *next=[welcome valueForKey:@"_continueButton"];CGRect actionPosition=[next convertRect:next.bounds toView:window];
  Check(CGRectGetMinY(actionPosition)>window.bounds.size.height*.7 && CGRectGetMaxY(actionPosition)<window.bounds.size.height-window.safeAreaInsets.bottom,@"Welcome action is not anchored near the bottom safe area");
  [(id)welcome continueClicked:nil];Wait(.4);UITableViewController *mode=(id)nav.topViewController;
  Check([mode.tableView numberOfRowsInSection:0]==3,@"Setup does not offer three transmission modes");
  UIButton *modeNext=[mode valueForKey:@"_continueButton"];Check(CGRectEqualToRect(actionPosition,[modeNext convertRect:modeNext.bounds toView:window]),@"Transmission action moves relative to Welcome");
  NSIndexPath *ptt=[NSIndexPath indexPathForRow:1 inSection:0];[mode tableView:mode.tableView didSelectRowAtIndexPath:ptt];Wait(.2);
  Check([[defaults stringForKey:@"AudioTransmitMethod"]isEqual:@"ptt"] && [mode.tableView cellForRowAtIndexPath:ptt].accessoryType==UITableViewCellAccessoryCheckmark,@"Setup mode selection is not saved or checked");Save(window,@"setup-transmission.png");
  [(id)mode continueClicked:nil];Wait(.4);MUOnboardingViewController *certificate=(id)nav.topViewController;UIButton *finish=[certificate valueForKey:@"_continueButton"];
  Check(CGRectEqualToRect(actionPosition,[finish convertRect:finish.bounds toView:window]),@"Certificate action moves relative to the first two steps");
  Check(!finish.enabled,@"Setup allows finishing without an identity");[(id)certificate continueClicked:nil];Check(completions==0 && ![defaults boolForKey:MUInitialSetupCompletedKey],@"Unready setup is marked complete");
  [certificate tableView:certificate.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];WaitForSheet(certificate);Check([((UINavigationController *)certificate.presentedViewController).topViewController isKindOfClass:MUCertificateCreationView.class],@"Setup generation does not open the native certificate form");DismissSheet(certificate);Check(!finish.enabled,@"Cancelling generation completes setup");
  [certificate tableView:certificate.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]];WaitForSheet(certificate);Check([((UINavigationController *)certificate.presentedViewController).topViewController isKindOfClass:MUCertificateDiskImportViewController.class],@"Setup import does not open the native import flow");DismissSheet(certificate);
  [MUCertificateController setDefaultCertificateByPersistentRef:createdRefs.firstObject];[MUCertificateController notifyCertificatesChanged];Wait(.2);
  Check(finish.enabled && [[[certificate valueForKey:@"_certificateStatus"]text]containsString:generated],@"Setup does not show the saved certificate without reopening");Save(window,@"setup-certificate-ready.png");
  certificate.traitOverrides.preferredContentSizeCategory=UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;Wait(.2);[certificate.view layoutIfNeeded];Save(window,@"setup-certificate-large.png");
  Check(certificate.tableView.tableFooterView.bounds.size.height>100,@"Certificate status clips at accessibility size");
  CGRect fixedPosition=[finish convertRect:finish.bounds toView:window];
  // Resolve estimated row heights as the table reaches its actual end.
  for(NSUInteger i=0;i<3;i++) {
   CGFloat end=MAX(-certificate.tableView.adjustedContentInset.top,certificate.tableView.contentSize.height-certificate.tableView.bounds.size.height+certificate.tableView.adjustedContentInset.bottom);
   [certificate.tableView setContentOffset:CGPointMake(0,end) animated:NO];Wait(.15);
  }
  CGRect finishRect=[finish convertRect:finish.bounds toView:window];
  Save(window,@"setup-certificate-large-footer.png");
  Check(CGRectEqualToRect(fixedPosition,finishRect),@"Scrolling moves the fixed setup action");
  UILabel *status=[certificate valueForKey:@"_certificateStatus"];Check(CGRectGetMaxY([status convertRect:status.bounds toView:window])+12<=CGRectGetMinY(finishRect),@"Certificate status cannot scroll clear of the fixed button");
  Check(CGRectGetMinY(finishRect)>=window.safeAreaInsets.top && CGRectGetMaxY(finishRect)<=window.bounds.size.height-window.safeAreaInsets.bottom+1,@"Fixed Finish button clips at accessibility size");
  [(id)certificate continueClicked:nil];[(id)certificate continueClicked:nil];Check(completions==1 && [defaults boolForKey:MUInitialSetupCompletedKey],@"Successful setup does not finish and persist once");
  [results addObject:@"PASS real certificate generation/import refresh under sheets, setup gating/retry/mode/identity/cancellation/completion and large text"];
 } @finally {
  if(observer)[NSNotificationCenter.defaultCenter removeObserver:observer];window.rootViewController=[UIViewController new];Wait(.1);
  // Delete only the two uniquely named fixtures made by this isolated test.
  for(NSData *ref in [MUCertificateController persistentRefsForIdentities]){NSString *name=[MUCertificateController certificateWithPersistentRef:ref].subjectName;if([name isEqual:generated] || [name isEqual:imported])[MUCertificateController deleteCertificateWithPersistentRef:ref];}
  if(source)[NSFileManager.defaultManager removeItemAtURL:source error:NULL];
  for(NSString *key in keys){if(old[key]==NSNull.null)[defaults removeObjectForKey:key];else[defaults setObject:old[key]forKey:key];}
  [(MUApplicationDelegate *)UIApplication.sharedApplication.delegate reloadPreferences];
 }
}
static void FormChecks(UIWindow *window) {
 for(NSString *name in @[@"MUFavouriteServerEditViewController",@"MUCertificateCreationView"]) {
  UIViewController *vc=[name isEqual:@"MUFavouriteServerEditViewController"]?[[MUFavouriteServerEditViewController alloc]initInEditMode:NO withContentOfFavouriteServer:nil]:[NSClassFromString(name)new];
  Show(window,vc);Save(window,[name stringByAppendingString:@"-default.png"]);
  vc.traitOverrides.preferredContentSizeCategory=UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;Wait(.2);[(UITableViewController *)vc tableView].rowHeight=UITableViewAutomaticDimension;[((UITableViewController *)vc).tableView reloadData];Wait(.2);CheckContent(vc);Save(window,[name stringByAppendingString:@"-large.png"]);
  for(UIView *view in Subviews(vc.view)) if([view isKindOfClass:UITextField.class]){UIStackView *stack=(id)view.superview;Check([stack isKindOfClass:UIStackView.class] && stack.axis==UILayoutConstraintAxisVertical,@"Large-text form remains a fixed horizontal label/input layout");}
 }
 [results addObject:@"PASS favorite and certificate forms use native adaptive stacks at accessibility size"];
}
@interface AuditCertificateTable : UITableViewController @end
@implementation AuditCertificateTable
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return 1; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
 MUCertificateCell *cell=[MUCertificateCell certificateCell];[cell setSubjectName:@"A long certificate identity name that must remain readable"];[cell setEmail:@"identity@example.com"];[cell setIssuerText:@"Mumble Certificate Authority"];[cell setExpiryText:@"Expires on October 13, 2027"];[cell setIsCurrentCertificate:YES];[cell setIsExpired:YES];[cell setIsExpired:NO];return cell;
}
@end
static void NativeChecks(UIWindow *window) {
 AuditCertificateTable *cert=[[AuditCertificateTable alloc]initWithStyle:UITableViewStyleInsetGrouped];cert.tableView.rowHeight=UITableViewAutomaticDimension;cert.tableView.estimatedRowHeight=100;Show(window,cert);Save(window,@"native-certificate-default.png");cert.traitOverrides.preferredContentSizeCategory=UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;Wait(.2);[cert.tableView reloadData];Wait(.2);UITableViewCell *cell=cert.tableView.visibleCells.firstObject;Check([cell.contentConfiguration isKindOfClass:UIListContentConfiguration.class] && cell.bounds.size.height>100,@"Certificate row is still a fixed nib layout");UIListContentConfiguration *configuration=(id)cell.contentConfiguration;Check(configuration.textProperties.numberOfLines==0 && configuration.secondaryTextProperties.numberOfLines==0,@"Certificate details cannot wrap");Check([configuration.secondaryTextProperties.color isEqual:UIColor.secondaryLabelColor],@"Expired color survives cell reuse");Save(window,@"native-certificate-large.png");
 MUCertificateCreationProgressView *progress=[[MUCertificateCreationProgressView alloc]initWithName:@"Certificate generation for a long identity name" email:@"identity@example.com"];Show(window,progress);progress.traitOverrides.preferredContentSizeCategory=UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;Wait(.2);Check(progress.nibName==nil,@"Certificate progress still uses fixed nib layout");BOOL spinner=NO;for(UIView *view in Subviews(progress.view))if([view isKindOfClass:UIActivityIndicatorView.class])spinner=((UIActivityIndicatorView *)view).isAnimating;Check(spinner,@"Native progress indicator is not running");Save(window,@"native-certificate-progress.png");
 for(NSString *name in @[@"MUPreferencesViewController",@"MUAdvancedAudioPreferencesViewController",@"MUAudioQualityPreferencesViewController",@"MUAudioSidetonePreferencesViewController",@"MUCertificatePreferencesViewController",@"MUVoiceActivitySetupViewController"]) {
  UITableViewController *settings=[NSClassFromString(name)new];Show(window,settings);settings.traitOverrides.preferredContentSizeCategory=UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;Wait(.15);[settings.tableView reloadData];Wait(.15);Check(settings.tableView.scrollEnabled && settings.tableView.rowHeight==UITableViewAutomaticDimension,@"Settings page does not support scrolling/self sizing");CheckContent(settings);Save(window,[name stringByAppendingString:@"-native.png"]);
  if([name isEqual:@"MUVoiceActivitySetupViewController"]){BOOL nativeMeter=NO;NSUInteger sliders=0;for(UIView *view in Subviews(settings.view)){if([view isKindOfClass:UIProgressView.class])nativeMeter=YES;if([view isKindOfClass:UISlider.class]){sliders++;Check(view.bounds.size.width>150 && view.bounds.size.height>=44,@"VAD slider is not accessible/full width");}}Check(nativeMeter && sliders>0,@"Voice detection still uses drawn background/slider accessories");}
 }
 [results addObject:@"PASS native certificate rows/progress and self-sizing scrollable settings"];
}
static void CertificateNavigationChecks(UIWindow *window) {
 MLCertificate *server=[MLCertificate selfSignedCertificateWithName:@"Server Certificate" email:nil],*issuer=[MLCertificate selfSignedCertificateWithName:@"Issuer Certificate" email:nil];
 Check(server && issuer,@"Unable to prepare certificate navigation fixtures");
 MUCertificateViewController *viewer=[[MUCertificateViewController alloc]initWithCertificates:@[server,issuer]];Show(window,viewer);
 UIBarButtonItem *previous=[viewer valueForKey:@"_previousCertificateButton"],*next=[viewer valueForKey:@"_nextCertificateButton"];
 Check(viewer.navigationItem.rightBarButtonItems.count==2 && previous.customView==nil && next.customView==nil,@"Certificate navigation still wraps nested controls/glass");
 Check(!previous.enabled && next.enabled,@"First certificate enables the wrong direction");
 Save(window,@"native-certificate-navigation-first.png");
 for(NSUInteger cycle=0;cycle<3;cycle++) {
  [UIApplication.sharedApplication sendAction:next.action to:next.target from:next forEvent:nil];Wait(.05);
  Check([[viewer valueForKey:@"_curIdx"]integerValue]==1 && previous.enabled && !next.enabled,@"Down does not advance to the second certificate");
  Check([((NSArray *)[viewer valueForKey:@"_subjectItems"]).firstObject[1]isEqual:@"Issuer Certificate"],@"Certificate content does not follow the displayed index");
  [UIApplication.sharedApplication sendAction:next.action to:next.target from:next forEvent:nil];
  Check([[viewer valueForKey:@"_curIdx"]integerValue]==1,@"Next moves past the end of the chain");
  if(cycle==0)Save(window,@"native-certificate-navigation-second.png");
  [UIApplication.sharedApplication sendAction:previous.action to:previous.target from:previous forEvent:nil];Wait(.05);
  [UIApplication.sharedApplication sendAction:previous.action to:previous.target from:previous forEvent:nil];
  Check([[viewer valueForKey:@"_curIdx"]integerValue]==0 && !previous.enabled && next.enabled,@"Up does not return safely to the first certificate");
 }
 [viewer setValue:@YES forKey:@"_allowExportAndDelete"];[viewer viewWillAppear:NO];Wait(.1);
 Check(viewer.navigationItem.rightBarButtonItems.count==3,@"Certificate actions disappeared from the editable chain");
 for(UIBarButtonItem *item in viewer.navigationItem.rightBarButtonItems)Check(item.customView==nil,@"Editable certificate chain still nests a toolbar");
 Save(window,@"native-certificate-navigation-actions.png");
 viewer=[[MUCertificateViewController alloc]initWithCertificate:server];Show(window,viewer);
 Check(viewer.navigationItem.rightBarButtonItems.count==0,@"A single read-only certificate shows unnecessary navigation");
 [results addObject:@"PASS native certificate bar items, down/up content switching, endpoint guards and editable-chain actions"];
}
static void SearchChecks(UIWindow *window) {
 NSArray *servers=@[@{@"name":@"Alpha",@"ip":@"127.0.0.1",@"port":@"64738"},@{@"name":@"Beta",@"ip":@"127.0.0.1",@"port":@"64739"}];
 MUCountryServerListController *country=[[MUCountryServerListController alloc]initWithName:@"Country" serverList:servers];Show(window,country);UISearchController *search=country.navigationItem.searchController;Check(search!=nil && country.navigationItem.titleView==nil,@"Search replaces the navigation title/back button");search.searchBar.text=@"Alpha";[(id)country updateSearchResultsForSearchController:search];search.searchBar.text=@"Beta";[(id)country updateSearchResultsForSearchController:search];Wait(.3);NSArray *visible=[country valueForKey:@"_visibleServers"];Check(visible.count==1 && [visible[0][@"name"]isEqual:@"Beta"],@"Older search result wins over the latest query");search.searchBar.text=@"";[(id)country updateSearchResultsForSearchController:search];Wait(.2);Check([(NSArray *)[country valueForKey:@"_visibleServers"]count]==2,@"Clearing native search leaves filtered data");Save(window,@"native-public-search.png");
 [results addObject:@"PASS native search preserves title/back navigation and discards stale results"];
}
@interface AuditVoiceModel : MLServerModel
@property(nonatomic) BOOL requestedMute, requestedDeafen;
@property(nonatomic) NSUInteger muteRequests;
@end
@implementation AuditVoiceModel
- (void)setSelfMuted:(BOOL)muted andSelfDeafened:(BOOL)deafened {
 self.requestedMute=muted; self.requestedDeafen=deafened; self.muteRequests++;
}
@end
static void SelectModeAction(MUServerRootViewController *root, NSString *method) {
 UIMenu *menu=(id)[root serverMenuActions].firstObject;
 Check([menu isKindOfClass:UIMenu.class] && menu.children.count==3,@"Quick transmission menu is missing its three modes");
 UIAction *chosen=nil;for(UIAction *action in menu.children)if([action.identifier isEqual:method])chosen=action;
 Check(chosen!=nil,@"Transmission menu is missing the requested mode");
 UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem primaryAction:chosen];
 [button sendActionsForControlEvents:UIControlEventTouchUpInside];Wait(.25);
 menu=(id)[root serverMenuActions].firstObject;
 NSUInteger checked=0;for(UIAction *action in menu.children)if(action.state==UIMenuElementStateOn){checked++;Check([action.identifier isEqual:method],@"Quick transmission menu checks a stale mode");}
 Check(checked==1,@"Quick transmission menu does not have exactly one selected mode");
}
static void TransmissionChecks(UIWindow *window) {
 NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;NSString *oldMethod=[defaults stringForKey:@"AudioTransmitMethod"],*oldQuality=[defaults stringForKey:@"AudioQualityKind"];
 MLAudioSettings original;[MLAudio.sharedAudio readAudioSettings:&original];
 @try {
  [defaults setObject:@"vad" forKey:@"AudioTransmitMethod"];
  MLAudioSettings settings=original;settings.transmitType=MLTransmitTypeVAD;[MLAudio.sharedAudio updateAudioSettings:&settings];
  UITableViewController *transmission=[NSClassFromString(@"MUAudioTransmissionPreferencesViewController")new];Show(window,transmission);
  for(NSNumber *row in @[@1,@2,@0,@0,@1,@0]) {
   NSIndexPath *path=[NSIndexPath indexPathForRow:row.integerValue inSection:0];UITableViewCell *before=[transmission.tableView cellForRowAtIndexPath:path];
   [transmission.tableView selectRowAtIndexPath:path animated:NO scrollPosition:UITableViewScrollPositionNone];[transmission tableView:transmission.tableView didSelectRowAtIndexPath:path];Wait(.35);
   Check([transmission.tableView cellForRowAtIndexPath:path]==before,@"Transmission selection replaces the tapped cell and destroys native feedback");
   Check(transmission.tableView.numberOfSections==(row.integerValue==0?2:1),@"Transmission switches leave an invalid Voice Activity section");
   Check(MLAudio.sharedAudio.transmitType==(row.integerValue==0?MLTransmitTypeVAD:row.integerValue==1?MLTransmitTypeToggle:MLTransmitTypeContinuous),@"Transmission choice does not apply to live audio");
  }
  UITableViewController *quality=[NSClassFromString(@"MUAudioQualityPreferencesViewController")new];Show(window,quality);
  NSIndexPath *path=[NSIndexPath indexPathForRow:2 inSection:0];UITableViewCell *before=[quality.tableView cellForRowAtIndexPath:path];
  [quality.tableView selectRowAtIndexPath:path animated:NO scrollPosition:UITableViewScrollPositionNone];[quality tableView:quality.tableView didSelectRowAtIndexPath:path];Wait(.25);
  Check([quality.tableView cellForRowAtIndexPath:path]==before,@"Quality selection destroys the native tapped cell");
  [MLAudio.sharedAudio readAudioSettings:&settings];Check(settings.quality==72000 && before.accessoryType==UITableViewCellAccessoryCheckmark,@"Quality choice does not apply/check immediately");
  [results addObject:@"PASS native Transmission/Quality selection retains tapped cells and applies live settings"];

  AuditVoiceModel *model=[[AuditVoiceModel alloc]initWithConnection:nil];MLUser *user=[MLUser new];user.session=1;user.userName=@"Me";user.channel=model.rootChannel;[[model.rootChannel valueForKey:@"userStorage"]addObject:user];[model setValue:user forKey:@"_connectedUser"];
  MUServerRootViewController *root=[[MUServerRootViewController alloc]initWithConnection:nil andServerModel:model];window.rootViewController=root;[window makeKeyAndVisible];Wait(.25);
  SelectModeAction(root,@"ptt");MUServerViewController *server=[root valueForKey:@"_serverView"];
  for(NSString *category in @[UIContentSizeCategoryLarge,UIContentSizeCategoryAccessibilityExtraExtraExtraLarge]) {
   server.traitOverrides.preferredContentSizeCategory=category;Wait(.2);[window layoutIfNeeded];
   UIButton *talk=[server valueForKey:@"_talkButton"],*speaker=[server valueForKey:@"_speakerButton"];UIView *dock=[server valueForKey:@"_voiceDock"];
   Check(talk && speaker && [server valueForKey:@"_microphoneButton"]==nil,@"Push-to-talk retains the old microphone/audio group");
   CGRect t=[talk convertRect:talk.bounds toView:window],s=[speaker convertRect:speaker.bounds toView:window];
   Check(t.size.width>window.bounds.size.width*.55 && s.size.width==64 && fabs(CGRectGetMidY(t)-CGRectGetMidY(s))<1,@"Push-to-talk is not a wide bar beside a centered speaker button");
   Check(CGRectGetMaxX(t)+11<=CGRectGetMinX(s) && CGRectGetMinX(t)>=25 && CGRectGetMaxX(s)<=window.bounds.size.width-25,@"Push-to-talk controls overlap or lose edge padding");
   Check(!speaker.configuration.title.length && dock.superview==server.view.superview,@"Speaker control is not an independent floating icon");
   Save(window,[category isEqual:UIContentSizeCategoryLarge]?@"ptt-dock-default.png":@"ptt-dock-large.png");
  }
  server.traitOverrides.preferredContentSizeCategory=UIContentSizeCategoryLarge;Wait(.2);
  UIButton *talk=[server valueForKey:@"_talkButton"],*speaker=[server valueForKey:@"_speakerButton"];
  [talk sendActionsForControlEvents:UIControlEventTouchDown];Check(MLAudio.sharedAudio.forceTransmit,@"Hold to speak does not start transmission");
  [talk sendActionsForControlEvents:UIControlEventTouchCancel];Check(!MLAudio.sharedAudio.forceTransmit,@"Cancelling the hold leaves transmission active");
  [speaker sendActionsForControlEvents:UIControlEventTouchUpInside];Check(model.muteRequests==1 && model.requestedDeafen,@"Independent speaker does not use Self-Deafen");
  user.selfDeafened=YES;user.selfMuted=YES;[server updateMuteControls];Check(!talk.enabled,@"Deafened user can still press to transmit");
  [speaker sendActionsForControlEvents:UIControlEventTouchUpInside];Check(!model.requestedDeafen && !model.requestedMute,@"Independent speaker cannot clear Self-Deafen");
  user.selfDeafened=NO;user.selfMuted=NO;[server updateMuteControls];[talk sendActionsForControlEvents:UIControlEventTouchDown];
  [talk sendActionsForControlEvents:UIControlEventTouchCancel];
  [talk sendActionsForControlEvents:UIControlEventTouchDown];
  SelectModeAction(root,@"vad");Check(!MLAudio.sharedAudio.forceTransmit && [server valueForKey:@"_talkButton"]==nil && [server valueForKey:@"_microphoneButton"]!=nil,@"Quick mode change leaves the hold active or keeps the wrong dock");
  for (UIView *view in Subviews([server valueForKey:@"_voiceDock"])) if ([view isKindOfClass:UILabel.class]) {
   NSString *text=((UILabel *)view).text;
   Check(![text isEqual:@"Mic"] && ![text isEqual:NSLocalizedString(@"Audio",nil)],@"Voice icons retain redundant captions");
  }
  SelectModeAction(root,@"continuous");Check(MLAudio.sharedAudio.transmitType==MLTransmitTypeContinuous,@"Continuous mode did not apply");
  SelectModeAction(root,@"ptt");Check([server valueForKey:@"_talkButton"]!=nil && !MLAudio.sharedAudio.forceTransmit,@"Returning to push-to-talk starts unintended transmission");
  [results addObject:@"PASS quick transmission menu, adaptive wide PTT bar, cancellation, Self-Deafen and repeated mode switches"];
 } @finally {
  window.rootViewController=[UIViewController new];Wait(.1);[defaults setObject:oldMethod forKey:@"AudioTransmitMethod"];[defaults setObject:oldQuality forKey:@"AudioQualityKind"];[MLAudio.sharedAudio setForceTransmit:NO];[MLAudio.sharedAudio updateAudioSettings:&original];
 }
}
static void MenuChecks(UIWindow *window) {
 MLServerModel *model=[[MLServerModel alloc]initWithConnection:nil];MLUser *user=[MLUser new];user.session=1;user.userName=@"Me";user.channel=model.rootChannel;[[model.rootChannel valueForKey:@"userStorage"]addObject:user];[model setValue:user forKey:@"_connectedUser"];
 MUServerRootViewController *server=[[MUServerRootViewController alloc]initWithConnection:nil andServerModel:model];window.rootViewController=server;Wait(.2);UISegmentedControl *segments=[server valueForKey:@"_segmentedControl"];for(int i=0;i<3;i++)[(id)server serverModel:model textMessageReceived:[MLTextMessage messageWithPlainText:@"Sample"]fromUser:user];Check([[segments titleForSegmentAtIndex:1]containsString:@"3"],@"Native segment does not announce unread count");UIBarButtonItem *disconnect=[server valueForKey:@"_disconnectButton"];Check(disconnect.customView==nil,@"Disconnect is still a undersized custom bar button");segments.selectedSegmentIndex=1;[segments sendActionsForControlEvents:UIControlEventValueChanged];Wait(.2);Check([[segments titleForSegmentAtIndex:1]isEqual:NSLocalizedString(@"Messages",nil)],@"Unread count does not clear when opening messages");
 UIViewController *messages=[server valueForKey:@"_messagesView"];UITextView *draft=[messages valueForKey:@"_textView"];draft.text=@"Draft survives reconnect";
 [(id<MLConnectionDelegate>)server connection:nil willReconnectAfterDelay:.5 attempt:1];Wait(.1);
 Check(server.topViewController.navigationItem.prompt.length>0 && ![(UIButton *)[messages valueForKey:@"_sendButton"]isEnabled],@"Reconnecting lacks progress or permits sending a draft");
 segments.selectedSegmentIndex=0;[segments sendActionsForControlEvents:UIControlEventValueChanged];Wait(.1);
 Check(server.topViewController.navigationItem.prompt.length>0,@"Switching panes hides reconnect progress");Save(window,@"reconnecting-progress.png");
 [(id<MLConnectionDelegate>)server connectionDidRestoreSession:nil];Wait(.1);
 Check(!server.topViewController.navigationItem.prompt && [draft.text isEqual:@"Draft survives reconnect"],@"Restored connection retains stale progress or loses the draft");
 [results addObject:@"PASS native reconnect progress across pane switches and preserved draft on restore"];
 UIViewController *files=[NSClassFromString(@"MUCertificateDiskImportViewController")new];UINavigationController *nav=Show(window,files);[(id)files importFromFiles:nil];NSDate *pickerEnd=[NSDate dateWithTimeIntervalSinceNow:8];while(!files.presentedViewController && !nav.presentedViewController && pickerEnd.timeIntervalSinceNow>0)Wait(.05);Wait(.3);[results addObject:[NSString stringWithFormat:@"Files presentation: %@ / %@",files.presentedViewController,nav.presentedViewController]];Check([(files.presentedViewController ?: nav.presentedViewController)isKindOfClass:UIDocumentPickerViewController.class],@"Import does not use native Files picker");[nav dismissViewControllerAnimated:NO completion:nil];Wait(.2);
 UIViewController *blank=[UIViewController new];nav=Show(window,blank);MUNotificationController *notice=[MUNotificationController new];[notice addNotification:@"The server denied this action." fromViewController:blank];Wait(.3);UIAlertController *alert=(id)(nav.presentedViewController ?: blank.presentedViewController);Check([alert isKindOfClass:UIAlertController.class] && alert.preferredStyle==UIAlertControllerStyleAlert && alert.actions.count==1,@"Server notice is still a disappearing custom overlay");[nav dismissViewControllerAnimated:NO completion:nil];Wait(.2);
 [results addObject:@"PASS native unread count/bar controls, Files picker and readable server notice"];
}
static NSDictionary *quickConnectionRequest;
static NSUInteger quickConnectionCount, homeDiscoveryStarts;
static BOOL quickConnectionPresentedEarly;
static void CaptureQuickConnection(id object, SEL command, NSString *host, NSUInteger port, NSString *username, NSString *password, UIViewController *parent) {
 quickConnectionCount++;
 quickConnectionPresentedEarly=parent.presentedViewController!=nil;
 quickConnectionRequest=@{@"host":host ?: @"", @"port":@(port), @"username":username ?: @"", @"password":password ?: @""};
}
static void CaptureHomeDiscovery(id object, SEL command) { homeDiscoveryStarts++; }
static MUFavouriteServer *capturedRecentFavourite;
static void CaptureRecentFavourite(id object, SEL command, MUFavouriteServer *server, UIViewController *parent) { capturedRecentFavourite=server; }
static void RecentHomeChecks(UIWindow *window) {
 NSArray *history=[MUDatabase recentServers];
 NSUInteger favouriteCount=[MUDatabase fetchAllFavourites].count;
 Method connect=class_getInstanceMethod(MUConnectionController.class,@selector(connectToHostname:port:withUsername:andPassword:withParentViewController:));
 IMP oldConnect=method_setImplementation(connect,(IMP)CaptureQuickConnection);
 Method favouriteConnect=class_getInstanceMethod(MUConnectionController.class,@selector(connectToFavouriteServer:withParentViewController:));
 IMP oldFavouriteConnect=method_setImplementation(favouriteConnect,(IMP)CaptureRecentFavourite);
 Method discovery=class_getInstanceMethod(NSClassFromString(@"MULanServerListController"),NSSelectorFromString(@"startDiscovery"));
 IMP oldDiscovery=method_setImplementation(discovery,(IMP)CaptureHomeDiscovery);
 @try {
  for(MUFavouriteServer *server in history)[MUDatabase deleteRecentServer:server];
  [MUDatabase recordRecentServerWithHostname:@"community.example.org" port:65000 displayName:@"Community" username:@"Recent guest"];
  MUWelcomeScreenPhone *home=[MUWelcomeScreenPhone new];UINavigationController *nav=Show(window,home);Wait(.3);
  [home setValue:@[] forKey:@"_favouriteServers"];
  [home.tableView reloadData];[home.view layoutIfNeeded];
  Check(home.tableView.numberOfSections==3 && [home.tableView numberOfRowsInSection:2]==1,@"History is absent after reopening Home");
  NSIndexPath *path=[NSIndexPath indexPathForRow:0 inSection:2];quickConnectionCount=0;capturedRecentFavourite=nil;
  [home.tableView.delegate tableView:home.tableView didSelectRowAtIndexPath:path];
  Check(quickConnectionCount==1 && [quickConnectionRequest[@"host"]isEqual:@"community.example.org"] && [quickConnectionRequest[@"port"]unsignedIntegerValue]==65000 && [quickConnectionRequest[@"username"]isEqual:@"Recent guest"] && ![quickConnectionRequest[@"password"]length],@"Recent reconnect loses its endpoint/account or invents a password");
  MUFavouriteServer *favourite=[[MUFavouriteServer alloc]initWithDisplayName:@"Saved community" hostName:@"COMMUNITY.EXAMPLE.ORG" port:65000 userName:@"Saved user" password:@"saved-fixture"];
  [home setValue:@[favourite] forKey:@"_favouriteServers"];
  [home.tableView.delegate tableView:home.tableView didSelectRowAtIndexPath:path];
  Check(capturedRecentFavourite==favourite && quickConnectionCount==1,@"A recent saved server bypasses its favourite credentials");
  [home setValue:@[] forKey:@"_favouriteServers"];
  UISwipeActionsConfiguration *swipe=[home.tableView.delegate tableView:home.tableView trailingSwipeActionsConfigurationForRowAtIndexPath:path];
  Check(swipe.actions.count==1 && swipe.actions.firstObject.style==UIContextualActionStyleDestructive,@"Recent history has no native removal action");
  __block BOOL removed=NO;UIContextualAction *remove=swipe.actions.firstObject;remove.handler(remove,home.view,^(BOOL success){removed=success;});Wait(.5);
  Check(removed && [MUDatabase recentServers].count==0 && home.tableView.numberOfSections==2 && [MUDatabase fetchAllFavourites].count==favouriteCount,@"Removing the last recent server leaves a broken section or changes favourites");
  UITableViewHeaderFooterView *header=[home.tableView headerViewForSection:0];UIButton *manage=nil;
  for(UIView *view in Subviews(header))if([view isKindOfClass:UIButton.class] && [view.accessibilityLabel isEqual:NSLocalizedString(@"Manage Favourites",nil)])manage=(id)view;
  Check(manage!=nil && !home.navigationItem.rightBarButtonItem,@"Manage favourites is not attached to its card header");
  [manage sendActionsForControlEvents:UIControlEventTouchUpInside];Wait(.5);
  Check([nav.topViewController isKindOfClass:NSClassFromString(@"MUFavouriteServerListController")],@"The favourites header action does not open management");
  [results addObject:@"PASS recent reconnect, favourite credential reuse, native history removal and the section-level Manage action"];
 } @finally {
  window.rootViewController=[UIViewController new];Wait(.1);method_setImplementation(connect,oldConnect);method_setImplementation(favouriteConnect,oldFavouriteConnect);method_setImplementation(discovery,oldDiscovery);capturedRecentFavourite=nil;
  for(MUFavouriteServer *server in [MUDatabase recentServers])[MUDatabase deleteRecentServer:server];
  for(MUFavouriteServer *server in history.reverseObjectEnumerator)[MUDatabase recordRecentServerWithHostname:server.hostName port:server.port displayName:server.displayName username:server.userName];
 }
}
static void RecentServerChecks(void) {
 NSArray *original=[MUDatabase recentServers];
 @try {
  for(MUFavouriteServer *server in original)[MUDatabase deleteRecentServer:server];
  for(NSString *host in @[@"a.history.invalid",@"b.history.invalid",@"c.history.invalid",@"d.history.invalid"])[MUDatabase recordRecentServerWithHostname:host port:64738 displayName:host username:@"Audit"];
  NSArray<MUFavouriteServer *> *recent=[MUDatabase recentServers];
  Check(recent.count==3 && [recent[0].hostName isEqual:@"d.history.invalid"] && [recent[2].hostName isEqual:@"b.history.invalid"],@"Recent connections are not bounded or ordered by last connection");
  [MUDatabase recordRecentServerWithHostname:@"B.HISTORY.INVALID" port:64738 displayName:@"Updated name" username:@"Other account"];
  recent=[MUDatabase recentServers];
  Check(recent.count==3 && [recent[0].hostName isEqual:@"b.history.invalid"] && [recent[0].displayName isEqual:@"Updated name"] && [recent[0].userName isEqual:@"Other account"],@"Reconnecting duplicates a server or loses its latest account/name");
  for(MUFavouriteServer *server in recent)Check(!server.password && !server.hasPrimaryKey,@"History contains passwords or masquerades as a saved favourite");
  [MUDatabase recordRecentServerWithHostname:@" " port:64738 displayName:nil username:nil];
  [MUDatabase recordRecentServerWithHostname:@"invalid.history.invalid" port:65536 displayName:nil username:nil];
  [MUDatabase recordRecentServerWithHostname:@"invalid.history.invalid" port:0 displayName:nil username:nil];
  Check([MUDatabase recentServers].count==3 && [[MUDatabase recentServers][0].hostName isEqual:@"b.history.invalid"],@"Invalid history endpoint changes the recent list");
  [MUDatabase recordRecentServerWithHostname:@"b.history.invalid" port:65000 displayName:nil username:nil];
  recent=[MUDatabase recentServers];Check(recent.count==3 && recent[0].port==65000 && recent[1].port==64738,@"History merges different ports at the same host");
  [MUDatabase deleteRecentServer:recent[0]];recent=[MUDatabase recentServers];
  Check(recent.count==2 && recent[0].port==64738,@"Removing a recent server removes another endpoint");
  [results addObject:@"PASS recent connection ordering, three-server limit, endpoint deduplication, account updates, deletion and password-free storage"];
 } @finally {
  for(MUFavouriteServer *server in [MUDatabase recentServers])[MUDatabase deleteRecentServer:server];
  for(MUFavouriteServer *server in original.reverseObjectEnumerator)[MUDatabase recordRecentServerWithHostname:server.hostName port:server.port displayName:server.displayName username:server.userName];
 }
}
static __weak UIScrollView *homeDraggingScroll;
static IMP originalHomeDragging;
static BOOL AuditHomeDragging(id object, SEL command) {
 return object==homeDraggingScroll || ((BOOL (*)(id,SEL))originalHomeDragging)(object,command);
}
static void CheckHomeScrollViewport(MUWelcomeScreenPhone *home, UITableView *table) {
 [table layoutIfNeeded];
 NSIndexPath *last=[NSIndexPath indexPathForRow:[table numberOfRowsInSection:table.numberOfSections-1]-1 inSection:table.numberOfSections-1];
 [table scrollToRowAtIndexPath:last atScrollPosition:UITableViewScrollPositionBottom animated:NO];[table layoutIfNeeded];
 CGRect viewport=[table convertRect:table.bounds toView:home.view];
 CGFloat bottom=MAX(0,table.contentSize.height-table.bounds.size.height);
 for(NSNumber *offset in @[@0,@(bottom),@(bottom+32),@(bottom),@0,@-80,@0]) {
  [table setContentOffset:CGPointMake(0,offset.doubleValue) animated:NO];
  [home.view setNeedsLayout];[home.view layoutIfNeeded];Wait(.05);
  CGRect actual=[table convertRect:table.bounds toView:home.view];
  BOOL stable=fabs(actual.origin.x-viewport.origin.x)<.5 && fabs(actual.origin.y-viewport.origin.y)<.5 && fabs(actual.size.width-viewport.size.width)<.5 && fabs(actual.size.height-viewport.size.height)<.5;
  Check(stable && table.visibleCells.count>0,[NSString stringWithFormat:@"Home scroll %@: viewport %@ -> %@, content %@, offset %@, visible %lu",offset,NSStringFromCGRect(viewport),NSStringFromCGRect(actual),NSStringFromCGSize(table.contentSize),NSStringFromCGPoint(table.contentOffset),(unsigned long)table.visibleCells.count]);
  for(UITableViewCell *cell in table.visibleCells) Check(!cell.hidden && cell.alpha==1 && cell.bounds.size.height>0,@"Home scroll hides a visible server cell");
 }
}
static void HomeScrollChecks(UIWindow *window) {
 Method discovery=class_getInstanceMethod(NSClassFromString(@"MULanServerListController"),NSSelectorFromString(@"startDiscovery"));
 IMP oldDiscovery=method_setImplementation(discovery,(IMP)CaptureHomeDiscovery);
 Method dragging=class_getInstanceMethod(UITableView.class,@selector(isDragging));
 originalHomeDragging=method_setImplementation(dragging,(IMP)AuditHomeDragging);
 @try {
  MUWelcomeScreenPhone *home=[MUWelcomeScreenPhone new];
  UINavigationController *navigation=[[UINavigationController alloc]initWithRootViewController:home];
  navigation.navigationBar.prefersLargeTitles=YES;
  UITabBarController *tabs=[UITabBarController new];
  navigation.tabBarItem=[[UITabBarItem alloc]initWithTitle:NSLocalizedString(@"Home",nil) image:[UIImage systemImageNamed:@"house"] tag:0];
  UIViewController *settings=[UIViewController new];settings.tabBarItem=[[UITabBarItem alloc]initWithTitle:NSLocalizedString(@"Settings",nil) image:[UIImage systemImageNamed:@"gearshape"] tag:1];
  tabs.viewControllers=@[navigation,settings];window.rootViewController=tabs;[window makeKeyAndVisible];Wait(.5);
  MUFavouriteServer *favourite=[[MUFavouriteServer alloc]initWithDisplayName:@"Favourite server" hostName:@"home-audit.invalid" port:64738 userName:@"Audit" password:nil];
  NSNetService *lan=[[NSNetService alloc]initWithDomain:@"local." type:@"_mumble._tcp." name:@"LAN server" port:64738];
  [home setValue:@[favourite] forKey:@"_favouriteServers"];
  [home setValue:@[lan] forKey:@"_lanServices"];
  [home setValue:@[] forKey:@"_recentServers"];
  [home.tableView reloadData];[home.view layoutIfNeeded];Wait(.2);
  CheckHomeScrollViewport(home,home.tableView);
  Save(window,@"home-scroll-audit.png");
  MUFavouriteServer *recent=[[MUFavouriteServer alloc]initWithDisplayName:@"Community" hostName:@"community.example.org" port:64738 userName:@"Guest" password:nil];
  MUFavouriteServer *second=[[MUFavouriteServer alloc]initWithDisplayName:@"Voice Chat" hostName:@"voice.example.net" port:64738 userName:@"Guest" password:nil];
  [home setValue:@[recent,second] forKey:@"_recentServers"];[home.tableView reloadData];[home.view layoutIfNeeded];Wait(.2);
  Check(home.tableView.style==UITableViewStyleInsetGrouped && home.tableView.numberOfSections==3 && [home.tableView numberOfRowsInSection:2]==2,@"Recent connections are not an independent native card group");
  UIUserInterfaceStyle previousStyle=window.overrideUserInterfaceStyle;
  window.overrideUserInterfaceStyle=UIUserInterfaceStyleLight;Wait(.2);Save(window,@"home-cards-light.png");
  window.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;Wait(.2);Save(window,@"home-cards-dark.png");window.overrideUserInterfaceStyle=previousStyle;
  [home setValue:@[] forKey:@"_recentServers"];[home.tableView reloadData];[home.view layoutIfNeeded];
  NSMutableArray *many=[NSMutableArray array];for(int i=0;i<30;i++)[many addObject:favourite];
  [home setValue:many forKey:@"_favouriteServers"];[home.tableView reloadData];[home.view layoutIfNeeded];
  CheckHomeScrollViewport(home,home.tableView);
  [home.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:29 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:NO];
  homeDraggingScroll=home.tableView;
  Check(home.tableView.isDragging,@"Home scroll fixture did not enter the dragging state");
  [home setValue:@[favourite] forKey:@"_pendingFavourites"];[(id)home drainPendingUpdates];
  Check([[home valueForKey:@"_favouriteServers"]count]==30 && [home valueForKey:@"_pendingFavourites"]!=nil,@"Home replaces its rows while a bottom-edge gesture is active");
  homeDraggingScroll=nil;
  [(id<UIScrollViewDelegate>)home scrollViewDidEndDragging:home.tableView willDecelerate:NO];[home.view layoutIfNeeded];Wait(.1);
  Check([[home valueForKey:@"_favouriteServers"]count]==1 && [home valueForKey:@"_pendingFavourites"]==nil && home.tableView.visibleCells.count>0,@"Home does not restore a visible short list after a deferred refresh");
  // Exercise the same resize path used by a Duo opening or rotating without
  // relying on the currently selected Simulator posture.
  UIViewController *host=[UIViewController new];
  MUWelcomeScreenPhone *resizable=[MUWelcomeScreenPhone new];
  window.rootViewController=host;[host addChildViewController:resizable];
  resizable.view.translatesAutoresizingMaskIntoConstraints=NO;[host.view addSubview:resizable.view];
  NSLayoutConstraint *width=[resizable.view.widthAnchor constraintEqualToConstant:900];
  [NSLayoutConstraint activateConstraints:@[[resizable.view.leadingAnchor constraintEqualToAnchor:host.view.leadingAnchor],[resizable.view.topAnchor constraintEqualToAnchor:host.view.topAnchor],[resizable.view.bottomAnchor constraintEqualToAnchor:host.view.bottomAnchor],width]];
  [resizable didMoveToParentViewController:host];Wait(.4);
  [resizable setValue:@[favourite] forKey:@"_favouriteServers"];
  [resizable setValue:@[lan] forKey:@"_lanServices"];
  [resizable setValue:@[recent,second] forKey:@"_recentServers"];
  UITableView *lanTable=[resizable valueForKey:@"_lanTable"];
  for(NSNumber *size in @[@900,@402,@900,@402]) {
   width.constant=size.doubleValue;[host.view setNeedsLayout];[host.view layoutIfNeeded];Wait(.1);
   [resizable.tableView reloadData];[lanTable reloadData];[resizable.view layoutIfNeeded];
   BOOL split=size.doubleValue>=700;
   Check(lanTable.hidden!=split && resizable.tableView.numberOfSections==(split ? 1 : 3) && lanTable.numberOfSections==2,@"Home resize loses its single/dual-column server grouping");
   CheckHomeScrollViewport(resizable,resizable.tableView);
   if(split)CheckHomeScrollViewport(resizable,lanTable);
  }
  resizable.traitOverrides.preferredContentSizeCategory=UIContentSizeCategoryAccessibilityExtraExtraLarge;
  [host.view setNeedsLayout];[host.view layoutIfNeeded];Wait(.2);
  UIStackView *actions=[resizable valueForKey:@"_actions"];
  Check(actions.axis==UILayoutConstraintAxisVertical,@"Home shortcuts do not stack at accessibility text sizes");
  CGRect controls=[actions convertRect:actions.bounds toView:resizable.view];
  CGRect list=[resizable.tableView convertRect:resizable.tableView.bounds toView:resizable.view];
  Check(CGRectGetMaxY(controls)<=CGRectGetMinY(list)-7 && list.size.height>80,@"Large-text Home shortcuts cover the server list");
  Save(window,@"home-cards-accessibility.png");
  [results addObject:@"PASS populated Home overscroll, deferred refresh, long lists and repeated single/dual-column resizing"];
 } @finally { homeDraggingScroll=nil;method_setImplementation(dragging,originalHomeDragging);window.rootViewController=[UIViewController new];Wait(.1);method_setImplementation(discovery,oldDiscovery); }
}
static void ServerActionPresentationChecks(UIWindow *window) {
 NSMutableArray *items=[NSMutableArray array];
 for(NSUInteger i=1;i<=6;++i)[items addObject:@{@"name":[NSString stringWithFormat:@"Server %lu",(unsigned long)i],@"ip":@"127.0.0.1",@"port":@"64738"}];
 MUCountryServerListController *servers=[[MUCountryServerListController alloc]initWithName:@"Fixture" serverList:items];
 Show(window,servers);UITableView *table=[servers valueForKey:@"_tableView"];
 NSIndexPath *selected=[NSIndexPath indexPathForRow:5 inSection:0];
 [(id<UITableViewDelegate>)servers tableView:table didSelectRowAtIndexPath:selected];WaitForSheet(servers);
 UIAlertController *menu=(id)servers.presentedViewController;
 Check([menu isKindOfClass:UIAlertController.class] && menu.actions.count==3,@"Server actions did not present");
 CGRect row=[table convertRect:[table rectForRowAtIndexPath:selected] toView:menu.presentationController.containerView];
 CGRect popup=menu.presentationController.frameOfPresentedViewInContainerView;
 Check(CGRectGetMaxY(popup)<=CGRectGetMinY(row)+20 && CGRectGetMaxY(popup)>CGRectGetMinY(row)-40,@"Server menu is not anchored above its selected row");
 Save(window,@"server-actions-at-row.png");DismissSheet(servers);
 [results addObject:@"PASS native server actions open upward at the selected row"];
}
static void QuickConnectHomeChecks(UIWindow *window) {
 Method connect=class_getInstanceMethod(MUConnectionController.class,@selector(connectToHostname:port:withUsername:andPassword:withParentViewController:));
 IMP oldConnect=method_setImplementation(connect,(IMP)CaptureQuickConnection);
 Method discovery=class_getInstanceMethod(NSClassFromString(@"MULanServerListController"),NSSelectorFromString(@"startDiscovery"));
 IMP oldDiscovery=method_setImplementation(discovery,(IMP)CaptureHomeDiscovery);
 id oldUsername=[NSUserDefaults.standardUserDefaults objectForKey:@"DefaultUserName"];
 NSUInteger favourites=[MUDatabase fetchAllFavourites].count;
 quickConnectionCount=0;homeDiscoveryStarts=0;quickConnectionRequest=nil;
 @try {
  [NSUserDefaults.standardUserDefaults setObject:@"Default quick user" forKey:@"DefaultUserName"];
  MUWelcomeScreenPhone *home=[MUWelcomeScreenPhone new];Show(window,home);Wait(.3);
  [home setValue:@[] forKey:@"_recentServers"];[home.tableView reloadData];
  BOOL split = home.view.bounds.size.width >= 700;
  Check(home.tableView.numberOfSections==(split ? 1 : 2) && homeDiscoveryStarts>0,@"Home lists contain an extra public-server subsection");
  UITableView *lanTable=[home valueForKey:@"_lanTable"];
  Check(lanTable.numberOfSections==1,@"Public servers remain nested in the LAN column");
  UIButton *publicButton=nil,*quickButton=nil;
  for(UIView *view in Subviews(home.view)) if([view isKindOfClass:UIButton.class]) {
   UIButton *button=(id)view;
   if([button.configuration.title isEqual:NSLocalizedString(@"Public Servers",nil)]) publicButton=button;
   if([button.configuration.title isEqual:NSLocalizedString(@"Quick Connect",nil)]) quickButton=button;
  }
  Check(publicButton && quickButton && publicButton.superview==quickButton.superview,@"Public servers are not a peer of the top-level quick-connect action");
  [publicButton sendActionsForControlEvents:UIControlEventTouchUpInside];Wait(.6);
  UINavigationController *homeNavigation=home.navigationController;
  Check([homeNavigation.topViewController isKindOfClass:NSClassFromString(@"MUPublicServerListController")] && homeNavigation.viewControllers.count==2,@"Public servers do not open the directory directly from Home");
  [homeNavigation popViewControllerAnimated:NO];Wait(.2);
  CGRect publicFrame=[publicButton convertRect:publicButton.bounds toView:home.view];
  CGRect quickFrame=[quickButton convertRect:quickButton.bounds toView:home.view];
  CGRect listFrame=[home.tableView convertRect:home.tableView.bounds toView:home.view];
  [results addObject:[NSString stringWithFormat:@"Home action frames: quick %@, public %@, list %@",NSStringFromCGRect(quickFrame),NSStringFromCGRect(publicFrame),NSStringFromCGRect(listFrame)]];
  Check(publicFrame.size.height>=44 && quickFrame.size.height>=44 && CGRectGetMaxY(publicFrame)<=CGRectGetMinY(listFrame)-7 && CGRectGetMaxY(quickFrame)<=CGRectGetMinY(listFrame)-7,@"Top-level server actions overlap the list or lose their touch targets");
  Save(window,@"native-home-audit.png");
  NSIndexPath *quick=[NSIndexPath indexPathForRow:0 inSection:0];
  [(id)home showQuickConnect:nil];WaitForSheet(home);
  MUFavouriteServerEditViewController *form=(id)[(UINavigationController *)home.presentedViewController topViewController];
  UINavigationController *quickNavigation=(id)home.presentedViewController;
  if(quickNavigation.traitCollection.verticalSizeClass!=UIUserInterfaceSizeClassCompact){
   CGRect frame=quickNavigation.presentationController.frameOfPresentedViewInContainerView;
   Check(frame.size.height<window.bounds.size.height*.75 && CGRectGetMinY(frame)>window.bounds.size.height*.2,@"Quick Connect opens full-height instead of a floating half sheet");
  }
  Save(window,@"quick-connect-half-sheet.png");
  Check([form isKindOfClass:MUFavouriteServerEditViewController.class] && [form.tableView numberOfRowsInSection:0]==4,@"Quick connect does not use the native four-field connection form");
  UITextField *address=[form valueForKey:@"_addressField"],*port=[form valueForKey:@"_portField"],*password=[form valueForKey:@"_passwordField"];
  Check([form.tableView cellForRowAtIndexPath:quick]==[form valueForKey:@"_addressCell"] && password.secureTextEntry && !form.navigationItem.rightBarButtonItem.enabled,@"Quick connect exposes a description field, plaintext password or an empty address");
  address.text=@"  \n ";[address sendActionsForControlEvents:UIControlEventEditingChanged];[(id)form doneClicked:nil];
  Check(!form.navigationItem.rightBarButtonItem.enabled && quickConnectionCount==0,@"Quick connect accepts a whitespace-only address");
  address.text=@"  quick-connect-audit.invalid  ";[address sendActionsForControlEvents:UIControlEventEditingChanged];
  for(NSString *invalid in @[@"0",@"65536",@"-1",@"12x",@"1.5",@"99999999999"]) {
   port.text=invalid;[port sendActionsForControlEvents:UIControlEventEditingChanged];[(id)form doneClicked:nil];
   Check(!form.navigationItem.rightBarButtonItem.enabled && quickConnectionCount==0 && home.presentedViewController!=nil,@"Quick connect accepts an invalid port");
  }
  for(NSString *valid in @[@"1",@"65535",@""]) { port.text=valid;[port sendActionsForControlEvents:UIControlEventEditingChanged];Check(form.navigationItem.rightBarButtonItem.enabled,@"Quick connect rejects a valid/default port"); }
  password.text=@"  quick password  ";Save(window,@"quick-connect-audit.png");
  [(id)form doneClicked:nil];Wait(.8);
  Check(quickConnectionCount==1 && !quickConnectionPresentedEarly && [quickConnectionRequest[@"host"]isEqual:@"quick-connect-audit.invalid"] && [quickConnectionRequest[@"port"]unsignedIntegerValue]==64738 && [quickConnectionRequest[@"username"]isEqual:@"Default quick user"] && [quickConnectionRequest[@"password"]isEqual:@"  quick password  "],@"Quick connect loses parameters, trims the password, duplicates attempts or starts before dismissal");
  Check([MUDatabase fetchAllFavourites].count==favourites,@"Quick connect saves an unwanted favourite");
  [(id)home showQuickConnect:nil];WaitForSheet(home);
  form=(id)[(UINavigationController *)home.presentedViewController topViewController];
  address=[form valueForKey:@"_addressField"];port=[form valueForKey:@"_portField"];UITextField *username=[form valueForKey:@"_usernameField"];
  address.text=@"2001:db8::1";port.text=@" 65000 ";username.text=@" guest ";[address sendActionsForControlEvents:UIControlEventEditingChanged];[port sendActionsForControlEvents:UIControlEventEditingChanged];
  [(id)form doneClicked:nil];Wait(.8);
  Check(quickConnectionCount==2 && [quickConnectionRequest[@"host"]isEqual:@"2001:db8::1"] && [quickConnectionRequest[@"port"]unsignedIntegerValue]==65000 && [quickConnectionRequest[@"username"]isEqual:@"guest"] && ![quickConnectionRequest[@"password"]length],@"Quick connect loses an IPv6 address, custom port, username or optional password");
  [(id)home showQuickConnect:nil];WaitForSheet(home);
  form=(id)[(UINavigationController *)home.presentedViewController topViewController];[(id)form cancelClicked:nil];Wait(.7);
  Check(quickConnectionCount==2 && [MUDatabase fetchAllFavourites].count==favourites,@"Cancelling quick connect starts a connection or saves a favourite");
  [results addObject:@"PASS native Quick Connect form, validation, defaults, dismissal ordering, no favourite writes, cancellation and a full-height home"];
 } @finally {
  window.rootViewController=[UIViewController new];Wait(.1);
  method_setImplementation(connect,oldConnect);method_setImplementation(discovery,oldDiscovery);
  if(oldUsername)[NSUserDefaults.standardUserDefaults setObject:oldUsername forKey:@"DefaultUserName"];else[NSUserDefaults.standardUserDefaults removeObjectForKey:@"DefaultUserName"];
  quickConnectionRequest=nil;
 }
}
static void PreviewAndHomeChecks(UIWindow *window) {
 RecentHomeChecks(window);HomeScrollChecks(window);QuickConnectHomeChecks(window);ServerActionPresentationChecks(window);
 UIImage *image=[[[UIGraphicsImageRenderer alloc]initWithSize:CGSizeMake(600,340)]imageWithActions:^(UIGraphicsImageRendererContext *context){[UIColor.systemTealColor setFill];UIRectFill(CGRectMake(0,0,600,340));}];
 MUImageViewController *viewer=[[MUImageViewController alloc]initWithImages:@[image]];Show(window,viewer);NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:8];while([viewer.dataSource numberOfPreviewItemsInPreviewController:viewer]!=1 && deadline.timeIntervalSinceNow>0)Wait(.05);Check([viewer.dataSource numberOfPreviewItemsInPreviewController:viewer]==1,@"Native preview did not finish preparing");Wait(1);Save(window,@"native-quicklook-audit.png");
 [results addObject:@"PASS native Home and Quick Look screenshots"];
}
static void CrowdedServerSnapshots(UIWindow *window) {
 MLAudioSettings original;[MLAudio.sharedAudio readAudioSettings:&original];
 UIUserInterfaceStyle oldStyle=window.overrideUserInterfaceStyle;
 @try {
  MLAudioSettings settings=original;settings.transmitType=MLTransmitTypeVAD;[MLAudio.sharedAudio updateAudioSettings:&settings];
  MLServerModel *model=[[MLServerModel alloc]initWithConnection:nil];model.rootChannel.channelName=@"Voice Channels";
  MLUser *me=[MLUser new];me.session=1;me.userName=@"Me";me.channel=model.rootChannel;[[model.rootChannel valueForKey:@"userStorage"]addObject:me];[model setValue:me forKey:@"_connectedUser"];
  for(NSUInteger i=1;i<=40;i++) {
   MLChannel *room=[MLChannel new];room.channelId=i;room.channelName=[NSString stringWithFormat:@"Voice room %02lu",(unsigned long)i];room.parent=model.rootChannel;
   [[model.rootChannel valueForKey:@"childStorage"]addObject:room];
   if(i%3==0){MLUser *member=[MLUser new];member.session=i+100;member.userName=[NSString stringWithFormat:@"Member %lu",(unsigned long)i];member.channel=room;member.talkState=i%2?MLTalkStateTalking:MLTalkStatePassive;[[room valueForKey:@"userStorage"]addObject:member];}
  }
  MUServerViewController *server=[[MUServerViewController alloc]initWithServerModel:model];Show(window,server);
  for(NSNumber *style in @[@(UIUserInterfaceStyleLight),@(UIUserInterfaceStyleDark)]) {
   window.overrideUserInterfaceStyle=style.integerValue;[server.tableView setContentOffset:CGPointMake(0,350) animated:NO];Wait(.3);
   Save(window,style.integerValue==UIUserInterfaceStyleLight?@"dense-channels-dock-light.png":@"dense-channels-dock-dark.png");
  }
  window.overrideUserInterfaceStyle=UIUserInterfaceStyleLight;
  settings.transmitType=MLTransmitTypeToggle;[MLAudio.sharedAudio updateAudioSettings:&settings];
  [(id)server audioSettingsUpdated:nil];Wait(.3);Save(window,@"dense-channels-dock-ptt.png");
  [results addObject:@"VISUAL dense-channel dock snapshots: light, dark and push-to-talk"];
 } @finally {window.rootViewController=[UIViewController new];window.overrideUserInterfaceStyle=oldStyle;[MLAudio.sharedAudio updateAudioSettings:&original];}
}
@interface AuditTokenModel : NSObject
@property(nonatomic,copy) NSArray *saved;
@end
@implementation AuditTokenModel
- (NSString *)hostname { return @"native-token-regression.invalid"; }
- (NSInteger)port { return 64738; }
- (void)setAccessTokens:(NSArray *)tokens { self.saved=[tokens copy]; }
@end
static NSArray *EmptyTokens(id self,SEL selector,NSString *hostname,NSInteger port) { return @[]; }
static void IgnoreTokenStore(id self,SEL selector,NSArray *tokens,NSString *hostname,NSInteger port) {}
static float DetectedSpeech(id self,SEL selector) { return .82f; }
static UITextField *TokenField(UIViewController *vc) { for(UIView *view in Subviews(vc.view))if([view isKindOfClass:UITextField.class])return (id)view;return nil; }
static void TokenAndDetectionChecks(UIWindow *window) {
 Method load=class_getClassMethod(NSClassFromString(@"MUDatabase"),@selector(accessTokensForServerWithHostname:port:));
 Method store=class_getClassMethod(NSClassFromString(@"MUDatabase"),@selector(storeAccessTokens:forServerWithHostname:port:));
 IMP oldLoad=method_setImplementation(load,(IMP)EmptyTokens),oldStore=method_setImplementation(store,(IMP)IgnoreTokenStore);
 @try {
  AuditTokenModel *model=[AuditTokenModel new];
  MUAccessTokenViewController *tokens=[[MUAccessTokenViewController alloc]initWithServerModel:(id)model];
  // Repeated appearance must never replace a live draft with the empty DB snapshot.
  Show(window,tokens);[tokens addButtonClicked:nil];Wait(.3);
  UITextField *field=TokenField(tokens);Check(field!=nil,@"Adding first access token did not create an editor");
  field.text=@"first";[field sendActionsForControlEvents:UIControlEventEditingChanged];
  [tokens viewWillAppear:NO];[tokens viewWillDisappear:NO];Wait(.1);
  Check([model.saved isEqual:@[@"first"]],@"Appearance transition discarded or crashed on first token draft");
  [tokens viewWillAppear:NO];[tokens addButtonClicked:nil];Wait(.3);field=TokenField(tokens);field.text=@"second";[field sendActionsForControlEvents:UIControlEventEditingDidEndOnExit];Wait(.1);
  [tokens addButtonClicked:nil];Wait(.3);field=TokenField(tokens);field.text=@"third";[tokens doneButtonClicked:nil];[tokens viewWillDisappear:NO];
  Check([model.saved isEqual:@[@"first",@"second",@"third"]],@"Return/Done failed to preserve new token values");
  [tokens tableView:tokens.tableView commitEditingStyle:UITableViewCellEditingStyleDelete forRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]];
  [tokens tableView:tokens.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]];Wait(.2);field=TokenField(tokens);field.text=@"updated";[field resignFirstResponder];Wait(.1);[tokens viewWillDisappear:NO];
  Check([model.saved isEqual:@[@"first",@"updated"]],@"Delete/edit/keyboard dismissal lost token changes");
 } @finally { method_setImplementation(load,oldLoad);method_setImplementation(store,oldStore); }
 [results addObject:@"PASS empty token list: add, repeated appearance, Return, Done, delete, edit and keyboard dismissal"];
 NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;NSString *oldKind=[defaults stringForKey:@"AudioVADKind"];BOOL oldProcessor=[defaults boolForKey:@"AudioPreprocessor"];float oldBelow=[defaults floatForKey:@"AudioVADBelow"],oldAbove=[defaults floatForKey:@"AudioVADAbove"];
 @try {
  [defaults setBool:YES forKey:@"AudioPreprocessor"];[defaults setObject:@"amplitude" forKey:@"AudioVADKind"];
  UITableViewController *vad=[NSClassFromString(@"MUVoiceActivitySetupViewController")new];Show(window,vad);
  [vad tableView:vad.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]];
  MLAudioSettings settings;[MLAudio.sharedAudio readAudioSettings:&settings];Check(settings.vadKind==MLVADKindSignalToNoise,@"Selecting SNR only updated the checkmark");
  Method probability=class_getInstanceMethod(MLAudio.class,@selector(speechProbablity));IMP previous=method_setImplementation(probability,(IMP)DetectedSpeech);
  @try {
   BOOL matched=NO;for(UIView *view in Subviews(vad.view))if([view isKindOfClass:NSClassFromString(@"MUAudioBarView")]){[view tickTock];for(UIView *child in Subviews(view))if([child isKindOfClass:UIProgressView.class])matched=fabs(((UIProgressView *)child).progress-.82f)<.001;}
   Check(matched,@"Native SNR progress does not display the active speech detector reading");
  } @finally { method_setImplementation(probability,previous); }
  for(NSString *category in @[UIContentSizeCategoryLarge,UIContentSizeCategoryAccessibilityExtraExtraExtraLarge]) {
   vad.traitOverrides.preferredContentSizeCategory=category;[vad.tableView reloadData];Wait(.2);
   for(UIView *view in Subviews(vad.view))if([view isKindOfClass:UISlider.class]||[view isKindOfClass:UIProgressView.class]) {
    UIView *parent=view;while(parent && ![parent isKindOfClass:UITableViewCell.class])parent=parent.superview;
    CGRect frame=[view convertRect:view.bounds toView:((UITableViewCell *)parent).contentView];
    Check(CGRectGetMinX(frame)>=19 && CGRectGetMaxX(frame)<=((UITableViewCell *)parent).contentView.bounds.size.width-19,@"VAD control touches cell edges");
   }
  }
  UISlider *slider=[UISlider new];slider.value=.31;[vad vadBelowChanged:slider];slider.value=.62;[vad vadAboveChanged:slider];[MLAudio.sharedAudio readAudioSettings:&settings];
  Check(fabs(settings.vadMin-.31)<.001 && fabs(settings.vadMax-.62)<.001,@"VAD sliders did not update active microphone thresholds");
  vad.traitOverrides.preferredContentSizeCategory=UIContentSizeCategoryLarge;[vad.tableView reloadData];Wait(.2);Save(window,@"vad-insets-default.png");
 } @finally { [defaults setBool:oldProcessor forKey:@"AudioPreprocessor"];[defaults setObject:oldKind forKey:@"AudioVADKind"];[defaults setFloat:oldBelow forKey:@"AudioVADBelow"];[defaults setFloat:oldAbove forKey:@"AudioVADAbove"];[(id)UIApplication.sharedApplication.delegate reloadPreferences]; }
 [results addObject:@"PASS VAD mode and slider changes apply live; native controls retain 20pt edge padding"];
}
@interface MUPublicListFixture : MUPublicServerList
@property(nonatomic, copy) NSData *bundledXML;
@property(nonatomic, copy) NSData *downloadedXML;
@end
@implementation MUPublicListFixture
- (NSData *)bundledListData { return self.bundledXML; }
- (NSData *)downloadedListData { return self.downloadedXML; }
@end
static void PublicServerModelChecks(void) {
 MUPublicListFixture *list = [MUPublicListFixture new];
 NSString *us = @"<server name='A' ip='a.example' port='64738' country_code='US' continent_code='NA'/>";
 NSString *de = @"<server name='B' ip='b.example' port='64738' country_code='DE' continent_code='EU'/>";
 NSString *unknown = @"<server name='C' ip='c.example' port='64738'/>";
 NSString *invalid = @"<server name='Invalid' port='64738' country_code='US' continent_code='NA'/>";
 list.bundledXML = [[NSString stringWithFormat:@"<servers>%@%@%@</servers>",us,us,invalid] dataUsingEncoding:NSUTF8StringEncoding];
 list.downloadedXML = [[NSString stringWithFormat:@"<servers>%@%@%@</servers>",us,de,unknown] dataUsingEncoding:NSUTF8StringEncoding];
 [list parse];Check(list.isParsed && list.numberOfContinents==3,@"Public list grouping depends on removed continent resources");
 NSMutableSet *hosts = [NSMutableSet set];BOOL localizedUS=NO;
 NSLocale *locale = [NSLocale localeWithLocaleIdentifier:NSBundle.mainBundle.preferredLocalizations.firstObject ?: @"en"];
 for(NSInteger continent=0;continent<list.numberOfContinents;continent++) {
  for(NSInteger country=0;country<[list numberOfCountriesAtContinentIndex:continent];country++) {
   NSUInteger indexes[] = {continent,country};NSDictionary *item=[list countryAtIndexPath:[NSIndexPath indexPathWithIndexes:indexes length:2]];
   Check([item[@"name"]length]>0,@"A country without an ISO code has no fallback label");
   for(NSDictionary *server in item[@"servers"]) {
    Check(![hosts containsObject:server[@"ip"]],@"Bundled/downloaded public servers are duplicated");[hosts addObject:server[@"ip"]];
    if([server[@"country_code"]isEqual:@"US"])localizedUS=[item[@"name"]isEqual:[locale displayNameForKey:NSLocaleCountryCode value:@"US"]];
   }
  }
 }
 Check(hosts.count==3 && localizedUS,@"Public servers are lost or country names bypass Foundation localization");
 list.downloadedXML=[NSData data];[list invalidate];Check(!list.isParsed,@"Public list invalidation leaves its old model active");[list parse];
 Check(list.numberOfContinents==1 && [list numberOfCountriesAtContinentIndex:0]==1,@"Refreshing public servers retains stale countries");
 [results addObject:@"PASS bundled/downloaded public servers, duplicate filtering, system country names, missing codes and model refresh"];
}

static void Run(void) {
 results=[NSMutableArray array];Method start=class_getInstanceMethod(MLAudio.class,@selector(start));IMP previous=method_setImplementation(start,(IMP)NoAudioStart);
 NSString *language=NSProcessInfo.processInfo.environment[@"MU_UI_TEST_LANGUAGE"];
 if(language.length) {
  Check([NSBundle.mainBundle.preferredLocalizations.firstObject isEqual:language],@"The requested app language was not selected by Foundation");
  Check(NSBundle.mainBundle.localizations.count>=12,@"The installed app does not expose all twelve languages");
  [results addObject:[NSString stringWithFormat:@"PASS Foundation selected app language %@; Home = %@",language,NSLocalizedString(@"Home",nil)]];
 }
 @try{RecentServerChecks();UIWindowScene *scene=(id)UIApplication.sharedApplication.connectedScenes.allObjects.firstObject;UIWindow *window=[(id)scene.delegate valueForKey:@"window"];if([NSProcessInfo.processInfo.environment[@"MU_UI_TEST_SERVER_ACTIONS_ONLY"]boolValue]){ServerActionPresentationChecks(window);}else if([NSProcessInfo.processInfo.environment[@"MU_UI_TEST_CONNECTION_ONLY"]boolValue]){MUConnectionLifecycleChecks(window,results);PasswordConnectionChecks(window);}else if([NSProcessInfo.processInfo.environment[@"MU_UI_TEST_HOME_ONLY"]boolValue]){RecentHomeChecks(window);HomeScrollChecks(window);QuickConnectHomeChecks(window);ServerActionPresentationChecks(window);}else{MUCredentialStoreChecks(results);MUMessageStoreChecks(window,results);PublicServerModelChecks();MUConnectionLifecycleChecks(window,results);PasswordConnectionChecks(window);SetupAndCertificateChecks(window);CertificateNavigationChecks(window);TransmissionChecks(window);TokenAndDetectionChecks(window);FormChecks(window);NativeChecks(window);SearchChecks(window);MenuChecks(window);CrowdedServerSnapshots(window);PreviewAndHomeChecks(window);}[results addObject:@"ALL INTERFACE AUDIT CHECKS PASSED"];}@catch(NSException *error){[results addObject:[NSString stringWithFormat:@"FAIL %@",error.reason]];}@finally{method_setImplementation(start,previous);[MLAudio.sharedAudio stop];}
 [[results componentsJoinedByString:@"\n"]writeToFile:[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"composer-ui-results.txt"]atomically:YES encoding:NSUTF8StringEncoding error:nil];
}
__attribute__((constructor))static void Schedule(void){dispatch_async(dispatch_get_main_queue(),^{[NSTimer scheduledTimerWithTimeInterval:1 repeats:NO block:^(NSTimer *timer){Run();}];});}
