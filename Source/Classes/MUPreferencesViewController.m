// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUPreferencesViewController.h"
#import "MUApplicationDelegate.h"
#import "MUCertificatePreferencesViewController.h"
#import "MUAudioTransmissionPreferencesViewController.h"
#import "MUAdvancedAudioPreferencesViewController.h"
#import "MURemoteControlPreferencesViewController.h"
#import "MUCertificateController.h"
#import "MUTableViewHeaderLabel.h"
#import "MURemoteControlServer.h"
#import "MUColor.h"
#import "MUImage.h"
#import "MUOperatingSystem.h"
#import "MUBackgroundView.h"

#import <MumbleKit/MKCertificate.h>

@interface MUPreferencesViewController () {
    UITextField *_activeTextField;
}
- (void) audioVolumeChanged:(UISlider *)volumeSlider;
- (void) forceTCPChanged:(UISwitch *)tcpSwitch;
@end

@implementation MUPreferencesViewController

#pragma mark -
#pragma mark Initialization

- (id) init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        [self setContentSizeForViewInPopover:CGSizeMake(320, 480)];
    }
    return self;
}

- (void) dealloc {
    [[NSUserDefaults standardUserDefaults] synchronize];
    MUApplicationDelegate *delegate = [[UIApplication sharedApplication] delegate];
    [delegate reloadPreferences];
    [super dealloc];
}

#pragma mark -
#pragma mark Looks

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.navigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
        [self.navigationController.navigationBar setBackgroundImage:[MUImage clearColorImage] forBarMetrics:UIBarMetricsDefault];
        self.navigationController.navigationBar.translucent = YES;
    }
 
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

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];

    self.title = NSLocalizedString(@"Preferences", nil);
    [self.tableView reloadData];
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Audio
    if (section == 0) {
        return 3;
    // Network
    } else if (section == 1) {
#ifdef ENABLE_REMOTE_CONTROL
        return 3;
#else
        return 2;
#endif
    }

    return 0;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"PreferencesCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleGray;
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    // Audio section
    if ([indexPath section] == 0) {
        // Volume
        if ([indexPath row] == 0) {
            UISlider *volSlider = [[UISlider alloc] init];
            [volSlider setMinimumTrackTintColor:[UIColor blackColor]];
            [volSlider setMaximumValue:1.0f];
            [volSlider setMinimumValue:0.0f];
            [volSlider setValue:[[NSUserDefaults standardUserDefaults] floatForKey:@"AudioOutputVolume"]];
            [[cell textLabel] setText:NSLocalizedString(@"Volume", nil)];
            [cell setAccessoryView:volSlider];
            [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
            [volSlider addTarget:self action:@selector(audioVolumeChanged:) forControlEvents:UIControlEventValueChanged];
            [volSlider release];
        }
        // Transmit method
        if ([indexPath row] == 1) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AudioTransmitCell"];
            if (cell == nil)
                cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"AudioTransmitCell"] autorelease];
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
    } else if ([indexPath section] == 1) {
        if ([indexPath row] == 0) {
            UISwitch *tcpSwitch = [[UISwitch alloc] init];
            [tcpSwitch setOn:[[NSUserDefaults standardUserDefaults] boolForKey:@"NetworkForceTCP"]];
            [[cell textLabel] setText:NSLocalizedString(@"Force TCP", nil)];
            [cell setAccessoryView:tcpSwitch];
            [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
            [tcpSwitch setOnTintColor:[UIColor blackColor]];
            [tcpSwitch addTarget:self action:@selector(forceTCPChanged:) forControlEvents:UIControlEventValueChanged];
            [tcpSwitch release];
        } else if ([indexPath row] == 1) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PrefCertificateCell"];
            if (cell == nil)
                cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"PrefCertificateCell"] autorelease];
            MKCertificate *cert = [MUCertificateController defaultCertificate];
            cell.textLabel.text = NSLocalizedString(@"Certificate", nil);
            cell.detailTextLabel.text = cert ? [cert subjectName] : NSLocalizedString(@"None", @"None (No certificate chosen)");
            cell.detailTextLabel.textColor = [MUColor selectedTextColor];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleGray;
            return cell;
        } else if ([indexPath row] == 2) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"RemoteControlCell"];
            if (cell == nil)
                cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"RemoteControlCell"] autorelease];
            cell.textLabel.text = NSLocalizedString(@"Remote Control", nil);
            BOOL isOn = [[MURemoteControlServer sharedRemoteControlServer] isRunning];
            if (isOn) {
                cell.detailTextLabel.text = NSLocalizedString(@"On", nil);
            } else {
                cell.detailTextLabel.text = NSLocalizedString(@"Off", nil);
            }
            cell.detailTextLabel.textColor = [MUColor selectedTextColor];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleGray;
            return cell;
        }
    }

    return cell;
}

- (UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return [MUTableViewHeaderLabel labelWithText:NSLocalizedString(@"Audio", nil)];
    } else if (section == 1) {
        return [MUTableViewHeaderLabel labelWithText:NSLocalizedString(@"Network", nil)];
    }

    return nil;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return [MUTableViewHeaderLabel defaultHeaderHeight];
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) { // Audio
        if (indexPath.row == 1) { // Transmission
            MUAudioTransmissionPreferencesViewController *audioXmit = [[MUAudioTransmissionPreferencesViewController alloc] init];
            [self.navigationController pushViewController:audioXmit animated:YES];
            [audioXmit release];
        } else if (indexPath.row == 2) { // Advanced
            MUAdvancedAudioPreferencesViewController *advAudio = [[MUAdvancedAudioPreferencesViewController alloc] init];
            [self.navigationController pushViewController:advAudio animated:YES];
            [advAudio release];
        }
    } else if ([indexPath section] == 1) { // Network
        if ([indexPath row] == 1) { // Certificates
            MUCertificatePreferencesViewController *certPref = [[MUCertificatePreferencesViewController alloc] init];
            [self.navigationController pushViewController:certPref animated:YES];
            [certPref release];
        }
        if ([indexPath row] == 2) { // Remote Control
            MURemoteControlPreferencesViewController *remoteControlPref = [[MURemoteControlPreferencesViewController alloc] init];
            [self.navigationController pushViewController:remoteControlPref animated:YES];
            [remoteControlPref release];
        }
    }
}

- (void) audioVolumeChanged:(UISlider *)volumeSlider {
    [[NSUserDefaults standardUserDefaults] setFloat:[volumeSlider value] forKey:@"AudioOutputVolume"];
}

- (void) forceTCPChanged:(UISwitch *)tcpSwitch {
    [[NSUserDefaults standardUserDefaults] setBool:[tcpSwitch isOn] forKey:@"NetworkForceTCP"];
}

@end

