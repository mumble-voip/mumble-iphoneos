// Use of this source code is governed by the BSD-style license in LICENSE.

#import "MUAboutViewController.h"
#import "MULegalViewController.h"

@implementation MUAboutViewController

- (id)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedString(@"About", nil);
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 56;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:animated];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 1 : 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"aboutItem"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"aboutItem"];
    UIListContentConfiguration *content;
    if (indexPath.section == 0) {
        content = [UIListContentConfiguration subtitleCellConfiguration];
        content.text = @"Mumble";
        content.textProperties.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle1];
        NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        content.secondaryText = [NSString stringWithFormat:@"%@\n%@", version, NSLocalizedString(@"Low latency, high quality voice chat", nil)];
        content.secondaryTextProperties.numberOfLines = 0;
        content.secondaryTextProperties.color = UIColor.secondaryLabelColor;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else {
        content = [UIListContentConfiguration cellConfiguration];
        content.text = @[NSLocalizedString(@"Website", nil), NSLocalizedString(@"Legal", nil), NSLocalizedString(@"Support", nil)][indexPath.row];
        content.image = [UIImage systemImageNamed:@[@"globe", @"doc.text", @"questionmark.circle"][indexPath.row]];
        content.imageProperties.tintColor = UIColor.labelColor;
        content.imageProperties.reservedLayoutSize = CGSizeMake(28, 28);
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    cell.contentConfiguration = content;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != 1) return;
    if (indexPath.row == 1) {
        UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:[MULegalViewController new]];
        [self presentViewController:navigation animated:YES completion:nil];
    } else {
        NSString *address = indexPath.row == 0 ? @"https://www.mumble.info/" : @"https://github.com/mumble-voip/mumble-iphoneos/issues";
        [UIApplication.sharedApplication openURL:[NSURL URLWithString:address] options:@{} completionHandler:nil];
    }
}

@end
