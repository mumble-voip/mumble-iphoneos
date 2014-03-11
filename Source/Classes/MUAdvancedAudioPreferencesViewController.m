// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUAdvancedAudioPreferencesViewController.h"
#import "MUTableViewHeaderLabel.h"
#import "MUApplicationDelegate.h"
#import "MUAudioQualityPreferencesViewController.h"
#import "MUAudioSidetonePreferencesViewController.h"
#import "MUColor.h"
#import "MUImage.h"
#import "MUOperatingSystem.h"
#import "MUBackgroundView.h"

#import <MumbleKit/MKAudio.h>

@implementation MUAdvancedAudioPreferencesViewController

- (id) init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        self.contentSizeForViewInPopover = CGSizeMake(320, 480);
    }
    return self;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.title = NSLocalizedString(@"Advanced Audio", nil);
    
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

    self.tableView.scrollEnabled = YES;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioSubsystemRestarted:) name:MKAudioDidRestartNotification object:nil];
    
    [self.tableView reloadData];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:YES];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 4;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 1;
    } else if (section == 1) {
        return 2;
    } else if (section == 2) {
        return 2;
    } else if (section == 3) {
        return 1;
    }
    return 0;
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"MUAdvancedAudioPreferencesCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier] autorelease];
    }
    
    cell.detailTextLabel.text = nil;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if ([indexPath section] == 0) {
        if ([indexPath row] == 0) {
            cell.textLabel.text = NSLocalizedString(@"Quality", nil);
            cell.detailTextLabel.textColor = [MUColor selectedTextColor];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            if ([[defaults stringForKey:@"AudioQualityKind"] isEqualToString:@"low"])
                cell.detailTextLabel.text = NSLocalizedString(@"Low", nil);
            else if ([[defaults stringForKey:@"AudioQualityKind"] isEqualToString:@"balanced"])
                cell.detailTextLabel.text = NSLocalizedString(@"Balanced", nil);
            else if ([[defaults stringForKey:@"AudioQualityKind"] isEqualToString:@"high"])
                cell.detailTextLabel.text = NSLocalizedString(@"High", nil);
            else
                cell.detailTextLabel.text = NSLocalizedString(@"Custom", nil);
            cell.selectionStyle = UITableViewCellSelectionStyleGray;
        }
    } else if ([indexPath section] == 1) {
        if ([indexPath row] == 0) {
            cell.textLabel.text = NSLocalizedString(@"Preprocessing", nil);
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            UISwitch *preprocSwitch = [[[UISwitch alloc] init] autorelease];
            preprocSwitch.onTintColor = [UIColor blackColor];
            preprocSwitch.on = [defaults boolForKey:@"AudioPreprocessor"];
            [preprocSwitch addTarget:self action:@selector(preprocessingChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = preprocSwitch;
        } else if ([indexPath row] == 1) {
            if ([defaults boolForKey:@"AudioPreprocessor"]) {
                cell.textLabel.text = NSLocalizedString(@"Echo Cancellation", nil);
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                UISwitch *echoCancelSwitch = [[[UISwitch alloc] init] autorelease];
                echoCancelSwitch.onTintColor = [UIColor blackColor];
                echoCancelSwitch.on = [defaults boolForKey:@"AudioEchoCancel"];
                echoCancelSwitch.enabled = [[MKAudio sharedAudio] echoCancellationAvailable];
                if (!echoCancelSwitch.enabled) {
                    echoCancelSwitch.on = NO;
                }
                [echoCancelSwitch addTarget:self action:@selector(echoCancelChanged:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = echoCancelSwitch;
            } else {
                cell.textLabel.text = NSLocalizedString(@"Mic Boost", nil);
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                UISlider *slider = [[[UISlider alloc] init] autorelease];
                [slider setMaximumValue:2.0f];
                [slider setMinimumValue:0.0f];
                float boost = [defaults floatForKey:@"AudioMicBoost"];
                if (boost > 1.0f) {
                    [slider setMinimumTrackTintColor:[MUColor badPingColor]];
                } else {
                    [slider setMinimumTrackTintColor:[MUColor goodPingColor]];
                }
                [slider setValue:boost];
                [slider addTarget:self action:@selector(micBoostChanged:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = slider;
            }
        }
    } else if ([indexPath section] == 2) {
        if ([indexPath row] == 0) {
            cell.textLabel.text = NSLocalizedString(@"Sidetone", nil);
            cell.detailTextLabel.textColor = [MUColor selectedTextColor];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            if ([defaults boolForKey:@"AudioSidetone"]) {
                cell.detailTextLabel.text = NSLocalizedString(@"On", nil);
            } else {
                cell.detailTextLabel.text = NSLocalizedString(@"Off", nil);
            }
            cell.selectionStyle = UITableViewCellSelectionStyleGray;
        } else if ([indexPath row] == 1) {
            cell.textLabel.text = NSLocalizedString(@"Speakerphone Mode", nil);
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            UISwitch *speakerPhoneSwitch = [[[UISwitch alloc] init] autorelease];
            speakerPhoneSwitch.onTintColor = [UIColor blackColor];
            speakerPhoneSwitch.on = [defaults boolForKey:@"AudioSpeakerPhoneMode"];
            speakerPhoneSwitch.enabled = YES;
            [speakerPhoneSwitch addTarget:self action:@selector(speakerPhoneModeChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = speakerPhoneSwitch;
        }
    } else if ([indexPath section] == 3) {
        if ([indexPath row] == 0) {
            cell.textLabel.text = NSLocalizedString(@"Force CELT Mode", nil);
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            UISwitch *celtSwitch = [[[UISwitch alloc] init] autorelease];
            celtSwitch.onTintColor = [UIColor blackColor];
            celtSwitch.on = [defaults boolForKey:@"AudioOpusCodecForceCELTMode"];
            celtSwitch.enabled = YES;
            [celtSwitch addTarget:self action:@selector(opusCodecForceCELTModeChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = celtSwitch;
        }
    }
    
    return cell;
}

- (UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == 0) { // Xmit
        return [MUTableViewHeaderLabel labelWithText:NSLocalizedString(@"Transmission Quality", nil)];
    } else if (section == 1) { // Audio Input
        return [MUTableViewHeaderLabel labelWithText:NSLocalizedString(@"Audio Input", nil)];
    } else if (section == 2) { // Audio Output
        return [MUTableViewHeaderLabel labelWithText:NSLocalizedString(@"Audio Output", nil)];
    } else if (section == 3) { // Opus Codec
        return [MUTableViewHeaderLabel labelWithText:NSLocalizedString(@"Opus Codec", nil)];
    } else {
        return nil;
    }
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return [MUTableViewHeaderLabel defaultHeaderHeight];
    } else if (section == 1) {
        return [MUTableViewHeaderLabel defaultHeaderHeight];
    } else if (section == 2) {
        return [MUTableViewHeaderLabel defaultHeaderHeight];
    } else if (section == 3) {
        return [MUTableViewHeaderLabel defaultHeaderHeight];
    }
    return 0.0f;
}

- (UIView *) tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (section == 1) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"AudioPreprocessor"]) {
            if (![[MKAudio sharedAudio] echoCancellationAvailable]) {
                NSString *echoCancelNotAvail = NSLocalizedString(@"Echo Cancellation is not available when using the current audio peripheral.", nil);
                MUTableViewHeaderLabel *lbl = [MUTableViewHeaderLabel labelWithText:echoCancelNotAvail];
                lbl.font = [UIFont systemFontOfSize:16.0f];
                lbl.lineBreakMode = UILineBreakModeWordWrap;
                lbl.numberOfLines = 0;
                return lbl;
            }
        }
    }
    return nil;
}

- (CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (section == 1) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"AudioPreprocessor"]) {
            if (![[MKAudio sharedAudio] echoCancellationAvailable]) {
                return 44.0f;
            }
        }
    }
    return 0.0f;
}

#pragma mark - Table view delegate

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([indexPath section] == 0 && [indexPath row] == 0) {
        MUAudioQualityPreferencesViewController *audioQual = [[MUAudioQualityPreferencesViewController alloc] init];
        [self.navigationController pushViewController:audioQual animated:YES];
        [audioQual release];
    } else if ([indexPath section] == 2 && [indexPath row] == 0) {
        MUAudioSidetonePreferencesViewController *sidetonePrefs = [[MUAudioSidetonePreferencesViewController alloc] init];
        [self.navigationController pushViewController:sidetonePrefs animated:YES];
        [sidetonePrefs release];
    }
}

#pragma mark - Actions

- (void) preprocessingChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"AudioPreprocessor"];
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
}

- (void) echoCancelChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"AudioEchoCancel"];
}

- (void) micBoostChanged:(UISlider *)sender {
    [[NSUserDefaults standardUserDefaults] setFloat:sender.value forKey:@"AudioMicBoost"];
    if (sender.value > 1.0f) {
        [sender setMinimumTrackTintColor:[MUColor badPingColor]];
    } else {
        [sender setMinimumTrackTintColor:[MUColor goodPingColor]];
    }
}

- (void) speakerPhoneModeChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"AudioSpeakerPhoneMode"];
}

- (void) opusCodecForceCELTModeChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"AudioOpusCodecForceCELTMode"];
}

- (void) audioSubsystemRestarted:(NSNotification *)notification {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"AudioPreprocessor"]) {
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
    }
}

@end
