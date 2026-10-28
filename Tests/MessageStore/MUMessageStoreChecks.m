// Network-free regressions called by the isolated interface audit.
#import <UIKit/UIKit.h>
#import "MLClient.h"
#import "MUMessagesDatabase.h"
#import "MUTextMessage.h"
#import "MUMessageBubbleTableViewCell.h"
#import "MUImageViewController.h"
#import "MUMessagesViewController.h"

@interface MUMessagesViewController (MessageStoreChecks)
- (void)serverModel:(MLServerModel *)model textMessageReceived:(MLTextMessage *)message fromUser:(MLUser *)user;
- (void)sendMessage:(id)sender;
@end
static void Check(BOOL condition,NSString *message){if(!condition)@throw [NSException exceptionWithName:@"MessageStoreFailure" reason:message userInfo:nil];}
static void Wait(BOOL (^ready)(void)){
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:5];
    while(!ready() && deadline.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]];
    Check(ready(),@"Timed out waiting for background message processing");
}
static CGFloat Height(MUTextMessage *message){return [MUMessageBubbleTableViewCell heightForCellWithHeading:message.heading message:message.message images:message.embeddedImageSizes footer:nil date:message.date width:390 traitCollection:UITraitCollection.currentTraitCollection];}
void MUMessageStoreChecks(UIWindow *window,NSMutableArray<NSString *> *results){
    UIGraphicsImageRendererFormat *format=[UIGraphicsImageRendererFormat preferredFormat];format.scale=1;format.opaque=YES;
    UIImage *original=[[[UIGraphicsImageRenderer alloc]initWithSize:CGSizeMake(2048,1024) format:format]imageWithActions:^(UIGraphicsImageRendererContext *context){[UIColor.systemBlueColor setFill];UIRectFill(CGRectMake(0,0,2048,1024));}];
    NSString *html=[NSString stringWithFormat:@"<img src=\"data:image/png;base64,%@\"/><a href=\"https://example.org\">Link</a>",[UIImagePNGRepresentation(original)base64EncodedStringWithOptions:0]];
    MUMessagesDatabase *store=[MUMessagesDatabase new];__block BOOL saved=NO;
    [store addMessage:[MLTextMessage messageWithHTML:html] withHeading:@"From audit" andSentBySelf:NO completion:^{Check(NSThread.isMainThread,@"Message completion changed UIKit off main thread");saved=YES;}];
    Check(store.count==0,@"Message insertion blocks until persistence or publishes a partial snapshot");Wait(^BOOL{return saved;});
    MUTextMessage *warm=[store messageAtIndex:0];
    Check(store.count==1 && warm.hasAttachments && warm.numberOfAttachments==2 && warm.embeddedImages.count==1,@"Prepared message loses its links/images/order");
    UIImage *thumbnail=warm.embeddedImages.firstObject;
    Check(MAX(thumbnail.size.width,thumbnail.size.height)<=1280 && [warm.embeddedImageSizes[0]CGSizeValue].width==2048,@"Message preview keeps full-size pixels or loses original geometry");
    CGFloat height=Height(warm);
    __block NSArray *fullImages=nil;
    [store loadImagesAtIndex:0 completion:^(NSArray<UIImage *> *images){fullImages=images;}];Wait(^BOOL{return fullImages!=nil;});
    Check(fullImages.count==1 && [(UIImage *)fullImages.firstObject size].width==2048,@"Opening an attachment returns its reduced preview instead of the original");
    MUImageViewController *viewer=[[MUImageViewController alloc]initWithImageLoader:^(void (^completion)(NSArray<UIImage *> *)){[store loadImagesAtIndex:0 completion:completion];}];
    window.rootViewController=[[UINavigationController alloc]initWithRootViewController:viewer];[window makeKeyAndVisible];
    Wait(^BOOL{return [viewer.dataSource numberOfPreviewItemsInPreviewController:viewer]==1;});
    [results addObject:@"PASS asynchronous message snapshots, bounded thumbnails, original-image loading and native preview"];

    NSCache *cache=[store valueForKey:@"_previewCache"];
    dispatch_queue_t queue=(dispatch_queue_t)[store valueForKey:@"_queue"];
    dispatch_semaphore_t release=dispatch_semaphore_create(0),entered=dispatch_semaphore_create(0);
    dispatch_async(queue,^{dispatch_semaphore_signal(entered);dispatch_semaphore_wait(release,dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC));});
    Check(dispatch_semaphore_wait(entered,dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC))==0,@"Message worker did not enter the blocked-I/O fixture");
    @try{
        [cache removeAllObjects];__block MUTextMessage *loaded=nil;
        store.messageDidLoad=^(NSInteger row,MUTextMessage *message){Check(row==0 && NSThread.isMainThread,@"Preview completion targets the wrong row/thread");loaded=message;};
        NSTimeInterval started=NSProcessInfo.processInfo.systemUptime;
        MUTextMessage *cold=[store messageAtIndex:0];
        Check(NSProcessInfo.processInfo.systemUptime-started<.5 && cold.embeddedImages.count==0 && cold.hasAttachments,@"A cold row blocks the UI on SQLite/image I/O");
        Check(fabs(Height(cold)-height)<.1,@"Evicting a thumbnail changes message height");
        dispatch_semaphore_signal(release);Wait(^BOOL{return loaded!=nil;});
        Check(loaded.embeddedImages.count==1 && fabs(Height(loaded)-height)<.1,@"Reloaded thumbnail changes message geometry");
    } @finally {dispatch_semaphore_signal(release);}

    release=dispatch_semaphore_create(0);entered=dispatch_semaphore_create(0);
    dispatch_async(queue,^{dispatch_semaphore_signal(entered);dispatch_semaphore_wait(release,dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC));});
    Check(dispatch_semaphore_wait(entered,dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC))==0,@"Prefetch fixture did not block I/O");
    @try{
        [cache removeAllObjects];__block BOOL loaded=NO;
        store.messageDidLoad=^(NSInteger row,MUTextMessage *message){loaded=YES;};
        [store prefetchMessagesAtIndexes:[NSIndexSet indexSetWithIndex:0]];
        [store cancelPrefetchAtIndexes:[NSIndexSet indexSetWithIndex:0]];
        Check([[store valueForKey:@"_previewRequests"]count]==0 && !loaded,@"Cancelled prefetch retains a pending preview request");
        [store prefetchMessagesAtIndexes:[NSIndexSet indexSetWithIndex:0]];
        [store messageAtIndex:0]; // A visible cell now owns this request.
        [store cancelPrefetchAtIndexes:[NSIndexSet indexSetWithIndex:0]];
        dispatch_semaphore_signal(release);Wait(^BOOL{return loaded;});
        Check([store messageAtIndex:0].embeddedImages.count==1,@"Cancelling prefetch discards a now-visible image");
    }@finally{dispatch_semaphore_signal(release);}
    [results addObject:@"PASS cancellable background thumbnail prefetch and promotion of visible rows"];

    release=dispatch_semaphore_create(0);entered=dispatch_semaphore_create(0);
    dispatch_async(queue,^{dispatch_semaphore_signal(entered);dispatch_semaphore_wait(release,dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC));});
    Check(dispatch_semaphore_wait(entered,dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC))==0,@"Message worker did not enter deletion fixture");
    @try{
        [cache removeAllObjects];__block BOOL stale=NO,drained=NO;
        store.messageDidLoad=^(NSInteger row,MUTextMessage *message){stale=YES;};
        [store messageAtIndex:0];[store clearMessageAtIndex:0];
        Check(store.count==1 && [store messageAtIndex:0]==nil,@"Deletion shifts message identities or waits on disk");
        dispatch_semaphore_signal(release);
        dispatch_async(queue,^{dispatch_async(dispatch_get_main_queue(),^{drained=YES;});});Wait(^BOOL{return drained;});
        Check(!stale,@"Deleted image reappears after an in-flight thumbnail load");
    } @finally {dispatch_semaphore_signal(release);}
    __block NSUInteger inserted=0;
    for(NSString *text in @[@"First",@"Second"])[store addMessage:[MLTextMessage messageWithPlainText:text] withHeading:@"Audit" andSentBySelf:NO completion:^{inserted++;}];
    Wait(^BOOL{return inserted==2;});
    Check(store.count==3 && [[store messageAtIndex:1].message isEqual:@"First"] && [[store messageAtIndex:2].message isEqual:@"Second"],@"Background storage reorders messages after deletion");
    [results addObject:@"PASS cold-row responsiveness, stable geometry, deletion races and FIFO message insertion"];

    MUMessagesViewController *conversation=[[MUMessagesViewController alloc]initWithServerModel:nil];
    [conversation loadViewIfNeeded];
    for(int i=0;i<3;i++)[conversation serverModel:nil textMessageReceived:[MLTextMessage messageWithPlainText:@"Early message"] fromUser:nil];
    window.rootViewController=[[UINavigationController alloc]initWithRootViewController:conversation];[window makeKeyAndVisible];
    MUMessagesDatabase *current=[conversation valueForKey:@"_msgdb"];
    Wait(^BOOL{return current.count==3;});UITableView *table=[conversation valueForKey:@"_tableView"];[conversation.view layoutIfNeeded];
    Check([table numberOfRowsInSection:0]==3,@"Messages received during initial layout create inconsistent row updates");
    [conversation serverModel:nil textMessageReceived:[MLTextMessage messageWithPlainText:@"Discard pending"] fromUser:nil];
    [conversation clearAllMessages];
    __block BOOL finished=NO;[current addMessage:[MLTextMessage messageWithPlainText:@"Barrier"] withHeading:@"Audit" andSentBySelf:NO completion:^{finished=YES;}];Wait(^BOOL{return finished;});
    Check([[conversation valueForKey:@"_msgdb"]count]==0 && [table numberOfRowsInSection:0]==0,@"Clearing history applies a completion from the old store");
    UITextView *composer=[conversation valueForKey:@"_textView"];composer.text=@"Keep this draft";
    [conversation setConnectionReconnecting:YES];[conversation sendMessage:nil];
    Check([composer.text isEqual:@"Keep this draft"] && ![(UIButton *)[conversation valueForKey:@"_sendButton"]isEnabled],@"Reconnecting sends or clears the draft");
    [conversation setValue:[MLUser new] forKey:@"_user"];
    [conversation resetRecipientAfterReconnect];
    Check([composer.text isEqual:@"Keep this draft"] && ![conversation valueForKey:@"_user"],@"Reconnection loses a draft or retains an old session's recipient");
    [results addObject:@"PASS early-message batch updates and clear-history generation guards"];
    [results addObject:@"PASS reconnect preserves drafts and clears recipients tied to an old session"];
    window.rootViewController=[UIViewController new];
}
