/* Copyright (C) 2012 Mikkel Krautz <mikkel@krautz.dk>

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

#import "MURemoteControlPreferencesViewController.h"
#import "MURemoteControlServer.h"

@interface MURemoteControlPreferencesViewController () {
}
@end

@implementation MURemoteControlPreferencesViewController

- (id) init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
    }
    return self;
}

#pragma mark - View controller life cycle

- (void) viewWillAppear:(BOOL)animated {
    self.navigationItem.title = NSLocalizedString(@"Remote Control", nil);
    self.tableView.backgroundView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"BackgroundTextureBlackGradient"]] autorelease];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.scrollEnabled = NO;
}

#pragma mark - Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 1;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"RemoteControlPrefsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Enable";
            UISwitch *enableSwitch = [[[UISwitch alloc] initWithFrame:CGRectZero] autorelease];
            [enableSwitch addTarget:self action:@selector(enableSwitchChanged:) forControlEvents:UIControlEventValueChanged];
            enableSwitch.on = [[MURemoteControlServer sharedRemoteControlServer] isRunning];
            enableSwitch.onTintColor = [UIColor blackColor];
            cell.accessoryView = enableSwitch;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
    }

    return cell;
}



#pragma mark - Table view delegate

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
}

#pragma mark - Action

- (void) enableSwitchChanged:(id)sender {
    UISwitch *enableSwitch = sender;
    MURemoteControlServer *server = [MURemoteControlServer sharedRemoteControlServer];
    [[NSUserDefaults standardUserDefaults] setBool:enableSwitch.isOn forKey:@"RemoteControlServerEnabled"];
    if (enableSwitch.isOn) {
        BOOL on = [server start];
        if (!on) {
            enableSwitch.on = NO;
        }
    } else {
        [server stop];
    }
}

@end
