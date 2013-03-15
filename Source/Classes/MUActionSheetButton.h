// Copyright 2013 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

typedef enum {
    MUActionSheetButtonKindNormal,
    MUActionSheetButtonKindCancel,
    MUActionSheetButtonKindDestructive,
    MUActionSheetButtonKindConstructive,
} MUActionSheetButtonKind;

@interface MUActionSheetButton : UIControl
+ (MUActionSheetButton *) buttonWithKind:(MUActionSheetButtonKind)kind;
- (NSString *) title;
- (void) setTitle:(NSString *)title;
@end
