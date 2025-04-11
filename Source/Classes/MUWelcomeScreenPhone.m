// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUWelcomeScreenPhone.h"

#import "MUPublicServerListController.h"
#import "MUFavouriteServerListController.h"
#import "MULanServerListController.h"
#import "MUPreferencesViewController.h"
#import "MUServerRootViewController.h"
#import "MUNotificationController.h"
#import "MULegalViewController.h"
#import "MUImage.h"
#import "MUOperatingSystem.h"
#import "MUBackgroundView.h"

@interface MUWelcomeScreenPhone () {
    NSInteger    _aboutWebsiteButton;
    NSInteger    _aboutContribButton;
    NSInteger    _aboutLegalButton;
}
@end

#define MUMBLE_LAUNCH_IMAGE_CREATION 0

@implementation MUWelcomeScreenPhone

- (id) init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        // ...
    }
    return self;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.navigationItem.title = @"Mumble";
    self.navigationController.toolbarHidden = YES;

    UINavigationBar *navBar = self.navigationController.navigationBar;
    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        navBar.tintColor = [UIColor whiteColor];
        navBar.translucent = NO;
        navBar.backgroundColor = [UIColor blackColor];
    }
    navBar.barStyle = UIBarStyleBlackOpaque;

    self.tableView.backgroundView = [MUBackgroundView backgroundView];
    
    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        self.tableView.separatorInset = UIEdgeInsetsZero;
    } else {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    }

    self.tableView.scrollEnabled = NO;
    
#if MUMBLE_LAUNCH_IMAGE_CREATION != 1
    UIBarButtonItem *about = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"About", nil)
                                                              style:UIBarButtonItemStylePlain
                                                             target:self
                                                             action:@selector(aboutClicked:)];
    [self.navigationItem setRightBarButtonItem:about];
    
    UIBarButtonItem *prefs = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Preferences", nil)
                                                              style:UIBarButtonItemStylePlain
                                                             target:self
                                                             action:@selector(prefsClicked:)];
    [self.navigationItem setLeftBarButtonItem:prefs];
#endif
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return toInterfaceOrientation == UIInterfaceOrientationPortrait;
}

#pragma mark -
#pragma mark TableView

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// Customize the number of rows in the table view.
- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
#if MUMBLE_LAUNCH_IMAGE_CREATION == 1
    return 1;
#endif
    if (section == 0)
        return 3;
    return 0;
}

- (UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIImage *img = [MUImage imageNamed:@"WelcomeScreenIcon"];
    UIImageView *imgView = [[UIImageView alloc] initWithImage:img];
    [imgView setContentMode:UIViewContentModeCenter];
    [imgView setFrame:CGRectMake(0, 0, img.size.width, img.size.height)];
    return imgView;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
#if MUMBLE_LAUNCH_IMAGE_CREATION == 1
    CGFloat statusBarAndTitleBarHeight = 64;
    return [UIScreen mainScreen].bounds.size.height - statusBarAndTitleBarHeight;
#endif
    UIImage *img = [MUImage imageNamed:@"WelcomeScreenIcon"];
    return img.size.height;
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0;
}

// Customize the appearance of table view cells.
- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"welcomeItem"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"welcomeItem"];
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
            MUPublicServerListController *serverList = [[MUPublicServerListController alloc] init];
            [self.navigationController pushViewController:serverList animated:YES];
        } else if (indexPath.row == 1) {
            MUFavouriteServerListController *favList = [[MUFavouriteServerListController alloc] init];
            [self.navigationController pushViewController:favList animated:YES];
        } else if (indexPath.row == 2) {
            MULanServerListController *lanList = [[MULanServerListController alloc] init];
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
    NSString *aboutMessage = NSLocalizedString(@"Low latency, high quality voice chat", nil);
    
    UIAlertController* aboutAlert = [UIAlertController alertControllerWithTitle:aboutTitle message:aboutMessage preferredStyle:UIAlertControllerStyleAlert];
    
    [aboutAlert addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                    style:UIAlertActionStyleCancel
                                                  handler:nil]];
    [aboutAlert addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Website", nil)
                                                    style:UIAlertActionStyleDefault
                                                  handler:^(UIAlertAction * _Nonnull action) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.mumbleapp.com/"]];
    }]];
    [aboutAlert addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Legal", nil)
                                                    style:UIAlertActionStyleDefault
                                                  handler:^(UIAlertAction * _Nonnull action) {
        MULegalViewController *legalView = [[MULegalViewController alloc] init];
        UINavigationController *navController = [[UINavigationController alloc] init];
        [navController pushViewController:legalView animated:NO];
        [[self navigationController] presentViewController:navController animated:YES completion:nil];
    }]];
    [aboutAlert addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Support", nil)
                                                    style:UIAlertActionStyleDefault
                                                  handler:^(UIAlertAction * _Nonnull action) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"mailto:support@mumbleapp.com"]];
    }]];
    
    [self presentViewController:aboutAlert animated:YES completion:nil];
}

- (void) prefsClicked:(id)sender {
    MUPreferencesViewController *prefs = [[MUPreferencesViewController alloc] init];
    [self.navigationController pushViewController:prefs animated:YES];
}

@end
