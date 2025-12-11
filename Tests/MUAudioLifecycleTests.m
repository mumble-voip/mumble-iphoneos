#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import <TargetConditionals.h>

#if __has_include(<MumbleKit/MKAudio.h>)
#import <MumbleKit/MKAudio.h>
#else
// Minimal stubs to allow the tests to compile in environments where
// the real MumbleKit headers are not available (such as CI runners).
// These stubs are non-functional and only exist for compilation.
// Actual testing uses the mock (MUMockAudio) created via method swizzling.
typedef NS_ENUM(NSInteger, MKTransmitType) {
    MKTransmitTypeVAD = 0,
    MKTransmitTypeToggle = 1,
    MKTransmitTypeContinuous = 2,
};

@interface MKAudio : NSObject
@property (nonatomic) MKTransmitType transmitType;
+ (instancetype)sharedAudio;
- (void)start;
- (void)stop;
- (BOOL)isRunning;
- (void)setForceTransmit:(BOOL)force;
- (BOOL)forceTransmit;
@end

@implementation MKAudio
static MKAudio *_mkAudioShared;
+ (instancetype)sharedAudio {
    if (_mkAudioShared == nil) {
        _mkAudioShared = [[MKAudio alloc] init];
    }
    return _mkAudioShared;
}
- (void)start {}
- (void)stop {}
- (BOOL)isRunning { return NO; }
- (void)setForceTransmit:(BOOL)force {}
- (BOOL)forceTransmit { return NO; }
@end
#endif

#if __has_include(<MumbleKit/MKServerModel.h>)
#import "MUServerViewController.h"
#else
@interface MKServerModel : NSObject
- (void)addDelegate:(id)delegate;
- (void)removeDelegate:(id)delegate;
@end

#if TARGET_OS_IPHONE
@interface MUServerViewController : UITableViewController
- (id)initWithServerModel:(MKServerModel *)serverModel;
- (void)talkOn:(UIButton *)button;
- (void)talkOff:(UIButton *)button;
- (void)appDidEnterBackground:(NSNotification *)notification;
@end
#endif // TARGET_OS_IPHONE
#endif // __has_include(<MumbleKit/MKServerModel.h>)

#import "MUApplicationDelegate.h"
#import "MUConnectionController.h"

@interface MUMockAudio : NSObject
@property (nonatomic) BOOL running;
@property (nonatomic) BOOL forceTransmitState;
@property (nonatomic) MKTransmitType transmitType;
@property (nonatomic) NSInteger startCallCount;
@property (nonatomic) NSInteger stopCallCount;
@end

@implementation MUMockAudio
- (void)start {
    self.startCallCount += 1;
    self.running = YES;
}

- (void)stop {
    self.stopCallCount += 1;
    self.running = NO;
}

- (BOOL)isRunning {
    return self.running;
}

- (void)setForceTransmit:(BOOL)forceTransmit {
    self.forceTransmitState = forceTransmit;
}

- (BOOL)forceTransmit {
    return self.forceTransmitState;
}
@end

static IMP OriginalSharedAudioImp;
static MUMockAudio *CurrentMockAudio;

static id MUSharedAudioReplacement(id self, SEL _cmd) {
    return CurrentMockAudio;
}

@interface MUTestServerModel : MKServerModel
@end

@implementation MUTestServerModel
- (void)addDelegate:(id)delegate {}
- (void)removeDelegate:(id)delegate {}
@end

@interface MUAudioLifecycleTest : XCTestCase
@end

@implementation MUAudioLifecycleTest

- (void)setUp {
    [super setUp];
    CurrentMockAudio = [[MUMockAudio alloc] init];
    [self installMockAudio];
}

- (void)tearDown {
    [self uninstallMockAudio];
    CurrentMockAudio = nil;
    [super tearDown];
}

- (void)installMockAudio {
    Class audioClass = objc_getClass("MKAudio");
    Method sharedAudioMethod = class_getClassMethod(audioClass, @selector(sharedAudio));
    if (sharedAudioMethod == NULL) {
        class_addMethod(object_getClass(audioClass), @selector(sharedAudio), (IMP)MUSharedAudioReplacement, "@@:");
        sharedAudioMethod = class_getClassMethod(audioClass, @selector(sharedAudio));
    }
    if (OriginalSharedAudioImp == NULL && sharedAudioMethod != NULL) {
        OriginalSharedAudioImp = method_getImplementation(sharedAudioMethod);
    }
    if (sharedAudioMethod != NULL) {
        method_setImplementation(sharedAudioMethod, (IMP)MUSharedAudioReplacement);
    }
}

- (void)uninstallMockAudio {
    Class audioClass = objc_getClass("MKAudio");
    Method sharedAudioMethod = class_getClassMethod(audioClass, @selector(sharedAudio));
    if (sharedAudioMethod != NULL && OriginalSharedAudioImp != NULL) {
        method_setImplementation(sharedAudioMethod, OriginalSharedAudioImp);
        OriginalSharedAudioImp = NULL;
    }
}

- (void)testPushToTalkTogglesForceTransmitState {
#if TARGET_OS_IPHONE
    MUTestServerModel *serverModel = [[MUTestServerModel alloc] init];
    MUServerViewController *controller = [[MUServerViewController alloc] initWithServerModel:serverModel];

    [controller talkOn:nil];
    XCTAssertTrue(CurrentMockAudio.forceTransmitState);

    [controller talkOff:nil];
    XCTAssertFalse(CurrentMockAudio.forceTransmitState);

    [controller appDidEnterBackground:nil];
    XCTAssertFalse(CurrentMockAudio.forceTransmitState);
#else
    XCTSkip(@"Push-to-talk tests require UIKit to be available.");
#endif
}

- (void)testApplicationStopsAudioWhenBackgroundedWithoutConnection {
    MUApplicationDelegate *delegate = [[MUApplicationDelegate alloc] init];
    CurrentMockAudio.running = YES;
    [delegate applicationWillResignActive:nil];
    XCTAssertEqual(CurrentMockAudio.stopCallCount, 1);
    XCTAssertEqual(CurrentMockAudio.startCallCount, 0);
}

- (void)testApplicationKeepsAudioRunningWhileConnected {
    MUApplicationDelegate *delegate = [[MUApplicationDelegate alloc] init];
    
    // Set up the notification observers that would normally be initialized
    // in application:didFinishLaunchingWithOptions:
    [[NSNotificationCenter defaultCenter] addObserver:delegate 
                                             selector:@selector(connectionOpened:) 
                                                 name:MUConnectionOpenedNotification 
                                               object:nil];
    
    // Simulate a connection opening by posting the notification
    // (Note: NSNotificationCenter delivers notifications synchronously, so the
    // connectionOpened: method will be called before this line returns)
    [[NSNotificationCenter defaultCenter] postNotificationName:MUConnectionOpenedNotification object:nil];
    
    CurrentMockAudio.running = YES;
    [delegate applicationWillResignActive:nil];
    XCTAssertEqual(CurrentMockAudio.stopCallCount, 0);
    
    // Clean up the observer to avoid side effects
    [[NSNotificationCenter defaultCenter] removeObserver:delegate 
                                                    name:MUConnectionOpenedNotification 
                                                  object:nil];
}

- (void)testApplicationRestartsAudioAfterInterruption {
    MUApplicationDelegate *delegate = [[MUApplicationDelegate alloc] init];
    CurrentMockAudio.running = NO;
    [delegate applicationDidBecomeActive:nil];
    XCTAssertEqual(CurrentMockAudio.startCallCount, 1);
}

- (void)testApplicationDoesNotRestartWhenAlreadyRunning {
    MUApplicationDelegate *delegate = [[MUApplicationDelegate alloc] init];
    CurrentMockAudio.running = YES;
    [delegate applicationDidBecomeActive:nil];
    XCTAssertEqual(CurrentMockAudio.startCallCount, 0);
}

@end

