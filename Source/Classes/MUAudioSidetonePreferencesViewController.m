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

#import "MUAudioSidetonePreferencesViewController.h"
#import "MUTableViewHeaderLabel.h"
#import "MUColor.h"
#import "MUImage.h"

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
    self.tableView.backgroundView = [[[UIImageView alloc] initWithImage:[MUImage imageNamed:@"BackgroundTextureBlackGradient"]] autorelease];
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
