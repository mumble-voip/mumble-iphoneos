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
#import "ServerRootViewController.h"

#import "AboutDialog.h"

@implementation WelcomeScreenPhone

- (void)dealloc {
    [super dealloc];
}

- (void)viewDidLoad {
	[super viewDidLoad];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];

	self.navigationItem.title = @"Mumble";
	self.navigationController.toolbarHidden = YES;
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
}

/*
 * TableView
 */
- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
	return 3;
}

// Customize the number of rows in the table view.
- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0)
		return 4;
	if (section == 2)
		return 2;

	return 0;
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == 0)
		return @"Servers";
	if (section == 1)
		return @"Recent";
	if (section == 2)
		return @"Other";

	return @"Unknown";
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 35.0;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

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
		} else if (indexPath.row == 3) {
			cell.textLabel.text = @"Local Server";
		}

	/* 'Other' section. */
	} else if (indexPath.section == 2) {
		if (indexPath.row == 0) {
			cell.textLabel.text = @"Preferences";
		} else if (indexPath.row == 1) {
			cell.textLabel.text = @"About";
		}
	}

	[[cell textLabel] setHidden: NO];

	return cell;
}

// Override to support row selection in the table view.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

	/* Servers section. */
	if (indexPath.section == 0) {
		if (indexPath.row == 0) {
			PublicServerListController *serverList = [[[PublicServerListController alloc] init] autorelease];
			[self.navigationController pushViewController:serverList animated:YES];
		}
		else if (indexPath.row == 3) {
			ServerRootViewController *serverRoot = [[ServerRootViewController alloc] initWithHostname:@"mumble.sasquash.dk" port:64801];
			[self.navigationController presentModalViewController:serverRoot animated:YES];
		}
	}

	/* Other section. */
	if (indexPath.section == 2) {
		if (indexPath.row == 1) {
			[tableView deselectRowAtIndexPath:indexPath animated:YES];
			[AboutDialog show];
		}
	}
}

@end
