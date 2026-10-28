// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

extern NSString * const MUPublicServerListDidUpdateNotification;

@interface MUPublicServerListFetcher : NSObject
- (void) attemptUpdate;
@end

@interface MUPublicServerList : NSObject <NSXMLParserDelegate> 
- (void) invalidate;
- (void) parse;
- (BOOL) isParsed;
- (NSInteger) numberOfContinents;
- (NSString *) continentNameAtIndex:(NSInteger)index;
- (NSInteger) numberOfCountriesAtContinentIndex:(NSInteger)index;
- (NSDictionary *) countryAtIndexPath:(NSIndexPath *)indexPath;
@end
