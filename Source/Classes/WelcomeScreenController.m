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

#import <Three20/Three20.h> // force Xcode to syntax highlight
#import "WelcomeScreenController.h"

#import "PublicServerListController.h"
#import "FavouriteServerListController.h"
#import "LanServerListController.h"
#import "PreferencesViewController.h"
#import "ServerRootViewController.h"
#import "AboutViewController.h"

@implementation WelcomeScreenController

- (void) viewWillAppear:(BOOL)animated {
	self.navigationItem.title = @"Mumble";

	TTLauncherItem *item;
	item = [[TTLauncherItem alloc] initWithTitle:@"Public Servers"
										   image:@"bundle://globe.png" 
											 URL:@"mumbleapp://public"];
	[_launcherView addItem:item animated:YES];

	item = [[TTLauncherItem alloc] initWithTitle:@"Favourite Servers"
										   image:@"bundle://star.png"
											 URL:@"mumbleapp://favourite"];
	[_launcherView addItem:item animated:YES];

	item = [[TTLauncherItem alloc] initWithTitle:@"LAN Servers"
										   image:@"bundle://cloud.png"
											 URL:@"mumbleapp://lan"];
	[_launcherView addItem:item animated:YES];

	[_launcherView setDelegate:self];

	UIBarButtonItem *about = [[UIBarButtonItem alloc] initWithTitle:@"About" style:UIBarButtonItemStyleBordered target:self action:@selector(aboutClicked:)];
	[self.navigationItem setRightBarButtonItem:about];
	[about release];
	
	UIBarButtonItem *prefs = [[UIBarButtonItem alloc] initWithTitle:@"Preferences" style:UIBarButtonItemStyleBordered target:self action:@selector(prefsClicked:)];
	[self.navigationItem setLeftBarButtonItem:prefs];
	[prefs release];
}

- (void) loadView {
	UIScreen *screen = [UIScreen mainScreen];
	_launcherView = [[TTLauncherView alloc] initWithFrame:[screen applicationFrame]];
	_launcherView.backgroundColor = [UIColor groupTableViewBackgroundColor];
	self.view = _launcherView;
	[_launcherView release];
}

- (void) viewDidLoad {
	[super viewDidLoad];
	self.view.autoresizesSubviews = YES;
	self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
}

- (void) viewDidUnload {
    [super viewDidUnload];
}

#pragma mark -
#pragma mark TTLauncherView delegate

- (void) launcherView:(TTLauncherView *)launcherView didSelectItem:(TTLauncherItem *)item {
	UIViewController *controller = nil;
	if ([[item URL] isEqualToString:@"mumbleapp://public"]) {
		controller = [[PublicServerListController alloc] init];
	} else if ([[item URL] isEqualToString:@"mumbleapp://favourite"]) {
		controller = [[FavouriteServerListController alloc] init];
	} else if ([[item URL] isEqualToString:@"mumbleapp://lan"]) {
		controller = [[LanServerListController alloc] init];
	}

	if (controller) {
		[[self navigationController] pushViewController:controller animated:YES];
		[controller release];
	}
}


- (void) launcherViewDidBeginEditing:(TTLauncherView *)launcher {
	UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneEditingClicked:)];
	[self setToolbarItems:[NSArray arrayWithObjects:flexSpace, doneButton, flexSpace, nil]];
	[self.navigationController setToolbarHidden:NO animated:YES];
	[doneButton release];
	[flexSpace release];
}

- (void) launcherViewDidEndEditing:(TTLauncherView *)launcher {
	[self.navigationController setToolbarHidden:YES animated:YES];
}

#pragma mark -
#pragma mark Actions

- (void) aboutClicked:(id)sender {
#ifdef MUMBLE_BETA_DIST
	NSString *aboutTitle = [NSString stringWithFormat:@"Mumble %@ (%@)",
							[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"],
							[[NSBundle mainBundle] objectForInfoDictionaryKey:@"MumbleGitRevision"]];
#else
	NSString *aboutTitle = [NSString stringWithFormat:@"Mumble %@",
							[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
#endif
	NSString *aboutMessage = @"Low-latency, high-quality VoIP app";
	
	UIAlertView *aboutView = [[UIAlertView alloc] initWithTitle:aboutTitle message:aboutMessage delegate:self
											  cancelButtonTitle:@"OK"
											  otherButtonTitles:@"Website", @"Contributors", @"Legal", nil];
	[aboutView show];
	[aboutView release];
}

- (void) prefsClicked:(id)sender {
	PreferencesViewController *prefs = [[[PreferencesViewController alloc] init] autorelease];
	[self.navigationController pushViewController:prefs animated:YES];
}

- (void) doneEditingClicked:(id)sender {
	[_launcherView endEditing];
}

#pragma mark -
#pragma mark About Dialog

- (void) alertView:(UIAlertView *)alert didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if (buttonIndex == 1) {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.mumble.info/"]];
	} else if (buttonIndex ==  2) { 
		AboutViewController *contribView = [[AboutViewController alloc] initWithContent:@"Contributors"];
		UINavigationController *navController = [[UINavigationController alloc] init];
		[navController pushViewController:contribView animated:NO];
		[contribView release];
		[[self navigationController] presentModalViewController:navController animated:YES];
		[navController release];
	} else if (buttonIndex == 3) {
		AboutViewController *legalView = [[AboutViewController alloc] initWithContent:@"Legal"];
		UINavigationController *navController = [[UINavigationController alloc] init];
		[navController pushViewController:legalView animated:NO];
		[legalView release];
		[[self navigationController] presentModalViewController:navController animated:YES];
		[navController release];
	}
}

@end
