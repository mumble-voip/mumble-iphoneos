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

#import "MumbleApplicationDelegate.h"

#import "MumbleApplication.h"
#import "WelcomeScreenPhone.h"
#import "WelcomeScreenPad.h"
#import "WelcomeScreenController.h"
#import "Database.h"

#import "MumbleStyleSheet.h"

#import <MumbleKit/MKAudio.h>
#import <MumbleKit/MKConnectionController.h>

@interface MumbleApplicationDelegate (Private)
- (void) setupAudio;
- (void) notifyCrash;
@end

@implementation MumbleApplicationDelegate

@synthesize window;
@synthesize navigationController;

- (void) applicationDidFinishLaunching:(UIApplication *)application {
	_launchDate = [[NSDate alloc] init];

	UIUserInterfaceIdiom idiom = [[UIDevice currentDevice] userInterfaceIdiom];
	[window makeKeyAndVisible];

	[self reloadPreferences];
	[Database initializeDatabase];
	[TTDefaultStyleSheet setGlobalStyleSheet:[[[MumbleStyleSheet alloc] init] autorelease]];

	self.navigationController.toolbarHidden = YES;
	[window addSubview:[navigationController view]];

	// Create a fake splash screen that we can animate to give us
	// a pretty fade-in launch...
	UIScreen *screen = [UIScreen mainScreen];
	UIImageView *imageView = [[UIImageView alloc] initWithFrame:[screen applicationFrame]];
	[imageView setImage:[UIImage imageNamed:@"Splash.png"]];
	[window addSubview:imageView];

#if 1
	self.navigationController.view.autoresizesSubviews = YES;

	WelcomeScreenController *welcomeScreen = [[WelcomeScreenController alloc] init];
	[navigationController pushViewController:welcomeScreen animated:NO];
	[welcomeScreen release];

#else
	if (idiom == UIUserInterfaceIdiomPad) {
		NSLog(@"UIUserInterfaceIdiomPad detected.");
		WelcomeScreenPad *welcomeScreen = [[WelcomeScreenPad alloc] initWithNibName:@"WelcomeScreenPad" bundle:nil];
		[navigationController pushViewController:welcomeScreen animated:YES];
		[welcomeScreen release];
	} else if (idiom == UIUserInterfaceIdiomPhone) {
		NSLog(@"UIUserInterfaceIdiomPhone detected.");
		WelcomeScreenPhone *welcomeScreen = [[WelcomeScreenPhone alloc] init];
		[navigationController pushViewController:welcomeScreen animated:YES];
		[welcomeScreen release];
	}
#endif
	
	[UIView animateWithDuration:0.8f animations:^{
		imageView.alpha = 0.0f;
	} completion:^(BOOL finished){
		[imageView removeFromSuperview];
		[imageView release];

		[self notifyCrash];
		_verCheck = [[VersionChecker alloc] init];
	}];	
}

- (void) applicationWillTerminate:(UIApplication *)application {
	[Database teardown];
}

- (void) dealloc {
	[_verCheck release];
	[_launchDate release];
	[navigationController release];
	[window release];
	[super dealloc];
}

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

- (void) setupAudio {
	// Set up a good set of default audio settings.
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	MKAudioSettings settings;
	settings.codec = MKCodecFormatCELT;
	settings.quality = 24000;
	settings.audioPerPacket = 10;
	settings.noiseSuppression = -42; /* -42 dB */
	settings.amplification = 20.0f;
	settings.jitterBufferSize = 0; /* 10 ms */
	settings.volume = [defaults floatForKey:@"AudioOutputVolume"];
	settings.outputDelay = 0; /* 10 ms */
	settings.enablePreprocessor = [defaults boolForKey:@"AudioInputPreprocessor"];
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
