// Copyright 2012 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUWelcomeScreenPad.h"
#import "MUPreferencesViewController.h"
#import "MULegalViewController.h"
#import "MUPopoverBackgroundView.h"
#import "MUPublicServerListController.h"
#import "MUFavouriteServerListController.h"
#import "MULanServerListController.h"

@interface MUWelcomeScreenPad () <UIPopoverControllerDelegate> {
    UIPopoverController   *_prefsPopover;
    IBOutlet UITableView  *_tableView;
}
@end

@implementation MUWelcomeScreenPad

- (id) init {
    if ((self = [super init])) {
    }
    return self;
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return UIInterfaceOrientationIsLandscape(interfaceOrientation);
}

- (void) viewDidLoad {
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.opaque = NO;
    _tableView.backgroundView = nil;
    _tableView.scrollEnabled = NO;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone; // doesn't work?
}

- (void) viewWillAppear:(BOOL)animated {
    self.navigationItem.title = @"Mumble";
    
    UIBarButtonItem *aboutBtn = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"About", nil) style:UIBarButtonItemStyleBordered target:self action:@selector(aboutButtonClicked:)];
    self.navigationItem.rightBarButtonItem = aboutBtn;
    [aboutBtn release];
    
    UIBarButtonItem *prefsBtn = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Preferences", nil) style:UIBarButtonItemStyleBordered target:self action:@selector(prefsButtonClicked:)];
    self.navigationItem.leftBarButtonItem = prefsBtn;
    [prefsBtn release];
    
    [_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:animated];
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

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0;
}

// Customize the appearance of table view cells.
- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"welcomeItem"];
    if (!cell) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"welcomeItem"] autorelease];
    }
    
    cell.selectionStyle = UITableViewCellSelectionStyleGray;
    
    /* Servers section. */
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = NSLocalizedString(@"Public Servers", nil);
        } else if (indexPath.row == 1) {
            cell.textLabel.text = NSLocalizedString(@"Favourite Servers", nil);
        } else if (indexPath.row == 2) {
            cell.textLabel.text = NSLocalizedString(@"LAN Servers", nil);
        }
    }
    
    [[cell textLabel] setHidden: NO];
    
    return cell;
}

// Override to support row selection in the table view.
- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
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

#pragma mark -
#pragma mark About Dialog

- (void) alertView:(UIAlertView *)alert didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.mumbleapp.com/"]];
    } else if (buttonIndex == 2) {
        MULegalViewController *legalView = [[MULegalViewController alloc] init];
        UINavigationController *navController = [[UINavigationController alloc] init];
        [navController pushViewController:legalView animated:NO];
        [legalView release];
        [[self navigationController] presentModalViewController:navController animated:YES];
        [navController release];
    } else if (buttonIndex == 3) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"mailto:support@mumbleapp.com"]];
    }
}

#pragma mark - Actions

- (void) aboutButtonClicked:(id)sender {
#ifdef MUMBLE_BETA_DIST
    NSString *aboutTitle = [NSString stringWithFormat:@"Mumble %@ (%@)",
                            [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"],
                            [[NSBundle mainBundle] objectForInfoDictionaryKey:@"MumbleGitRevision"]];
#else
    NSString *aboutTitle = [NSString stringWithFormat:@"Mumble %@",
                            [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
#endif
    NSString *aboutMessage = NSLocalizedString(@"Low latency, high quality voice chat", nil);
    
    UIAlertView *aboutView = [[UIAlertView alloc] initWithTitle:aboutTitle message:aboutMessage delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                              otherButtonTitles:NSLocalizedString(@"Website", nil),
                              NSLocalizedString(@"Legal", nil),
                              NSLocalizedString(@"Support", nil), nil];
    [aboutView show];
    [aboutView release];
}

- (void) prefsButtonClicked:(id)sender {
    if (_prefsPopover != nil) {
        return;
    }
    
    MUPreferencesViewController *prefs = [[[MUPreferencesViewController alloc] init] autorelease];
    UINavigationController *navCtrl = [[[UINavigationController alloc] initWithRootViewController:prefs] autorelease];
    UIPopoverController *popOver = [[UIPopoverController alloc] initWithContentViewController:navCtrl];
    popOver.popoverBackgroundViewClass = [MUPopoverBackgroundView class];
    [popOver setDelegate:self];
    [popOver presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionUp animated:YES];
    
    _prefsPopover = popOver;
}

#pragma mark - UIPopoverControllerDelegate

- (void) popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    if (popoverController == _prefsPopover) {
        [_prefsPopover release];
        _prefsPopover = nil;
    }
}

@end
