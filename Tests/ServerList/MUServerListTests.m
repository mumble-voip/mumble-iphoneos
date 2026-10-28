// Injected only into the isolated Simulator app by test-server-list.sh.
#import <UIKit/UIKit.h>
#import "MUServerViewController.h"

@interface MLServerModel (ServerListTests)
- (void)receiveType:(uint16_t)type data:(NSData *)data;
- (void)reset;
- (void)setTalkState:(MLTalkState)state forSession:(NSUInteger)session;
@end
@interface MUServerViewController (ServerListTests)
- (void)rebuildModelArrayFromChannel:(MLChannel *)channel;
- (NSInteger)indexForUser:(MLUser *)user;
@end
@interface MUServerListTestController : MUServerViewController
@property(nonatomic) NSUInteger rebuildCount;
@end
@implementation MUServerListTestController
- (void)rebuildModelArrayFromChannel:(MLChannel *)channel {
    self.rebuildCount++;
    [super rebuildModelArrayFromChannel:channel];
}
@end

static NSMutableArray<NSString *> *results;
static void Check(BOOL condition, NSString *message) {
    if (!condition) @throw [NSException exceptionWithName:@"ServerListTestFailure" reason:message userInfo:nil];
}
static void Drain(void) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:.1];
    while (deadline.timeIntervalSinceNow > 0)
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]];
}
// Minimal protobuf wire fields exercise the real parser and delegate ordering.
// Field numbers and TCP types follow Dependencies/libmumble/src/proto/MumbleTCP.proto.
static void Varint(NSMutableData *data, uint64_t value) {
    do { uint8_t byte = value & 0x7f; value >>= 7; if (value) byte |= 0x80; [data appendBytes:&byte length:1]; } while (value);
}
static NSData *Fields(NSDictionary<NSNumber *, id> *fields) {
    NSMutableData *data = [NSMutableData data];
    for (NSNumber *field in [fields.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        id value = fields[field];
        if ([value isKindOfClass:NSString.class]) {
            NSData *text = [value dataUsingEncoding:NSUTF8StringEncoding];
            Varint(data, (field.unsignedIntegerValue << 3) | 2); Varint(data, text.length); [data appendData:text];
        } else {
            Varint(data, field.unsignedIntegerValue << 3); Varint(data, [value unsignedLongLongValue]);
        }
    }
    return data;
}
static void Receive(MLServerModel *model, uint16_t type, NSDictionary *fields) { [model receiveType:type data:Fields(fields)]; }
static void CheckRows(MUServerListTestController *server, NSInteger expected) {
    [server.tableView layoutIfNeeded];
    NSInteger actual = [server.tableView numberOfRowsInSection:0];
    Check(actual == expected, [NSString stringWithFormat:@"Expected %ld channel rows, got %ld (rebuilds: %lu, visible: %@)", (long)expected, (long)actual, (unsigned long)server.rebuildCount, server.view.window ? @"yes" : @"no"]);
}

static void ServerListChecks(UIWindow *window) {
    MLServerModel *model = [[MLServerModel alloc] initWithConnection:nil];
    MUServerListTestController *server = [[MUServerListTestController alloc] initWithServerModel:model];
    // The old implementation created a zero-frame table and inserted one row
    // even though the initial tree contained both Root and the new user.
    Receive(model, 9, @{@1:@10, @3:@"Alice", @5:@0});
    Check(!server.isViewLoaded, @"Initial user state prematurely loads the table");
    Receive(model, 7, @{@1:@1, @2:@0, @3:@"Channel"});
    Receive(model, 9, @{@1:@10, @5:@1});
    Receive(model, 5, @{@1:@10});
    Check(!server.isViewLoaded && server.rebuildCount == 0, @"Initial channel/sync callbacks prematurely load the table");
    [results addObject:@"PASS user/channel initialization and server sync before presentation"];

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:server];
    window.rootViewController = nav; [window makeKeyAndVisible]; Drain(); CheckRows(server, 3);
    UIView *header = server.tableView.tableHeaderView;
    Check(header.bounds.size.height > 44, @"Server summary begins with a zero height");
    CGFloat normalHeight = header.bounds.size.height;
    server.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;
    Drain(); [server.view layoutIfNeeded];
    Check(header.bounds.size.height > normalHeight, @"Server summary does not grow with accessibility text size");
    for (NSString *key in @[@"_serverNameLabel", @"_channelTitleLabel", @"_channelMetaLabel"]) {
        UILabel *label = [server valueForKey:key];
        CGRect rect = [label convertRect:label.bounds toView:header];
        Check(CGRectGetMinY(rect) >= 15 && CGRectGetMaxY(rect) <= header.bounds.size.height - 15, @"Server summary clips a label inside its margins");
    }
    server.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryLarge;
    Drain(); [server.view layoutIfNeeded];
    [results addObject:@"PASS initial server header height and accessibility-size summary margins"];
    NSUInteger before = server.rebuildCount;
    // A user can arrive before the referenced channel's parent/name state.
    Receive(model, 9, @{@1:@11, @3:@"Bob", @5:@99});
    Receive(model, 7, @{@1:@99, @2:@0, @3:@"Late channel"});
    Receive(model, 7, @{@1:@2, @2:@1, @3:@"Nested"});
    Receive(model, 9, @{@1:@12, @3:@"Carol", @5:@2});
    Drain(); CheckRows(server, 7);
    Check(server.rebuildCount == before + 1, @"Protocol burst causes redundant full list refreshes");
    Check([server indexForUser:[model userWithSession:12]] != NSNotFound, @"New user's row is missing");
    [results addObject:@"PASS coalesced channel/user bursts and out-of-order channel state"];

    Receive(model, 9, @{@1:@10, @5:@2}); Drain(); CheckRows(server, 7);
    Check([[(UILabel *)[server valueForKey:@"_channelTitleLabel"] text] isEqual:@"Nested"], @"Current channel summary fails after a move");
    Receive(model, 9, @{@1:@12, @3:@"AAA"});
    Receive(model, 7, @{@1:@99, @9:@1}); Drain();
    Check([server indexForUser:[model userWithSession:12]] < [server indexForUser:[model userWithSession:10]], @"Renamed users are not sorted");
    before = server.rebuildCount;
    [model setTalkState:MLTalkStateTalking forSession:10];
    Receive(model, 9, @{@1:@10, @9:@1});
    UITableViewCell *cell = [server.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:[server indexForUser:model.connectedUser] inSection:0]];
    Check([((UIListContentConfiguration *)cell.contentConfiguration).secondaryText containsString:@"Microphone muted"], @"Mute state does not update the visible cell");
    Check(server.rebuildCount == before, @"Talk/mute changes rebuild the channel tree");
    Receive(model, 8, @{@1:@12}); Drain(); CheckRows(server, 6);
    Receive(model, 6, @{@1:@1}); Drain(); CheckRows(server, 5);
    Receive(model, 6, @{@1:@2}); Drain(); CheckRows(server, 4);
    Check(model.connectedUser.channel == model.rootChannel, @"Removing an occupied channel loses its user");
    [results addObject:@"PASS channel moves, renames, user departure, subtree removal and direct status updates"];

    UIViewController *otherPage = [UIViewController new];
    [nav setViewControllers:@[otherPage] animated:NO]; Drain(); before = server.rebuildCount;
    Receive(model, 7, @{@1:@3, @2:@0, @3:@"Offscreen"});
    Receive(model, 9, @{@1:@13, @3:@"Daniel", @5:@3});
    Receive(model, 8, @{@1:@11}); Drain();
    Check(server.rebuildCount == before, @"Hidden server page refreshes its table");
    [nav setViewControllers:@[server] animated:NO]; Drain(); CheckRows(server, 5);
    Check([server indexForUser:[model userWithSession:13]] != NSNotFound, @"Returning to the server page leaves a stale snapshot");
    Receive(model, 9, @{@1:@14, @3:@"Eve", @5:@0});
    [nav setViewControllers:@[otherPage] animated:NO]; Drain();
    [nav setViewControllers:@[server] animated:NO]; Drain(); CheckRows(server, 6);
    [results addObject:@"PASS offscreen updates and disappearance with a pending refresh"];

    [model reset];
    Receive(model, 7, @{@1:@4, @2:@0, @3:@"Reconnected"});
    Receive(model, 9, @{@1:@20, @3:@"New user", @5:@4});
    Receive(model, 5, @{@1:@20}); Drain(); CheckRows(server, 3);
    Check([[(UILabel *)[server valueForKey:@"_channelTitleLabel"] text] isEqual:@"Reconnected"], @"Reconnect retains old channel state");
    [results addObject:@"PASS reconnect replaces the previous tree"];
    [nav setViewControllers:@[otherPage] animated:NO];
}

static void Run(void) {
    results = [NSMutableArray array];
    @try {
        UIWindowScene *scene = (id)UIApplication.sharedApplication.connectedScenes.allObjects.firstObject;
        UIWindow *window = [(id)scene.delegate valueForKey:@"window"];
        ServerListChecks(window); [results addObject:@"ALL SERVER LIST TESTS PASSED"];
    } @catch (NSException *error) { [results addObject:[NSString stringWithFormat:@"FAIL %@", error.reason]]; }
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"server-list-results.txt"];
    [[results componentsJoinedByString:@"\n"] writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}
__attribute__((constructor)) static void Schedule(void) {
    dispatch_async(dispatch_get_main_queue(), ^{ [NSTimer scheduledTimerWithTimeInterval:1 repeats:NO block:^(NSTimer *timer) { Run(); }]; });
}
