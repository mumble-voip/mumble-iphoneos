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

#import "PreferencesViewController.h"
#import "MumbleApplication.h"
#import "MumbleApplicationDelegate.h"
#import "AdvancedAudioPreferencesViewController.h"
#import "CertificatePreferencesViewController.h"
#import "DiagnosticsViewController.h"

#import <MumbleKit/MKCertificate.h>

@interface PreferencesViewController (Private)
- (void) audioVolumeChanged:(UISlider *)volumeSlider;
- (void) audioDuckingChanged:(UISwitch *)duckSwitch;
- (void) forceTCPChanged:(UISwitch *)tcpSwitch;
@end

@implementation PreferencesViewController

#pragma mark -
#pragma mark Initialization

- (id) init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self == nil)
		return nil;

	return self;
}

- (void) dealloc {
	// Sync user defaults to persistent storage
	[[NSUserDefaults standardUserDefaults] synchronize];

	// Call our app delegate to reload preferences
	[[MumbleApp delegate] reloadPreferences];

	[super dealloc];
}

#pragma mark -
#pragma mark Looks

- (void) viewWillAppear:(BOOL)animated {
	[self setTitle:@"Preferences"];
	[[self tableView] reloadData];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 4;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	// Audio
	if (section == 0) {
		return 3;
	// Network
	} else if (section == 1) {
		return 1;
	// Certificates
	} else if (section == 2) {
		return 2;
	// Beta
	} else if (section == 3) {
		return 1;
	}

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

		// Ducking
		if ([indexPath row] == 1) {
			UISwitch *duckSwitch = [[UISwitch alloc] init];
			[duckSwitch	setOn:[[NSUserDefaults standardUserDefaults] boolForKey:@"AudioDucking"]];
			[[cell textLabel] setText:@"Duck Audio"];
			[cell setAccessoryView:duckSwitch];
			[cell setSelectionStyle:UITableViewCellSelectionStyleNone];
			[duckSwitch addTarget:self action:@selector(audioDuckingChanged:) forControlEvents:UIControlEventValueChanged];
			[duckSwitch release];
		}

		// Advanced Audio
		if ([indexPath row] == 2) {
			[[cell textLabel] setText:@"Advanced Audio"];
			[cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
		}

	// Network
	} else if ([indexPath section] == 1) {
		if ([indexPath row] == 0) {
			UISwitch *tcpSwitch = [[UISwitch alloc] init];
			[tcpSwitch setOn:[[NSUserDefaults standardUserDefaults] boolForKey:@"ForceTCP"]];
			[[cell textLabel] setText:@"Force TCP"];
			[cell setAccessoryView:tcpSwitch];
			[cell setSelectionStyle:UITableViewCellSelectionStyleNone];
			[tcpSwitch addTarget:self action:@selector(forceTCPChanged:) forControlEvents:UIControlEventValueChanged];
			[tcpSwitch release];
		}

	// Certificates
	} else if ([indexPath section] == 2) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PrefCertificateCell"];
		if (cell == nil)
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"PrefCertificateCell"] autorelease];

		NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
							   kSecClassIdentity,    kSecClass,
							   kCFBooleanTrue,       kSecReturnPersistentRef,
							   kSecMatchLimitAll,    kSecMatchLimit,
							   nil];
		NSArray *certs = nil;
		SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&certs);
		[certs autorelease];
		
		NSUInteger certCount = [certs count];
		
		if ([indexPath row] == 0) {
			NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
								   kSecClassIdentity,    kSecClass,
								   kCFBooleanTrue,       kSecReturnPersistentRef,
								   kSecMatchLimitAll,    kSecMatchLimit,
								   nil];
			NSArray *certs = nil;
			SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&certs);
			[certs autorelease];

			cell.textLabel.text = @"All Certificates";
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%i", certCount];
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

		} else if ([indexPath row] == 1) {

			NSData *persistentRef = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultCertificate"];
			NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
								   persistentRef,      kSecValuePersistentRef,
								   kCFBooleanTrue,     kSecReturnRef,
								   kSecMatchLimitOne,  kSecMatchLimit,
								   nil];
			SecIdentityRef identity = NULL;
			MKCertificate *cert = nil;
			if (SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&identity) == noErr && identity != NULL) {
				SecCertificateRef secCert;
				if (SecIdentityCopyCertificate(identity, &secCert) == noErr) {
					NSData *secData = (NSData *)SecCertificateCopyData(secCert);
					cert = [MKCertificate certificateWithCertificate:secData privateKey:nil];
				}
			}
			cell.textLabel.text = @"Certificate";
			cell.detailTextLabel.text = cert ? [cert commonName] : @"None";
			if (certCount > 1) {
				cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
				cell.selectionStyle = UITableViewCellSelectionStyleBlue;
			} else {
				cell.accessoryType = UITableViewCellAccessoryNone;
				cell.selectionStyle = UITableViewCellSelectionStyleNone;
			}
		}
		
		return cell;
	
	// Beta
	} else if ([indexPath section] == 3) {
		if ([indexPath row] == 0) {
			cell.textLabel.text = @"Diagnostics";
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
	}

    return cell;
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == 0) // Audio
		return @"Audio";
	else if (section == 1) // Network
		return @"Network";
	else if (section == 2) // Certificates
		return @"Certificates";
	else if (section == 3) // Beta
		return @"Beta";

	return @"Default";
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[[self tableView] deselectRowAtIndexPath:indexPath animated:YES];

	if ([indexPath section] == 0) { // Audio
		if ([indexPath row] == 2) { // Advanced Audio
			AdvancedAudioPreferencesViewController *advAudio = [[AdvancedAudioPreferencesViewController alloc] init];
			[[self navigationController] pushViewController:advAudio animated:YES];
			[advAudio release];
		}
	} else if ([indexPath section] == 2) { // Certificates
		if ([indexPath row] == 0) { // All Certificates
			CertificatePreferencesViewController *certPref = [[CertificatePreferencesViewController alloc] init];
			[self.navigationController pushViewController:certPref animated:YES];
			[certPref release];
		} else if ([indexPath row] == 1) { // Certificate
			NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
								   kSecClassIdentity,    kSecClass,
								   kCFBooleanTrue,       kSecReturnPersistentRef,
								   kSecMatchLimitAll,    kSecMatchLimit,
								   nil];
			NSArray *certs = nil;
			SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&certs);
			[certs autorelease];
			if ([certs count] > 1) {
				CertificatePreferencesViewController *certPref = [[CertificatePreferencesViewController alloc] initAsPicker];
				[self.navigationController pushViewController:certPref animated:YES];
				[certPref release];
			}
		}
	} else if ([indexPath section] == 3) { // Beta
		if ([indexPath row] == 0) {
			DiagnosticsViewController *diagView = [[DiagnosticsViewController alloc] init];
			[self.navigationController pushViewController:diagView animated:YES];
			[diagView release];
		}
	}
}

#pragma mark -
#pragma mark Change notification

- (void) audioVolumeChanged:(UISlider *)volumeSlider {
	[[NSUserDefaults standardUserDefaults] setFloat:[volumeSlider value] forKey:@"AudioOutputVolume"];
}

- (void) audioDuckingChanged:(UISwitch *)duckSwitch {
	[[NSUserDefaults standardUserDefaults] setBool:[duckSwitch isOn] forKey:@"AudioDucking"];
}

// Network

- (void) forceTCPChanged:(UISwitch *)tcpSwitch {
	[[NSUserDefaults standardUserDefaults] setBool:[tcpSwitch isOn] forKey:@"ForceTCP"];
}

@end

