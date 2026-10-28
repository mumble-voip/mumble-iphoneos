#import "MUInterface.h"
// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUVoiceActivitySetupViewController.h"
#import "MUApplicationDelegate.h"
#import "MUConnectionController.h"
#import "MUAudioBarViewCell.h"
#import "MLClient.h"
#import "MUImage.h"

@implementation MUVoiceActivitySetupViewController

- (id) init {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        self.preferredContentSize = CGSizeMake(320, 480);
    }
    return self;
}

#pragma mark - View lifecycle

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    MUConfigureTable(self.tableView);
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    
    self.navigationItem.title = NSLocalizedString(@"Voice Activity", nil);
    
    self.tableView.backgroundView = nil;
    
    {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    }
    
    self.tableView.scrollEnabled = YES;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 72;

    MUApplicationDelegate *delegate = (MUApplicationDelegate *)[UIApplication sharedApplication].delegate;
    [delegate reloadPreferences];
    if (![[MLAudio sharedAudio] isRunning]) {
        [[MLAudio sharedAudio] start];
    }
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (![MUConnectionController sharedController].hasActiveSession) {
        [[MLAudio sharedAudio] stop];
    }
}

#pragma mark - Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"AudioPreprocessor"])
        return 2;
    return 3;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"AudioPreprocessor"])
        ++section;

    if (section == 0)
        return 2;
    if (section == 1)
        return 1;
    if (section == 2)
        return 3;
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        MUConfigureStandardCell(cell);
    }
    
    NSString *current = [[NSUserDefaults standardUserDefaults] stringForKey:@"AudioVADKind"];
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.textColor = [UIColor labelColor];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    
    NSInteger section = [indexPath section];
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"AudioPreprocessor"])
        ++section;
    
    if (section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = NSLocalizedString(@"Amplitude", @"Amplitude voice-activity mode");
            if ([current isEqualToString:@"amplitude"]) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            }
        } else if (indexPath.row == 1) {
            cell.textLabel.text = NSLocalizedString(@"Signal to Noise", @"SNR voice-activity mode");
            if ([current isEqualToString:@"snr"]) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            }
        }
    } else if (section == 1) {
        if (indexPath.row == 0) {
            MUAudioBarViewCell *cell = [[MUAudioBarViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"AudioBarCell"];
            MUConfigureStandardCell(cell);
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            return cell;
        }
    } else if (section == 2) {
        if (indexPath.row < 2) {
            NSString *title = indexPath.row == 0 ? NSLocalizedString(@"Silence Below", nil) : NSLocalizedString(@"Speech Above", nil);
            UILabel *label = [UILabel new]; label.text = title;
            label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
            label.adjustsFontForContentSizeCategory = YES; label.numberOfLines = 0;
            UISlider *slider = [UISlider new]; slider.accessibilityLabel = title;
            slider.value = [NSUserDefaults.standardUserDefaults floatForKey:indexPath.row == 0 ? @"AudioVADBelow" : @"AudioVADAbove"];
            [slider addTarget:self action:indexPath.row == 0 ? @selector(vadBelowChanged:) : @selector(vadAboveChanged:) forControlEvents:UIControlEventValueChanged];
            UITableViewCell *sliderCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            MUConfigureStandardCell(sliderCell);
            sliderCell.selectionStyle = UITableViewCellSelectionStyleNone;
            sliderCell.contentView.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(12, 20, 12, 20);
            UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[label, slider]];
            stack.axis = UILayoutConstraintAxisVertical; stack.spacing = 4; stack.translatesAutoresizingMaskIntoConstraints = NO;
            [sliderCell.contentView addSubview:stack];
            UILayoutGuide *margins = sliderCell.contentView.layoutMarginsGuide;
            [NSLayoutConstraint activateConstraints:@[
                [stack.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor], [stack.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor],
                [stack.topAnchor constraintEqualToAnchor:margins.topAnchor], [stack.bottomAnchor constraintEqualToAnchor:margins.bottomAnchor],
                [slider.heightAnchor constraintGreaterThanOrEqualToConstant:44]
            ]];
            return sliderCell;
        } else if (indexPath.row == 2) {
            cell.accessoryView = nil;
            cell.textLabel.text = NSLocalizedString(@"Help", nil);
        }
    }    
    return cell;
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"AudioPreprocessor"])
        ++section;

    if (section == 0) {
        return NSLocalizedString(@"Method", nil);
    } else if (section == 1) {
        return NSLocalizedString(@"Configuration", nil);
    }
    return nil;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = nil;

    NSInteger section = [indexPath section];
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"AudioPreprocessor"])
        ++section;

    // Transmission setting change
    if (section == 0) {
        for (int i = 0; i < 2; i++) {
            cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:indexPath.section]];
            cell.accessoryView = nil;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.textLabel.textColor = [UIColor labelColor];
        }
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        if (indexPath.row == 0) {
            [[NSUserDefaults standardUserDefaults] setObject:@"amplitude" forKey:@"AudioVADKind"];
        } else if (indexPath.row == 1) {
            [[NSUserDefaults standardUserDefaults] setObject:@"snr" forKey:@"AudioVADKind"];
        }
        cell = [self.tableView cellForRowAtIndexPath:indexPath];
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        cell.textLabel.textColor = [UIColor labelColor];
        [self applyDetectionPreferences];
    }
    
    if (section == 2 && [indexPath row] == 2) {
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        
        NSString *title = NSLocalizedString(@"Voice Activity Help", nil);
        NSString *msg = NSLocalizedString(@"To calibrate the voice activity correctly, adjust the sliders so that:\n\n"
                                          @"1. The first few utterances you make are inside the green area.\n"
                                          @"2. While talking, the bar should stay inside the yellow area.\n"
                                          @"3. When not speaking, the bar should stay inside the red area.",
                                                @"Help text for Voice Activity");
        
        UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                                           message:msg
                                                                    preferredStyle:UIAlertControllerStyleAlert];
        
        [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                       style:UIAlertActionStyleCancel
                                                     handler: nil]];
        
        [self presentViewController:alertCtrl animated:YES completion:nil];
    }
}

#pragma mark - Actions

- (void) vadBelowChanged:(UISlider *)sender {
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:[sender value]] forKey:@"AudioVADBelow"];
    [self applyDetectionPreferences];
}

- (void) vadAboveChanged:(UISlider *)sender {
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:[sender value]] forKey:@"AudioVADAbove"];
    [self applyDetectionPreferences];
}

- (void) applyDetectionPreferences {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    MLAudio *audio = MLAudio.sharedAudio;
    MLAudioSettings settings;
    [audio readAudioSettings:&settings];
    settings.vadKind = [[defaults stringForKey:@"AudioVADKind"] isEqualToString:@"snr"] ? MLVADKindSignalToNoise : MLVADKindAmplitude;
    settings.vadMin = [defaults floatForKey:@"AudioVADBelow"];
    settings.vadMax = [defaults floatForKey:@"AudioVADAbove"];
    [audio updateAudioSettings:&settings];
}

@end
