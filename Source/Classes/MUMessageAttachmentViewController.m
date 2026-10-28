#import "MUInterface.h"
// Copyright 2009-2012 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUMessageAttachmentViewController.h"
#import "MUImageViewController.h"
#import "MUImage.h"

@interface MUMessageAttachmentViewController () {
    NSArray *_links;
    NSArray *_images;
    MUImageLoader _imageLoader;
    NSUInteger _imageCount;
}
@end

@implementation MUMessageAttachmentViewController

- (id) initWithImages:(NSArray *)images andLinks:(NSArray *)links {
    return [self initWithImages:images andLinks:links imageCount:images.count imageLoader:nil];
}
- (id)initWithImages:(NSArray *)images andLinks:(NSArray *)links imageCount:(NSUInteger)count imageLoader:(MUImageLoader)loader {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        _images = images;
        _links = links;
        _imageLoader=[loader copy];
        _imageCount=count;
    }
    return self;
}

#pragma mark - View lifecycle

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    MUConfigureTable(self.tableView);
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    self.navigationItem.title = NSLocalizedString(@"Attachments", nil);
    
    self.tableView.backgroundView = nil;
    
    {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    }
}

#pragma mark - Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    BOOL hasImages = _imageCount > 0;
    if (hasImages) {
        return 2;
    } else {
        return 1;
    }
    return 0;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    BOOL hasImages = _imageCount > 0;
    if (hasImages && section == 0) {
        return 1;
    } else {
        return [_links count];
    }
    return 0;
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    BOOL hasImages = _imageCount > 0;
    if (hasImages && section == 0) {
        return NSLocalizedString(@"Images", nil);
    }
    return NSLocalizedString(@"Links", nil);
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        MUConfigureStandardCell(cell);
    }
    
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;

    BOOL hasImages = _imageCount > 0;
    if (hasImages && [indexPath section] == 0) {
        UIImage *img = _images.firstObject;
        UIImage *round = img ? [MUImage tableViewCellImageFromImage:img] : [UIImage systemImageNamed:@"photo.on.rectangle"];
        [cell.imageView setImage:round];
        cell.textLabel.text = NSLocalizedString(@"Images", nil);
        NSString *detailText = NSLocalizedString(@"1 image", nil);
        if (_imageCount > 1)
            detailText = [NSString stringWithFormat:NSLocalizedString(@"%lu images", nil), (unsigned long)_imageCount];
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
    BOOL hasImages = _imageCount > 0;
    if (hasImages && [indexPath section] == 0) {
        MUImageViewController *imgViewController = _imageLoader ? [[MUImageViewController alloc] initWithImageLoader:_imageLoader] : [[MUImageViewController alloc] initWithImages:_images];
        [self.navigationController pushViewController:imgViewController animated:YES];
    } else {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[_links objectAtIndex:[indexPath row]]] options:@{} completionHandler:nil];
    }

    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
