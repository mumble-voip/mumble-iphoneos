// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUAudioTransmissionPreferencesViewController.h"
#import "MUVoiceActivitySetupViewController.h"
#import "MUApplicationDelegate.h"
#import "MUInterface.h"

@interface MUAudioTransmissionPreferencesViewController () {
}
@end

@implementation MUAudioTransmissionPreferencesViewController

- (id) init {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        self.preferredContentSize = CGSizeMake(320, 480);
        self.title = NSLocalizedString(@"Transmission", nil);
        self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 52;
    // Measure the short settings sections before the first frame, not after a selection.
    self.tableView.estimatedSectionHeaderHeight = 0;
    self.tableView.estimatedSectionFooterHeight = 0;
}

#pragma mark - View lifecycle

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.title = NSLocalizedString(@"Transmission", nil);
    
    self.tableView.backgroundView = nil;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tableView.scrollEnabled = YES;
}

#pragma mark - Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    NSString *current = [[NSUserDefaults standardUserDefaults] stringForKey:@"AudioTransmitMethod"];
    return [current isEqualToString:@"vad"] ? 2 : 1;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 3;
    }
    return 1;
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"AudioXmitOptionCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        MUConfigureStandardCell(cell);
    }
    
    NSString *current = [[NSUserDefaults standardUserDefaults] stringForKey:@"AudioTransmitMethod"];
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.textColor = [UIColor labelColor];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    if (indexPath.section == 0) {
        NSString *title = nil;
        NSString *method = nil;
        if (indexPath.row == 0) {
            title = NSLocalizedString(@"Voice Activated", nil);
            method = @"vad";
        } else if (indexPath.row == 1) {
            title = NSLocalizedString(@"Push-to-talk", nil);
            method = @"ptt";
        } else if (indexPath.row == 2) {
            title = NSLocalizedString(@"Continuous", nil);
            method = @"continuous";
        }
        cell.textLabel.text = title;
        if ([current isEqualToString:method]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
    } else if (indexPath.section == 1) {
        cell.textLabel.text = NSLocalizedString(@"Voice Activity", nil);
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    return cell;
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return NSLocalizedString(@"Method", nil);
    }
    return nil;
}

- (NSString *) tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section != 0) {
        return nil;
    }
    NSString *current = [[NSUserDefaults standardUserDefaults] stringForKey:@"AudioTransmitMethod"];
    if ([current isEqualToString:@"vad"]) {
        return NSLocalizedString(@"Mumble transmits when it senses you talking. Adjust the sensitivity below.", nil);
    }
    if ([current isEqualToString:@"ptt"]) {
        return NSLocalizedString(@"Touch the microphone button to speak while connected to a server.", nil);
    }
    return NSLocalizedString(@"Mumble continuously transmits all recorded audio.", nil);
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        NSString *previous = [[NSUserDefaults standardUserDefaults] stringForKey:@"AudioTransmitMethod"];
        NSString *method = @"vad";
        if (indexPath.row == 1) {
            method = @"ptt";
        } else if (indexPath.row == 2) {
            method = @"continuous";
        }
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        if ([previous isEqualToString:method]) return;
        BOOL wasVad = [previous isEqualToString:@"vad"];
        BOOL isVad = [method isEqualToString:@"vad"];
        [(MUApplicationDelegate *)UIApplication.sharedApplication.delegate setAudioTransmitMethod:method];
        // Keep the tapped cell alive so UIKit can finish its selection fade.
        for (NSIndexPath *visible in tableView.indexPathsForVisibleRows) {
            if (visible.section == 0) [tableView cellForRowAtIndexPath:visible].accessoryType = visible.row == indexPath.row ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        }
        [tableView footerViewForSection:0].textLabel.text = [self tableView:tableView titleForFooterInSection:0];
        [tableView performBatchUpdates:^{
            if (wasVad != isVad) {
                NSIndexSet *voiceActivity = [NSIndexSet indexSetWithIndex:1];
                if (isVad) [tableView insertSections:voiceActivity withRowAnimation:UITableViewRowAnimationFade];
                else [tableView deleteSections:voiceActivity withRowAnimation:UITableViewRowAnimationFade];
            }
        } completion:nil];
    } else if (indexPath.section == 1) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        MUVoiceActivitySetupViewController *vadSetup = [[MUVoiceActivitySetupViewController alloc] init];
        [self.navigationController pushViewController:vadSetup animated:YES];
    }
}

@end
