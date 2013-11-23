// Copyright 2013 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUAudioMixerDebugViewController.h"
#import <MumbleKit/MKAudio.h>

@interface MUAudioMixerDebugViewController () {
    NSDictionary  *_mixerInfo;
    NSTimer       *_timer;
}
@end

@implementation MUAudioMixerDebugViewController

- (id) init {
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        // ...
    }
    return self;
}

- (void) dealloc {
    [_mixerInfo release];
    [super dealloc];
}

- (void) viewWillAppear:(BOOL)animated {
    [[self navigationItem] setTitle:@"Mixer Debug"];
    
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneDebugging:)];
    [[self navigationItem] setRightBarButtonItem:doneButton];
    [doneButton release];
    
    _timer = [[NSTimer scheduledTimerWithTimeInterval:0.001 target:self selector:@selector(updateMixerInfo:) userInfo:nil repeats:YES] retain];
    [self updateMixerInfo:self];
}

- (void) viewWillDisappear:(BOOL)animated {
    [_timer invalidate];
    [_timer release];
}

- (void) updateMixerInfo:(id)sender {
    [_mixerInfo release];
    _mixerInfo = [[MKAudio sharedAudio] copyAudioOutputMixerDebugInfo];
    [[self tableView] reloadData];
}

#pragma mark - Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) { // Metadata
        return 1;
    } else if (section == 1) { // Sources
        return [[_mixerInfo objectForKey:@"sources"] count];
    } else if (section == 1) { // Removed
        return [[_mixerInfo objectForKey:@"removed"] count];
    }
    
    return 0;
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"AudioMixerDebugCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier] autorelease];
    }
    
    if (indexPath.section == 0) { // Meta
        if (indexPath.row == 0) { // Last Update
            NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
            [fmt setDateFormat:@"HH:mm:ss:SSS"];
            NSDate *date = [_mixerInfo objectForKey:@"last-update"];
            cell.textLabel.text = @"Last Updated";
            cell.detailTextLabel.text = [fmt stringFromDate:date];
            [fmt release];
        }
    }
    
    if (indexPath.section == 1) {
        NSDictionary *info = [[_mixerInfo objectForKey:@"sources"] objectAtIndex:indexPath.row];
        cell.textLabel.text = [info objectForKey:@"kind"];
        cell.detailTextLabel.text = [info objectForKey:@"identifier"];
    } else if (indexPath.section == 2) {
        NSDictionary *info = [[_mixerInfo objectForKey:@"removed"] objectAtIndex:indexPath.row];
        cell.textLabel.text = [info objectForKey:@"kind"];
        cell.detailTextLabel.text = [info objectForKey:@"identifier"];    }
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    return cell;
}
- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return @"Metadata";
    } else if (section == 1) {
        return @"Sources";
    } else if (section == 2) {
        return @"Removed";
    }

    return @"Unknown";
}

- (void) doneDebugging:(id)sender {
    [self dismissModalViewControllerAnimated:YES];
}

@end
