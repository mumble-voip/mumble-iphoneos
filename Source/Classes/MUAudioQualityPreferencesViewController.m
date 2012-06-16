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

#import "MUAudioQualityPreferencesViewController.h"
#import "MUTableViewHeaderLabel.h"
#import "MUColor.h"

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
    self.tableView.backgroundView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"BackgroundTextureBlackGradient"]] autorelease];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
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
            cell.detailTextLabel.text = NSLocalizedString(@"Speex 16kbit/s, 60ms audio per packet", nil);
            if ([[defaults stringForKey:@"AudioQualityKind"] isEqualToString:@"low"]) {
                cell.accessoryView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"GrayCheckmark"]] autorelease];
                cell.textLabel.textColor = [MUColor selectedTextColor];
            }
        } else if ([indexPath row] == 1) {
            cell.textLabel.text = NSLocalizedString(@"Balanced", nil);
            cell.detailTextLabel.text = NSLocalizedString(@"Opus 40kbit/s, 20ms audio per packet", nil);
            if ([[defaults stringForKey:@"AudioQualityKind"] isEqualToString:@"balanced"]) {
                cell.accessoryView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"GrayCheckmark"]] autorelease];
                cell.textLabel.textColor = [MUColor selectedTextColor];
            }
        } else if ([indexPath row] == 2) {
            cell.textLabel.text = NSLocalizedString(@"High", nil);
            cell.detailTextLabel.text = NSLocalizedString(@"Opus 72kbit/s, 10ms audio per packet", nil);
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
