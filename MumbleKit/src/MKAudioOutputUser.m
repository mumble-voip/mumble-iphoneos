/* Copyright (C) 2009-2010 Mikkel Krautz <mikkel@krautz.dk>
   Copyright (C) 2005-2010 Thorvald Natvig <thorvald@natvig.com>

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

#import <MumbleKit/MKAudioOutputUser.h>

@implementation MKAudioOutputUser

- (id) init {
	self = [super init];
	if (self == nil)
		return nil;

	bufferSize = 0;
	buffer = NULL;
	volume = NULL;

	pos[0] = pos[1] = pos[2] = 0.0f;

	return self;
}

- (void) dealloc {
	[super dealloc];

	if (buffer)
		free(buffer);
	if (volume)
		free(volume);
}

- (MKUser *) user {
	return nil;
}

- (float *) buffer {
	return buffer;
}

- (NSUInteger) bufferLength {
	return bufferSize;
}

- (void) resizeBuffer:(NSUInteger)newSize {
	if (newSize > bufferSize) {
		float *n = malloc(sizeof(float)*newSize);
		if (buffer) {
			memcpy(n, buffer, sizeof(float)*bufferSize);
			free(buffer);
		}
		buffer = n;
		bufferSize = newSize;
	}
}

- (BOOL) needSamples:(NSUInteger)nsamples {
	return NO;
}

@end
