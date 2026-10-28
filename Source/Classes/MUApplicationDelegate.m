// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUApplicationDelegate.h"

#import "MUWelcomeScreenPhone.h"
#import "MUInterface.h"
#import "MUAppMenuViewController.h"
#import "MUOnboardingViewController.h"
#import "MUDatabase.h"
#import "MUCredentialStore.h"
#import "MUPublicServerList.h"
#import "MUConnectionController.h"
#import "MUNotificationController.h"
#import "MLClient.h"
#import <UserNotifications/UserNotifications.h>

static NSInteger MUApplicationBadgeCount = 0;
NSNotificationName const MUAudioTransmissionModeDidChangeNotification = @"MUAudioTransmissionModeDidChangeNotification";

@interface MUApplicationDelegate () <UIApplicationDelegate, UITabBarControllerDelegate, UINavigationControllerDelegate> {
    UIWindow                  *_window;
    UINavigationController    *_navigationController;
    UINavigationController    *_settingsNavigationController;
    UITabBarController        *_tabBarController;
    MUPublicServerListFetcher *_publistFetcher;
    BOOL                      _connectionActive;
    UINavigationController    *_onboardingNavigationController;
    NSURL                     *_pendingMumbleURL;
}
- (void) setupAudio;
@end

@implementation MUApplicationDelegate

+ (void) setApplicationBadgeCount:(NSInteger)count {
    if (count < 0) {
        count = 0;
    }
    MUApplicationBadgeCount = count;
    [[UNUserNotificationCenter currentNotificationCenter] setBadgeCount:count withCompletionHandler:nil];
}

+ (void) incrementApplicationBadgeCount {
    [self setApplicationBadgeCount:MUApplicationBadgeCount + 1];
}

- (BOOL) application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)application;
    (void)launchOptions;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(connectionStateChanged:) name:MUConnectionStateDidChangeNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(credentialStorageFailed:) name:MUCredentialStorageDidFailNotification object:nil];
    
    [MUNotificationController sharedController];
    
    // Set libmumble release string
    [[MLVersion sharedVersion] setOverrideReleaseString:
        [NSString stringWithFormat:@"Mumble for iOS %@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]]];
    
    // Enable Opus unconditionally

    // Register default settings
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                // Audio
                                                                [NSNumber numberWithFloat:1.0f],   @"AudioOutputVolume",
                                                                [NSNumber numberWithFloat:0.6f],   @"AudioVADAbove",
                                                                [NSNumber numberWithFloat:0.3f],   @"AudioVADBelow",
                                                                @"amplitude",                      @"AudioVADKind",
                                                                @"vad",                            @"AudioTransmitMethod",
                                                                [NSNumber numberWithBool:YES],     @"AudioPreprocessor",
                                                                [NSNumber numberWithFloat:1.0f],   @"AudioMicBoost",
                                                                @"balanced",                       @"AudioQualityKind",
                                                                [NSNumber numberWithBool:NO],      @"AudioSidetone",
                                                                [NSNumber numberWithFloat:0.2f],   @"AudioSidetoneVolume",
                                                                [NSNumber numberWithBool:YES],     @"AudioSpeakerPhoneMode",
                                                                [NSNumber numberWithBool:NO],      @"AudioOpusLowDelay",
                                                                // Network
                                                                [NSNumber numberWithBool:NO],      @"NetworkForceTCP",
                                                                @"MumbleUser",                     @"DefaultUserName",
                                                        nil]];

    
    
    return YES;
}
    
- (void) installUserInterfaceInWindow:(UIWindow *)window {
    _window = window;

    UIViewController *welcomeScreen = [MUWelcomeScreenPhone new];
    _navigationController = [[UINavigationController alloc] initWithRootViewController:welcomeScreen];
    _navigationController.navigationBar.prefersLargeTitles = YES;
    _navigationController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Home", nil)
        image:[UIImage systemImageNamed:@"house"] selectedImage:[UIImage systemImageNamed:@"house.fill"]];

    _settingsNavigationController = [[UINavigationController alloc] initWithRootViewController:[MUAppMenuViewController new]];
    _settingsNavigationController.delegate = self;
    _settingsNavigationController.navigationBar.prefersLargeTitles = YES;
    _settingsNavigationController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Settings", nil)
        image:[UIImage systemImageNamed:@"gearshape"] selectedImage:[UIImage systemImageNamed:@"gearshape.fill"]];

    _tabBarController = [UITabBarController new];
    _tabBarController.delegate = self;
    _tabBarController.viewControllers = @[_navigationController, _settingsNavigationController];
    NSString *databasePath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"mumble.sqlite"];
    BOOL needsSetup = [MUOnboardingViewController shouldPresentForDefaults:NSUserDefaults.standardUserDefaults hasExistingInstallation:[NSFileManager.defaultManager fileExistsAtPath:databasePath]];
    if (needsSetup) {
        __weak MUApplicationDelegate *weakSelf = self;
        MUOnboardingViewController *setup = [[MUOnboardingViewController alloc] initWithCompletion:^{
            MUApplicationDelegate *delegate = weakSelf;
            if (!delegate) return;
            delegate->_window.rootViewController = delegate->_tabBarController;
            delegate->_onboardingNavigationController = nil;
            [delegate reloadPreferences];
            NSURL *pendingURL = delegate->_pendingMumbleURL;
            delegate->_pendingMumbleURL = nil;
            if (pendingURL) [delegate openMumbleURL:pendingURL];
        }];
        _onboardingNavigationController = [[UINavigationController alloc] initWithRootViewController:setup];
        _window.rootViewController = _onboardingNavigationController;
    } else {
        _window.rootViewController = _tabBarController;
    }
    [_window makeKeyAndVisible];

    // Database, badge and the public-server refresh are not needed to draw
    // the first screen. Doing them here keeps them off the launch path.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        [MUDatabase initializeDatabase];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self->_publistFetcher == nil) {
                self->_publistFetcher = [[MUPublicServerListFetcher alloc] init];
                [self->_publistFetcher attemptUpdate];
            }
        });
    });
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (navigationController != _settingsNavigationController) return;
    BOOL isRoot = viewController == navigationController.viewControllers.firstObject;
    if (isRoot) MUApplyRootLargeTitle(viewController);
    else viewController.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 270000
    if (@available(iOS 27.0, *)) {
        UIBarMinimization *minimization = viewController.navigationItem.navigationBarMinimization;
        minimization.minimizationBehavior = isRoot ? UIBarMinimizationBehaviorAutomatic : UIBarMinimizationBehaviorNever;
        viewController.navigationItem.navigationBarMinimization = minimization;
    }
#endif
}

- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
    // A tab switch can leave a settings detail page whose root is already offscreen.
    if (viewController == _navigationController) [self reloadPreferences];
}

- (BOOL) openMumbleURL:(NSURL *)url {
    if (![[url scheme] isEqualToString:@"mumble"]) {
        return NO;
    }
    if (_onboardingNavigationController) {
        _pendingMumbleURL = url;
        return YES;
    }
    MUConnectionController *connController = [MUConnectionController sharedController];
    if (connController.hasActiveSession || connController.hasPendingConnection) {
        return NO;
    }
    NSString *hostname = [url host];
    NSNumber *port = [url port];
    NSString *username = [url user];
    NSString *password = [url password];
    _tabBarController.selectedViewController = _navigationController;
    [self reloadPreferences];
    UIViewController *parent = _navigationController.visibleViewController;
    if (parent == nil) {
        parent = _navigationController;
    }
    [connController connectToHostname:hostname port:port ? [port integerValue] : 64738 withUsername:username andPassword:password withParentViewController:parent];
    return YES;
}

- (void) setupAudio {
    // Set up a good set of default audio settings.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    MLAudioSettings settings = {0};

    if ([[defaults stringForKey:@"AudioTransmitMethod"] isEqualToString:@"vad"])
        settings.transmitType = MLTransmitTypeVAD;
    else if ([[defaults stringForKey:@"AudioTransmitMethod"] isEqualToString:@"continuous"])
        settings.transmitType = MLTransmitTypeContinuous;
    else if ([[defaults stringForKey:@"AudioTransmitMethod"] isEqualToString:@"ptt"])
        settings.transmitType = MLTransmitTypeToggle;
    else
        settings.transmitType = MLTransmitTypeVAD;
    
    settings.vadKind = MLVADKindAmplitude;
    if ([[defaults stringForKey:@"AudioVADKind"] isEqualToString:@"snr"]) {
        settings.vadKind = MLVADKindSignalToNoise;
    } else if ([[defaults stringForKey:@"AudioVADKind"] isEqualToString:@"amplitude"]) {
        settings.vadKind = MLVADKindAmplitude;
    }
    
    settings.vadMin = [defaults floatForKey:@"AudioVADBelow"];
    settings.vadMax = [defaults floatForKey:@"AudioVADAbove"];
    
    NSString *quality = [defaults stringForKey:@"AudioQualityKind"];
    if ([quality isEqualToString:@"low"]) {

        settings.quality = 16000;
        settings.audioPerPacket = 6;
    } else if ([quality isEqualToString:@"balanced"]) {

        settings.quality = 40000;
        settings.audioPerPacket = 2;
    } else if ([quality isEqualToString:@"high"] || [quality isEqualToString:@"opus"]) {

        settings.quality = 72000;
        settings.audioPerPacket = 1;
    } else {

        settings.quality = (int) [defaults integerForKey:@"AudioQualityBitrate"];
        settings.audioPerPacket = (int) [defaults integerForKey:@"AudioQualityFrames"];
    }
    
    settings.noiseSuppression = -42; /* -42 dB */
    settings.amplification = 20.0f;
    settings.jitterBufferSize = 0; /* 10 ms */
    settings.volume = [defaults floatForKey:@"AudioOutputVolume"];
    settings.outputDelay = 0; /* 10 ms */
    settings.micBoost = [defaults floatForKey:@"AudioMicBoost"];
    settings.enablePreprocessor = [defaults boolForKey:@"AudioPreprocessor"];
    settings.enableEchoCancellation = settings.enablePreprocessor;

    settings.enableSideTone = [defaults boolForKey:@"AudioSidetone"];
    settings.sidetoneVolume = [defaults floatForKey:@"AudioSidetoneVolume"];
    
    if ([defaults boolForKey:@"AudioSpeakerPhoneMode"]) {
        settings.preferReceiverOverSpeaker = NO;
    } else {
        settings.preferReceiverOverSpeaker = YES;
    }
    
    settings.opusForceCELTMode = [defaults boolForKey:@"AudioOpusLowDelay"];
    
    MLAudio *audio = [MLAudio sharedAudio];
    [audio updateAudioSettings:&settings];

}

// Reload application preferences...
- (void) reloadPreferences {
    [self setupAudio];
}

- (void)setAudioTransmitMethod:(NSString *)method {
    NSArray<NSString *> *methods = @[@"vad", @"ptt", @"continuous"];
    NSUInteger index = [methods indexOfObject:method];
    if (index == NSNotFound) return;
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if ([[defaults stringForKey:@"AudioTransmitMethod"] isEqualToString:method]) return;
    [defaults setObject:method forKey:@"AudioTransmitMethod"];
    MLAudio *audio = MLAudio.sharedAudio;
    [audio setForceTransmit:NO];
    MLAudioSettings settings;
    [audio readAudioSettings:&settings];
    settings.transmitType = index == 0 ? MLTransmitTypeVAD : index == 1 ? MLTransmitTypeToggle : MLTransmitTypeContinuous;
    // Transmission is evaluated for every audio packet; switching it does not
    // require rebuilding the microphone or interrupting server playback.
    [audio updateAudioSettings:&settings];
    [NSNotificationCenter.defaultCenter postNotificationName:MUAudioTransmissionModeDidChangeNotification object:self];
}


- (void)credentialStorageFailed:(NSNotification *)notification {
    if(_window.rootViewController)[MUNotificationController.sharedController addNotification:NSLocalizedString(@"The credentials could not be saved securely. Please try again.", nil) fromViewController:_window.rootViewController];
}

- (void)connectionStateChanged:(NSNotification *)notification {
    BOOL active=[(MUConnectionController *)notification.object hasActiveSession];
    if(active==_connectionActive)return;
    _connectionActive=active;
    if(active){[self reloadPreferences];[MLAudio.sharedAudio start];[MLAudio.sharedAudio resumeIfNeeded];}
    else [MLAudio.sharedAudio stop];
}

- (void) sceneWillResignActive {
    // If we have any active connections, don't stop MLAudio. This is
    // for 'clicking-the-home-button' invocations of this method.
    //
    // In case we've been backgrounded by a phone call, MLAudio will
    // already have shut itself down.
    if (!_connectionActive) {
        NSLog(@"MumbleApplicationDelegate: Not connected to a server. Stopping MLAudio.");
        [[MLAudio sharedAudio] stop];
        
    }
}

- (void) sceneDidBecomeActive {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{[MUDatabase migrateLegacyCredentials];});
    // It is possible that we will become active after a phone call has ended.
    // In the case of phone calls, MLAudio will automatically stop itself, to
    // allow the phone call to go through. However, once we're back inside the
    // application, we have to start ourselves again.
    //
    // For regular backgrounding, we usually don't turn off the audio system, and
    // we won't have to start it again. Don't start it just because the app
    // became active; that pulls up the microphone before the user connects.
    if (_connectionActive) {
        MLAudio *audio = MLAudio.sharedAudio;
        if (!audio.isRunning) {
            NSLog(@"MumbleApplicationDelegate: MLAudio not running. Starting it.");
            [self reloadPreferences];
            [audio start];
        }
        // Engine.isRunning does not prove the microphone tap is delivering PCM.
        [audio resumeIfNeeded];
        
    } else {
        // A visible calibration meter also owns a foreground capture preview.
        [MLAudio.sharedAudio resumeIfNeeded];
    }
}

@end
