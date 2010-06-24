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

#import "AppDelegate.h"

#import "WelcomeScreenPhone.h"
#import "WelcomeScreenPad.h"
#import "Database.h"

#import <MumbleKit/MKAudio.h>

@interface AppDelegate (Private)
 - (void) setupAudio;
@end

@implementation AppDelegate

@synthesize window;
@synthesize navigationController;

- (void) applicationDidFinishLaunching:(UIApplication *)application {
	_launchDate = [[NSDate alloc] init];

	[window addSubview:[navigationController view]];
	[window makeKeyAndVisible];

	[self reloadPreferences];
	[Database initializeDatabase];

	// If we're running on anything below OS 3.2, UIDevice does not
	// respond to the userInterfaceIdiom method. We must assume we're
	// running on an iPhone or iPod Touch.
	UIDevice *device = [UIDevice currentDevice];
	UIUserInterfaceIdiom idiom = UIUserInterfaceIdiomPhone;
	if ([device respondsToSelector:@selector(userInterfaceIdiom)]) {
		idiom = [[UIDevice currentDevice] userInterfaceIdiom];
	}

	if (idiom == UIUserInterfaceIdiomPad) {
		NSLog(@"iPad detected.");
		WelcomeScreenPad *welcomeScreen = [[WelcomeScreenPad alloc] initWithNibName:@"WelcomeScreenPad" bundle:nil];
		[navigationController pushViewController:welcomeScreen animated:YES];
		[welcomeScreen release];
	} else if (idiom == UIUserInterfaceIdiomPhone) {
		NSLog(@"iPhone detected.");
		WelcomeScreenPhone *welcomeScreen = [[WelcomeScreenPhone alloc] init];
		[navigationController pushViewController:welcomeScreen animated:YES];
		[welcomeScreen release];
	}
}

- (void) applicationWillTerminate:(UIApplication *)application {
	[Database teardown];
}

- (void) dealloc {
	[_launchDate release];
	[navigationController release];
	[window release];
	[super dealloc];
}

- (void) setupAudio {
	// Set up a good set of default audio settings.
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	MKAudioSettings settings;
	settings.inputCodec = MKCodecFormatCELT;
	settings.outputCodec = MKCodecFormatCELT;
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

@end
