/* Copyright (C) 2005-2010 Thorvald Natvig <thorvald@natvig.com>
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

#import <MumbleKit/MKPacketDataStream.h>

@implementation MKPacketDataStream

- (id) initWithData:(NSData *)ourContainer {
	self = [super init];
	if (self == nil)
		return nil;

	immutableData = ourContainer;
	[immutableData retain];

	data = (unsigned char *)[immutableData bytes];
	offset = 0;
	overshoot = 0;
	maxSize = [immutableData length];
	ok = YES;

	return self;
}

- (id) initWithMutableData:(NSMutableData *)ourContainer {
	self = [super init];
	if (self == nil)
		return nil;

	mutableData = ourContainer;
	[mutableData retain];

	data = [mutableData mutableBytes];
	offset = 0;
	overshoot = 0;
	maxSize = [mutableData capactiy]; // fixme(mkrautz)
	ok = YES;

	return self;
}

- (id) initWithBuffer:(unsigned char *)buffer length:(NSUInteger)len {
	self = [super init];
	if (self == nil)
		return nil;

	mutableData = nil;
	data = buffer;
	offset = 0;
	overshoot = 0;
	maxSize = len;
	ok = YES;

	return self;
}

- (void) dealloc {
	[super dealloc];
	[mutableData release];
	[immutableData release];
}

- (NSUInteger) size {
	return offset;
}

- (NSUInteger) capactiy {
	return maxSize;
}

- (NSUInteger) left {
	return maxSize - offset;
}

- (BOOL) valid {
	return ok;
}

- (void) appendValue:(uint64_t)value {
	assert(value <= 0xff);

	if (offset < maxSize)
		data[offset++] = (unsigned char)value;
	else {
		ok = NO;
		overshoot++;
	}
}

- (void) appendBytes:(unsigned char *)buffer length:(NSUInteger)len {
	if ([self left] >= len) {
		memcpy(&data[offset], buffer, len);
		offset += len;
	} else {
		int l = [self left];
		memset(&data[offset], 0, l);
		overshoot += len - l;
		ok = NO;
	}
}

- (void) skip:(NSUInteger)amount {
	if ([self left] >= amount) {
		offset += amount;
	} else
		ok = NO;
}

- (uint64_t) next {
	if (offset < maxSize) {
		return data[offset++];
	} else {
		ok = NO;
		return 0;
	}
}

- (uint8_t) next8 {
	if (offset < maxSize) {
		return data[offset++];
	} else {
		ok = NO;
		return 0;
	}
}

- (void) rewind {
	offset = 0;
}

- (void) truncate {
	maxSize = offset;
}

- (unsigned char *) dataPtr {
	return (unsigned char *)&data[offset];
}

- (char *) charPtr {
	return (char *)&data[offset];
}

- (NSData *) data {
	return (NSData *)mutableData;
}

- (NSMutableData *) mutableData {
	return mutableData;
}

- (void) addVarint:(uint64_t)value {
	uint64_t i = value;

	if ((i & 0x8000000000000000LL) && (~i < 0x100000000LL)) {
		// Signed number.
		i = ~i;
		if (i <= 0x3) {
			// Shortcase for -1 to -4
			[self appendValue:(0xFC | i)];
		} else {
			[self appendValue:(0xF8)];
		}
	}
	if (i < 0x80) {
		// Need top bit clear
		[self appendValue:i];
	} else if (i < 0x4000) {
		// Need top two bits clear
		[self appendValue:((i >> 8) | 0x80)];
		[self appendValue:(i & 0xFF)];
	} else if (i < 0x200000) {
		// Need top three bits clear
		[self appendValue:((i >> 16) | 0xC0)];
		[self appendValue:((i >> 8) & 0xFF)];
		[self appendValue:(i & 0xFF)];
	} else if (i < 0x10000000) {
		// Need top four bits clear
		[self appendValue:((i >> 24) | 0xE0)];
		[self appendValue:((i >> 16) & 0xFF)];
		[self appendValue:((i >> 8) & 0xFF)];
		[self appendValue:(i & 0xFF)];
	} else if (i < 0x100000000LL) {
		// It's a full 32-bit integer.
		[self appendValue:(0xF0)];
		[self appendValue:((i >> 24) & 0xFF)];
		[self appendValue:((i >> 16) & 0xFF)];
		[self appendValue:((i >> 8) & 0xFF)];
		[self appendValue:(i & 0xFF)];
	} else {
		// It's a 64-bit value.
		[self appendValue:(0xF4)];
		[self appendValue:((i >> 56) & 0xFF)];
		[self appendValue:((i >> 48) & 0xFF)];
		[self appendValue:((i >> 40) & 0xFF)];
		[self appendValue:((i >> 32) & 0xFF)];
		[self appendValue:((i >> 24) & 0xFF)];
		[self appendValue:((i >> 16) & 0xFF)];
		[self appendValue:((i >> 8) & 0xFF)];
		[self appendValue:(i & 0xFF)];
	}
}

- (uint64_t) getVarint {
	uint64_t i = 0;
	uint64_t v = [self next];

	if ((v & 0x80) == 0x00) {
		i = (v & 0x7F);
	} else if ((v & 0xC0) == 0x80) {
		i = (v & 0x3F) << 8 | [self next];
	} else if ((v & 0xF0) == 0xF0) {
		switch (v & 0xFC) {
			case 0xF0:
				i=[self next] << 24 | [self next] << 16 | [self next] << 8 | [self next];
				break;
			case 0xF4:
				i = [self next] << 56 | [self next] << 48 | [self next] << 40 | [self next] << 32 | [self next] << 24 | [self next] << 16 | [self next] << 8 | [self next];
				break;
			case 0xF8:
				i = [self getVarint];
				i = ~i;
				break;
			case 0xFC:
				i = v & 0x03;
				i = ~i;
				break;
			default:
				ok = NO;
				i = 0;
				break;
		}
	} else if ((v & 0xF0) == 0xE0) {
		i = (v & 0x0F) << 24 | [self next] << 16 | [self next] << 8 | [self next];
	} else if ((v & 0xE0) == 0xC0) {
		i = (v & 0x1F) << 16 | [self next] << 8 | [self next];
	}
	return i;
}

- (unsigned int) getUnsignedInt {
	return (unsigned int) [self getVarint];
}

- (int) getInt {
	return (int) [self getVarint];
}

- (short) getShort {
	return (short) [self getVarint];
}

- (unsigned short) getUnsignedShort {
	return (unsigned short) [self getVarint];
}

- (char) getChar {
	return (char) [self getVarint];
}

- (unsigned char) getUnsignedChar {
	return (unsigned char) [self getVarint];
}

- (float) getFloat {
	float32u u;

	if ([self left] < 4) {
		ok = NO;
		return 0.0f;
	}

	u.b[0] = [self next8];
	u.b[1] = [self next8];
	u.b[2] = [self next8];
	u.b[3] = [self next8];

	return u.f;
}

- (double) getDouble {
	NSLog(@"PacketDataStream: getDouble not implemented yet.");
	return 0.0f;
}

- (NSData *) copyDataBlock:(NSUInteger)len {
	if ([self left] >= len) {
		NSData *db = [[NSData alloc] initWithBytes:[self dataPtr] length:len];
		offset += len;
		return db;
	} else {
		NSLog(@"PacketDataStream: Unable to copyDataBlock. Requsted=%u, avail=%u", len, [self left]);
		ok = NO;
		return nil;
	}
}

@end
