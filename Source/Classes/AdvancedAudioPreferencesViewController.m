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

#import "AdvancedAudioPreferencesViewController.h"

@interface AdvancedAudioPreferencesViewController (Private)
- (void) audioPreprocessorChanged:(UISwitch *)aSwitch;
@end

@implementation AdvancedAudioPreferencesViewController

#pragma mark -
#pragma mark Initialization

- (id) init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self == nil)
		return nil;
	
	return self;
}

- (void) dealloc {
	[super dealloc];
}

#pragma mark -
#pragma mark Looks

- (void) viewWillAppear:(BOOL)animated {
	[self setTitle:@"Advanced Audio"];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}


- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	// Audio Input
	if (section == 0) {
		return 1;
	}
	
	return 0;
}


// Customize the appearance of table view cells.
- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"PreferencesCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
	
	// Audio Input section
	if ([indexPath section] == 0) {
		// Ducking
		if ([indexPath row] == 0) {
			UISwitch *preprocessSwitch = [[UISwitch alloc] init];
			[preprocessSwitch setOn:[[NSUserDefaults standardUserDefaults] boolForKey:@"AudioInputPreprocessor"]];
			[[cell textLabel] setText:@"Enable Preprocessor"];
			[cell setAccessoryView:preprocessSwitch];
			[cell setSelectionStyle:UITableViewCellSelectionStyleNone];
			[preprocessSwitch addTarget:self action:@selector(audioPreprocessorChanged:) forControlEvents:UIControlEventValueChanged];
			[preprocessSwitch release];
		}
		
	}

    return cell;
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == 0) // Audio Input
		return @"Audio Input";

	return @"Default";
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
}

#pragma mark -
#pragma mark Change notification

- (void) audioPreprocessorChanged:(UISwitch *)aSwitch {
	[[NSUserDefaults standardUserDefaults] setBool:[aSwitch isOn] forKey:@"AudioInputPreprocessor"];
}

@end