// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUVoiceActivitySetupViewController.h"
#import "MUTableViewHeaderLabel.h"
#import "MUAudioBarViewCell.h"
#import "MUColor.h"
#import "MUImage.h"
#import "MUOperatingSystem.h"
#import "MUBackgroundView.h"

@implementation MUVoiceActivitySetupViewController

- (id) init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        self.preferredContentSize = CGSizeMake(320, 480);
    }
    return self;
}

#pragma mark - View lifecycle

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationItem.title = NSLocalizedString(@"Voice Activity", nil);
    
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
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
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
    }
    
    NSString *current = [[NSUserDefaults standardUserDefaults] stringForKey:@"AudioVADKind"];
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.textColor = [UIColor blackColor];
    cell.selectionStyle = UITableViewCellSelectionStyleGray;
    
    NSInteger section = [indexPath section];
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"AudioPreprocessor"])
        ++section;
    
    if (section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = NSLocalizedString(@"Amplitude", @"Amplitude voice-activity mode");
            if ([current isEqualToString:@"amplitude"]) {
                cell.accessoryView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"GrayCheckmark"]];
                cell.textLabel.textColor = [MUColor selectedTextColor];
            }
        } else if (indexPath.row == 1) {
            cell.textLabel.text = NSLocalizedString(@"Signal to Noise", @"SNR voice-activity mode");
            if ([current isEqualToString:@"snr"]) {
                cell.accessoryView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"GrayCheckmark"]];
                cell.textLabel.textColor = [MUColor selectedTextColor];
            }
        }
    } else if (section == 1) {
        if (indexPath.row == 0) {
            MUAudioBarViewCell *cell = [[MUAudioBarViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"AudioBarCell"];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            return cell;
        }
    } else if (section == 2) {
        if (indexPath.row == 0) {
            cell.textLabel.text = NSLocalizedString(@"Silence Below", @"Silence Below VAD configuration");
            UISlider *slider = [[UISlider alloc] init];
            [slider setMinimumValue:0.0f];
            [slider setMaximumValue:1.0f];
            [slider addTarget:self action:@selector(vadBelowChanged:) forControlEvents:UIControlEventValueChanged];
            [slider setValue:[[[NSUserDefaults standardUserDefaults] objectForKey:@"AudioVADBelow"] floatValue]];
            [slider setMaximumTrackTintColor:[UIColor whiteColor]];
            [slider setMinimumTrackTintColor:[MUColor badPingColor]];
            cell.accessoryView = slider;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else if (indexPath.row == 1) {
            cell.textLabel.text = NSLocalizedString(@"Speech Above", @"Silence Above VAD configuration");
            UISlider *slider = [[UISlider alloc] init];
            [slider setMinimumValue:0.0f];
            [slider setMaximumValue:1.0f];
            [slider addTarget:self action:@selector(vadAboveChanged:) forControlEvents:UIControlEventValueChanged];
            [slider setValue:[[[NSUserDefaults standardUserDefaults] objectForKey:@"AudioVADAbove"] floatValue]];
            [slider setMaximumTrackTintColor:[MUColor goodPingColor]];
            [slider setMinimumTrackTintColor:[UIColor whiteColor]];
            cell.accessoryView = slider;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else if (indexPath.row == 2) {
            cell.accessoryView = nil;
            cell.textLabel.text = NSLocalizedString(@"Help", nil);
        }
    }    
    return cell;
}

- (UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"AudioPreprocessor"])
        ++section;

    if (section == 0) {
        return [MUTableViewHeaderLabel labelWithText:NSLocalizedString(@"Method", nil)];
    } else if (section == 1) {
        return [MUTableViewHeaderLabel labelWithText:NSLocalizedString(@"Configuration", nil)];
    }
    return nil;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"AudioPreprocessor"])
        ++section;

    if (section == 0) {
        return [MUTableViewHeaderLabel defaultHeaderHeight];
    } else if (section == 1) {
        return [MUTableViewHeaderLabel defaultHeaderHeight];
    }
    return 0.0f;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = nil;

    NSInteger section = [indexPath section];
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"AudioPreprocessor"])
        ++section;

    // Transmission setting change
    if (section == 0) {
        for (int i = 0; i < 2; i++) {
            cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
            cell.accessoryView = nil;
            cell.textLabel.textColor = [UIColor blackColor];
        }
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        if (indexPath.row == 0) {
            [[NSUserDefaults standardUserDefaults] setObject:@"amplitude" forKey:@"AudioVADKind"];
        } else if (indexPath.row == 1) {
            [[NSUserDefaults standardUserDefaults] setObject:@"snr" forKey:@"AudioVADKind"];
        }
        cell = [self.tableView cellForRowAtIndexPath:indexPath];
        cell.accessoryView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"GrayCheckmark"]];
        cell.textLabel.textColor = [MUColor selectedTextColor];
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
}

- (void) vadAboveChanged:(UISlider *)sender {
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:[sender value]] forKey:@"AudioVADAbove"];
}

@end
