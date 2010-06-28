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

#import "WelcomeScreenPhone.h"

#import "PublicServerListController.h"
#import "FavouriteServerListController.h"
#import "LanServerListController.h"
#import "DiagnosticsViewController.h"
#import "PreferencesViewController.h"
#import "IdentityViewController.h"
#import "ServerRootViewController.h"
#import "AboutViewController.h"


@interface WelcomeScreenPhone (Private)
- (void) presentAboutDialog;
@end


@implementation WelcomeScreenPhone

- (id) init {
	self = [super initWithNibName:@"WelcomeScreenPhone" bundle:nil];
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

- (void) viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];

	self.navigationItem.title = @"Mumble";
	self.navigationController.toolbarHidden = YES;
}

- (void) didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
}

#pragma mark -
#pragma mark TableView

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
	return 2;
}

// Customize the number of rows in the table view.
- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0)
		return 3;
	if (section == 1)
		return 4;

	return 0;
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == 0)
		return @"Servers";
	if (section == 1)
		return @"Other";

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
	/* 'Other' section. */
	} else if (indexPath.section == 1) {
		if (indexPath.row == 0) {
			cell.textLabel.text = @"Preferences";
		} else if (indexPath.row == 1) {
			cell.textLabel.text = @"Identities";
		} else if (indexPath.row == 2) {
			cell.textLabel.text = @"Diagnostics";
		} else if (indexPath.row == 3) {
			cell.textLabel.text = @"About";
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
			PublicServerListController *serverList = [[[PublicServerListController alloc] init] autorelease];
			[self.navigationController pushViewController:serverList animated:YES];
		} else if (indexPath.row == 1) {
			FavouriteServerListController *favList = [[[FavouriteServerListController alloc] init] autorelease];
			[self.navigationController pushViewController:favList animated:YES];
		} else if (indexPath.row == 2) {
			LanServerListController *lanList = [[[LanServerListController alloc] init] autorelease];
			[self.navigationController pushViewController:lanList animated:YES];
		}
	}

	/* Other section. */
	if (indexPath.section == 1) {
		if (indexPath.row == 0) { // Preferences
			PreferencesViewController *preferences = [[PreferencesViewController alloc] init];
			[[self navigationController] pushViewController:preferences animated:YES];
			[preferences release];
		} else if (indexPath.row == 1) { // Identities
			IdentityViewController *ident = [[IdentityViewController alloc] init];
			//CertificateViewController *ident = [[CertificateViewController alloc] init];
			//IdentitiesTabBarController *ident = [[IdentitiesTabBarController alloc] init];
			[[self navigationController] pushViewController:ident animated:YES];
			[ident release];
		} else if (indexPath.row == 2) { // Diagnostics
			DiagnosticsViewController *diag = [[DiagnosticsViewController alloc] init];
			[[self navigationController] pushViewController:diag animated:YES];
			[diag release];
		} else if (indexPath.row == 3) { // About
			[self presentAboutDialog];
		}
	}
}

#pragma mark -
#pragma mark About Dialog

- (void) presentAboutDialog {
	NSString *aboutTitle = [NSString stringWithFormat:@"Mumble %@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
	NSString *aboutMessage = @"Low-latency, high-quality VoIP app";

	_aboutView = [[UIAlertView alloc] initWithTitle:aboutTitle message:aboutMessage delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
	_aboutWebsiteButton = [_aboutView addButtonWithTitle:@"Website"];
	_aboutContribButton = [_aboutView addButtonWithTitle:@"Contributors"];
	_aboutLegalButton = [_aboutView addButtonWithTitle:@"Legal"];
	[_aboutView show];
	[_aboutView release];
}

- (void) alertView:(UIAlertView *)alert didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if (buttonIndex == _aboutWebsiteButton) {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.mumble.info/"]];
	} else if (buttonIndex == _aboutContribButton) {
		AboutViewController *contribView = [[AboutViewController alloc] initWithContent:@"Contributors"];
		UINavigationController *navController = [[UINavigationController alloc] init];
		[navController pushViewController:contribView animated:NO];
		[contribView release];
		[[self navigationController] presentModalViewController:navController animated:YES];
		[navController release];
	} else if (buttonIndex == _aboutLegalButton) {
		AboutViewController *legalView = [[AboutViewController alloc] initWithContent:@"Legal"];
		UINavigationController *navController = [[UINavigationController alloc] init];
		[navController pushViewController:legalView animated:NO];
		[legalView release];
		[[self navigationController] presentModalViewController:navController animated:YES];
		[navController release];
	}
}

@end
