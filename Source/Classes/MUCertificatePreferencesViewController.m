// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUCertificatePreferencesViewController.h"
#import "MUCertificateCell.h"
#import "MUCertificateCreationView.h"
#import "MUCertificateViewController.h"
#import "MUCertificateController.h"
#import "MUCertificateDiskImportViewController.h"

#import "MLClient.h"

@interface MUCertificatePreferencesViewController () {
    NSMutableArray   *_certificateItems;
    BOOL             _picker;
    NSUInteger       _selectedIndex;
    BOOL             _showAll;
}
- (void) fetchCertificates;
- (void) deleteCertificateForRow:(NSUInteger)row;
@end

@implementation MUCertificatePreferencesViewController

#pragma mark -
#pragma mark Initialization

- (id) init {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        self.preferredContentSize = CGSizeMake(320, 480);
        _showAll = [[[NSUserDefaults standardUserDefaults] objectForKey:@"CertificatesShowIntermediates"] boolValue];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(certificatesChanged:) name:MUCertificatesDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)certificatesChanged:(NSNotification *)notification {
    if (!self.isViewLoaded) return;
    [self fetchCertificates];
    [self.tableView reloadData];
}

#pragma mark -
#pragma mark View lifecycle

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.navigationItem.title = NSLocalizedString(@"Certificates", nil);
    
    {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        

    }
    
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 100;
    [self fetchCertificates];
    [self.tableView reloadData];
    
    __weak MUCertificatePreferencesViewController *weakSelf = self;
    UIDeferredMenuElement *items = [UIDeferredMenuElement elementWithUncachedProvider:^(void (^completion)(NSArray<UIMenuElement *> *)) {
        completion([weakSelf certificateMenuActions] ?: @[]);
    }];
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd menu:[UIMenu menuWithChildren:@[items]]];
    addButton.accessibilityLabel = NSLocalizedString(@"Certificates", nil);
    [self.navigationItem setRightBarButtonItem:addButton];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_certificateItems count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"CertificateCell";
    MUCertificateCell *cell = (MUCertificateCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
        cell = [MUCertificateCell certificateCell];
    
    // Configure the cell...
    NSDictionary *dict = [_certificateItems objectAtIndex:[indexPath row]];
    MLCertificate *cert = [dict objectForKey:@"cert"];
    [cell setSubjectName:[cert subjectName]];
    [cell setEmail:[cert emailAddress]];
    [cell setIssuerText:[cert issuerName]];
    
    [cell setIsExpired:![cert isValidOnDate:[NSDate date]]];
    if ([cert isValidOnDate:[NSDate date]]) {
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateStyle = NSDateFormatterMediumStyle;
        NSString *formattedDate = [dateFormatter stringFromDate:[cert notAfter]];
        NSString *fmt = NSLocalizedString(@"Expires on %@", @"Certificate expiry explanation");
        [cell setExpiryText:[NSString stringWithFormat:fmt, formattedDate]];
    } else {
        [cell setExpiryText:NSLocalizedString(@"Expired", @"Date is past the certificate's notAfter date")];
        [cell setIsExpired:YES];
    }

    NSData *persistentRef = [dict objectForKey:@"persistentRef"];
    NSData *curPersistentRef = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultCertificate"];

    if ([[dict objectForKey:@"isIdentity"] boolValue]) {
        [cell setIsIntermediate:NO];
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    } else {
        [cell setIsIntermediate:YES];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    if ([persistentRef isEqualToData:curPersistentRef]) {
        _selectedIndex = [indexPath row];
        [cell setIsCurrentCertificate:YES];
    } else {
        [cell setIsCurrentCertificate:NO];
    }

    {
        [cell setAccessoryType:UITableViewCellAccessoryDetailButton];
    }

    return (UITableViewCell *) cell;
}


#pragma mark -
#pragma mark Table view delegate
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *dict = [_certificateItems objectAtIndex:[indexPath row]];
    
    // Don't allow selection of intermediates.
    if (![[dict objectForKey:@"isIdentity"] boolValue]) {
        return;
    }
        
    NSData *persistentRef = [dict objectForKey:@"persistentRef"];
    [[NSUserDefaults standardUserDefaults] setObject:persistentRef forKey:@"DefaultCertificate"];

    MUCertificateCell *prevCell = _selectedIndex < _certificateItems.count ? (MUCertificateCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:_selectedIndex inSection:0]] : nil;
    MUCertificateCell *curCell = (MUCertificateCell *) [[self tableView] cellForRowAtIndexPath:indexPath];
    [prevCell setIsCurrentCertificate:NO];
    [curCell setIsCurrentCertificate:YES];
    _selectedIndex = [indexPath row];

    [[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
}

- (void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self deleteCertificateForRow:[indexPath row]];
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationRight];
    }
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

- (void) tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *dict = [_certificateItems objectAtIndex:[indexPath row]];
    NSData *persistentRef = [dict objectForKey:@"persistentRef"];
    MUCertificateViewController *certView = [[MUCertificateViewController alloc] initWithPersistentRef:persistentRef];
    [[self navigationController] pushViewController:certView animated:YES];
}

#pragma mark -
#pragma mark Target/actions

- (NSArray<UIMenuElement *> *)certificateMenuActions {
    __weak MUCertificatePreferencesViewController *weakSelf = self;
    UIAction *generate = [UIAction actionWithTitle:NSLocalizedString(@"Generate New Certificate", nil) image:[UIImage systemImageNamed:@"person.crop.circle.badge.plus"] identifier:nil handler:^(UIAction *action) {
        MUCertificateCreationView *form = [MUCertificateCreationView new];
        [weakSelf presentViewController:[[UINavigationController alloc] initWithRootViewController:form] animated:YES completion:nil];
    }];
    UIAction *filter = [UIAction actionWithTitle:self->_showAll ? NSLocalizedString(@"Show Identities Only", nil) : NSLocalizedString(@"Show All Certificates", nil) image:[UIImage systemImageNamed:@"line.3.horizontal.decrease"] identifier:nil handler:^(UIAction *action) {
        MUCertificatePreferencesViewController *controller = weakSelf;
        if (!controller) return;
        controller->_showAll = !controller->_showAll;
        [NSUserDefaults.standardUserDefaults setBool:controller->_showAll forKey:@"CertificatesShowIntermediates"];
        [controller fetchCertificates]; [controller.tableView reloadData];
    }];
    UIAction *import = [UIAction actionWithTitle:NSLocalizedString(@"Import From iTunes", nil) image:[UIImage systemImageNamed:@"square.and.arrow.down"] identifier:nil handler:^(UIAction *action) {
        MUCertificateDiskImportViewController *files = [MUCertificateDiskImportViewController new];
        [weakSelf presentViewController:[[UINavigationController alloc] initWithRootViewController:files] animated:YES completion:nil];
    }];
    return @[generate, import, filter];
}

#pragma mark -
#pragma mark Utils

- (void) fetchCertificates {
    NSArray *persistentRefs = [MUCertificateController persistentRefsForIdentities];

    _certificateItems = nil;
    _selectedIndex = NSNotFound;

    if (persistentRefs) {
        _certificateItems = [[NSMutableArray alloc] initWithCapacity:[persistentRefs count]];
        for (NSData *persistentRef in persistentRefs) {
            MLCertificate *cert = [MUCertificateController certificateWithPersistentRef:persistentRef];
            if (cert) {
                [_certificateItems addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                              cert,                          @"cert",
                                              persistentRef,                 @"persistentRef",
                                              [NSNumber numberWithBool:YES], @"isIdentity",
                                              nil]];
            }
        }
    }

    if (_showAll) {
        // Extract hashes of identity certs
        NSMutableArray *identityCertHashes = [[NSMutableArray alloc] init];
        for (NSDictionary *item in _certificateItems) {
            MLCertificate *cert = [item objectForKey:@"cert"];
            [identityCertHashes addObject:[cert digest]];
        }

        // Extract all intermediates
        NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
                                    (id)kSecClassCertificate, kSecClass,
                                    kCFBooleanTrue,       kSecReturnPersistentRef,
                                    kSecMatchLimitAll,    kSecMatchLimit, nil];
        NSArray *persistentRefs = nil;
        CFTypeRef rawPersistentRefs = NULL;
        SecItemCopyMatching((CFDictionaryRef)query, &rawPersistentRefs);
        persistentRefs = (NSArray *)CFBridgingRelease(rawPersistentRefs);
    
        for (NSData *ref in persistentRefs) {
            NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
                                   ref,      kSecValuePersistentRef,
                                   kCFBooleanTrue,     kSecReturnRef,
                                   kSecMatchLimitOne,  kSecMatchLimit,
                                   nil];
            SecCertificateRef secCert;
            if (SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&secCert) == noErr && secCert != NULL) {
                CFDataRef rawCertData = SecCertificateCopyData(secCert);
                NSData *certData = (NSData *) CFBridgingRelease(rawCertData);
                CFRelease(secCert);
                
                MLCertificate *consideredCert = [MLCertificate certificateWithCertificate:certData privateKey:nil];
                NSData *consideredDigest = [consideredCert digest];
    
                BOOL alreadyPresent = NO;
                for (NSData *digest in identityCertHashes) {
                    if ([consideredDigest isEqualToData:digest]) {
                        alreadyPresent = YES;
                        break;
                    }
                }

                if (!alreadyPresent) {
                    [_certificateItems addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                                  consideredCert,                @"cert",
                                                  ref,                           @"persistentRef",
                                                  [NSNumber numberWithBool:NO],  @"isIdentity",
                                                  nil]];
                }
            }
        }
    }
}

- (void) deleteCertificateForRow:(NSUInteger)row {
    // Delete a certificate from the keychain
    NSDictionary *dict = [_certificateItems objectAtIndex:row];
    OSStatus err = [MUCertificateController deleteCertificateWithPersistentRef:[dict objectForKey:@"persistentRef"]];
    if (err == noErr) {
        [_certificateItems removeObjectAtIndex:row];
    }
}

@end

