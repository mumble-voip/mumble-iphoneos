// Copyright 2009-2011 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUServerCell.h"
#import "MUFavouriteServer.h"

@interface MUServerCell () {
    NSString        *_displayname;
    NSString        *_hostname;
    NSString        *_port;
    NSString        *_username;
    MLServerPinger  *_pinger;
    BOOL _hasServer, _verifiedCertificate, _lastFull;
    NSUInteger _lastPing, _lastUserCount;
}
- (void) applyPing:(NSUInteger)pingMs userCount:(NSUInteger)userCount isFull:(BOOL)isFull;
@end

@implementation MUServerCell

+ (NSString *) reuseIdentifier {
    return @"ServerCell";
}

- (id) init {
    if ((self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:[MUServerCell reuseIdentifier]])) {
        [self registerForTraitChanges:@[UITraitPreferredContentSizeCategory.class] withHandler:^(__kindof MUServerCell *cell, UITraitCollection *previous) {
            [cell applyPing:cell->_lastPing userCount:cell->_lastUserCount isFull:cell->_lastFull];
        }];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(updatePinger) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(updatePinger) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }

- (void)didMoveToWindow { [super didMoveToWindow]; [self updatePinger]; }

- (void)updatePinger {
    BOOL visible = _hasServer && self.window && UIApplication.sharedApplication.applicationState != UIApplicationStateBackground;
    if (!visible) { _pinger.delegate = nil; _pinger = nil; }
    else if (!_pinger) { _pinger = [[MLServerPinger alloc] initWithHostname:_hostname port:_port]; _pinger.delegate = self; }
}

- (void) prepareForReuse {
    [super prepareForReuse];
    [_pinger setDelegate:nil];
    _pinger = nil; _hasServer = NO; _verifiedCertificate = NO;
}

- (void) populateFromDisplayName:(NSString *)displayName hostName:(NSString *)hostName port:(NSString *)port {
    [_pinger setDelegate:nil];
    _pinger = nil;
    _username = nil;
    _displayname = [displayName copy];
    _port = [port copy];

    if ([hostName length] > 0) {
        _hostname = [hostName copy];
    } else {
        _hostname = NSLocalizedString(@"(No Server)", nil);
    }

    _hasServer = _hostname.length > 0 && ![_hostname isEqualToString:NSLocalizedString(@"(No Server)", nil)];
    [self applyPing:999 userCount:0 isFull:NO];
    [self updatePinger];
}

- (void) populateFromFavouriteServer:(MUFavouriteServer *)favServ {
    [_pinger setDelegate:nil];
    _pinger = nil;
    _displayname = [[favServ displayName] copy];
    _hostname = [[favServ hostName] copy];
    _port = [NSString stringWithFormat:@"%lu", (unsigned long)[favServ port]];

    if ([[favServ userName] length] > 0) {
        _username = [[favServ userName] copy];
    } else {
        _username = [[[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultUserName"] copy];
    }

    if (![_hostname length]) {
        _hostname = NSLocalizedString(@"(No Server)", nil);
    }
    
    _hasServer = _hostname.length > 0 && ![_hostname isEqualToString:NSLocalizedString(@"(No Server)", nil)];
    [self applyPing:999 userCount:0 isFull:NO];
    [self updatePinger];
}

- (void) applyPing:(NSUInteger)pingMs userCount:(NSUInteger)userCount isFull:(BOOL)isFull {
    _lastPing = pingMs; _lastUserCount = userCount; _lastFull = isFull;
    UIColor *pingColor = [UIColor secondaryLabelColor];
    NSString *pingText = NSLocalizedString(@"—", @"Ping not measured yet");
    if (pingMs < 999) {
        pingText = [NSString stringWithFormat:NSLocalizedString(@"%lu ms", @"server ping in milliseconds"), (unsigned long)pingMs];
        if (pingMs <= 125) {
            pingColor = [UIColor systemGreenColor];
        } else if (pingMs <= 250) {
            pingColor = [UIColor systemOrangeColor];
        } else {
            pingColor = [UIColor systemRedColor];
        }
    }

    NSString *place = [NSString stringWithFormat:@"%@:%@", _hostname, _port];
    if ([_username length] > 0) {
        place = [NSString stringWithFormat:NSLocalizedString(@"%@ on %@", @"username on hostname:port"), _username, place];
    }
    NSString *people = [NSString stringWithFormat:NSLocalizedString(@"%lu online", @"people currently on a server"), (unsigned long)userCount];
    if (isFull) {
        people = [NSString stringWithFormat:NSLocalizedString(@"%lu full", @"server is full"), (unsigned long)userCount];
    }
    NSString *line = [NSString stringWithFormat:@"%@ · %@ · %@", place, pingText, people];

    UIFont *footnote = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote compatibleWithTraitCollection:self.traitCollection];
    NSMutableAttributedString *detail = [[NSMutableAttributedString alloc] initWithString:line attributes:@{
        NSFontAttributeName: footnote,
        NSForegroundColorAttributeName: [UIColor secondaryLabelColor]
    }];
    NSRange pingRange = [line rangeOfString:pingText];
    if (pingRange.location != NSNotFound && pingMs < 999) {
        [detail addAttribute:NSForegroundColorAttributeName value:pingColor range:pingRange];
    }
    if (isFull) {
        NSRange peopleRange = [line rangeOfString:people];
        if (peopleRange.location != NSNotFound) {
            [detail addAttribute:NSForegroundColorAttributeName value:[UIColor systemRedColor] range:peopleRange];
        }
    }

    UIListContentConfiguration *content = [UIListContentConfiguration subtitleCellConfiguration];
    content.text = _displayname;
    content.textProperties.numberOfLines = 0;
    content.secondaryTextProperties.numberOfLines = 0;
    content.secondaryAttributedText = detail;
    if (_verifiedCertificate) {
        content.image = [UIImage systemImageNamed:@"checkmark.seal.fill"];
        content.imageProperties.tintColor = UIColor.systemGreenColor;
        content.imageProperties.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightRegular];
    }
    self.contentConfiguration = content;
    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    self.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
}

- (void) setShowsVerifiedCertificate:(BOOL)verified {
    _verifiedCertificate = verified;
    UIListContentConfiguration *content = (UIListContentConfiguration *)self.contentConfiguration;
    if (![content isKindOfClass:[UIListContentConfiguration class]]) {
        content = [UIListContentConfiguration subtitleCellConfiguration];
        content.text = _displayname;
    }
    if (verified) {
        content.image = [UIImage systemImageNamed:@"checkmark.seal.fill"];
        content.imageProperties.tintColor = [UIColor systemGreenColor];
        content.imageProperties.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightRegular];
    } else {
        content.image = nil;
    }
    self.contentConfiguration = content;
    self.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
}

- (void) serverPingerResult:(MLServerPingerResult *)result {
    NSUInteger pingValue = (NSUInteger)(result->ping * 1000.0f);
    NSUInteger userCount = (NSUInteger)(result->cur_users);
    BOOL isFull = result->max_users > 0 && result->cur_users == result->max_users;
    [self applyPing:pingValue userCount:userCount isFull:isFull];
}

@end
