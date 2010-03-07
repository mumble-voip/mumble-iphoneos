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

#import <MumbleKit/MKAudioOutputSpeech.h>
#import <MumbleKit/MKPacketDataStream.h>

#include <pthread.h>

@implementation MKAudioOutputSpeech

- (id) initWithUser:(MKUser *)u sampleRate:(NSUInteger)freq messageType:(MKMessageType)type {
	self = [super init];
	if (self == nil)
		return nil;

	user = u;
	messageType = type;

	NSUInteger sampleRate;

	if (type != UDPVoiceSpeexMessage) {
		sampleRate = SAMPLE_RATE;
		frameSize = sampleRate / 100;
	} else {
		sampleRate = 32000;
		NSLog(@"AudioOutputSpeech: No Speex support (yet).");
	}

	if (freq != sampleRate) {
		NSLog(@"AudioOutputSpeech: freq != sampleRate");
	}

	outputSize = frameSize;
	bufferOffset = bufferFilled = lastConsume = 0;

	lastAlive = TRUE;

	missCount = 0;
	missedFrames = 0;

	flags = 0xff;

	jitter = jitter_buffer_init(frameSize);
	int margin = /* g.s.iJitterBufferSize */ 10 * frameSize;
	jitter_buffer_ctl(jitter, JITTER_BUFFER_SET_MARGIN, &margin);

	fadeIn = malloc(sizeof(float)*frameSize);
	fadeOut = malloc(sizeof(float)*frameSize);

	float mul = (float)(M_PI / (2.0 * (float)frameSize));
	NSUInteger i;
	for (i = 0; i < frameSize; ++i) {
		fadeIn[i] = fadeOut[frameSize-i-1] = sinf((float)i * mul);
	}

	frames = [[NSMutableArray alloc] init];
	celtMode = celt_mode_create(SAMPLE_RATE, SAMPLE_RATE/100, NULL);
	celtDecoder = celt_decoder_create(celtMode, 1, NULL);

	int err = pthread_mutex_init(&jitterMutex, NULL);
	if (err != 0) {
		NSLog(@"AudioOutputSpeech: pthread_mutex_init() failed.");
		return nil;
	}

	return self;
}

- (void) dealloc {
	[super dealloc];

	if (celtDecoder)
		celt_decoder_destroy(celtDecoder);
	if (celtMode)
		celt_mode_destroy(celtMode);
}

- (MKUser *) user {
	return user;
}

- (MKMessageType) messageType {
	return messageType;
}

- (void) addFrame:(NSData *)data forSequence:(NSUInteger)seq {
	int err = pthread_mutex_lock(&jitterMutex);
	if (err != 0) {
		NSLog(@"AudioOutputSpeech: pthread_mutex_lock() failed.");
		return;
	}

	if ([data length] < 2) {
		pthread_mutex_unlock(&jitterMutex);
		return;
	}

	MKPacketDataStream *pds = [[MKPacketDataStream alloc] initWithData:data];
	[pds next];

	int nframes = 0;
	unsigned int header = 0;
	do {
		header = (unsigned int)[pds next];
		++nframes;
		[pds skip:(header & 0x7f)];
	} while ((header & 0x80) && [pds valid]);

	if (! [pds valid]) {
		[pds release];
		NSLog(@"addFrame:: Invalid pds.");
		pthread_mutex_unlock(&jitterMutex);
		return;
	}

	JitterBufferPacket jbp;
	jbp.data = (char *)[data bytes];
	jbp.len = [data length];
	jbp.span = frameSize * nframes;
	jbp.timestamp = frameSize * seq;

	jitter_buffer_put(jitter, &jbp);

	[pds release];

	err = pthread_mutex_unlock(&jitterMutex);
	if (err != 0) {
		NSLog(@"AudioOutputSpeech: Unable to unlock() jitter mutex.");
		return;
	}
}

- (BOOL) needSamples:(NSUInteger)nsamples {
	NSUInteger i;

	for (i = lastConsume; i < bufferFilled; ++i) {
		buffer[i-lastConsume] = buffer[i];
	}
	bufferFilled -= lastConsume;

	lastConsume = nsamples;

	if (bufferFilled >= nsamples) {
		NSLog(@"AudioOutputSpeech: bufferFilled >= nsamples... returning lastAlive.");
		return lastAlive;
	}

	float *output = NULL;
	BOOL nextAlive = lastAlive;

	while (bufferFilled < nsamples) {
		[self resizeBuffer:(bufferFilled + outputSize)];
		output = buffer + bufferFilled;

		if (! lastAlive) {
			memset(output, 0, frameSize * sizeof(float));
		} else {
			int avail = 0;
			int ts = jitter_buffer_get_pointer_timestamp(jitter);
			jitter_buffer_ctl(jitter, JITTER_BUFFER_GET_AVAILABLE_COUNT, &avail);

			if (user && (ts == 0)) {
				int want = (int)averageAvailable; // fixme(mkrautz): Was iroundf.
				if (avail < want) {
					++missCount;
					if (missCount < 20) {
						memset(output, 0, frameSize * sizeof(float));
						goto nextframe;
					}
				}
			}

			if ([frames count] == 0) {
				int err = pthread_mutex_lock(&jitterMutex);
				if (err != 0) {
					NSLog(@"AudioOutputSpeech: unable to lock() mutex.");
				}

				// lock jitter mutex
				char data[4096];

				JitterBufferPacket jbp;
				jbp.data = data;
				jbp.len = 4096;

				spx_int32_t startofs = 0;

				if (jitter_buffer_get(jitter, &jbp, frameSize, &startofs) == JITTER_BUFFER_OK) {
					MKPacketDataStream *pds = [[MKPacketDataStream alloc] initWithBuffer:(unsigned char *)jbp.data length:jbp.len];

					missCount = 0;
					flags = (unsigned char)[pds next];
					hasTerminator = NO;

					unsigned int header = 0;
					do {
						header = (unsigned int)[pds next];
						if (header) {
							NSData *block = [pds copyDataBlock:(header & 0x7f)];
							[frames addObject:block];
							[block release];
						} else {
							hasTerminator = YES;
						}
					} while ((header & 0x80) && [pds valid]);

					if ([pds left]) {
						pos[0] = [pds getFloat];
						pos[1] = [pds getFloat];
						pos[2] = [pds getFloat];
					} else {
						pos[0] = pos[1] = pos[2] = 0.0f;
					}

					[pds release];

					float a = (float) avail;
					if (a >= averageAvailable) {
						averageAvailable = a;
					} else {
						averageAvailable *= 0.99f;
					}
				} else {
					NSLog(@"AudioOutputSpeech: Nothing in jitter buffer...");
					jitter_buffer_update_delay(jitter, &jbp, NULL);

					++missCount;
					if (missCount > 10) {
						nextAlive = NO;
					}
				}

				err = pthread_mutex_unlock(&jitterMutex);
				if (err != 0) {
					NSLog(@"AudioOutputSpeech: Unable to unlock mutex.");
				}
			}

			if ([frames count] > 0) {
				NSData *frameData = [frames objectAtIndex:0];

				if (messageType != UDPVoiceSpeexMessage) {
					if ([frameData length] != 0) {
						celt_decode_float(celtDecoder, [frameData bytes], [frameData length], output);
					} else {
						celt_decode_float(celtDecoder, NULL, 0, output);
					}
				} else {
					NSLog(@"AudioOutputSpeech: Don't know how to decode Speex.");
				}

				[frames removeObjectAtIndex:0];

				BOOL update = YES;

				float pow = 0.0f;
				for (i = 0; i < frameSize; ++i) {
					pow += output[i] * output[i];
				}
				pow = sqrtf(pow / frameSize);
				if (pow > powerMax) {
					powerMax = pow;
				} else {
					if (pow <= powerMin) {
						powerMin = pow;
					} else {
						powerMax = 0.99f * powerMax;
						powerMin += 0.0001f * pow;
					}
				}

				update = (pow < (powerMin + 0.01f * (powerMax - powerMin)));

				if ([frames count] == 0 && update) {
					jitter_buffer_update_delay(jitter, NULL, NULL);
				}

				if ([frames count] == 0 && hasTerminator) {
					nextAlive = NO;
				}
			} else {
				if (messageType != UDPVoiceSpeexMessage) {
					celt_decode_float(celtDecoder, NULL, 0, output);
				} else {
					NSLog(@"AudioOutputSpeech: I don't handle Speex.");
				}
			}

			if (! nextAlive) {
				for (i = 0; i < frameSize; i++) {
					output[i] *= fadeOut[i];
				}
			} else if (ts == 0) {
				for (i = 0; i < frameSize; i++) {
					output[i] *= fadeIn[i];
				}
			}

			jitter_buffer_tick(jitter);
		}

nextframe:
		bufferFilled += outputSize;
	}

	BOOL tmp = lastAlive;
	lastAlive = nextAlive;
	return tmp;
}

@end
