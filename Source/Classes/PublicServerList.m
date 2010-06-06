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

#import "PublicServerList.h"
#import <MumbleKit/MKServices.h>

@implementation PublicServerList

- (id) init {
	self = [super init];
	if (self == nil)
		return nil;

	continentNames = [[NSDictionary alloc] initWithContentsOfFile: [NSString stringWithFormat:@"%@/Continents.plist", [[NSBundle mainBundle] resourcePath]]];
	countryNames = [[NSDictionary alloc] initWithContentsOfFile: [NSString stringWithFormat:@"%@/Countries.plist", [[NSBundle mainBundle] resourcePath]]];

	return self;
}

- (void) dealloc {
	[modelContinents release];
	[modelCountries release];

	[continentNames release];
	[countryNames release];

	[super dealloc];
}

- (void) setDelegate:(id)selector {
	delegate = selector;
}

- (void) load {
	// Setup request.
	urlRequest = [NSURLRequest requestWithURL:[MKServices regionalServerListURL]];
	[NSURLConnection connectionWithRequest:urlRequest delegate:self];
}

#pragma mark -
#pragma mark NSConnection delegate methods

/*
 * Called when new data from the NSURLConnecting is available.
 */
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	if (serverListData == nil) {
		serverListData = [[NSMutableData alloc] init];
	}
	[serverListData appendData:data];
}

/*
 * Called when we fail to grab the server list.
 */
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	NSLog(@"PublicServerList: Failed to fetch public server list.");

	if ([(NSObject *)delegate respondsToSelector:@selector(serverListError:)]) {
		[delegate serverListError:error];
	}
}

/*
 * Called when we're done loading the server list XML. Time to parse it!
 */
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	NSLog(@"PublicServerList: Finished loading list.");

	continentCountries = [[NSMutableDictionary alloc] initWithCapacity:[continentNames count]];
	countryServers = [[NSMutableDictionary alloc] init];

	// Parse XML server list
	NSXMLParser *parser = [[NSXMLParser alloc] initWithData:serverListData];
	[parser setDelegate:self];
	[parser parse];
	[parser release];

	// Transform from NSDictionary representation to a NSArray-model
	NSArray *continentCodes = [[continentNames allKeys] sortedArrayUsingSelector:@selector(compare:)];
	[modelContinents release];
	modelContinents = [[NSMutableArray alloc] initWithCapacity:[continentCodes count]];
	[modelCountries release];
	modelCountries = [[NSMutableArray alloc] init];

	for (NSString *key in continentCodes) {
		[modelContinents addObject:[continentNames objectForKey:key]];

		NSSet *countryCodeSet = [continentCountries objectForKey:key];
		NSArray *countryCodes = [[countryCodeSet allObjects] sortedArrayUsingSelector:@selector(compare:)];

		NSMutableArray *countries = [NSMutableArray arrayWithCapacity:[countryCodes count]];

		for (NSString *countryKey in countryCodes) {
			NSString *countryName = [countryNames objectForKey:countryKey];
			NSArray *countryServerList = [countryServers objectForKey:countryKey];
			NSDictionary *country = [NSDictionary dictionaryWithObjectsAndKeys:
										countryName, @"name",
										countryServerList, @"servers", nil];
			[countries addObject:country];
		}
		[modelCountries addObject:countries];
	}

	[continentCountries release];
	[countryServers release];
	continentCountries = countryServers = nil;

	[serverListData release];
	serverListData = nil;

	// Call our delegate.
	if ([(NSObject *)delegate respondsToSelector:@selector(serverListReady:)]) {
		[delegate serverListReady:self];
	}
}

#pragma mark -
#pragma mark NSXMLParserDelegate methods

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict {
	if ([elementName isEqual:@"server"]) {
		NSString *countryCode = [attributeDict objectForKey:@"country_code"];
		if (countryCode) {

			// Get server array for this particular country
			NSMutableArray *array = [countryServers objectForKey:countryCode];
			if (array == nil) {
				// No array available. Create a new one.
				array = [NSMutableArray arrayWithCapacity:50];
				[countryServers setObject:array forKey:countryCode];
			}
			// Add attribute dict to server array.
			[array addObject:[attributeDict retain]];

			// Extract the continent code of the country
			NSString *continentCode = [attributeDict objectForKey:@"continent_code"];
			// Get our country set from our continent -> countries mapping
			NSMutableSet *countries = [continentCountries objectForKey:continentCode];
			if (countries == nil) {
				// No set for continent? Create a new one.
				countries = [NSMutableSet setWithCapacity:100];
				[continentCountries setObject:countries forKey:continentCode];
			}
			[countries addObject:countryCode];
		}
	}
}

- (void)parserDidEndDocument:(NSXMLParser *)parser {
}

#pragma mark -
#pragma mark Model access

- (NSInteger) numberOfContinents {
	return [continentNames count];
}

- (NSString *) continentNameAtIndex:(NSInteger)index {
	return [modelContinents objectAtIndex:index];
}

- (NSInteger) numberOfCountriesAtContinentIndex:(NSInteger)index {
	return [[modelCountries objectAtIndex:index] count];
}

- (NSDictionary *) countryAtIndexPath:(NSIndexPath *)indexPath {
	return [[modelCountries objectAtIndex:[indexPath indexAtPosition:0]] objectAtIndex:[indexPath indexAtPosition:1]];
}

@end
