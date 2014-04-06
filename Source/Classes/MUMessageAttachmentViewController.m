// Copyright 2009-2012 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUMessageAttachmentViewController.h"
#import "MUTableViewHeaderLabel.h"
#import "MUImageViewController.h"
#import "MUImage.h"
#import "MUOperatingSystem.h"
#import "MUBackgroundView.h"

@interface MUMessageAttachmentViewController () {
    NSArray *_links;
    NSArray *_images;
}
@end

@implementation MUMessageAttachmentViewController

- (id) initWithImages:(NSArray *)images andLinks:(NSArray *)links {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        _images = [images retain];
        _links = [links retain];
    }
    return self;
}

#pragma mark - View lifecycle

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.navigationItem.title = NSLocalizedString(@"Attachments", nil);

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
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    BOOL hasImages = [_images count] > 0;
    if (hasImages) {
        return 2;
    } else {
        return 1;
    }
    return 0;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    BOOL hasImages = [_images count] > 0;
    if (hasImages && section == 0) {
        return 1;
    } else {
        return [_links count];
    }
    return 0;
}

- (UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    BOOL hasImages = [_images count] > 0;
    if (hasImages && section == 0) {
        return [MUTableViewHeaderLabel labelWithText:NSLocalizedString(@"Images", nil)];
    } else {
        return [MUTableViewHeaderLabel labelWithText:NSLocalizedString(@"Links", nil)];
    }
    return nil;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return [MUTableViewHeaderLabel defaultHeaderHeight];
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
    }
    
    cell.selectionStyle = UITableViewCellSelectionStyleGray;

    BOOL hasImages = [_images count] > 0;
    if (hasImages && [indexPath section] == 0) {
        UIImage *img = [_images objectAtIndex:0];
        UIImage *round = [MUImage tableViewCellImageFromImage:img];
        [cell.imageView setImage:round];
        cell.textLabel.text = NSLocalizedString(@"Images", nil);
        NSString *detailText = NSLocalizedString(@"1 image", nil);
        if ([_images count] > 1)
            detailText = [NSString stringWithFormat:NSLocalizedString(@"%lu images", nil), (unsigned long)[_images count]];
        cell.detailTextLabel.text = detailText;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        cell.imageView.image = nil;
        NSString *urlStr = [_links objectAtIndex:[indexPath row]];
        NSURL *url = [NSURL URLWithString:urlStr];
        cell.textLabel.text = [url host];
        cell.detailTextLabel.text = urlStr;
    }

    return cell;
}

#pragma mark - Table view delegate

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    BOOL hasImages = [_images count] > 0;
    if (hasImages && [indexPath section] == 0) {
        MUImageViewController *imgViewController = [[MUImageViewController alloc] initWithImages:_images];
        [self.navigationController pushViewController:imgViewController animated:YES];
        [imgViewController release];
    } else {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[_links objectAtIndex:[indexPath row]]]];
    }

    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
