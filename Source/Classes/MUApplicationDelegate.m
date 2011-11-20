/* Copyright (C) 2009-2010 Mikkel Krautz <mikkel@krautz.dk>

   All rights reserved.

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions
   are met:

   - Redistributions of source code must retain the above copyright notice,
     this list of conditions and the following disclaimer.
   - Redistributions in binary form must reproduce the above copyright notice,
     this list of conditions and the following disclaimer in the documentation
     and/or other materials provided with the distribution.
   - Neither the name of the Mumble Developers nor the names of its
     contributors may be used to endorse or promote products derived from this
     software without specific prior written permission.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
   ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
   A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR
   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "MUApplicationDelegate.h"

#import "MUApplication.h"
#import "MUWelcomeScreenPhone.h"
#import "MUWelcomeScreenPad.h"
#import "MUDatabase.h"

#import <MumbleKit/MKAudio.h>
#import <MumbleKit/MKConnectionController.h>

@interface MUApplicationDelegate () {
    UIWindow                  *window;
    UINavigationController    *navigationController;
    NSDate                    *_launchDate;
#ifdef MUMBLE_BETA_DIST
    MUVersionChecker          *_verCheck;
#endif
}
- (void) setupAudio;
#ifdef MUMBLE_BETA_DIST
- (void) notifyCrash;
#endif
@end

@implementation MUApplicationDelegate

@synthesize window;
@synthesize navigationController;

#ifdef MUMBLE_BETA_DIST
- (void) notifyCrash {
    if ([MumbleApp didCrashRecently]) {
        NSString *title = @"Beta Crash Reporting";
        NSString *msg = @"Mumble has detected that it has recently crashed.\n\n"
        "Don't forget to report your crashes to the beta portal using the crash reporting tool.\n";
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alertView show];
        [alertView release];
        
        [MumbleApp resetCrashCount];
    }
}
#endif

- (void) applicationDidFinishLaunching:(UIApplication *)application {
    _launchDate = [[NSDate alloc] init];

    [window makeKeyAndVisible];

    // Register default settings
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                // Audio
                                                                [NSNumber numberWithFloat:1.0f],   @"AudioOutputVolume",
                                                                @"vad",                            @"AudioTransmitMethod",
                                                                // Network
                                                                [NSNumber numberWithBool:NO],      @"NetworkForceTCP",
                                                             nil]];
    
    [self reloadPreferences];
    [MUDatabase initializeDatabase];

    self.navigationController.toolbarHidden = YES;
    [window addSubview:[navigationController view]];

    UIUserInterfaceIdiom idiom = [[UIDevice currentDevice] userInterfaceIdiom];
    if (idiom == UIUserInterfaceIdiomPad) {
        MUWelcomeScreenPad *welcomeScreen = [[MUWelcomeScreenPad alloc] init];
        [navigationController pushViewController:welcomeScreen animated:YES];
        [welcomeScreen release];
    } else {
        MUWelcomeScreenPhone *welcomeScreen = [[MUWelcomeScreenPhone alloc] init];
        [navigationController pushViewController:welcomeScreen animated:YES];
        [welcomeScreen release];
    }

#ifdef MUMBLE_BETA_DIST
    [self notifyCrash];
#endif
}

- (void) applicationWillTerminate:(UIApplication *)application {
    [MUDatabase teardown];
}

- (void) dealloc {
#ifdef MUMBLE_BETA_DIST
    [_verCheck release];
#endif
    [_launchDate release];
    [navigationController release];
    [window release];
    [super dealloc];
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
    settings.codec = MKCodecFormatCELT;
    settings.quality = 24000;
    settings.audioPerPacket = 10;
    settings.noiseSuppression = -42; /* -42 dB */
    settings.amplification = 20.0f;
    settings.jitterBufferSize = 0; /* 10 ms */
    settings.volume = [defaults floatForKey:@"AudioOutputVolume"];
    settings.outputDelay = 0; /* 10 ms */
    settings.enablePreprocessor = YES;
    settings.enableBenchmark = YES;

    MKAudio *audio = [MKAudio sharedAudio];
    [audio updateAudioSettings:&settings];
    [audio restart];
}

// Reload application preferences...
- (void) reloadPreferences {
    [self setupAudio];
}

// Time since we launched
- (NSTimeInterval) timeIntervalSinceLaunch {
    return [[NSDate date] timeIntervalSinceDate:_launchDate];
}

- (void) applicationWillResignActive:(UIApplication *)application {
    // If we have any active connections, don't stop MKAudio. This is
    // for 'clicking-the-home-button' invocations of this method.
    //
    // In case we've been backgrounded by a phone call, MKAudio will
    // already have shut itself down.
    NSArray *connections = [[MKConnectionController sharedController] allConnections];
    if ([connections count] == 0) {
        NSLog(@"MumbleApplicationDelegate: Not connected to a server. Stopping MKAudio.");
        [[MKAudio sharedAudio] stop];
    }
}

- (void) applicationDidBecomeActive:(UIApplication *)application {
    // It is possible that we will become active after a phone call has ended.
    // In the case of phone calls, MKAudio will automatically stop itself, to
    // allow the phone call to go through. However, once we're back inside the
    // application, we have to start ourselves again.
    //
    // For regular backgrounding, we usually don't turn off the audio system, and
    // we won't have to start it again.
    if (![[MKAudio sharedAudio] isRunning]) {
        NSLog(@"MumbleApplicationDelegate: MKAudio not running. Starting it.");
        [[MKAudio sharedAudio] start];
    }
}

@end
