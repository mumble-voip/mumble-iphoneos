// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUAudioSidetonePreferencesViewController.h"
#import "MUTableViewHeaderLabel.h"
#import "MUColor.h"
#import "MUImage.h"
#import "MUOperatingSystem.h"
#import "MUBackgroundView.h"

@implementation MUAudioSidetonePreferencesViewController

- (id) init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        self.contentSizeForViewInPopover = CGSizeMake(320, 480);
    }
    return self;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.title = NSLocalizedString(@"Sidetone", nil);

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
    return 2;
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"MUAudioSidetonePreferencesCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    cell.selectionStyle = UITableViewCellSelectionStyleGray;
    cell.accessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    if ([indexPath section] == 0) {
        if ([indexPath row] == 0) {
            cell.textLabel.text = NSLocalizedString(@"Enable Sidetone", nil);
            UISwitch *sidetoneSwitch = [[UISwitch alloc] init];
            [sidetoneSwitch setOnTintColor:[UIColor blackColor]];
            [sidetoneSwitch addTarget:self action:@selector(sidetoneStatusChanged:) forControlEvents:UIControlEventValueChanged];
            [sidetoneSwitch setOn:[defaults boolForKey:@"AudioSidetone"]];
            cell.accessoryView = sidetoneSwitch;
            [sidetoneSwitch release];
        } else if ([indexPath row] == 1) {
            NSLog(@"reloadin' (enabled? %u)", [defaults boolForKey:@"AudioSidetone"]);
            cell.textLabel.text = NSLocalizedString(@"Playback Volume", nil);
            UISlider *sidetoneSlider = [[UISlider alloc] init];
            [sidetoneSlider addTarget:self action:@selector(sidetoneVolumeChanged:) forControlEvents:UIControlEventValueChanged];
            [sidetoneSlider setEnabled:[defaults boolForKey:@"AudioSidetone"]];
            [sidetoneSlider setMinimumValue:0.0f];
            [sidetoneSlider setMaximumValue:1.0f];
            [sidetoneSlider setValue:[defaults floatForKey:@"AudioSidetoneVolume"]];
            [sidetoneSlider setMinimumTrackTintColor:[UIColor blackColor]];
            cell.accessoryView = sidetoneSlider;
            [sidetoneSlider release];
        }
    }
    
    return cell;
}

- (UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return [MUTableViewHeaderLabel labelWithText:NSLocalizedString(@"Sidetone Feedback", nil)];
    }
    return nil;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return [MUTableViewHeaderLabel defaultHeaderHeight];
    }
    return 0.0f;
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
