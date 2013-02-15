// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUFavouriteServer.h"

@interface MUFavouriteServerEditViewController : UITableViewController 
- (id) initInEditMode:(BOOL)editMode withContentOfFavouriteServer:(MUFavouriteServer *)favServ;
- (id) init;
- (void) dealloc;

#pragma mark Accessors

- (MUFavouriteServer *) copyFavouriteFromContent;

#pragma mark Target and action handlers

- (void) setTarget:(id)target;
- (id) target;

- (void) setDoneAction:(SEL)action;
- (SEL) doneAction;

@end
