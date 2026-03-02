// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUPreferencesViewController.h"
#import "MUApplicationDelegate.h"
#import "MUAudioTransmissionPreferencesViewController.h"
#import "MUAdvancedAudioPreferencesViewController.h"
#import "MURemoteControlPreferencesViewController.h"
#import "MURemoteControlServer.h"
#import "MULegalViewController.h"
#import "MUTableViewHeaderLabel.h"
#import "MUColor.h"
#import "MUImage.h"
#import "MUBackgroundView.h"

@import UserNotifications;

// Section 0: Audio
// Section 1: Network
// Section 2: Notifications
// Section 3: About
enum {
    MUSettingsSectionAudio = 0,
    MUSettingsSectionNetwork = 1,
    MUSettingsSectionNotifications = 2,
    MUSettingsSectionAbout = 3,
    MUSettingsSectionCount = 4,
};

@interface MUPreferencesViewController () {
    UITextField *_activeTextField;
    UISwitch    *_notificationsSwitch;
}
- (void) audioVolumeChanged:(UISlider *)volumeSlider;
- (void) forceTCPChanged:(UISwitch *)tcpSwitch;
- (void) notificationsChanged:(UISwitch *)notifSwitch;
@end

@implementation MUPreferencesViewController

#pragma mark -
#pragma mark Initialization

- (id) init {
    UITableViewStyle style;
    if (@available(iOS 13.0, *)) {
        style = UITableViewStyleInsetGrouped;
    } else {
        style = UITableViewStyleGrouped;
    }
    if ((self = [super initWithStyle:style])) {
        self.preferredContentSize = CGSizeMake(320, 480);
    }
    return self;
}

- (void) dealloc {
    [[NSUserDefaults standardUserDefaults] synchronize];
    MUApplicationDelegate *delegate = (MUApplicationDelegate *)[[UIApplication sharedApplication] delegate];
    [delegate reloadPreferences];
}

#pragma mark -
#pragma mark Looks

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = YES;
        self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
    }
    
    self.tableView.backgroundView = [MUBackgroundView backgroundView];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];

    self.title = NSLocalizedString(@"Settings", nil);
    [self.tableView reloadData];
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return MUSettingsSectionCount;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == MUSettingsSectionAudio) {
        return 3; // Volume, Transmission, Advanced
    } else if (section == MUSettingsSectionNetwork) {
#ifdef ENABLE_REMOTE_CONTROL
        return 2; // Force TCP, Remote Control
#else
        return 1; // Force TCP only
#endif
    } else if (section == MUSettingsSectionNotifications) {
        return 1; // Enable Notifications
    } else if (section == MUSettingsSectionAbout) {
        return 3; // Website, Legal, Support
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"PreferencesCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleGray;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    
    // Audio section
    if ([indexPath section] == MUSettingsSectionAudio) {
        if ([indexPath row] == 0) {
            UISlider *volSlider = [[UISlider alloc] init];
            [volSlider setMinimumTrackTintColor:[UIColor systemBlueColor]];
            [volSlider setMaximumValue:1.0f];
            [volSlider setMinimumValue:0.0f];
            [volSlider setValue:[[NSUserDefaults standardUserDefaults] floatForKey:@"AudioOutputVolume"]];
            [[cell textLabel] setText:NSLocalizedString(@"Volume", nil)];
            [cell setAccessoryView:volSlider];
            [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
            [volSlider addTarget:self action:@selector(audioVolumeChanged:) forControlEvents:UIControlEventValueChanged];
        }
        if ([indexPath row] == 1) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AudioTransmitCell"];
            if (cell == nil)
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"AudioTransmitCell"];
            cell.textLabel.text = NSLocalizedString(@"Transmission", nil);
            NSString *xmit = [[NSUserDefaults standardUserDefaults] stringForKey:@"AudioTransmitMethod"];
            if ([xmit isEqualToString:@"vad"]) {
                cell.detailTextLabel.text = NSLocalizedString(@"Voice Activated", @"Voice activated transmission mode");
            } else if ([xmit isEqualToString:@"ptt"]) {
                cell.detailTextLabel.text = NSLocalizedString(@"Push-to-talk", @"Push-to-talk transmission mode");
            } else if ([xmit isEqualToString:@"continuous"]) {
                cell.detailTextLabel.text = NSLocalizedString(@"Continuous", @"Continuous transmission mode");
            }
            cell.detailTextLabel.textColor = [MUColor selectedTextColor];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleGray;
            return cell;
        } else if ([indexPath row] == 2) {
            cell.textLabel.text = NSLocalizedString(@"Advanced", nil);
            cell.accessoryView = nil;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }

    // Network
    } else if ([indexPath section] == MUSettingsSectionNetwork) {
        if ([indexPath row] == 0) {
            UISwitch *tcpSwitch = [[UISwitch alloc] init];
            [tcpSwitch setOn:[[NSUserDefaults standardUserDefaults] boolForKey:@"NetworkForceTCP"]];
            [[cell textLabel] setText:NSLocalizedString(@"Force TCP", nil)];
            [cell setAccessoryView:tcpSwitch];
            [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
            [tcpSwitch setOnTintColor:[UIColor colorWithRed:0.204 green:0.780 blue:0.349 alpha:1.0]];
            [tcpSwitch addTarget:self action:@selector(forceTCPChanged:) forControlEvents:UIControlEventValueChanged];
        } else if ([indexPath row] == 1) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"RemoteControlCell"];
            if (cell == nil)
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"RemoteControlCell"];
            cell.textLabel.text = NSLocalizedString(@"Remote Control", nil);
            BOOL isOn = [[MURemoteControlServer sharedRemoteControlServer] isRunning];
            cell.detailTextLabel.text = isOn ? NSLocalizedString(@"On", nil) : NSLocalizedString(@"Off", nil);
            cell.detailTextLabel.textColor = [MUColor selectedTextColor];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleGray;
            return cell;
        }
    
    // Notifications
    } else if ([indexPath section] == MUSettingsSectionNotifications) {
        if ([indexPath row] == 0) {
            _notificationsSwitch = [[UISwitch alloc] init];
            [_notificationsSwitch setOn:[[NSUserDefaults standardUserDefaults] boolForKey:@"NotificationsEnabled"]];
            [[cell textLabel] setText:NSLocalizedString(@"Enable Notifications", nil)];
            [cell setAccessoryView:_notificationsSwitch];
            [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
            [_notificationsSwitch addTarget:self action:@selector(notificationsChanged:) forControlEvents:UIControlEventValueChanged];
            
            // Update switch state based on actual system authorization
            [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (settings.authorizationStatus == UNAuthorizationStatusDenied) {
                        [_notificationsSwitch setOn:NO animated:NO];
                    }
                });
            }];
        }

    // About
    } else if ([indexPath section] == MUSettingsSectionAbout) {
        if ([indexPath row] == 0) {
            cell.textLabel.text = NSLocalizedString(@"Website", nil);
            if (@available(iOS 13.0, *)) {
                cell.imageView.image = [UIImage systemImageNamed:@"safari"];
                cell.imageView.tintColor = [UIColor systemBlueColor];
            }
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else if ([indexPath row] == 1) {
            cell.textLabel.text = NSLocalizedString(@"Legal", nil);
            if (@available(iOS 13.0, *)) {
                cell.imageView.image = [UIImage systemImageNamed:@"doc.text"];
                cell.imageView.tintColor = [UIColor systemGrayColor];
            }
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else if ([indexPath row] == 2) {
            cell.textLabel.text = NSLocalizedString(@"Support", nil);
            if (@available(iOS 13.0, *)) {
                cell.imageView.image = [UIImage systemImageNamed:@"questionmark.circle"];
                cell.imageView.tintColor = [UIColor systemOrangeColor];
            }
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    }

    return cell;
}

- (UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == MUSettingsSectionAudio) {
        return [MUTableViewHeaderLabel labelWithText:NSLocalizedString(@"Audio", nil)];
    } else if (section == MUSettingsSectionNetwork) {
        return [MUTableViewHeaderLabel labelWithText:NSLocalizedString(@"Network", nil)];
    } else if (section == MUSettingsSectionNotifications) {
        return [MUTableViewHeaderLabel labelWithText:NSLocalizedString(@"Notifications", nil)];
    } else if (section == MUSettingsSectionAbout) {
        return [MUTableViewHeaderLabel labelWithText:NSLocalizedString(@"About", nil)];
    }
    return nil;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return [MUTableViewHeaderLabel defaultHeaderHeight];
}

- (NSString *) tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == MUSettingsSectionAbout) {
#ifdef MUMBLE_BETA_DIST
        return [NSString stringWithFormat:@"Mumble %@ (%@)",
                [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
                [[NSBundle mainBundle] objectForInfoDictionaryKey:@"MumbleGitRevision"]];
#else
        return [NSString stringWithFormat:@"Mumble %@",
                [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
#endif
    }
    return nil;
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == MUSettingsSectionAudio) {
        if (indexPath.row == 1) { // Transmission
            MUAudioTransmissionPreferencesViewController *audioXmit = [[MUAudioTransmissionPreferencesViewController alloc] init];
            [self.navigationController pushViewController:audioXmit animated:YES];
        } else if (indexPath.row == 2) { // Advanced
            MUAdvancedAudioPreferencesViewController *advAudio = [[MUAdvancedAudioPreferencesViewController alloc] init];
            [self.navigationController pushViewController:advAudio animated:YES];
        }
    } else if (indexPath.section == MUSettingsSectionNetwork) {
        if (indexPath.row == 1) { // Remote Control
            MURemoteControlPreferencesViewController *remoteControlPref = [[MURemoteControlPreferencesViewController alloc] init];
            [self.navigationController pushViewController:remoteControlPref animated:YES];
        }
    } else if (indexPath.section == MUSettingsSectionAbout) {
        if (indexPath.row == 0) { // Website
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.mumble.info/"] options:@{} completionHandler:nil];
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
        } else if (indexPath.row == 1) { // Legal
            MULegalViewController *legalView = [[MULegalViewController alloc] init];
            [self.navigationController pushViewController:legalView animated:YES];
        } else if (indexPath.row == 2) { // Support
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/mumble-voip/mumble-iphoneos/issues"] options:@{} completionHandler:nil];
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
        }
    }
}

- (void) audioVolumeChanged:(UISlider *)volumeSlider {
    [[NSUserDefaults standardUserDefaults] setFloat:[volumeSlider value] forKey:@"AudioOutputVolume"];
}

- (void) forceTCPChanged:(UISwitch *)tcpSwitch {
    [[NSUserDefaults standardUserDefaults] setBool:[tcpSwitch isOn] forKey:@"NetworkForceTCP"];
}

- (void) notificationsChanged:(UISwitch *)notifSwitch {
    if ([notifSwitch isOn]) {
        [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (settings.authorizationStatus == UNAuthorizationStatusNotDetermined) {
                    [[UNUserNotificationCenter currentNotificationCenter]
                        requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionBadge | UNAuthorizationOptionSound)
                        completionHandler:^(BOOL granted, NSError *error) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [[NSUserDefaults standardUserDefaults] setBool:granted forKey:@"NotificationsEnabled"];
                                [notifSwitch setOn:granted animated:YES];
                            });
                        }];
                } else if (settings.authorizationStatus == UNAuthorizationStatusDenied) {
                    [notifSwitch setOn:NO animated:YES];
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Notifications Disabled", nil)
                                                                                   message:NSLocalizedString(@"Notifications are disabled in system settings. Please enable them in Settings > Mumble > Notifications.", nil)
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                              style:UIAlertActionStyleCancel
                                                            handler:nil]];
                    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Open Settings", nil)
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *action) {
                        NSURL *settingsURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                        [[UIApplication sharedApplication] openURL:settingsURL options:@{} completionHandler:nil];
                    }]];
                    [self presentViewController:alert animated:YES completion:nil];
                } else {
                    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"NotificationsEnabled"];
                }
            });
        }];
    } else {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"NotificationsEnabled"];
    }
}

@end
