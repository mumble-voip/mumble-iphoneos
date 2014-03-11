// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUAudioQualityPreferencesViewController.h"
#import "MUTableViewHeaderLabel.h"
#import "MUColor.h"
#import "MUImage.h"
#import "MUOperatingSystem.h"
#import "MUBackgroundView.h"

@implementation MUAudioQualityPreferencesViewController

- (id) init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        self.contentSizeForViewInPopover = CGSizeMake(320, 480);
    }
    return self;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.title = NSLocalizedString(@"Audio Quality", nil);
    
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
    return 1;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 3;
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"MUAudioQualityPreferencesCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    cell.selectionStyle = UITableViewCellSelectionStyleGray;
    cell.accessoryView = nil;
    
    if ([indexPath section] == 0) {
        if ([indexPath row] == 0) {
            cell.textLabel.text = NSLocalizedString(@"Low", nil);
            cell.detailTextLabel.text = NSLocalizedString(@"16 kbit/s, 60 ms audio per packet", nil);
            if ([[defaults stringForKey:@"AudioQualityKind"] isEqualToString:@"low"]) {
                cell.accessoryView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"GrayCheckmark"]] autorelease];
                cell.textLabel.textColor = [MUColor selectedTextColor];
            }
        } else if ([indexPath row] == 1) {
            cell.textLabel.text = NSLocalizedString(@"Balanced", nil);
            cell.detailTextLabel.text = NSLocalizedString(@"40 kbit/s, 20 ms audio per packet", nil);
            if ([[defaults stringForKey:@"AudioQualityKind"] isEqualToString:@"balanced"]) {
                cell.accessoryView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"GrayCheckmark"]] autorelease];
                cell.textLabel.textColor = [MUColor selectedTextColor];
            }
        } else if ([indexPath row] == 2) {
            cell.textLabel.text = NSLocalizedString(@"High", nil);
            cell.detailTextLabel.text = NSLocalizedString(@"72 kbit/s, 10 ms audio per packet", nil);
            if ([[defaults stringForKey:@"AudioQualityKind"] isEqualToString:@"high"]) {
                cell.accessoryView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"GrayCheckmark"]] autorelease];
                cell.textLabel.textColor = [MUColor selectedTextColor];
            }
        } else if ([indexPath row] == 3) {
            cell.textLabel.text = NSLocalizedString(@"Custom", nil);
            cell.detailTextLabel.text = nil;
            if ([[defaults stringForKey:@"AudioQualityKind"] isEqualToString:@"custom"]) {
                cell.accessoryView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"GrayCheckmark"]] autorelease];
                cell.textLabel.textColor = [MUColor selectedTextColor];
            }
        }
    }
    
    return cell;
}

- (UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == 0) { // Input
        return [MUTableViewHeaderLabel labelWithText:NSLocalizedString(@"Quality Presets", nil)];
    } else if (section == 1) {
        return [MUTableViewHeaderLabel labelWithText:NSLocalizedString(@"Custom Quality", nil)];
    } else {
        return nil;
    }
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return [MUTableViewHeaderLabel defaultHeaderHeight];
    } else if (section == 1) {
        return [MUTableViewHeaderLabel defaultHeaderHeight];
    }
    return 0.0f;
}

#pragma mark - Table view delegate

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    UITableViewCell *cell = nil;
    int nsects = 3;
    for (int i = 0; i <= nsects; i++) {
        cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
        cell.accessoryView = nil;
        cell.textLabel.textColor = [UIColor blackColor];
    }
    cell = [self.tableView cellForRowAtIndexPath:indexPath];
    cell.accessoryView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"GrayCheckmark"]] autorelease];
    cell.textLabel.textColor = [MUColor selectedTextColor];
    NSString *val = nil;
    switch ([indexPath row]) {
        case 0: val = @"low"; break;
        case 1: val = @"balanced"; break;
        case 2: val = @"high"; break;
        case 3: val = @"custom"; break;
    }
    if (val != nil)
        [[NSUserDefaults standardUserDefaults] setObject:val forKey:@"AudioQualityKind"];
}

@end
