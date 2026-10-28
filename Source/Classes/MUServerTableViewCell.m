// Use of this source code is governed by the BSD-style license in LICENSE.
#import "MUServerTableViewCell.h"
@implementation MUServerTableViewCell
- (id)initWithReuseIdentifier:(NSString *)identifier {
    return [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    UIListContentConfiguration *content = (id)self.contentConfiguration;
    CGFloat leading = _channelRow ? 16 : content.directionalLayoutMargins.leading + 48;
    UIEdgeInsets safe = self.safeAreaInsets;
    // Separators use cell-edge coordinates, while UIKit keeps the row content
    // inside its safe area. Respect the same boundary for vertical system bars.
    self.separatorInset = self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft ? UIEdgeInsetsMake(0, safe.left + 16, 0, safe.right + leading) : UIEdgeInsetsMake(0, safe.left + leading, 0, safe.right + 16);
}
@end
