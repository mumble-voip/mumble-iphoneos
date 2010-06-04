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

#import <MumbleKit/MKAudio.h>

@implementation AppDelegate

@synthesize window;
@synthesize navigationController;

- (void) applicationDidFinishLaunching:(UIApplication *)application {
	[window addSubview:[navigationController view]];
	[window makeKeyAndVisible];

#if defined(__IPHONE_3_2)
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
		WelcomeScreenPhone *welcomeScreen = [[WelcomeScreenPhone alloc] initWithNibName:@"WelcomeScreenPhone" bundle:nil];
		[navigationController pushViewController:welcomeScreen animated:YES];
		[welcomeScreen release];
	}
#else
	WelcomeScreenPhone *welcomeScreen = [[WelcomeScreenPhone alloc] initWithNibName:@"WelcomeScreenPhone" bundle:nil];
	[navigationController pushViewController:welcomeScreen animated:YES];
	[welcomeScreen release];
#endif

	[MKAudio initializeAudio];
}

- (void)applicationWillTerminate:(UIApplication *)application {
}

- (void)dealloc {
	[navigationController release];
	[window release];
	[super dealloc];
}

@end
