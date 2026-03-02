// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUApplicationDelegate.h"

#import "MUWelcomeScreenPhone.h"
#import "MUWelcomeScreenPad.h"
#import "MUOnboardingViewController.h"
#import "MUDatabase.h"
#import "MUPublicServerList.h"
#import "MUConnectionController.h"
#import "MUNotificationController.h"
#import "MURemoteControlServer.h"
#import "MUImage.h"
#import "MUBackgroundView.h"
#import "MUServerPlaceholderViewController.h"
#import "MUPreferencesViewController.h"
#import "MUCertificatePreferencesViewController.h"

#import <MumbleKit/MKAudio.h>
#import <MumbleKit/MKVersion.h>

@import UserNotifications;

@interface MUApplicationDelegate () <UIApplicationDelegate> {
    UIWindow                  *_window;
    UITabBarController        *_tabBarController;
    MUPublicServerListFetcher *_publistFetcher;
    BOOL                      _connectionActive;
}
- (void) setupAudio;
- (void) forceKeyboardLoad;
@end

@implementation MUApplicationDelegate

- (UITabBarController *) tabBarController {
    return _tabBarController;
}

- (BOOL) application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionOpened:) name:MUConnectionOpenedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionClosed:) name:MUConnectionClosedNotification object:nil];
    
    // Reset application badge, in case something brought it into an inconsistent state.
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    
    // Initialize the notification controller
    [MUNotificationController sharedController];
    
    // Request notification permissions
    [[UNUserNotificationCenter currentNotificationCenter]
        requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionBadge | UNAuthorizationOptionSound)
        completionHandler:^(BOOL granted, NSError *error) {
            // Permission prompt shown on first launch
        }];
    
    // Try to fetch an updated public server list
    _publistFetcher = [[MUPublicServerListFetcher alloc] init];
    [_publistFetcher attemptUpdate];
    
    // Set MumbleKit release string
    [[MKVersion sharedVersion] setOverrideReleaseString:
        [NSString stringWithFormat:@"Mumble for iOS %@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]]];
    
    // Enable Opus unconditionally
    [[MKVersion sharedVersion] setOpusEnabled:YES];

    // Register default settings
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                // Audio
                                                                [NSNumber numberWithFloat:1.0f],   @"AudioOutputVolume",
                                                                [NSNumber numberWithFloat:0.6f],   @"AudioVADAbove",
                                                                [NSNumber numberWithFloat:0.3f],   @"AudioVADBelow",
                                                                @"amplitude",                      @"AudioVADKind",
                                                                @"vad",                            @"AudioTransmitMethod",
                                                                [NSNumber numberWithBool:YES],     @"AudioPreprocessor",
                                                                [NSNumber numberWithBool:YES],     @"AudioEchoCancel",
                                                                [NSNumber numberWithFloat:1.0f],   @"AudioMicBoost",
                                                                @"balanced",                       @"AudioQualityKind",
                                                                [NSNumber numberWithBool:NO],      @"AudioSidetone",
                                                                [NSNumber numberWithFloat:0.2f],   @"AudioSidetoneVolume",
                                                                [NSNumber numberWithBool:YES],     @"AudioSpeakerPhoneMode",
                                                                [NSNumber numberWithBool:YES],     @"AudioOpusCodecForceCELTMode",
                                                                // Network
                                                                [NSNumber numberWithBool:NO],      @"NetworkForceTCP",
                                                                @"MumbleUser",                     @"DefaultUserName",
                                                                // Notifications
                                                                [NSNumber numberWithBool:YES],     @"NotificationsEnabled",
                                                        nil]];

    // Disable mixer debugging for all builds.
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:NO] forKey:@"AudioMixerDebug"];
    
    [self reloadPreferences];
    [MUDatabase initializeDatabase];
    
#ifdef ENABLE_REMOTE_CONTROL
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"RemoteControlServerEnabled"]) {
        [[MURemoteControlServer sharedRemoteControlServer] start];
    }
#endif
    
    // Try to use a dark keyboard throughout the app's text fields.
    if (@available(iOS 7, *)) {
        [[UITextField appearance] setKeyboardAppearance:UIKeyboardAppearanceDark];
    }
    
    _window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *navAppearance = [[UINavigationBarAppearance alloc] init];
        [navAppearance configureWithDefaultBackground];
        UINavigationBar.appearance.standardAppearance = navAppearance;
        UINavigationBar.appearance.scrollEdgeAppearance = navAppearance;
        UINavigationBar.appearance.tintColor = [UIColor systemBlueColor];
    } else {
        UINavigationBar.appearance.tintColor = [UIColor whiteColor];
        UINavigationBar.appearance.translucent = NO;
        UINavigationBar.appearance.barTintColor = [UIColor blackColor];
        UINavigationBar.appearance.backgroundColor = [UIColor blackColor];
        UINavigationBar.appearance.barStyle = UIBarStyleBlack;
    }

    // --- Tab 0: Home ---
    UIViewController *welcomeScreen = nil;
    UIUserInterfaceIdiom idiom = [[UIDevice currentDevice] userInterfaceIdiom];
    if (idiom == UIUserInterfaceIdiomPad) {
        welcomeScreen = [[MUWelcomeScreenPad alloc] init];
    } else {
        welcomeScreen = [[MUWelcomeScreenPhone alloc] init];
    }
    UINavigationController *homeNav = [[UINavigationController alloc] initWithRootViewController:welcomeScreen];
    homeNav.toolbarHidden = YES;
    if (@available(iOS 13.0, *)) {
        homeNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Home", nil)
                                                          image:[UIImage systemImageNamed:@"house.fill"]
                                                            tag:0];
    } else {
        homeNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Home", nil) image:nil tag:0];
    }

    // --- Tab 1: Server ---
    MUServerPlaceholderViewController *placeholder = [[MUServerPlaceholderViewController alloc] init];
    UINavigationController *serverNav = [[UINavigationController alloc] initWithRootViewController:placeholder];
    serverNav.toolbarHidden = YES;
    if (@available(iOS 13.0, *)) {
        serverNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Server", nil)
                                                            image:[UIImage systemImageNamed:@"server.rack"]
                                                              tag:1];
    } else {
        serverNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Server", nil) image:nil tag:1];
    }

    // --- Tab 2: My Profiles ---
    MUCertificatePreferencesViewController *profilesVC = [[MUCertificatePreferencesViewController alloc] init];
    UINavigationController *profilesNav = [[UINavigationController alloc] initWithRootViewController:profilesVC];
    profilesNav.toolbarHidden = YES;
    if (@available(iOS 13.0, *)) {
        profilesNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"My Profiles", nil)
                                                              image:[UIImage systemImageNamed:@"person.crop.circle"]
                                                                tag:2];
    } else {
        profilesNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"My Profiles", nil) image:nil tag:2];
    }

    // --- Tab 3: Settings ---
    MUPreferencesViewController *settingsVC = [[MUPreferencesViewController alloc] init];
    UINavigationController *settingsNav = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    settingsNav.toolbarHidden = YES;
    if (@available(iOS 13.0, *)) {
        settingsNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Settings", nil)
                                                              image:[UIImage systemImageNamed:@"gearshape"]
                                                                tag:3];
    } else {
        settingsNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Settings", nil) image:nil tag:3];
    }

    // --- Tab Bar Controller ---
    _tabBarController = [[UITabBarController alloc] init];
    _tabBarController.viewControllers = @[homeNav, serverNav, profilesNav, settingsNav];
    
    [_window setRootViewController:_tabBarController];
    [_window makeKeyAndVisible];

    // Show onboarding on first launch
    BOOL hasCompletedOnboarding = [[NSUserDefaults standardUserDefaults] boolForKey:@"HasCompletedOnboarding"];
    if (!hasCompletedOnboarding) {
        MUOnboardingViewController *onboarding = [[MUOnboardingViewController alloc] init];
        onboarding.modalPresentationStyle = UIModalPresentationFullScreen;
        onboarding.completionHandler = ^{
            [self->_tabBarController dismissViewControllerAnimated:YES completion:nil];
        };
        [_tabBarController presentViewController:onboarding animated:NO completion:nil];
    }

    NSURL *url = [launchOptions objectForKey:UIApplicationLaunchOptionsURLKey];
    if ([[url scheme] isEqualToString:@"mumble"]) {
        MUConnectionController *connController = [MUConnectionController sharedController];
        NSString *hostname = [url host];
        NSNumber *port = [url port];
        NSString *username = [url user];
        NSString *password = [url password];
        [connController connetToHostname:hostname port:port ? [port integerValue] : 64738 withUsername:username andPassword:password withParentViewController:welcomeScreen];
        return YES;
    }
    return NO;
}

- (BOOL) application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    if ([[url scheme] isEqualToString:@"mumble"]) {
        MUConnectionController *connController = [MUConnectionController sharedController];
        if ([connController isConnected]) {
            return NO;
        }
        NSString *hostname = [url host];
        NSNumber *port = [url port];
        NSString *username = [url user];
        NSString *password = [url password];
        // Present from the Home tab's visible view controller
        UINavigationController *homeNav = (UINavigationController *)_tabBarController.viewControllers[0];
        [connController connetToHostname:hostname port:port ? [port integerValue] : 64738 withUsername:username andPassword:password withParentViewController:homeNav.visibleViewController];
        return YES;
    }
    return NO;
}

- (void) applicationWillTerminate:(UIApplication *)application {
    [MUDatabase teardown];
}

- (void) setupAudio {
    // Set up a good set of default audio settings.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    MKAudioSettings settings;

    if ([[defaults stringForKey:@"AudioTransmitMethod"] isEqualToString:@"vad"])
        settings.transmitType = MKTransmitTypeVAD;
    else if ([[defaults stringForKey:@"AudioTransmitMethod"] isEqualToString:@"continuous"])
        settings.transmitType = MKTransmitTypeContinuous;
    else if ([[defaults stringForKey:@"AudioTransmitMethod"] isEqualToString:@"ptt"])
        settings.transmitType = MKTransmitTypeToggle;
    else
        settings.transmitType = MKTransmitTypeVAD;
    
    settings.vadKind = MKVADKindAmplitude;
    if ([[defaults stringForKey:@"AudioVADKind"] isEqualToString:@"snr"]) {
        settings.vadKind = MKVADKindSignalToNoise;
    } else if ([[defaults stringForKey:@"AudioVADKind"] isEqualToString:@"amplitude"]) {
        settings.vadKind = MKVADKindAmplitude;
    }
    
    settings.vadMin = [defaults floatForKey:@"AudioVADBelow"];
    settings.vadMax = [defaults floatForKey:@"AudioVADAbove"];
    
    NSString *quality = [defaults stringForKey:@"AudioQualityKind"];
    if ([quality isEqualToString:@"low"]) {
        settings.codec = MKCodecFormatOpus;
        settings.quality = 16000;
        settings.audioPerPacket = 6;
    } else if ([quality isEqualToString:@"balanced"]) {
        settings.codec = MKCodecFormatOpus;
        settings.quality = 40000;
        settings.audioPerPacket = 2;
    } else if ([quality isEqualToString:@"high"] || [quality isEqualToString:@"opus"]) {
        settings.codec = MKCodecFormatOpus;
        settings.quality = 72000;
        settings.audioPerPacket = 1;
    } else {
        settings.codec = MKCodecFormatCELT;
        if ([[defaults stringForKey:@"AudioCodec"] isEqualToString:@"opus"])
            settings.codec = MKCodecFormatOpus;
        if ([[defaults stringForKey:@"AudioCodec"] isEqualToString:@"celt"])
            settings.codec = MKCodecFormatCELT;
        if ([[defaults stringForKey:@"AudioCodec"] isEqualToString:@"speex"])
            settings.codec = MKCodecFormatSpeex;
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
    if (settings.enablePreprocessor) {
        settings.enableEchoCancellation = [defaults boolForKey:@"AudioEchoCancel"];
    } else {
        settings.enableEchoCancellation = NO;
    }

    settings.enableSideTone = [defaults boolForKey:@"AudioSidetone"];
    settings.sidetoneVolume = [defaults floatForKey:@"AudioSidetoneVolume"];
    
    if ([defaults boolForKey:@"AudioSpeakerPhoneMode"]) {
        settings.preferReceiverOverSpeaker = NO;
    } else {
        settings.preferReceiverOverSpeaker = YES;
    }
    
    settings.opusForceCELTMode = [defaults boolForKey:@"AudioOpusCodecForceCELTMode"];
    settings.audioMixerDebug = [defaults boolForKey:@"AudioMixerDebug"];
    
    MKAudio *audio = [MKAudio sharedAudio];
    [audio updateAudioSettings:&settings];
    [audio restart];
}

// Reload application preferences...
- (void) reloadPreferences {
    [self setupAudio];
}

- (void) forceKeyboardLoad {
    UITextField *textField = [[UITextField alloc] initWithFrame:CGRectZero];
    [_window addSubview:textField];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [textField becomeFirstResponder];
}

- (void) keyboardWillShow:(NSNotification *)notification {
    for (UIView *view in [_window subviews]) {
        if ([view isFirstResponder]) {
            [view resignFirstResponder];
            [view removeFromSuperview];
            
            [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
        }
    }
}

- (void) connectionOpened:(NSNotification *)notification {
    _connectionActive = YES;
}

- (void) connectionClosed:(NSNotification *)notification {
    _connectionActive = NO;
}

- (void) applicationWillResignActive:(UIApplication *)application {
    if (!_connectionActive) {
        NSLog(@"MumbleApplicationDelegate: Not connected to a server. Stopping MKAudio.");
        [[MKAudio sharedAudio] stop];
        
#ifdef ENABLE_REMOTE_CONTROL
        [[MURemoteControlServer sharedRemoteControlServer] stop];
#endif
    }
}

- (void) applicationDidBecomeActive:(UIApplication *)application {
    if (![[MKAudio sharedAudio] isRunning]) {
        NSLog(@"MumbleApplicationDelegate: MKAudio not running. Starting it.");
        [[MKAudio sharedAudio] start];
        
#if ENABLE_REMOTE_CONTROL
        [[MURemoteControlServer sharedRemoteControlServer] stop];
        [[MURemoteControlServer sharedRemoteControlServer] start];
#endif
    }
}

@end
