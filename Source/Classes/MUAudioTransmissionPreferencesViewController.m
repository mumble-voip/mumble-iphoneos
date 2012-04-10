/* Copyright (C) 2009-2011 Mikkel Krautz <mikkel@krautz.dk>

   All rights reserved.

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions
   are met:

   - Redistributions of source code must retain the above copyright notice,
     this list of conditions and the following disclaimer.
   - Redistributions in binary form must reproduce the above copyright notice,
     this list of conditions and the following disclaimer in the documentation
     and/or other materials provided with the distribution.
   - Neither the name of the Mumble Developers nor the names of its
     contributors may be used to endorse or promote products derived from this
     software without specific prior written permission.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
   ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
   A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR
   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "MUAudioTransmissionPreferencesViewController.h"
#import "MUVoiceActivitySetupViewController.h"
#import "MUTableViewHeaderLabel.h"
#import "MUAudioBarViewCell.h"
#import "MUColor.h"

@interface MUAudioTransmissionPreferencesViewController () {
}
@end

@implementation MUAudioTransmissionPreferencesViewController

- (id) init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        self.contentSizeForViewInPopover = CGSizeMake(320, 480);
    }
    return self;
}

- (void) didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - View lifecycle

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.tableView.backgroundView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"BackgroundTextureBlackGradient"]] autorelease];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.scrollEnabled = NO;
    self.title = NSLocalizedString(@"Transmission", nil);
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSString *current = [[NSUserDefaults standardUserDefaults] stringForKey:@"AudioTransmitMethod"];
    if (section == 0) {
        return 3;
    } else if (section == 1) {
        if ([current isEqualToString:@"vad"])
            return 1;
        if ([current isEqualToString:@"ptt"])
            return 2;
    }
    return 0;
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"AudioXmitOptionCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
    NSString *current = [[NSUserDefaults standardUserDefaults] stringForKey:@"AudioTransmitMethod"];
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.textColor = [UIColor blackColor];
    cell.selectionStyle = UITableViewCellSelectionStyleGray;
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = NSLocalizedString(@"Voice Activated", nil);
            if ([current isEqualToString:@"vad"]) {
                cell.accessoryView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"GrayCheckmark"]] autorelease];
                cell.textLabel.textColor = [MUColor selectedTextColor];
            }
        } else if (indexPath.row == 1) {
            cell.textLabel.text = NSLocalizedString(@"Push-to-talk", nil);
            if ([current isEqualToString:@"ptt"]) {
                cell.accessoryView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"GrayCheckmark"]] autorelease];
                cell.textLabel.textColor = [MUColor selectedTextColor];
            }
        } else if (indexPath.row == 2) {
            cell.textLabel.text = NSLocalizedString(@"Continuous", nil);
            if ([current isEqualToString:@"continuous"]) {
                cell.accessoryView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"GrayCheckmark"]] autorelease];
                cell.textLabel.textColor = [MUColor selectedTextColor];
            }
        }
    } else if (indexPath.section == 1) {
        if ([current isEqualToString:@"vad"]) {
            if (indexPath.row == 0) {
                cell.accessoryView = nil;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.textLabel.text = NSLocalizedString(@"Voice Activity Configuration", nil);
            }
        } else if ([current isEqualToString:@"ptt"]) {
            if (indexPath.row == 0) {
                cell.accessoryView = nil;
                cell.textLabel.text = NSLocalizedString(@"Only in Channel View", nil);
                cell.textLabel.textColor = [UIColor blackColor];
                if ([[NSUserDefaults standardUserDefaults] boolForKey:@"PTTButtonOnlyInChannelView"]) {
                    cell.accessoryView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"GrayCheckmark"]] autorelease];
                    cell.textLabel.textColor = [MUColor selectedTextColor];
                }
            } else if (indexPath.row == 1) {
                cell.accessoryView = nil;
                cell.textLabel.text = NSLocalizedString(@"Both in Server and Channel View", nil);
                cell.textLabel.textColor = [UIColor blackColor];
                if (![[NSUserDefaults standardUserDefaults] boolForKey:@"PTTButtonOnlyInChannelView"]) {
                    cell.accessoryView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"GrayCheckmark"]] autorelease];
                    cell.textLabel.textColor = [MUColor selectedTextColor];
                }
            }
        }
    }

    return cell;
}

- (UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *current = [[NSUserDefaults standardUserDefaults] stringForKey:@"AudioTransmitMethod"];
    if (section == 0) {
        return [MUTableViewHeaderLabel labelWithText:NSLocalizedString(@"Method", nil)];
    }
    if (section == 1 && [current isEqualToString:@"ptt"]) {
        return [MUTableViewHeaderLabel labelWithText:NSLocalizedString(@"Show Push-to-Talk Button", nil)];
    }
    return nil;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    NSString *current = [[NSUserDefaults standardUserDefaults] stringForKey:@"AudioTransmitMethod"];
    if (section == 1 && [current isEqualToString:@"vad"]) {
        return 0.0f;
    }

    return [MUTableViewHeaderLabel defaultHeaderHeight];
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = nil;

    // Transmission setting change
    if (indexPath.section == 0) {
        for (int i = 0; i < 3; i++) {
            cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
            cell.accessoryView = nil;
            cell.textLabel.textColor = [UIColor blackColor];
        }

        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        
        if (indexPath.row == 0) {
            [[NSUserDefaults standardUserDefaults] setObject:@"vad" forKey:@"AudioTransmitMethod"];
        } else if (indexPath.row == 1) {
            [[NSUserDefaults standardUserDefaults] setObject:@"ptt" forKey:@"AudioTransmitMethod"];
        } else if (indexPath.row == 2) {
            [[NSUserDefaults standardUserDefaults] setObject:@"continuous" forKey:@"AudioTransmitMethod"];
        }

        [self.tableView reloadSectionIndexTitles];
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationFade];
        
        cell = [self.tableView cellForRowAtIndexPath:indexPath];
        cell.accessoryView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"GrayCheckmark"]] autorelease];
        cell.textLabel.textColor = [MUColor selectedTextColor];

    } else if (indexPath.section == 1) {
        NSString *current = [[NSUserDefaults standardUserDefaults] stringForKey:@"AudioTransmitMethod"];
        if ([current isEqualToString:@"vad"]) {
            if (indexPath.row == 0) {
                MUVoiceActivitySetupViewController *vadSetup = [[MUVoiceActivitySetupViewController alloc] init];
                [self.navigationController pushViewController:vadSetup animated:YES];
                [vadSetup release];
            }
        } else if ([current isEqualToString:@"ptt"]) {
            for (int i = 0; i < 2; i++) {
                cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:1]];
                cell.accessoryView = nil;
                cell.textLabel.textColor = [UIColor blackColor];
            }
            
            cell = [self.tableView cellForRowAtIndexPath:indexPath];
            cell.textLabel.textColor = [MUColor selectedTextColor];
            cell.accessoryView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"GrayCheckmark"]] autorelease];
            
            BOOL onlyInChannelView = [indexPath row] == 0;
            [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:onlyInChannelView] forKey:@"PTTButtonOnlyInChannelView"];
            
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        }
    }
}

@end
