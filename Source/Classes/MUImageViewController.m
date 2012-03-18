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

#import "MUImageViewController.h"

@interface MUImageViewController () <UIScrollViewDelegate, UIActionSheetDelegate> {
    NSArray        *_images;
    NSArray        *_imageViews;
    UIScrollView   *_scrollView;
    NSInteger      _curPage;
}
@end

@implementation MUImageViewController

- (id) initWithImages:(NSArray *)images {
    if ((self = [super init])) {
        _images = [images retain];
        _curPage = 0;
    }
    return self;
}

- (void) dealloc {
    [_images release];
    [super dealloc];
}

- (void) viewDidLoad {
    [super viewDidLoad];

    CGRect frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height-44);
    
    _scrollView = [[UIScrollView alloc] initWithFrame:frame];
    [_scrollView setDelegate:self];
    [_scrollView setPagingEnabled:YES];
    [_scrollView setMaximumZoomScale:1.0f];
    [_scrollView setMinimumZoomScale:1.0f];
    [_scrollView setShowsVerticalScrollIndicator:NO];
    [_scrollView setShowsHorizontalScrollIndicator:NO];

    CGRect contentFrame = CGRectMake(0, 0, frame.size.width * [_images count], frame.size.height);
    [_scrollView setContentSize:contentFrame.size];
    NSMutableArray *imageViews = [[NSMutableArray alloc] initWithCapacity:[_images count]];
    
    int i = 0;
    for (UIImage *img in _images) {
        CGRect imageFrame = CGRectMake(frame.size.width*i, 0, frame.size.width, frame.size.height);
        UIScrollView *imgZoomer = [[UIScrollView alloc] initWithFrame:imageFrame];
        UIImageView *imgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, imageFrame.size.width, imageFrame.size.height)];
        [imgView setImage:[_images objectAtIndex:i]];
        [imgView setContentMode:UIViewContentModeScaleAspectFit];
        [imgZoomer setDelegate:self];
        [imgZoomer addSubview:imgView];
        [imgZoomer setMaximumZoomScale:4.0f];
        [imgZoomer setMinimumZoomScale:1.0f];
        [imgZoomer setShowsVerticalScrollIndicator:NO];
        [imgZoomer setShowsHorizontalScrollIndicator:NO];
        [_scrollView addSubview:imgZoomer];
        [imageViews addObject:imgView];
        [imgView release];
        [imgZoomer release];
        ++i;
    }

    _imageViews = imageViews;
    
    [self.view addSubview:_scrollView];
}

- (void) viewDidUnload {
    [super viewDidUnload];
    [_scrollView release];
    [_imageViews release];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationItem.title = [NSString stringWithFormat:NSLocalizedString(@"%i of %i", nil), 1, [_images count]];
    
    UIBarButtonItem *actionButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(actionClicked:)];
    self.navigationItem.rightBarButtonItem = actionButton;
    [actionButton release];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - UIScrollViewDelegate

- (void) scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == _scrollView) {
        CGPoint pt = [_scrollView contentOffset];
        NSInteger pg = (NSInteger)(pt.x / self.view.frame.size.width);
        if (pg != _curPage) {
            _curPage = pg;
            self.navigationItem.title = [NSString stringWithFormat:NSLocalizedString(@"%i of %i", nil), 1+_curPage, [_images count]];
        }
    }
}

- (UIView *) viewForZoomingInScrollView:(UIScrollView *)scrollView {
    if (scrollView != _scrollView) {
        return [_imageViews objectAtIndex:_curPage];
    }
    return nil;
}

#pragma mark - UIActionSheetDelegate

- (void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        UIImageWriteToSavedPhotosAlbum([_images objectAtIndex:_curPage], self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
    }
}

#pragma mark - Actions

- (void) image:(UIImage *)img didFinishSavingWithError:(NSError *)err contextInfo:(void *)userInfo {
    if (err != nil) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Unable to save image", nil)
                                                            message:[err description]
                                                           delegate:nil 
                                                   cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                  otherButtonTitles:nil];
        [alertView show];
        [alertView release];
    }
}

- (void) actionClicked:(id)sender {
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Export Image", nil)
                                                             delegate:self
                                                    cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                               destructiveButtonTitle:nil
                                                    otherButtonTitles:NSLocalizedString(@"Export to Photos", nil), nil];
    [actionSheet setActionSheetStyle:UIActionSheetStyleBlackOpaque];
    [actionSheet showFromBarButtonItem:sender animated:YES];
    [actionSheet release];
}

@end
