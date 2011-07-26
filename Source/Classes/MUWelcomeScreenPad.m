/* Copyright (C) 2009-2011 Mikkel Krautz <mikkel@krautz.dk>
 
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

#import "MUWelcomeScreenPad.h"

#import "MUPublicServerListController.h"
#import "MUFavouriteServerListController.h"
#import "MULanServerListController.h"
#import "MUPreferencesViewController.h"
#import "MUServerRootViewController.h"
#import "MUAboutViewController.h"


@interface MUWelcomeScreenPad (Private)
- (void) presentAboutDialog;
@end

@implementation MUWelcomeScreenPad

- (id) init {
	self = [super initWithNibName:@"WelcomeScreenPad" bundle:nil];
	if (self == nil)
		return nil;
    
	return self;
}

- (void) dealloc {
    [super dealloc];
}

- (void) viewDidLoad {
	[super viewDidLoad];
}

- (void) viewWillAppear:(BOOL)animated {
	self.navigationItem.title = @"Mumble";
	self.navigationController.toolbarHidden = YES;
	
	UIBarButtonItem *about = [[UIBarButtonItem alloc] initWithTitle:@"About" style:UIBarButtonItemStyleBordered target:self action:@selector(aboutClicked:)];
	[self.navigationItem setRightBarButtonItem:about];
	[about release];
	
	UIBarButtonItem *prefs = [[UIBarButtonItem alloc] initWithTitle:@"Preferences" style:UIBarButtonItemStyleBordered target:self action:@selector(prefsClicked:)];
	[self.navigationItem setLeftBarButtonItem:prefs];
	[prefs release];
}

- (void) didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

#pragma mark -
#pragma mark TableView

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

// Customize the number of rows in the table view.
- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0)
		return 3;
	return 0;
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == 0)
		return @"Servers";
    
	return @"Unknown";
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 35.0;
}

// Customize the appearance of table view cells.
- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"welcomeItem"];
	if (!cell) {
		cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"welcomeItem"] autorelease];
	}
    
	/* Servers section. */
	if (indexPath.section == 0) {
		if (indexPath.row == 0) {
			cell.textLabel.text = @"Public";
		} else if (indexPath.row == 1) {
			cell.textLabel.text = @"Favourites";
		} else if (indexPath.row == 2) {
			cell.textLabel.text = @"LAN";
		}
	}
    
	[[cell textLabel] setHidden: NO];
    
	return cell;
}

// Override to support row selection in the table view.
- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
    
	/* Servers section. */
	if (indexPath.section == 0) {
		if (indexPath.row == 0) {
			MUPublicServerListController *serverList = [[[MUPublicServerListController alloc] init] autorelease];
			[self.navigationController pushViewController:serverList animated:YES];
		} else if (indexPath.row == 1) {
			MUFavouriteServerListController *favList = [[[MUFavouriteServerListController alloc] init] autorelease];
			[self.navigationController pushViewController:favList animated:YES];
		} else if (indexPath.row == 2) {
			MULanServerListController *lanList = [[[MULanServerListController alloc] init] autorelease];
			[self.navigationController pushViewController:lanList animated:YES];
		}
	}
}

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
	if (_preferencesPopover != nil)
		return;

	MUPreferencesViewController *prefs = [[[MUPreferencesViewController alloc] init] autorelease];
	UINavigationController *nav = [[[UINavigationController alloc] initWithRootViewController:prefs] autorelease];
	[nav setContentSizeForViewInPopover:CGSizeMake(320, 480)];
	UIPopoverController *popover = [[UIPopoverController alloc] initWithContentViewController:nav];
	[popover setDelegate:self];
	[popover presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionUp animated:YES];

	_preferencesPopover = popover;
}

#pragma mark -
#pragma mark About Dialog

- (void) alertView:(UIAlertView *)alert didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if (buttonIndex == 1) {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.mumble.info/"]];
	} else if (buttonIndex ==  2) { 
		MUAboutViewController *contribView = [[MUAboutViewController alloc] initWithContent:@"Contributors"];
		UINavigationController *navController = [[UINavigationController alloc] init];
		[navController pushViewController:contribView animated:NO];
		[contribView release];
		[[self navigationController] presentModalViewController:navController animated:YES];
		[navController release];
	} else if (buttonIndex == 3) {
		MUAboutViewController *legalView = [[MUAboutViewController alloc] initWithContent:@"Legal"];
		UINavigationController *navController = [[UINavigationController alloc] init];
		[navController pushViewController:legalView animated:NO];
		[legalView release];
		[[self navigationController] presentModalViewController:navController animated:YES];
		[navController release];
	}
}

#pragma mark -
#pragma mark UIPopoverControllerDelegate

- (void) popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
	if (popoverController == _preferencesPopover) {
		[_preferencesPopover release];
		_preferencesPopover = nil;
	}
}

@end
