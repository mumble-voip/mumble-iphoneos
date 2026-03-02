// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUCertificatePreferencesViewController.h"
#import "MUCertificateCell.h"
#import "MUCertificateCreationView.h"
#import "MUCertificateViewController.h"
#import "MUCertificateController.h"
#import "MUCertificateDiskImportViewController.h"
#import "MUBackgroundView.h"
#import "MUColor.h"

#import <MumbleKit/MKCertificate.h>

// Section 0: Username
// Section 1: Certificates (profiles)
enum {
    MUProfilesSectionUsername = 0,
    MUProfilesSectionCertificates = 1,
    MUProfilesSectionCount = 2,
};

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
    UITableViewStyle style;
    if (@available(iOS 13.0, *)) {
        style = UITableViewStyleInsetGrouped;
    } else {
        style = UITableViewStyleGrouped;
    }
    if ((self = [super initWithStyle:style])) {
        self.preferredContentSize = CGSizeMake(320, 480);
        _showAll = [[[NSUserDefaults standardUserDefaults] objectForKey:@"CertificatesShowIntermediates"] boolValue];
    }
    return self;
}

#pragma mark -
#pragma mark View lifecycle

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.navigationItem.title = NSLocalizedString(@"My Profiles", nil);
    
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = YES;
        self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
    }
    
    self.tableView.backgroundView = [MUBackgroundView backgroundView];
    
    [self fetchCertificates];
    [self.tableView reloadData];
    
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addButtonClicked:)];
    [self.navigationItem setRightBarButtonItem:addButton];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return MUProfilesSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == MUProfilesSectionUsername)
        return 1;
    if (section == MUProfilesSectionCertificates)
        return [_certificateItems count];
    return 0;
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == MUProfilesSectionUsername)
        return NSLocalizedString(@"Display Name", nil);
    if (section == MUProfilesSectionCertificates)
        return NSLocalizedString(@"Certificates", nil);
    return nil;
}

- (NSString *) tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == MUProfilesSectionUsername)
        return NSLocalizedString(@"This name is used when connecting to servers that don't have a specific username set.", nil);
    if (section == MUProfilesSectionCertificates)
        return NSLocalizedString(@"Certificates identify you to servers. Select a certificate to use it as your default identity.", nil);
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == MUProfilesSectionUsername) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"UsernameCell"];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"UsernameCell"];
        }
        cell.textLabel.text = NSLocalizedString(@"Username", nil);
        NSString *username = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultUserName"];
        cell.detailTextLabel.text = username ? username : @"MumbleUser";
        cell.detailTextLabel.textColor = [MUColor selectedTextColor];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        return cell;
    }
    
    // Certificates section
    static NSString *CellIdentifier = @"CertificateCell";
    MUCertificateCell *cell = (MUCertificateCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
        cell = [MUCertificateCell loadFromNib];
    
    NSDictionary *dict = [_certificateItems objectAtIndex:[indexPath row]];
    MKCertificate *cert = [dict objectForKey:@"cert"];
    [cell setSubjectName:[cert subjectName]];
    [cell setEmail:[cert emailAddress]];
    [cell setIssuerText:[cert issuerName]];
    
    if ([cert isValidOnDate:[NSDate date]]) {
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd"];
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
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
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

    if (@available(iOS 7, *)) {
        [cell setAccessoryType:UITableViewCellAccessoryDetailButton];
    } else {
        [cell setAccessoryType:UITableViewCellAccessoryDetailDisclosureButton];
    }

    return (UITableViewCell *) cell;
}


#pragma mark -
#pragma mark Table view delegate

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == MUProfilesSectionCertificates)
        return UITableViewCellEditingStyleDelete;
    return UITableViewCellEditingStyleNone;
}

- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == MUProfilesSectionCertificates;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == MUProfilesSectionUsername) {
        [self showUsernameEditor];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    // Certificate section
    NSDictionary *dict = [_certificateItems objectAtIndex:[indexPath row]];
    
    if (![[dict objectForKey:@"isIdentity"] boolValue]) {
        return;
    }
        
    NSData *persistentRef = [dict objectForKey:@"persistentRef"];
    [[NSUserDefaults standardUserDefaults] setObject:persistentRef forKey:@"DefaultCertificate"];

    MUCertificateCell *prevCell = (MUCertificateCell *) [[self tableView] cellForRowAtIndexPath:[NSIndexPath indexPathForRow:_selectedIndex inSection:MUProfilesSectionCertificates]];
    MUCertificateCell *curCell = (MUCertificateCell *) [[self tableView] cellForRowAtIndexPath:indexPath];
    [prevCell setIsCurrentCertificate:NO];
    [curCell setIsCurrentCertificate:YES];
    _selectedIndex = [indexPath row];

    [[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
}

- (void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete && indexPath.section == MUProfilesSectionCertificates) {
        [self deleteCertificateForRow:[indexPath row]];
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationRight];
    }
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == MUProfilesSectionUsername)
        return 44.0f;
    return 85.0f;
}

- (void) tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != MUProfilesSectionCertificates) return;
    NSDictionary *dict = [_certificateItems objectAtIndex:[indexPath row]];
    NSData *persistentRef = [dict objectForKey:@"persistentRef"];
    MUCertificateViewController *certView = [[MUCertificateViewController alloc] initWithPersistentRef:persistentRef];
    [[self navigationController] pushViewController:certView animated:YES];
}

#pragma mark -
#pragma mark Username editor

- (void) showUsernameEditor {
    NSString *currentUsername = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultUserName"];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Display Name", nil)
                                                                   message:NSLocalizedString(@"Enter the username you want to use when connecting to servers.", nil)
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.text = currentUsername;
        textField.placeholder = @"MumbleUser";
        textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Save", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *newUsername = [[alert.textFields firstObject] text];
        if (newUsername && [newUsername length] > 0) {
            [[NSUserDefaults standardUserDefaults] setObject:newUsername forKey:@"DefaultUserName"];
            [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:MUProfilesSectionUsername]]
                                  withRowAnimation:UITableViewRowAnimationNone];
        }
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark -
#pragma mark Target/actions

- (void) addButtonClicked:(UIBarButtonItem *)addButton {
    NSString *showAllCerts = NSLocalizedString(@"Show All Certificates", nil);
    NSString *showIdentities = NSLocalizedString(@"Show Identities Only", nil);
    
    UIAlertController *sheetCtrl = [UIAlertController alertControllerWithTitle:nil
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
    
    [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                   style:UIAlertActionStyleCancel
                                                 handler:nil]];
    
    [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Create New Profile", nil)
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * _Nonnull action) {
        UINavigationController *navCtrl = [[UINavigationController alloc] init];
        navCtrl.modalPresentationStyle = UIModalPresentationCurrentContext;
        MUCertificateCreationView *certGen = [[MUCertificateCreationView alloc] init];
        [navCtrl pushViewController:certGen animated:NO];
        [[self navigationController] presentViewController:navCtrl animated:YES completion:nil];
    }]];
    
    [sheetCtrl addAction: [UIAlertAction actionWithTitle:_showAll ? showIdentities : showAllCerts
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * _Nonnull action) {
        self->_showAll = !self->_showAll;
        [[NSUserDefaults standardUserDefaults] setBool:self->_showAll forKey:@"CertificatesShowIntermediates"];
        [self fetchCertificates];
        [self.tableView reloadData];
    }]];
    
    [sheetCtrl addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Import From iTunes", nil)
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * _Nonnull action) {
        MUCertificateDiskImportViewController *diskImportViewController = [[MUCertificateDiskImportViewController alloc] init];
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:diskImportViewController];
        [[self navigationController] presentViewController:navController animated:YES completion:nil];
    }]];
    
    [self presentViewController:sheetCtrl animated:YES completion:nil];
}

#pragma mark -
#pragma mark Utils

- (void) fetchCertificates {
    NSArray *persistentRefs = [MUCertificateController persistentRefsForIdentities];

    _certificateItems = nil;

    if (persistentRefs) {
        _certificateItems = [[NSMutableArray alloc] initWithCapacity:[persistentRefs count]];
        for (NSData *persistentRef in persistentRefs) {
            MKCertificate *cert = [MUCertificateController certificateWithPersistentRef:persistentRef];
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
        NSMutableArray *identityCertHashes = [[NSMutableArray alloc] init];
        for (NSDictionary *item in _certificateItems) {
            MKCertificate *cert = [item objectForKey:@"cert"];
            [identityCertHashes addObject:[cert digest]];
        }

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
                
                MKCertificate *consideredCert = [MKCertificate certificateWithCertificate:certData privateKey:nil];
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
    NSDictionary *dict = [_certificateItems objectAtIndex:row];
    OSStatus err = [MUCertificateController deleteCertificateWithPersistentRef:[dict objectForKey:@"persistentRef"]];
    if (err == noErr) {
        [_certificateItems removeObjectAtIndex:row];
    }
}

@end
