/* Copyright (C) 2009-2010 Mikkel Krautz <mikkel@krautz.dk>

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

#import "MUCertificatePreferencesViewController.h"
#import "MUCertificateCell.h"
#import "MUCertificateCreationView.h"
#import "MUCertificateViewController.h"
#import "MUCertificateController.h"
#import "MUCertificateDiskImportViewController.h"

#import <MumbleKit/MKCertificate.h>

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
    if ((self = [super init])) {
        [self setContentSizeForViewInPopover:CGSizeMake(320, 480)];
        _showAll = [[[NSUserDefaults standardUserDefaults] objectForKey:@"CertificatesShowIntermediates"] boolValue];
    }
    return self;
}

- (void) dealloc {
    [_certificateItems release];
    [super dealloc];
}

#pragma mark -
#pragma mark View lifecycle

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.navigationItem.title = NSLocalizedString(@"Certificates", nil);

    [self fetchCertificates];
    [self.tableView reloadData];
    
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addButtonClicked:)];
    [self.navigationItem setRightBarButtonItem:addButton];
    [addButton release];
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
        cell = [MUCertificateCell loadFromNib];
    
    // Configure the cell...
    NSDictionary *dict = [_certificateItems objectAtIndex:[indexPath row]];
    MKCertificate *cert = [dict objectForKey:@"cert"];
    [cell setSubjectName:[cert subjectName]];
    [cell setEmail:[cert emailAddress]];
    [cell setIssuerText:[cert issuerName]];
    [cell setExpiryText:[[cert notAfter] description]];

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

    [cell setAccessoryType:UITableViewCellAccessoryDetailDisclosureButton];
    
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

    MUCertificateCell *prevCell = (MUCertificateCell *) [[self tableView] cellForRowAtIndexPath:[NSIndexPath indexPathForRow:_selectedIndex inSection:0]];
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
    return 85.0f;
}

- (void) tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *dict = [_certificateItems objectAtIndex:[indexPath row]];
    NSData *persistentRef = [dict objectForKey:@"persistentRef"];
    MUCertificateViewController *certView = [[MUCertificateViewController alloc] initWithPersistentRef:persistentRef];
    [[self navigationController] pushViewController:certView animated:YES];
    [certView release];
}

#pragma mark -
#pragma mark Target/actions

- (void) addButtonClicked:(UIBarButtonItem *)addButton {
    NSString *showAllCerts = NSLocalizedString(@"Show All Certificates", nil);
    NSString *showIdentities = NSLocalizedString(@"Show Identities Only", nil);
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:NSLocalizedString(@"Generate New Certificate", nil),
                                                                _showAll ? showIdentities : showAllCerts,
                                                                NSLocalizedString(@"Import From iTunes", nil),
                            nil];
    [sheet setActionSheetStyle:UIActionSheetStyleBlackOpaque];
    [sheet showInView:[self tableView]];
    [sheet release];
}

#pragma mark -
#pragma mark UIActionSheet delegate

- (void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)idx {
    if (idx == 0) { // Generate New Certificate
        UINavigationController *navCtrl = [[UINavigationController alloc] init];
        navCtrl.modalPresentationStyle = UIModalPresentationCurrentContext;
        MUCertificateCreationView *certGen = [[MUCertificateCreationView alloc] init];
        [navCtrl pushViewController:certGen animated:NO];
        [certGen release];
        [[self navigationController] presentModalViewController:navCtrl animated:YES];
        [navCtrl release];
    } else if (idx == 1) { // Show All Certificates; Show Identities Only
        _showAll = !_showAll;
        [[NSUserDefaults standardUserDefaults] setBool:_showAll forKey:@"CertificatesShowIntermediates"];
        [self fetchCertificates];
        [self.tableView reloadData];
    } else if (idx == 2) { // Import From Disk
        MUCertificateDiskImportViewController *diskImportViewController = [[MUCertificateDiskImportViewController alloc] init];
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:diskImportViewController];
        [[self navigationController] presentModalViewController:navController animated:YES];
        [diskImportViewController release];
        [navController release];
    }
}

#pragma mark -
#pragma mark Utils

- (void) fetchCertificates {
    NSArray *persistentRefs = [MUCertificateController allPersistentRefs];

    [_certificateItems release];
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
        // Extract hashes of identity certs
        NSMutableArray *identityCertHashes = [[[NSMutableArray alloc] init] autorelease];
        for (NSDictionary *item in _certificateItems) {
            [identityCertHashes addObject:[[item objectForKey:@"cert"] digest]];
        }

        // Extract all intermediates
        NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
                                    kSecClassCertificate, kSecClass,
                                    kCFBooleanTrue,       kSecReturnPersistentRef,
                                    kSecMatchLimitAll,    kSecMatchLimit, nil];
        NSArray *persistentRefs = nil;
        SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&persistentRefs);
        [persistentRefs autorelease];
    
        for (NSData *ref in persistentRefs) {
            NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
                                   ref,      kSecValuePersistentRef,
                                   kCFBooleanTrue,     kSecReturnRef,
                                   kSecMatchLimitOne,  kSecMatchLimit,
                                   nil];
            SecCertificateRef secCert;
            if (SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&secCert) == noErr && secCert != NULL) {
                NSData *certData = (NSData *) SecCertificateCopyData(secCert);
                CFRelease(secCert);
                
                MKCertificate *consideredCert = [MKCertificate certificateWithCertificate:certData privateKey:nil];
                NSData *consideredDigest = [consideredCert digest];
                [certData release];
    
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

