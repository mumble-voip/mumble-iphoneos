#import "MUInterface.h"
// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUPreferencesViewController.h"
#import "MUApplicationDelegate.h"
#import "MUCertificatePreferencesViewController.h"
#import "MUAudioTransmissionPreferencesViewController.h"
#import "MUAdvancedAudioPreferencesViewController.h"
#import "MUCertificateController.h"
#import "MUImage.h"
#import "MUAboutViewController.h"

#import "MLClient.h"

@interface MUPreferencesViewController ()
- (void) audioVolumeChanged:(UISlider *)volumeSlider;
- (void) forceTCPChanged:(UISwitch *)tcpSwitch;
@end

@implementation MUPreferencesViewController

#pragma mark -
#pragma mark Initialization

- (id) init {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        self.preferredContentSize = CGSizeMake(320, 480);
    }
    return self;
}

#pragma mark -
#pragma mark Looks

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    MUConfigureTable(self.tableView);
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    self.tableView.backgroundView = nil;
    
    {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    }

    self.title = NSLocalizedString(@"Preferences", nil);
    [self.tableView reloadData];
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // The Settings tab stays alive, so apply changes when leaving rather than on deallocation.
    [(MUApplicationDelegate *)UIApplication.sharedApplication.delegate reloadPreferences];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.showsAppInformation ? 3 : 2;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Audio
    if (section == 0) {
        return 3;
    // Network
    } else if (section == 1) {
        return 2;
    }

    return section == 2 && self.showsAppInformation ? 1 : 0;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"PreferencesCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        MUConfigureStandardCell(cell);
    }
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    cell.contentConfiguration = nil;
    cell.textLabel.text = nil;
    
    // Audio section
    if ([indexPath section] == 0) {
        if ([indexPath row] == 0) {
            UITableViewCell *sliderCell = [tableView dequeueReusableCellWithIdentifier:@"VolumeSliderCell"];
            UISlider *volSlider = nil;
            if (sliderCell == nil) {
                sliderCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"VolumeSliderCell"];
                MUConfigureStandardCell(sliderCell);
                sliderCell.selectionStyle = UITableViewCellSelectionStyleNone;
                volSlider = [[UISlider alloc] init];
                volSlider.translatesAutoresizingMaskIntoConstraints = NO;
                volSlider.tag = 1001;
                volSlider.minimumValue = 0.0f;
                volSlider.maximumValue = 1.0f;
                volSlider.accessibilityLabel = NSLocalizedString(@"Playback Volume", nil);
                UIImageSymbolConfiguration *quietSpeaker = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightMedium];
                UIImageSymbolConfiguration *loudSpeaker = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
                volSlider.minimumValueImage = [[UIImage systemImageNamed:@"speaker.fill" withConfiguration:quietSpeaker] imageWithTintColor:[UIColor secondaryLabelColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
                volSlider.maximumValueImage = [[UIImage systemImageNamed:@"speaker.wave.3.fill" withConfiguration:loudSpeaker] imageWithTintColor:[UIColor secondaryLabelColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
                [volSlider addTarget:self action:@selector(audioVolumeChanged:) forControlEvents:UIControlEventValueChanged];
                [sliderCell.contentView addSubview:volSlider];
                UILayoutGuide *margins = sliderCell.contentView.layoutMarginsGuide;
                [NSLayoutConstraint activateConstraints:@[
                    [sliderCell.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:44.0],
                    [volSlider.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor],
                    [volSlider.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor],
                    [volSlider.centerYAnchor constraintEqualToAnchor:sliderCell.contentView.centerYAnchor],
                    [volSlider.heightAnchor constraintGreaterThanOrEqualToConstant:44],
                ]];
            } else {
                volSlider = (UISlider *)[sliderCell.contentView viewWithTag:1001];
            }
            volSlider.value = [[NSUserDefaults standardUserDefaults] floatForKey:@"AudioOutputVolume"];
            return sliderCell;
        }
        // Transmit method
        if ([indexPath row] == 1) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AudioTransmitCell"];
            if (cell == nil)
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"AudioTransmitCell"];
                MUConfigureStandardCell(cell);
            cell.textLabel.text = NSLocalizedString(@"Transmission", nil);
            NSString *xmit = [[NSUserDefaults standardUserDefaults] stringForKey:@"AudioTransmitMethod"];
            if ([xmit isEqualToString:@"vad"]) {
                cell.detailTextLabel.text = NSLocalizedString(@"Voice Activated", @"Voice activated transmission mode");
            } else if ([xmit isEqualToString:@"ptt"]) {
                cell.detailTextLabel.text = NSLocalizedString(@"Push-to-talk", @"Push-to-talk transmission mode");
            } else if ([xmit isEqualToString:@"continuous"]) {
                cell.detailTextLabel.text = NSLocalizedString(@"Continuous", @"Continuous transmission mode");
            }
            cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
             cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            return cell;
        } else if ([indexPath row] == 2) {
            cell.textLabel.text = NSLocalizedString(@"Advanced", nil);
            cell.accessoryView = nil;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }

    // Network
    } else if ([indexPath section] == 1) {
        if ([indexPath row] == 0) {
            UISwitch *tcpSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(0, 0, 51, 31)];
            [tcpSwitch setOn:[[NSUserDefaults standardUserDefaults] boolForKey:@"NetworkForceTCP"]];
            [[cell textLabel] setText:NSLocalizedString(@"Force TCP", nil)];
            [cell setAccessoryView:tcpSwitch];
            [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
            [tcpSwitch addTarget:self action:@selector(forceTCPChanged:) forControlEvents:UIControlEventValueChanged];
        } else if ([indexPath row] == 1) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PrefCertificateCell"];
            if (cell == nil)
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"PrefCertificateCell"];
                MUConfigureStandardCell(cell);
            MLCertificate *cert = [MUCertificateController defaultCertificate];
            cell.textLabel.text = NSLocalizedString(@"Certificate", nil);
            cell.detailTextLabel.text = cert ? [cert subjectName] : NSLocalizedString(@"None", @"None (No certificate chosen)");
            cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            return cell;
        }
    }

    if (indexPath.section == 2 && self.showsAppInformation) {
        UIListContentConfiguration *content = [UIListContentConfiguration cellConfiguration];
        content.text = NSLocalizedString(@"About", nil);
        content.image = [UIImage systemImageNamed:@"info.circle"];
        content.imageProperties.tintColor = UIColor.labelColor;
        cell.contentConfiguration = content;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return NSLocalizedString(@"Audio", nil);
    } else if (section == 1) {
        return NSLocalizedString(@"Network", nil);
    }
    return nil;
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) { // Audio
        if (indexPath.row == 1) { // Transmission
            MUAudioTransmissionPreferencesViewController *audioXmit = [[MUAudioTransmissionPreferencesViewController alloc] init];
            [self.navigationController pushViewController:audioXmit animated:YES];
        } else if (indexPath.row == 2) { // Advanced
            MUAdvancedAudioPreferencesViewController *advAudio = [[MUAdvancedAudioPreferencesViewController alloc] init];
            [self.navigationController pushViewController:advAudio animated:YES];
        }
    } else if ([indexPath section] == 1) { // Network
        if ([indexPath row] == 1) { // Certificates
            MUCertificatePreferencesViewController *certPref = [[MUCertificatePreferencesViewController alloc] init];
            [self.navigationController pushViewController:certPref animated:YES];
        }
    } else if (indexPath.section == 2 && self.showsAppInformation) {
        [self.navigationController pushViewController:[MUAboutViewController new] animated:YES];
    }
}

- (void) audioVolumeChanged:(UISlider *)volumeSlider {
    [[NSUserDefaults standardUserDefaults] setFloat:[volumeSlider value] forKey:@"AudioOutputVolume"];
}

- (void) forceTCPChanged:(UISwitch *)tcpSwitch {
    [[NSUserDefaults standardUserDefaults] setBool:[tcpSwitch isOn] forKey:@"NetworkForceTCP"];
}

@end

