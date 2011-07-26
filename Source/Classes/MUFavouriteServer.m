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

#import "MUFavouriteServer.h"
#import "MUDatabase.h"

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
