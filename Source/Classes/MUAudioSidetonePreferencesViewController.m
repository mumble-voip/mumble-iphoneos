#import "MUInterface.h"
// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUAudioSidetonePreferencesViewController.h"
#import "MUImage.h"

@implementation MUAudioSidetonePreferencesViewController

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
    
    self.title = NSLocalizedString(@"Sidetone", nil);
    
    self.tableView.backgroundView = nil;
    
    {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    }

    self.tableView.scrollEnabled = YES;
}

#pragma mark - Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2;
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"MUAudioSidetonePreferencesCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        MUConfigureStandardCell(cell);
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    if ([indexPath section] == 0) {
        if ([indexPath row] == 0) {
            cell.textLabel.text = NSLocalizedString(@"Enable Sidetone", nil);
            UISwitch *sidetoneSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(0, 0, 51, 31)];
            [sidetoneSwitch addTarget:self action:@selector(sidetoneStatusChanged:) forControlEvents:UIControlEventValueChanged];
            [sidetoneSwitch setOn:[defaults boolForKey:@"AudioSidetone"]];
            cell.accessoryView = sidetoneSwitch;
        } else if ([indexPath row] == 1) {
            UITableViewCell *volumeCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            volumeCell.selectionStyle = UITableViewCellSelectionStyleNone;
            UILabel *label = [UILabel new]; label.text = NSLocalizedString(@"Playback Volume", nil);
            label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody]; label.adjustsFontForContentSizeCategory = YES; label.numberOfLines = 0;
            UISlider *slider = [UISlider new]; slider.accessibilityLabel = label.text;
            slider.enabled = [defaults boolForKey:@"AudioSidetone"]; slider.value = [defaults floatForKey:@"AudioSidetoneVolume"];
            [slider addTarget:self action:@selector(sidetoneVolumeChanged:) forControlEvents:UIControlEventValueChanged];
            UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[label, slider]];
            stack.axis = UILayoutConstraintAxisVertical; stack.spacing = 4; stack.translatesAutoresizingMaskIntoConstraints = NO;
            [volumeCell.contentView addSubview:stack]; UILayoutGuide *margins = volumeCell.contentView.layoutMarginsGuide;
            [NSLayoutConstraint activateConstraints:@[
                [stack.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor], [stack.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor],
                [stack.topAnchor constraintEqualToAnchor:margins.topAnchor], [stack.bottomAnchor constraintEqualToAnchor:margins.bottomAnchor],
                [slider.heightAnchor constraintGreaterThanOrEqualToConstant:44]
            ]];
            return volumeCell;
        }
    }
    
    return cell;
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return NSLocalizedString(@"Sidetone Feedback", nil);
    }
    return nil;
}

#pragma mark - Actions

- (void) sidetoneStatusChanged:(UISwitch *)sidetoneSwitch {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:[sidetoneSwitch isOn] forKey:@"AudioSidetone"];
    [[self tableView] reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:1 inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
}

- (void) sidetoneVolumeChanged:(UISlider *)sidetoneSlider {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setFloat:[sidetoneSlider value] forKey:@"AudioSidetoneVolume"];
}

@end
