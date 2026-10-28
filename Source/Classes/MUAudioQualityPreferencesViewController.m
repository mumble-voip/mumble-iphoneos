#import "MUInterface.h"
// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUAudioQualityPreferencesViewController.h"
#import "MUApplicationDelegate.h"

@implementation MUAudioQualityPreferencesViewController

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
    
    self.title = NSLocalizedString(@"Audio Quality", nil);
    
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
    return 3;
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"MUAudioQualityPreferencesCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        MUConfigureStandardCell(cell);
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.textColor = [UIColor labelColor];
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    
    NSString *kind = nil;
    if ([indexPath row] == 0) {
        cell.textLabel.text = NSLocalizedString(@"Low", nil);
        cell.detailTextLabel.text = NSLocalizedString(@"16 kbit/s, 60 ms audio per packet", nil);
        kind = @"low";
    } else if ([indexPath row] == 1) {
        cell.textLabel.text = NSLocalizedString(@"Balanced", nil);
        cell.detailTextLabel.text = NSLocalizedString(@"40 kbit/s, 20 ms audio per packet", nil);
        kind = @"balanced";
    } else if ([indexPath row] == 2) {
        cell.textLabel.text = NSLocalizedString(@"High", nil);
        cell.detailTextLabel.text = NSLocalizedString(@"72 kbit/s, 10 ms audio per packet", nil);
        kind = @"high";
    }

    if ([kind isEqualToString:[defaults stringForKey:@"AudioQualityKind"]]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }

    return cell;
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return NSLocalizedString(@"Quality Presets", nil);
}

#pragma mark - Table view delegate

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *val = nil;
    switch ([indexPath row]) {
        case 0: val = @"low"; break;
        case 1: val = @"balanced"; break;
        case 2: val = @"high"; break;
    }
    if (val != nil && ![val isEqualToString:[NSUserDefaults.standardUserDefaults stringForKey:@"AudioQualityKind"]]) {
        [[NSUserDefaults standardUserDefaults] setObject:val forKey:@"AudioQualityKind"];
        [(MUApplicationDelegate *)UIApplication.sharedApplication.delegate reloadPreferences];
    }
    for (NSIndexPath *visible in tableView.indexPathsForVisibleRows)
        [tableView cellForRowAtIndexPath:visible].accessoryType = visible.row == indexPath.row ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
}

@end
