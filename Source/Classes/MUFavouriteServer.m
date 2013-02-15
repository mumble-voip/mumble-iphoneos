// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUFavouriteServer.h"
#import "MUDatabase.h"

@interface MUFavouriteServer () {
    NSInteger  _pkey;
    NSString   *_displayName;
    NSString   *_hostName;
    NSUInteger _port;
    NSString   *_userName;
    NSString   *_password;
}
@end

@implementation MUFavouriteServer

@synthesize primaryKey         = _pkey;
@synthesize displayName        = _displayName;
@synthesize hostName           = _hostName;
@synthesize port               = _port;
@synthesize userName           = _userName;
@synthesize password           = _password;

- (id) initWithDisplayName:(NSString *)displayName hostName:(NSString *)hostName port:(NSUInteger)port userName:(NSString *)userName password:(NSString *)passWord {
    self = [super init];
    if (self == nil)
        return nil;

    _pkey = -1;
    _displayName = [displayName copy];
    _hostName = [hostName copy];
    _port = port;
    _userName = [userName copy];
    _password = [passWord copy];

    return self;
}

- (id) init {
    return [self initWithDisplayName:nil hostName:nil port:0 userName:nil password:nil];
}

- (void) dealloc {
    [_displayName release];
    [_hostName release];
    [_userName release];
    [_password release];
    [super dealloc];
}

- (id) copyWithZone:(NSZone *)zone {
    MUFavouriteServer *favServ = [[MUFavouriteServer alloc] initWithDisplayName:_displayName hostName:_hostName port:_port userName:_userName password:_password];
    if ([self hasPrimaryKey])
        [favServ setPrimaryKey:[self primaryKey]];
    return favServ;
}

- (BOOL) hasPrimaryKey {
    return _pkey != -1;
}

- (NSComparisonResult) compare:(MUFavouriteServer *)favServ {
    return [_displayName caseInsensitiveCompare:[favServ displayName]];
}

@end
