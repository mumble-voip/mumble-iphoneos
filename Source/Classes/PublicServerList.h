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

#import <Foundation/Foundation.h>

@class PublicServerList;

@protocol PublicServerListDelegate
- (void) serverListReady:(PublicServerList *)list;
- (void) serverListError:(NSError *)error;
@end


@interface PublicServerList : NSObject <NSXMLParserDelegate> {
	NSURLRequest *urlRequest;
	NSURLResponse *urlResponse;
	NSMutableData *serverListData;

	NSMutableDictionary *continentCountries;
	NSMutableDictionary *countryServers;

	NSDictionary *continentNames;
	NSDictionary *countryNames;

	NSMutableArray *modelContinents;
	NSMutableArray *modelCountries;

	id<PublicServerListDelegate> delegate;
}

- (id) init;
- (void) dealloc;

#pragma mark Public methods

- (void) load;
- (void) setDelegate:(id)selector;

#pragma mark Model access

- (NSInteger) numberOfContinents;
- (NSString *) continentNameAtIndex:(NSInteger)index;
- (NSInteger) numberOfCountriesAtContinentIndex:(NSInteger)index;
- (NSDictionary *) countryAtIndexPath:(NSIndexPath *)indexPath;

@end
