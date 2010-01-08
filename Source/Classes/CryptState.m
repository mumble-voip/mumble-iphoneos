/* Copyright (C) 2005-2009, Thorvald Natvig <thorvald@natvig.com>
   Copyright (C) 2009-2010 Mikkel Krautz <mikkel@krautz.dk>

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

/*
 * This code implements OCB-AES128.
 * In the US, OCB is covered by patents. The inventor has given a license
 * to all programs distributed under the GPL.
 * Mumble is BSD (revised) licensed, meaning you can use the code in a
 * closed-source program. If you do, you'll have to either replace
 * OCB with something else or get yourself a license.
 */

#import "CryptState.h"

@implementation CryptState

- (id) init {
	int i;

	self = [super init];
	if (self == nil)
		return nil;

	for (i = 0; i < 0x100; i++)
		decryptHistory[i] = 0;

	initialized = NO;
	numGood = numLost = numResync = 0;

	return self;
}

- (void) dealloc {
	[super dealloc];
	NSLog(@"CryptState: Dealloc.");
}

- (BOOL) valid {
	return initialized;
}

- (void) generateKey {
}

- (void) setKey:(NSData *)key eiv:(NSData *)enc div:(NSData *)dec {
}

- (void) setDecryptIV:(NSData *)dec {
}

- (NSData *) encryptData:(NSData *)data {
	return nil;
}

- (NSData *) decryptData:(NSData *)data {
	return nil;
}

@end
