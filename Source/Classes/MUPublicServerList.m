// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUPublicServerList.h"
#import "MLClient.h"

@interface MUPublicServerList () {
    NSMutableDictionary *_continentCountries;
    NSMutableDictionary *_countryServers;
    NSMutableArray      *_modelContinents;
    NSMutableArray      *_modelCountries;
    NSMutableSet        *_seenServers;
    BOOL                _parsed;
}
+ (NSString *) filePath;
+ (BOOL) dataLooksLikeServerList:(NSData *)data;
@end

NSString * const MUPublicServerListDidUpdateNotification = @"MUPublicServerListDidUpdateNotification";

@implementation MUPublicServerListFetcher

- (void) attemptUpdate {
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[MLServices regionalServerListURL]];
    // The public list answers GET with an empty 501. A POST returns the XML.
    req.HTTPMethod = @"POST";
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSInteger status = 0;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            status = [(NSHTTPURLResponse *)response statusCode];
        }
        if (error || status != 200 || ![MUPublicServerList dataLooksLikeServerList:data]) {
            return;
        }
        [data writeToFile:[MUPublicServerList filePath] atomically:YES];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:MUPublicServerListDidUpdateNotification object:nil];
        });
    }];
    [task resume];
}

@end


@implementation MUPublicServerList

+ (BOOL) dataLooksLikeServerList:(NSData *)data {
    if (data.length < 200) {
        return NO;
    }
    NSData *marker = [@"<server" dataUsingEncoding:NSUTF8StringEncoding];
    return [data rangeOfData:marker options:0 range:NSMakeRange(0, data.length)].location != NSNotFound;
}

+ (NSString *) filePath {
    NSArray *documentDirectories = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                                                       NSUserDomainMask,
                                                                       YES);
    NSString *directory = [documentDirectories objectAtIndex:0];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    return [directory stringByAppendingPathComponent:@"publist.xml"];
}

- (NSData *) bundledListData {
    return [[NSData alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"publist" ofType:@"xml"]];
}

- (NSData *) downloadedListData {
    return [[NSData alloc] initWithContentsOfFile:[MUPublicServerList filePath]];
}

- (void) invalidate {
    _parsed = NO;
    _modelContinents = nil;
    _modelCountries = nil;
}

- (void) parse {
    // Job's done.
    if (_parsed)
        return;

    _continentCountries = [[NSMutableDictionary alloc] initWithCapacity:7];
    _countryServers = [[NSMutableDictionary alloc] init];
    _seenServers = [[NSMutableSet alloc] init];

    // The bundled snapshot and the current public list each omit servers the other has.
    for (NSData *data in @[ [self bundledListData] ?: [NSData data], [self downloadedListData] ?: [NSData data] ]) {
        if (![MUPublicServerList dataLooksLikeServerList:data]) {
            continue;
        }
        NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
        [parser setDelegate:(id<NSXMLParserDelegate>)self];
        [parser parse];
    }

    // Transform from NSDictionary representation to a NSArray-model
    NSArray *continentCodes = [[_continentCountries allKeys] sortedArrayUsingSelector:@selector(compare:)];
    _modelContinents = [[NSMutableArray alloc] initWithCapacity:[continentCodes count]];
    _modelCountries = [[NSMutableArray alloc] init];
    NSLocale *displayLocale = [NSLocale localeWithLocaleIdentifier:NSBundle.mainBundle.preferredLocalizations.firstObject ?: @"en"];
    NSDictionary *continentTitles = @{
        @"AF": NSLocalizedString(@"Africa", nil), @"AS": NSLocalizedString(@"Asia", nil),
        @"EU": NSLocalizedString(@"Europe", nil), @"NA": NSLocalizedString(@"North America", nil),
        @"SA": NSLocalizedString(@"South America", nil), @"OC": NSLocalizedString(@"Oceania", nil),
        @"nil": NSLocalizedString(@"Unknown", nil)
    };

    for (NSString *key in continentCodes) {
        if (key.length == 0) {
            continue;
        }
        NSSet *countryCodeSet = [_continentCountries objectForKey:key];
        NSArray *countryCodes = [[countryCodeSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
        if (countryCodes.count == 0) {
            continue;
        }

        NSString *continentName = continentTitles[key] ?: key;
        [_modelContinents addObject:continentName];

        NSMutableArray *countries = [NSMutableArray arrayWithCapacity:[countryCodes count]];
        for (NSString *countryKey in countryCodes) {
            NSArray *countryServerList = [_countryServers objectForKey:countryKey];
            if (countryServerList.count == 0) {
                continue;
            }
            NSString *countryName = [displayLocale displayNameForKey:NSLocaleCountryCode value:countryKey] ?: countryKey;
            [countries addObject:@{ @"name": countryName, @"servers": countryServerList }];
        }
        [_modelCountries addObject:countries];
    }

    _continentCountries = nil;
    _countryServers = nil;
    _seenServers = nil;
    _parsed = YES;
}

#pragma mark -
#pragma mark NSXMLParserDelegate methods

- (void) parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict {
    if ([elementName isEqualToString:@"server"]) {
        NSString *countryCode = [attributeDict objectForKey:@"country_code"];
        NSString *host = [attributeDict objectForKey:@"ip"];
        NSString *port = [attributeDict objectForKey:@"port"];
        if (host.length == 0 || port.length == 0) {
            return;
        }
        NSString *identity = [NSString stringWithFormat:@"%@:%@", host, port];
        if ([_seenServers containsObject:identity]) {
            return;
        }
        [_seenServers addObject:identity];
        if (countryCode.length == 0) {
            countryCode = @"??";
        }
        if (countryCode) {
            // Get server array for this particular country
            NSMutableArray *array = [_countryServers objectForKey:countryCode];
            if (array == nil) {
                // No array available. Create a new one.
                array = [NSMutableArray arrayWithCapacity:50];
                [_countryServers setObject:array forKey:countryCode];
            }
            // Add attribute dict to server array.
            [array addObject:attributeDict];

            // Extract the continent code of the country
            NSString *continentCode = [attributeDict objectForKey:@"continent_code"];
            if (continentCode.length == 0) {
                continentCode = @"nil";
            }
            // Get our country set from our continent -> countries mapping
            NSMutableSet *countries = [_continentCountries objectForKey:continentCode];
            if (countries == nil) {
                // No set for continent? Create a new one.
                countries = [NSMutableSet setWithCapacity:100];
                [_continentCountries setObject:countries forKey:continentCode];
            }
            [countries addObject:countryCode];
        }
    }
}

#pragma mark -
#pragma mark Model access

// Returns the number of continents in the public server list
- (NSInteger) numberOfContinents {
    return [_modelContinents count];
}

// Get continent at index 'idx'.
- (NSString *) continentNameAtIndex:(NSInteger)index {
    return [_modelContinents objectAtIndex:index];
}

// Get the number of countries in the continent at index 'idx'.
- (NSInteger) numberOfCountriesAtContinentIndex:(NSInteger)index {
    return [[_modelCountries objectAtIndex:index] count];
}

// Get a dictionary representing a country.
- (NSDictionary *) countryAtIndexPath:(NSIndexPath *)indexPath {
    return [[_modelCountries objectAtIndex:[indexPath indexAtPosition:0]] objectAtIndex:[indexPath indexAtPosition:1]];
}

// Return whether or not the server list has already been parsed
- (BOOL) isParsed {
    return _parsed;
}

@end
