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

#import "AudioInput.h"
#import "PacketDataStream.h"

static OSStatus inputCallback(void *udata, AudioUnitRenderActionFlags *flags, const AudioTimeStamp *ts,
                              UInt32 busnum, UInt32 nframes, AudioBufferList *buflist) {
	AudioInput *i = (AudioInput *)udata;
	OSStatus err;

	if (! i->buflist.mBuffers->mData) {
		NSLog(@"AudioInput: No buffer allocated.");
		i->buflist.mNumberBuffers = 1;
		AudioBuffer *b = i->buflist.mBuffers;
		b->mNumberChannels = i->numMicChannels;
		b->mDataByteSize = i->micSampleSize * nframes;
		b->mData = calloc(1, b->mDataByteSize);
	}

	if (i->buflist.mBuffers->mDataByteSize < (nframes/i->micSampleSize)) {
		NSLog(@"AudioInput: Buffer too small. Allocating more space.");
		AudioBuffer *b = i->buflist.mBuffers;
		free(b->mData);
		b->mDataByteSize = i->micSampleSize * nframes;
		b->mData = calloc(1, b->mDataByteSize);
	}

	err = AudioUnitRender(i->audioUnit, flags, ts, busnum, nframes, &i->buflist);
	if (err != noErr) {
#if 0
		NSLog(@"AudioInput: AudioUnitRender failed. err = %i", err);
#endif
		return err;
	}

	short *buf = (short *)i->buflist.mBuffers->mData;
	[i addMicrophoneDataWithBuffer:buf amount:nframes];

	return noErr;
}

@implementation AudioInput

- (id) init {
	self = [super init];
	if (self == nil)
		return nil;

	frameCounter = 0;
	preprocessorState = NULL;

	/*
	 * Adjust bandwidth:
	 * Depending on the max quality the client has set, determine iAudioQuality and iAudioFrames.
	 */
	cfType = CELT;

	numAudioFrames = 10;
	if (cfType == CELT) {
		sampleRate = SAMPLE_RATE;
		frameSize = SAMPLE_RATE / 100;
		NSLog(@"AudioInput: %i bits/s, %d Hz, %d sample CELT", audioQuality, sampleRate, frameSize);
	} else {
		sampleRate = 32000;
		/* Speex. */
		NSLog(@"AudioInput: Speex input support not yet implemented.");
		return self;
	}

	doResetPreprocessor = YES;
	previousVoice = NO;

	preprocessorState = NULL;

	psMic = malloc(sizeof(short) * frameSize);

	numMicChannels = 0;
	bitrate = 0;

	/*
	 if (g.uiSession)
		setMaxBandwidth(g.iMaxBandwidth);
	 */

	/* Allocate buffer list. */
	frameList = [[NSMutableArray alloc] initWithCapacity: 20]; /* should be iAudioFrames. */

	udpMessageType = UDPVoiceCELTAlphaMessage;

	return self;
}

- (void) dealloc {
	[frameList release];

	if (psMic)
		free(psMic);

	[super dealloc];
}

- (void) initializeMixer {
	NSLog(@"AudioInput: initializeMixer -- iMicFreq=%u, iSampleRate=%u", micFrequency, sampleRate);

	micLength = (frameSize * micFrequency) / sampleRate;

	if (psMic)
		free(psMic);

	psMic = malloc(micLength * sizeof(short));
	micSampleSize = numMicChannels * sizeof(short);
	doResetPreprocessor = YES;

	NSLog(@"AudioInput: Initialized mixer for %i channel %i Hz and %i channel %i Hz echo", numMicChannels, micFrequency, 0, 0);
}

- (BOOL) setupDevice {
	UInt32 len;
	UInt32 val;
	OSStatus err;
	AudioComponent comp;
	AudioComponentDescription desc;
	AudioStreamBasicDescription fmt;

	desc.componentType = kAudioUnitType_Output;
	desc.componentSubType = kAudioUnitSubType_RemoteIO;
	desc.componentManufacturer = kAudioUnitManufacturer_Apple;
	desc.componentFlags = 0;
	desc.componentFlagsMask = 0;

	comp = AudioComponentFindNext(NULL, &desc);
	if (! comp) {
		NSLog(@"AudioInput: Unable to find AudioUnit.");
		return NO;
	}

	err = AudioComponentInstanceNew(comp, (AudioComponentInstance *) &audioUnit);
	if (err != noErr) {
		NSLog(@"AudioInput: Unable to instantiate new AudioUnit.");
		return NO;
	}

	/* fixme(mkrautz): Backport some of this to the desktop CoreAudio backend? */

	val = 1;
	err = AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &val, sizeof(UInt32));
	if (err != noErr) {
		NSLog(@"AudioInput: Unable to configure input scope on AudioUnit.");
		return NO;
	}

	val = 0;
	err = AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &val, sizeof(UInt32));
	if (err != noErr) {
		NSLog(@"AudioInput: Unable to configure output scope on AudioUnit.");
		return NO;
	}

	AURenderCallbackStruct cb;
	cb.inputProc = inputCallback;
	cb.inputProcRefCon = self;
	len = sizeof(AURenderCallbackStruct);
	err = AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0, &cb, len);
	if (err != noErr) {
		NSLog(@"AudioInput: Unable to setup callback.");
		return NO;
	}

	err = AudioUnitInitialize(audioUnit);
	if (err != noErr) {
		NSLog(@"AudioInput: Unable to initialize AudioUnit.");
		return NO;
	}

	len = sizeof(AudioStreamBasicDescription);
	err = AudioUnitGetProperty(audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 1, &fmt, &len);
	if (err != noErr) {
		NSLog(@"CoreAudioInput: Unable to query device for stream info.");
		return NO;
	}

	if (fmt.mChannelsPerFrame > 1) {
		NSLog(@"AudioInput: Input device with more than one channel detected. Defaulting to 1.");
	}

	micFrequency = (int) 48000;
	numMicChannels = 1;
	[self initializeMixer];

	fmt.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
	fmt.mBitsPerChannel = sizeof(short) * 8;
	fmt.mFormatID = kAudioFormatLinearPCM;
	fmt.mSampleRate = micFrequency;
	fmt.mChannelsPerFrame = numMicChannels;
	fmt.mBytesPerFrame = micSampleSize;
	fmt.mBytesPerPacket = micSampleSize;
	fmt.mFramesPerPacket = 1;

	len = sizeof(AudioStreamBasicDescription);
	err = AudioUnitSetProperty(audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &fmt, len);
	if (err != noErr) {
		NSLog(@"AudioInput: Unable to set stream format for output device. (output scope)");
		return NO;
	}

	len = sizeof(AudioStreamBasicDescription);
	err = AudioUnitSetProperty(audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &fmt, len);
	if (err != noErr) {
		NSLog(@"AudioInput: Unable to set stream format for output device. (input scope)");
		return NO;
	}

	err = AudioOutputUnitStart(audioUnit);
	if (err != noErr) {
		NSLog(@"AudioInput: Unable to start AudioUnit.");
		return NO;
	}

	return YES;
}

- (void) addMicrophoneDataWithBuffer:(short *)input amount:(NSUInteger)nsamp {
	int i;

	while (nsamp > 0) {
		unsigned int left = MIN(nsamp, micLength - micFilled);

		short *output = psMic + micFilled;

		for (i = 0; i < left; i++) {
			output[i] = input[i];
		}

		input += left;
		micFilled += left;
		nsamp -= left;

		if (micFilled == micLength) {
			micFilled = 0;
			[self encodeAudioFrame];
		}
	}
}

- (void) resetPreprocessor {
	int iArg;

	if (preprocessorState)
		speex_preprocess_state_destroy(preprocessorState);

	preprocessorState = speex_preprocess_state_init(frameSize, sampleRate);

	iArg = 1;
	speex_preprocess_ctl(preprocessorState, SPEEX_PREPROCESS_SET_VAD, &iArg);
	speex_preprocess_ctl(preprocessorState, SPEEX_PREPROCESS_SET_AGC, &iArg);
	speex_preprocess_ctl(preprocessorState, SPEEX_PREPROCESS_SET_DENOISE, &iArg);
	speex_preprocess_ctl(preprocessorState, SPEEX_PREPROCESS_SET_DEREVERB, &iArg);

	iArg = 30000;
	speex_preprocess_ctl(preprocessorState, SPEEX_PREPROCESS_SET_AGC_TARGET, &iArg);

//	float v = 30000.0f / (float) 0.0f; // iMinLoudness
//	iArg = iroundf(floorf(20.0f * log10f(v)));
//	speex_preprocess_ctl(preprocessorState, SPEEX_PREPROCESS_SET_AGC_MAX_GAIN, &iArg);

//	iArg = 0;//g.s.iNoiseSuppress;
//	speex_preprocess_ctl(preprocessorState, SPEEX_PREPROCESS_SET_NOISE_SUPPRESS, &iArg);
}

- (void) encodeAudioFrame {

	frameCounter++;

	if (doResetPreprocessor) {
		[self resetPreprocessor];
		doResetPreprocessor = NO;
	}

	int isSpeech = speex_preprocess_run(preprocessorState, psMic);

	{
		unsigned char buffer[1024];
		int len = 0;

		if (celtEncoder == nil) {
			CELTMode *mode = celt_mode_create(SAMPLE_RATE, SAMPLE_RATE / 100, NULL);
			celtEncoder = celt_encoder_create(mode, 1, NULL);
		}

		audioQuality = 24000;

		if (!previousVoice) {
			celt_encoder_ctl(celtEncoder, CELT_RESET_STATE);
			NSLog(@"AudioInput: Reset CELT state.");
		}

		celt_encoder_ctl(celtEncoder, CELT_SET_PREDICTION(0));
		celt_encoder_ctl(celtEncoder, CELT_SET_VBR_RATE(audioQuality));
		len = celt_encode(celtEncoder, psMic, NULL, buffer, MIN(audioQuality / 800, 127));

		bitrate = len * 100 * 8;

		NSData *outputBuffer = [[NSData alloc] initWithBytes:buffer length:len];
		[self flushCheck:outputBuffer terminator:NO];
		[outputBuffer release];

		previousVoice = YES;
	}
}

/*
 * Flush check.
 *
 * Queue up frames, and send them to the server when enough frames have been
 * queued up.
 */
- (void) flushCheck:(NSData *)codedSpeech terminator:(BOOL)terminator {
	[frameList addObject:codedSpeech];

	if (! terminator && [frameList count] < numAudioFrames) {
		return;
	}

	int flags = 0;
	if (terminator)
		flags = 0; /* g.iPrevTarget. */

	/*
	 * Server loopback:
	 * flags = 0x1f;
	 */
	flags |= (udpMessageType << 5);

	unsigned char data[1024];
	data[0] = (unsigned char )(flags & 0xff);

	PacketDataStream *pds = [[PacketDataStream alloc] initWithBuffer:(data+1) length:1023];
	[pds addVarint:(frameCounter - [frameList count])];

	/* fix terminator stuff here. */

	int i, nframes = [frameList count];
	for (i = 0; i < nframes; i++) {
		NSData *frame = [frameList objectAtIndex:i];
		unsigned char head = (unsigned char)[frame length];
		if (i < nframes-1)
			head |= 0x80;
		[pds appendValue:head];
		[pds appendBytes:(unsigned char *)[frame bytes] length:[frame length]];
	}
	[frameList removeAllObjects];

	NSUInteger len = [pds size] + 1;
	[pds release];

	Connection *conn = [[[UIApplication sharedApplication] delegate] connection];

	if ([conn connected]) {
		NSData *msgData = [[NSData alloc] initWithBytes:data length:len];
		[conn sendMessageWithType:UDPTunnelMessage data:msgData];
		[msgData release];
	}
}

@end
