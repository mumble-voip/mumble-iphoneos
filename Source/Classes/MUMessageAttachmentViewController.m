/* Copyright (C) 2009-2012 Mikkel Krautz <mikkel@krautz.dk>

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

#import "MUMessageAttachmentViewController.h"
#import "MUTableViewHeaderLabel.h"
#import "MUImageViewController.h"
#import "MUImage.h"

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
    self.tableView.backgroundView = [[[UIImageView alloc] initWithImage:[MUImage imageNamed:@"BackgroundTextureBlackGradient"]] autorelease];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
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
            detailText = [NSString stringWithFormat:NSLocalizedString(@"%i images", nil), [_images count]];
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
