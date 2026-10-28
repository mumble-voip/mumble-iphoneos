#import "MUInterface.h"
// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUAdvancedAudioPreferencesViewController.h"
#import "MUApplicationDelegate.h"
#import "MUAudioQualityPreferencesViewController.h"
#import "MUAudioSidetonePreferencesViewController.h"
#import "MUImage.h"

#import "MLClient.h"
#import <AVFoundation/AVFoundation.h>

static UISwitch *MUAudioSwitch(void) {
    UISwitch *control = [[UISwitch alloc] initWithFrame:CGRectMake(0, 0, 51, 31)];
    return control;
}

static UISlider *MUAudioSlider(void) {
    return [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 150, 31)];
}

static void *MUMicrophoneModeObservation = &MUMicrophoneModeObservation;

@interface MUAdvancedAudioPreferencesViewController () {
    BOOL _observingMicrophoneModes;
}
@end

@implementation MUAdvancedAudioPreferencesViewController

- (id) init {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        self.preferredContentSize = CGSizeMake(320, 480);
    }
    return self;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    MUConfigureTable(self.tableView);
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    self.title = NSLocalizedString(@"Advanced Audio", nil);
    
    self.tableView.backgroundView = nil;
    
    {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    }

    self.tableView.scrollEnabled = YES;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioSubsystemRestarted:) name:MLAudioDidRestartNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(microphoneModeEnvironmentChanged:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(microphoneModeEnvironmentChanged:) name:AVAudioSessionRouteChangeNotification object:nil];
    if (!_observingMicrophoneModes) {
        [AVCaptureDevice.class addObserver:self forKeyPath:@"preferredMicrophoneMode" options:0 context:MUMicrophoneModeObservation];
        [AVCaptureDevice.class addObserver:self forKeyPath:@"activeMicrophoneMode" options:0 context:MUMicrophoneModeObservation];
        _observingMicrophoneModes = YES;
    }
    
    [self.tableView reloadData];
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopObservingMicrophoneModes];
}

- (void)dealloc { [self stopObservingMicrophoneModes]; }

- (void)stopObservingMicrophoneModes {
    if (!_observingMicrophoneModes) return;
    [AVCaptureDevice.class removeObserver:self forKeyPath:@"preferredMicrophoneMode" context:MUMicrophoneModeObservation];
    [AVCaptureDevice.class removeObserver:self forKeyPath:@"activeMicrophoneMode" context:MUMicrophoneModeObservation];
    _observingMicrophoneModes = NO;
}

- (NSString *)microphoneModeName {
    AVCaptureMicrophoneMode mode = [[MLAudio sharedAudio] isRunning] ? AVCaptureDevice.activeMicrophoneMode : AVCaptureDevice.preferredMicrophoneMode;
    switch (mode) {
        case AVCaptureMicrophoneModeVoiceIsolation: return NSLocalizedString(@"Voice Isolation", nil);
        case AVCaptureMicrophoneModeWideSpectrum: return NSLocalizedString(@"Wide Spectrum", nil);
        default: return NSLocalizedString(@"Standard", nil);
    }
}

- (void)refreshMicrophoneMode {
    if (!self.viewIfLoaded.window || ![NSUserDefaults.standardUserDefaults boolForKey:@"AudioPreprocessor"]) return;
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:1]];
    cell.detailTextLabel.text = [self microphoneModeName];
    [cell setNeedsLayout];
}

- (void)microphoneModeEnvironmentChanged:(NSNotification *)notification {
    if (NSThread.isMainThread) [self refreshMicrophoneMode];
    else {
        __weak MUAdvancedAudioPreferencesViewController *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf refreshMicrophoneMode]; });
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context != MUMicrophoneModeObservation) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    __weak MUAdvancedAudioPreferencesViewController *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf refreshMicrophoneMode]; });
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
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
        MUConfigureStandardCell(cell);
    }
    
    cell.detailTextLabel.text = nil;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if ([indexPath section] == 0) {
        if ([indexPath row] == 0) {
            cell.textLabel.text = NSLocalizedString(@"Quality", nil);
            cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            if ([[defaults stringForKey:@"AudioQualityKind"] isEqualToString:@"low"])
                cell.detailTextLabel.text = NSLocalizedString(@"Low", nil);
            else if ([[defaults stringForKey:@"AudioQualityKind"] isEqualToString:@"balanced"])
                cell.detailTextLabel.text = NSLocalizedString(@"Balanced", nil);
            else if ([[defaults stringForKey:@"AudioQualityKind"] isEqualToString:@"high"])
                cell.detailTextLabel.text = NSLocalizedString(@"High", nil);
            else
                cell.detailTextLabel.text = NSLocalizedString(@"Custom", nil);
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        }
    } else if ([indexPath section] == 1) {
        if ([indexPath row] == 0) {
            cell.textLabel.text = NSLocalizedString(@"Voice Processing", nil);
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            UISwitch *preprocSwitch = MUAudioSwitch();
            preprocSwitch.on = [defaults boolForKey:@"AudioPreprocessor"];
            [preprocSwitch addTarget:self action:@selector(preprocessingChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = preprocSwitch;
        } else if ([indexPath row] == 1) {
            if ([defaults boolForKey:@"AudioPreprocessor"]) {
                cell.textLabel.text = NSLocalizedString(@"Microphone Mode", nil);
                cell.detailTextLabel.text = [self microphoneModeName];
                cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
                cell.selectionStyle=UITableViewCellSelectionStyleDefault;
            } else {
                cell.textLabel.text = NSLocalizedString(@"Mic Boost", nil);
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                UISlider *slider = MUAudioSlider();
                [slider setMaximumValue:2.0f];
                [slider setMinimumValue:0.0f];
                float boost = [defaults floatForKey:@"AudioMicBoost"];
                if (boost > 1.0f) {
                    [slider setMinimumTrackTintColor:UIColor.systemRedColor];
                } else {
                    [slider setMinimumTrackTintColor:UIColor.systemGreenColor];
                }
                [slider setValue:boost];
                [slider addTarget:self action:@selector(micBoostChanged:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = slider;
            }
        }
    } else if ([indexPath section] == 2) {
        if ([indexPath row] == 0) {
            cell.textLabel.text = NSLocalizedString(@"Sidetone", nil);
            cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            if ([defaults boolForKey:@"AudioSidetone"]) {
                cell.detailTextLabel.text = NSLocalizedString(@"On", nil);
            } else {
                cell.detailTextLabel.text = NSLocalizedString(@"Off", nil);
            }
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        } else if ([indexPath row] == 1) {
            cell.textLabel.text = NSLocalizedString(@"Speakerphone Mode", nil);
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            UISwitch *speakerPhoneSwitch = MUAudioSwitch();
            speakerPhoneSwitch.on = [defaults boolForKey:@"AudioSpeakerPhoneMode"];
            speakerPhoneSwitch.enabled = YES;
            [speakerPhoneSwitch addTarget:self action:@selector(speakerPhoneModeChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = speakerPhoneSwitch;
        }
    } else if ([indexPath section] == 3) {
        if ([indexPath row] == 0) {
            cell.textLabel.text = NSLocalizedString(@"Low-Delay Encoding", nil);
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            UISwitch *celtSwitch = MUAudioSwitch();
            celtSwitch.on = [defaults boolForKey:@"AudioOpusLowDelay"];
            celtSwitch.enabled = YES;
            [celtSwitch addTarget:self action:@selector(opusCodecForceCELTModeChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = celtSwitch;
        }
    }
    
    return cell;
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return NSLocalizedString(@"Transmission Quality", nil);
    } else if (section == 1) {
        return NSLocalizedString(@"Audio Input", nil);
    } else if (section == 2) {
        return NSLocalizedString(@"Audio Output", nil);
    } else if (section == 3) {
        return NSLocalizedString(@"Opus Codec", nil);
    }
    return nil;
}

- (NSString *) tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 1 && [[NSUserDefaults standardUserDefaults] boolForKey:@"AudioPreprocessor"]) {
        return NSLocalizedString(@"iOS handles echo cancellation, noise reduction and microphone level. You can choose a microphone mode before connecting. Availability depends on your device and audio route.", nil);
    }
    if (section == 3) {
        return NSLocalizedString(@"Leave off for speech. Low-delay encoding trades voice optimization for a shorter codec delay.", nil);
    }
    return nil;
}

#pragma mark - Table view delegate

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([indexPath section] == 0 && [indexPath row] == 0) {
        MUAudioQualityPreferencesViewController *audioQual = [[MUAudioQualityPreferencesViewController alloc] init];
        [self.navigationController pushViewController:audioQual animated:YES];
    } else if (indexPath.section==1 && indexPath.row==1 && [[NSUserDefaults standardUserDefaults] boolForKey:@"AudioPreprocessor"]) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [AVCaptureDevice showSystemUserInterface:AVCaptureSystemUserInterfaceMicrophoneModes];
    } else if ([indexPath section] == 2 && [indexPath row] == 0) {
        MUAudioSidetonePreferencesViewController *sidetonePrefs = [[MUAudioSidetonePreferencesViewController alloc] init];
        [self.navigationController pushViewController:sidetonePrefs animated:YES];
    }
}

#pragma mark - Actions

- (void) preprocessingChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"AudioPreprocessor"];
    [(MUApplicationDelegate *)UIApplication.sharedApplication.delegate reloadPreferences];
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
}

- (void) micBoostChanged:(UISlider *)sender {
    [[NSUserDefaults standardUserDefaults] setFloat:sender.value forKey:@"AudioMicBoost"];
    if (sender.value > 1.0f) {
        [sender setMinimumTrackTintColor:UIColor.systemRedColor];
    } else {
        [sender setMinimumTrackTintColor:UIColor.systemGreenColor];
    }
}

- (void) speakerPhoneModeChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"AudioSpeakerPhoneMode"];
}

- (void) opusCodecForceCELTModeChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"AudioOpusLowDelay"];
}

- (void) audioSubsystemRestarted:(NSNotification *)notification {
    [self refreshMicrophoneMode];
}

@end
