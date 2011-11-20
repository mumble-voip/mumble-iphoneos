/* Copyright (C) 2009-2010 Mikkel Krautz <mikkel@krautz.dk>

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

#import "MUPreferencesViewController.h"
#import "MUApplication.h"
#import "MUApplicationDelegate.h"
#import "MUCertificatePreferencesViewController.h"
#import "MUAudioTransmissionPreferencesViewController.h"
#import "MUDiagnosticsViewController.h"
#import "MUCertificateController.h"
#import "MUColor.h"

#import <MumbleKit/MKCertificate.h>

@interface MUPreferencesViewController () {
    UITextField *_activeTextField;
}
- (void) audioVolumeChanged:(UISlider *)volumeSlider;
- (void) forceTCPChanged:(UISwitch *)tcpSwitch;
@end

@implementation MUPreferencesViewController

#pragma mark -
#pragma mark Initialization

- (id) init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        [self setContentSizeForViewInPopover:CGSizeMake(320, 480)];
    }
    return self;
}

- (void) dealloc {
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[MumbleApp delegate] reloadPreferences];
    [super dealloc];
}

#pragma mark -
#pragma mark Looks

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];

    self.title = @"Preferences";
    [self.tableView reloadData];
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
#ifdef MUMBLE_BETA_DIST
    return 3;
#else
    return 2;
#endif
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Audio
    if (section == 0) {
        return 2;
    // Network
    } else if (section == 1) {
        return 3;
    }
#ifdef MUMBLE_BETA_DIST
    // Beta
    else if (section == 2) {
        return 1;
    }
#endif

    return 0;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"PreferencesCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }

    // Audio section
    if ([indexPath section] == 0) {
        // Volume
        if ([indexPath row] == 0) {
            UISlider *volSlider = [[UISlider alloc] init];
            [volSlider setMaximumValue:1.0f];
            [volSlider setMinimumValue:0.0f];
            [volSlider setValue:[[NSUserDefaults standardUserDefaults] floatForKey:@"AudioOutputVolume"]];
            [[cell textLabel] setText:@"Volume"];
            [cell setAccessoryView:volSlider];
            [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
            [volSlider addTarget:self action:@selector(audioVolumeChanged:) forControlEvents:UIControlEventValueChanged];
            [volSlider release];
        }
        // Transmit method
        if ([indexPath row] == 1) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AudioTransmitCell"];
            if (cell == nil)
                cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"AudioTransmitCell"] autorelease];
            cell.textLabel.text = @"Transmission";
            NSString *xmit = [[NSUserDefaults standardUserDefaults] stringForKey:@"AudioTransmitMethod"];
            if ([xmit isEqualToString:@"vad"]) {
                cell.detailTextLabel.text = @"Voice Activated";
            } else if ([xmit isEqualToString:@"ptt"]) {
                cell.detailTextLabel.text = @"Push-to-talk";
            } else if ([xmit isEqualToString:@"continuous"]) {
                cell.detailTextLabel.text = @"Continuous";
            }
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return cell;
        }

    // Network
    } else if ([indexPath section] == 1) {
        if ([indexPath row] == 0) {
            UISwitch *tcpSwitch = [[UISwitch alloc] init];
            [tcpSwitch setOn:[[NSUserDefaults standardUserDefaults] boolForKey:@"NetworkForceTCP"]];
            [[cell textLabel] setText:@"Force TCP"];
            [cell setAccessoryView:tcpSwitch];
            [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
            [tcpSwitch addTarget:self action:@selector(forceTCPChanged:) forControlEvents:UIControlEventValueChanged];
            [tcpSwitch release];
        } else if ([indexPath row] == 1) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PrefCertificateCell"];
            if (cell == nil)
                cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"PrefCertificateCell"] autorelease];
            MKCertificate *cert = [MUCertificateController defaultCertificate];
            cell.textLabel.text = @"Certificate";
            cell.detailTextLabel.text = cert ? [cert commonName] : @"None";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            return cell;
        } else if ([indexPath row] == 2) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PrefTextFieldCell"];
            if (cell == nil)
                cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"PrefTextFieldCell"] autorelease];
            
            for (UIView *subview in [[cell contentView] subviews]) {
                [subview removeFromSuperview];
            }
            
            [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
            [[cell textLabel] setText:@"Username"];
    
            UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(110.0, 10.0, 185.0, 30.0)];
            [tf setTextColor:[MUColor selectedTextColor]];
            [tf addTarget:self action:@selector(textFieldBeganEditing:) forControlEvents:UIControlEventEditingDidBegin];
            [tf addTarget:self action:@selector(textFieldEndedEditing:) forControlEvents:UIControlEventEditingDidEnd];
            [tf addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
            [tf addTarget:self action:@selector(textFieldDidEndOnExit:) forControlEvents:UIControlEventEditingDidEndOnExit];
            [tf setReturnKeyType:UIReturnKeyDone];
            [tf setAdjustsFontSizeToFitWidth:YES];
            [tf setPlaceholder:@"MumbleUser"];
            [tf setAutocapitalizationType:UITextAutocapitalizationTypeWords];
            [tf setText:[[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultUserName"]];
            [tf setTextAlignment:UITextAlignmentRight];
            [[cell contentView] addSubview:tf];
            [tf release];

            return cell;
        }
    }
#ifdef MUMBLE_BETA_DIST
    // Beta
    else if ([indexPath section] == 2) {
        if ([indexPath row] == 0) {
            cell.textLabel.text = @"Diagnostics";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    }
#endif

    return cell;
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) // Audio
        return @"Audio";
    else if (section == 1) // Network
        return @"Network";
#ifdef MUMBLE_BETA_DIST
    else if (section == 2) // Beta
        return @"Beta";
#endif

    return @"Default";
}

- (NSString *) tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 1) // Network
        return @"This username is the default username used for connections to public and LAN servers.";
    else
        return nil;
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [[self tableView] deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0) { // Audio
        if (indexPath.row == 1) { // Transmission
            MUAudioTransmissionPreferencesViewController *audioXmit = [[MUAudioTransmissionPreferencesViewController alloc] init];
            [self.navigationController pushViewController:audioXmit animated:YES];
            [audioXmit release];
        }
    } else if ([indexPath section] == 1) { // Network
        if ([indexPath row] == 1) { // Certificates
            MUCertificatePreferencesViewController *certPref = [[MUCertificatePreferencesViewController alloc] init];
            [self.navigationController pushViewController:certPref animated:YES];
            [certPref release];
        }
    }
#ifdef MUMBLE_BETA_DIST
    else if ([indexPath section] == 2) { // Beta
        if ([indexPath row] == 0) {
            MUDiagnosticsViewController *diagView = [[MUDiagnosticsViewController alloc] init];
            [self.navigationController pushViewController:diagView animated:YES];
            [diagView release];
        }
    }
#endif
}

#pragma mark -
#pragma mark Change notification

- (void) textFieldBeganEditing:(UITextField *)sender {
    _activeTextField = sender;
}

- (void) textFieldEndedEditing:(UITextField *)sender {
    _activeTextField = nil;
}

- (void) textFieldDidChange:(UITextField *)sender {
    [[NSUserDefaults standardUserDefaults] setObject:[sender text] forKey:@"DefaultUserName"];
}

- (void) textFieldDidEndOnExit:(UITextField *)sender {
    _activeTextField = nil;
    [sender resignFirstResponder];
}

- (void) keyboardWasShown:(NSNotification*)aNotification {
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;

    [UIView animateWithDuration:0.2f animations:^{
        UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height, 0.0);
        self.tableView.contentInset = contentInsets;
        self.tableView.scrollIndicatorInsets = contentInsets;
    } completion:^(BOOL finished) {
        if (!finished)
            return;
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:2 inSection:1]
                              atScrollPosition:UITableViewScrollPositionBottom animated:YES];

    }];
}

- (void) keyboardWillBeHidden:(NSNotification*)aNotification {
    [UIView animateWithDuration:0.2f animations:^{
        UIEdgeInsets contentInsets = UIEdgeInsetsZero;
        self.tableView.contentInset = contentInsets;
        self.tableView.scrollIndicatorInsets = contentInsets;
    } completion:^(BOOL finished) {
        // ...
    }];
}

- (void) audioVolumeChanged:(UISlider *)volumeSlider {
    [[NSUserDefaults standardUserDefaults] setFloat:[volumeSlider value] forKey:@"AudioOutputVolume"];
}

- (void) forceTCPChanged:(UISwitch *)tcpSwitch {
    [[NSUserDefaults standardUserDefaults] setBool:[tcpSwitch isOn] forKey:@"NetworkForceTCP"];
}

@end

