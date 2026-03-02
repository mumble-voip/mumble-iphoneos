// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUWelcomeScreenPhone.h"

#import "MUPublicServerListController.h"
#import "MUFavouriteServerListController.h"
#import "MUFavouriteServerEditViewController.h"
#import "MULanServerListController.h"
#import "MUConnectionController.h"
#import "MUImage.h"
#import "MUColor.h"
#import "MUBackgroundView.h"
#import "MUDatabase.h"
#import "MUFavouriteServer.h"
#import "MUServerCell.h"

@interface MUWelcomeScreenPhone () {
    NSArray *_recentConnections;
}
- (void) reloadRecentConnections;
@end

@implementation MUWelcomeScreenPhone

- (id) init {
    if (@available(iOS 13.0, *)) {
        self = [super initWithStyle:UITableViewStyleInsetGrouped];
    } else {
        self = [super initWithStyle:UITableViewStyleGrouped];
    }
    if (self) {
        _recentConnections = @[];
    }
    return self;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.navigationController.toolbarHidden = YES;
    
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
    }

    // Logo + "Mumble" side by side as left bar item
    self.navigationItem.title = nil;
    UIImage *logoImage = [MUImage imageNamed:@"SmallMumbleIcon"];
    UIImageView *logoView = [[UIImageView alloc] initWithImage:logoImage];
    logoView.contentMode = UIViewContentModeScaleAspectFit;
    [logoView.widthAnchor constraintEqualToConstant:32].active = YES;
    [logoView.heightAnchor constraintEqualToConstant:32].active = YES;
    logoView.translatesAutoresizingMaskIntoConstraints = NO;
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"Mumble";
    titleLabel.font = [UIFont boldSystemFontOfSize:28];
    titleLabel.textColor = [MUColor primaryTextColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    UIStackView *titleStack = [[UIStackView alloc] initWithArrangedSubviews:@[logoView, titleLabel]];
    titleStack.axis = UILayoutConstraintAxisHorizontal;
    titleStack.spacing = 8;
    titleStack.alignment = UIStackViewAlignmentCenter;
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:titleStack];

    self.tableView.backgroundView = [MUBackgroundView backgroundView];
    self.tableView.scrollEnabled = YES;

    [self reloadRecentConnections];
    [self.tableView reloadData];
}

- (void) reloadRecentConnections {
    _recentConnections = [MUDatabase fetchRecentConnections];
}

#pragma mark -
#pragma mark TableView

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0)
        return 4; // Join, Public, LAN, Favourites
    if (section == 1)
        return [_recentConnections count];
    return 0;
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 1 && [_recentConnections count] > 0)
        return NSLocalizedString(@"Recent Connections", nil);
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
        } else if (indexPath.row == 3) {
            cell.textLabel.text = NSLocalizedString(@"Favourite Servers", nil);
            if (@available(iOS 13.0, *)) {
                cell.imageView.image = [UIImage systemImageNamed:@"star.fill"];
                cell.imageView.tintColor = [UIColor systemYellowColor];
            }
        }
        
        [[cell textLabel] setHidden: NO];
        return cell;
    }
    
    // Section 1: Recent connections
    if (indexPath.section == 1) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"recentItem"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"recentItem"];
        }
        
        NSDictionary *entry = [_recentConnections objectAtIndex:indexPath.row];
        NSString *hostname = entry[@"hostname"];
        NSInteger port = [entry[@"port"] integerValue];
        NSString *username = entry[@"username"];
        NSTimeInterval timestamp = [entry[@"timestamp"] doubleValue];
        
        if (port != 64738) {
            cell.textLabel.text = [NSString stringWithFormat:@"%@:%ld", hostname, (long)port];
        } else {
            cell.textLabel.text = hostname;
        }
        
        // Relative time
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp];
        NSString *timeAgo;
        if (@available(iOS 13.0, *)) {
            NSRelativeDateTimeFormatter *fmt = [[NSRelativeDateTimeFormatter alloc] init];
            fmt.unitsStyle = NSRelativeDateTimeFormatterUnitsStyleFull;
            timeAgo = [fmt localizedStringForDate:date relativeToDate:[NSDate date]];
        } else {
            NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
            [fmt setDateStyle:NSDateFormatterShortStyle];
            [fmt setTimeStyle:NSDateFormatterShortStyle];
            timeAgo = [fmt stringFromDate:date];
        }
        
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", username, timeAgo];
        cell.detailTextLabel.textColor = [MUColor secondaryTextColor];
        
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightRegular];
            cell.imageView.image = [UIImage systemImageNamed:@"clock.arrow.circlepath" withConfiguration:config];
            cell.imageView.tintColor = [UIColor tertiaryLabelColor];
        }
        
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        cell.accessoryType = UITableViewCellAccessoryNone;
        
        return cell;
    }
    
    return [[UITableViewCell alloc] init];
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
        } else if (indexPath.row == 3) {
            MUFavouriteServerListController *favList = [[MUFavouriteServerListController alloc] init];
            [self.navigationController pushViewController:favList animated:YES];
        }
    } else if (indexPath.section == 1) {
        // Direct connect from recent history
        NSDictionary *entry = [_recentConnections objectAtIndex:indexPath.row];
        NSString *hostname = entry[@"hostname"];
        NSInteger port = [entry[@"port"] integerValue];
        NSString *username = entry[@"username"];
        
        MUConnectionController *connCtrlr = [MUConnectionController sharedController];
        [connCtrlr connetToHostname:hostname
                               port:port
                       withUsername:username
                        andPassword:nil
           withParentViewController:self];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

#pragma mark - Swipe actions for recent connections

- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
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
    
    // Try parsing as mumble:// URL
    if ([addressText hasPrefix:@"mumble://"]) {
        NSURL *url = [NSURL URLWithString:addressText];
        if (url) {
            hostname = [url host];
            if ([url port]) port = [[url port] integerValue];
            if ([url user]) username = [url user];
            if ([url password]) password = [url password];
        }
    }
    
    // Parse as host:port
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
