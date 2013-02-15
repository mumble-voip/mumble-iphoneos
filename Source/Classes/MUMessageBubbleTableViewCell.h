// Copyright 2009-2012 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

@class MUMessageBubbleTableViewCell;

@protocol MUMessageBubbleTableViewCellDelegate
- (void) messageBubbleTableViewCellRequestedAttachmentViewer:(MUMessageBubbleTableViewCell *)cell;
- (void) messageBubbleTableViewCellRequestedDeletion:(MUMessageBubbleTableViewCell *)cell;
- (void) messageBubbleTableViewCellRequestedCopy:(MUMessageBubbleTableViewCell *)cell;
@end

@interface MUMessageBubbleTableViewCell : UITableViewCell
+ (CGFloat) heightForCellWithHeading:(NSString *)heading message:(NSString *)msg images:(NSArray *)images footer:(NSString *)footer date:(NSDate *)date;

- (id) initWithReuseIdentifier:(NSString *)reuseIdentifier;
- (void) setHeading:(NSString *)heading;
- (void) setMessage:(NSString *)msg;
- (void) setShownImages:(NSArray *)shownImages;
- (void) setFooter:(NSString *)footer;
- (void) setDate:(NSDate *)date;
- (void) setRightSide:(BOOL)rightSide;
- (void) setSelected:(BOOL)selected;

- (id<MUMessageBubbleTableViewCellDelegate>) delegate;
- (void) setDelegate:(id<MUMessageBubbleTableViewCellDelegate>)delegate;
@end
