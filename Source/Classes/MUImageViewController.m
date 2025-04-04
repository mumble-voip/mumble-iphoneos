// Copyright 2009-2012 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUImageViewController.h"
#import "MUOperatingSystem.h"
#import "MUColor.h"

@interface MUImageViewController () <UIScrollViewDelegate> {
    NSArray        *_images;
    NSArray        *_imageViews;
    UIScrollView   *_scrollView;
    NSUInteger     _curPage;
}
@end

@implementation MUImageViewController

- (id) initWithImages:(NSArray *)images {
    if ((self = [super init])) {
        _images = images;
        _curPage = 0;
    }
    return self;
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
    
    NSUInteger i = 0;
    for (i = 0; i < [_images count]; i++) {
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
        ++i;
    }

    _imageViews = imageViews;
    
    [self.view addSubview:_scrollView];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationItem.title = [NSString stringWithFormat:NSLocalizedString(@"%lu of %lu", nil), (unsigned long)1, (unsigned long)[_images count]];
    
    UINavigationBar *navBar = self.navigationController.navigationBar;
    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        navBar.tintColor = [UIColor whiteColor];
        navBar.translucent = NO;
        navBar.backgroundColor = [UIColor blackColor];
    }
    navBar.barStyle = UIBarStyleBlackOpaque;
    
    if (MUGetOperatingSystemVersion() >= MUMBLE_OS_IOS_7) {
        _scrollView.backgroundColor = [MUColor backgroundViewiOS7Color];
    }
    
    UIBarButtonItem *actionButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(actionClicked:)];
    self.navigationItem.rightBarButtonItem = actionButton;
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
            self.navigationItem.title = [NSString stringWithFormat:NSLocalizedString(@"%lu of %lu", nil), (unsigned long)1+_curPage, (unsigned long)[_images count]];
        }
    }
}

- (UIView *) viewForZoomingInScrollView:(UIScrollView *)scrollView {
    if (scrollView != _scrollView) {
        return [_imageViews objectAtIndex:_curPage];
    }
    return nil;
}

#pragma mark - Actions

- (void) image:(UIImage *)img didFinishSavingWithError:(NSError *)err contextInfo:(void *)userInfo {
    if (err != nil) {
        UIAlertController* alertCtrl = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Unable to save image", nil)
                                                                           message:[err description]
                                                                    preferredStyle:UIAlertControllerStyleAlert];
        [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                       style:UIAlertActionStyleCancel
                                                     handler:nil]];
        
        [self presentViewController:alertCtrl animated:YES completion:nil];
    }
}

- (void) actionClicked:(id)sender {
    UIAlertController* alertCtrl = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Export Image", nil)
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
    [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                   style:UIAlertActionStyleCancel
                                                 handler:nil]];
    [alertCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Export to Photos", nil)
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * _Nonnull action) {
        UIImageWriteToSavedPhotosAlbum([self->_images objectAtIndex:self->_curPage], self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
    }]];
    
    [self presentViewController:alertCtrl animated:YES completion:nil];
}

@end
