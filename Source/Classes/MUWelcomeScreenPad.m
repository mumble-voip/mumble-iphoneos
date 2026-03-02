// Copyright 2012 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUWelcomeScreenPad.h"
#import "MUPublicServerListController.h"
#import "MUFavouriteServerListController.h"
#import "MUFavouriteServerEditViewController.h"
#import "MULanServerListController.h"
#import "MUConnectionController.h"
#import "MUDatabase.h"
#import "MUFavouriteServer.h"
#import "MUServerCell.h"

@interface MUWelcomeScreenPad () <UITableViewDataSource, UITableViewDelegate> {
    UIView                *_view;
    UIImageView           *_backgroundView;
    UITableView           *_tableView;
    UIImageView           *_logoView;
    NSMutableArray        *_favouriteServers;
}
- (void) reloadFavourites;
@end

@implementation MUWelcomeScreenPad

- (id) init {
    if ((self = [super init])) {
        _favouriteServers = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void) loadView {
    _view = [[UIView alloc] initWithFrame:CGRectZero];
    _view.frame = CGRectMake(0, 0, 768, 1024);
    self.view = _view;
    
    if (@available(iOS 13.0, *)) {
        _view.backgroundColor = [UIColor systemGroupedBackgroundColor];
        _backgroundView = [[UIImageView alloc] initWithFrame:_view.frame];
    } else {
        _backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"BackgroundTextureBlackGradientPad"]];
    }
    [_backgroundView setFrame:_view.frame];
    [_view addSubview:_backgroundView];

    // Smaller logo
    _logoView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"LogoBigShadow"]];
    _logoView.contentMode = UIViewContentModeScaleAspectFit;
    [_view addSubview:_logoView];

    UITableViewStyle tableStyle;
    if (@available(iOS 13.0, *)) {
        tableStyle = UITableViewStyleInsetGrouped;
    } else {
        tableStyle = UITableViewStyleGrouped;
    }
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:tableStyle];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.opaque = NO;
    _tableView.backgroundView = nil;
    _tableView.scrollEnabled = YES;
    [_view addSubview:_tableView];
}

- (void) setViewPositions {
    CGRect pr = self.view.frame;
    CGFloat pw = pr.size.width;
    
    CGFloat lw = 140;
    CGFloat lh = 140;
    
    CGFloat tw = MIN(pw - 40, 500);
    CGFloat th = pr.size.height - (50 + lh + 20);
    
    [_backgroundView setFrame:_view.frame];
    [_logoView setFrame:CGRectMake(pw/2 - lw/2, 30, lw, lh)];
    [_tableView setFrame:CGRectMake(pw/2 - tw/2, 30 + lh + 10, tw, th)];
}

- (void) viewWillLayoutSubviews {
    [self setViewPositions];
}

- (BOOL) shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask) supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void) viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self setViewPositions];
    } completion:nil];
}

- (void) viewWillAppear:(BOOL)animated {
    self.navigationItem.title = @"Mumble";
    
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = YES;
        self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
    }
    
    // No more Preferences/About buttons - they're in separate tabs now
    
    [self reloadFavourites];
    [_tableView reloadData];
    [_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:animated];
}

- (void) reloadFavourites {
    _favouriteServers = [MUDatabase fetchAllFavourites];
    [_favouriteServers sortUsingSelector:@selector(compare:)];
}

#pragma mark -
#pragma mark TableView

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0)
        return 3; // Join, Public, LAN
    if (section == 1)
        return [_favouriteServers count];
    return 0;
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 1)
        return NSLocalizedString(@"Favourite Servers", nil);
    return nil;
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0;
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"welcomeItem"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"welcomeItem"];
        }
        
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        if (indexPath.row == 0) {
            cell.textLabel.text = NSLocalizedString(@"Join a Server", nil);
            if (@available(iOS 13.0, *)) {
                cell.imageView.image = [UIImage systemImageNamed:@"plus.circle.fill"];
                cell.imageView.tintColor = [UIColor systemBlueColor];
            }
            cell.accessoryType = UITableViewCellAccessoryNone;
        } else if (indexPath.row == 1) {
            cell.textLabel.text = NSLocalizedString(@"Public Servers", nil);
            if (@available(iOS 13.0, *)) {
                cell.imageView.image = [UIImage systemImageNamed:@"globe"];
                cell.imageView.tintColor = [UIColor systemIndigoColor];
            }
        } else if (indexPath.row == 2) {
            cell.textLabel.text = NSLocalizedString(@"LAN Servers", nil);
            if (@available(iOS 13.0, *)) {
                cell.imageView.image = [UIImage systemImageNamed:@"wifi"];
                cell.imageView.tintColor = [UIColor systemGreenColor];
            }
        }
        
        [[cell textLabel] setHidden:NO];
        return cell;
    }
    
    // Section 1: Favourite servers
    MUFavouriteServer *favServ = [_favouriteServers objectAtIndex:[indexPath row]];
    MUServerCell *cell = (MUServerCell *)[tableView dequeueReusableCellWithIdentifier:[MUServerCell reuseIdentifier]];
    if (cell == nil) {
        cell = [[MUServerCell alloc] init];
    }
    [cell populateFromFavouriteServer:favServ];
    cell.selectionStyle = UITableViewCellSelectionStyleGray;
    
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightRegular];
        UIImageView *hintView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"line.3.horizontal" withConfiguration:config]];
        hintView.tintColor = [UIColor tertiaryLabelColor];
        cell.accessoryView = hintView;
    }
    
    return (UITableViewCell *) cell;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            [self showJoinServerDialog];
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
        } else if (indexPath.row == 1) {
            MUPublicServerListController *serverList = [[MUPublicServerListController alloc] init];
            [self.navigationController pushViewController:serverList animated:YES];
        } else if (indexPath.row == 2) {
            MULanServerListController *lanList = [[MULanServerListController alloc] init];
            [self.navigationController pushViewController:lanList animated:YES];
        }
    } else if (indexPath.section == 1) {
        // Direct connect
        MUFavouriteServer *favServ = [_favouriteServers objectAtIndex:[indexPath row]];
        NSString *userName = [favServ userName];
        if (userName == nil) {
            userName = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultUserName"];
        }
        MUConnectionController *connCtrlr = [MUConnectionController sharedController];
        [connCtrlr connetToHostname:[favServ hostName]
                               port:[favServ port]
                       withUsername:userName
                        andPassword:[favServ password]
           withParentViewController:self];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

#pragma mark - Swipe actions for favourites

- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 1;
}

- (UISwipeActionsConfiguration *) tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != 1) return nil;
    
    MUFavouriteServer *favServ = [_favouriteServers objectAtIndex:[indexPath row]];
    
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                               title:NSLocalizedString(@"Delete", nil)
                                                                             handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [MUDatabase deleteFavourite:favServ];
        [self->_favouriteServers removeObjectAtIndex:[indexPath row]];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        completionHandler(YES);
    }];
    if (@available(iOS 13.0, *)) {
        deleteAction.image = [UIImage systemImageNamed:@"trash"];
    }
    
    UIContextualAction *editAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                             title:NSLocalizedString(@"Edit", nil)
                                                                           handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [self presentEditDialogForFavourite:favServ];
        completionHandler(YES);
    }];
    editAction.backgroundColor = [UIColor systemBlueColor];
    if (@available(iOS 13.0, *)) {
        editAction.image = [UIImage systemImageNamed:@"pencil"];
    }
    
    return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction, editAction]];
}

- (void) presentEditDialogForFavourite:(MUFavouriteServer *)favServ {
    UINavigationController *modalNav = [[UINavigationController alloc] init];
    MUFavouriteServerEditViewController *editView = [[MUFavouriteServerEditViewController alloc] initInEditMode:YES withContentOfFavouriteServer:favServ];
    [editView setTarget:self];
    [editView setDoneAction:@selector(editDoneButtonClicked:)];
    [modalNav pushViewController:editView animated:NO];
    modalNav.modalPresentationStyle = UIModalPresentationFormSheet;
    [[self navigationController] presentViewController:modalNav animated:YES completion:nil];
}

- (void) editDoneButtonClicked:(id)sender {
    MUFavouriteServerEditViewController *editView = sender;
    MUFavouriteServer *updatedServer = [editView copyFavouriteFromContent];
    [MUDatabase storeFavourite:updatedServer];
    [self reloadFavourites];
    [_tableView reloadData];
}

#pragma mark - Join Server Dialog

- (void) showJoinServerDialog {
    NSString *title = NSLocalizedString(@"Join a Server", nil);
    NSString *msg = NSLocalizedString(@"Enter a server address or paste a mumble:// link", nil);
    
    UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:title
                                                                       message:msg
                                                                preferredStyle:UIAlertControllerStyleAlert];
    
    [alertCtrl addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = NSLocalizedString(@"mumble.example.com or mumble://...", nil);
        textField.keyboardType = UIKeyboardTypeURL;
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    
    [alertCtrl addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultUserName"];
        textField.text = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultUserName"];
    }];
    
    [alertCtrl addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                  style:UIAlertActionStyleCancel
                                                handler:nil]];
    
    [alertCtrl addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Connect", nil)
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * _Nonnull action) {
        NSString *addressText = [[[alertCtrl textFields] objectAtIndex:0] text];
        NSString *username = [[[alertCtrl textFields] objectAtIndex:1] text];
        
        if (!addressText || [addressText length] == 0) return;
        if (!username || [username length] == 0) {
            username = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultUserName"];
        }
        
        [self connectWithAddress:addressText username:username];
    }]];
    
    [self presentViewController:alertCtrl animated:YES completion:nil];
}

- (void) connectWithAddress:(NSString *)addressText username:(NSString *)username {
    NSString *hostname = nil;
    NSInteger port = 64738;
    NSString *password = nil;
    
    if ([addressText hasPrefix:@"mumble://"]) {
        NSURL *url = [NSURL URLWithString:addressText];
        if (url) {
            hostname = [url host];
            if ([url port]) port = [[url port] integerValue];
            if ([url user]) username = [url user];
            if ([url password]) password = [url password];
        }
    }
    
    if (!hostname) {
        NSArray *parts = [addressText componentsSeparatedByString:@":"];
        hostname = [parts firstObject];
        if ([parts count] > 1) {
            port = [[parts objectAtIndex:1] integerValue];
            if (port == 0) port = 64738;
        }
    }
    
    if (hostname && [hostname length] > 0) {
        MUConnectionController *connCtrlr = [MUConnectionController sharedController];
        [connCtrlr connetToHostname:hostname port:port withUsername:username andPassword:password withParentViewController:self];
    }
}

@end
