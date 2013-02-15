// Copyright 2013 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

@interface MUTextMessageProcessor : NSObject
+ (NSString *) processedHTMLFromPlainTextMessage:(NSString *)plain;
@end
