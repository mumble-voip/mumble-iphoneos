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

#import <MumbleKit/MKConnection.h>
#import <MumbleKit/MKAudio.h>
#import <MumbleKit/MKUser.h>
#import <MumbleKit/MKAudioOutputUser.h>

#include <speex/speex.h>
#include <speex/speex_preprocess.h>
#include <speex/speex_echo.h>
#include <speex/speex_resampler.h>
#include <speex/speex_jitter.h>
#include <speex/speex_types.h>
#include <celt.h>

@interface MKAudioOutputSpeech : MKAudioOutputUser {
	MKUDPMessageType messageType;
	NSUInteger bufferOffset;
	NSUInteger bufferFilled;
	NSUInteger outputSize;
	NSUInteger lastConsume;
	NSUInteger frameSize;
	BOOL lastAlive;
	BOOL hasTerminator;

	float *fadeIn;
	float *fadeOut;

	JitterBuffer *jitter;
	NSInteger missCount;
	NSInteger missedFrames;

	NSMutableArray *frames;
	unsigned char flags;

	MKUser *user;
	float powerMin, powerMax;
	float averageAvailable;

	CELTMode *celtMode;
	CELTDecoder *celtDecoder;

	pthread_mutex_t jitterMutex;
}

- (id) initWithUser:(MKUser *)user sampleRate:(NSUInteger)freq messageType:(MKMessageType)type;
- (void) dealloc;

- (MKUser *) user;
- (MKMessageType) messageType;

- (void) addFrame:(NSData *)data forSequence:(NSUInteger)seq;

@end
