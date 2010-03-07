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

#import <MumbleKit/MKUtils.h>
#import <MumbleKit/MKAudio.h>
#import <MumbleKit/MKAudioInput.h>
#import <MumbleKit/MKAudioOutput.h>

static MKAudio *audioSingleton = nil;

static void AudioInterruptionListenerCallback(void *udata, UInt32 interruptionState) {
	MK_UNUSED MKAudio *audio = (MKAudio *) udata;
	NSLog(@"Audio: Interruption state callback called.");
}

static void AudioSessionPropertyListenerCallback(void *udata, AudioSessionPropertyID property, UInt32 len, void *data) {
	MK_UNUSED MKAudio *audio = (MKAudio *) udata;
	BOOL audioInputAvailable;
	UInt32 *u32;

	switch (property) {
		case kAudioSessionProperty_AudioInputAvailable: {
			u32 = data;
			audioInputAvailable = (BOOL)*u32;
			if (audioInputAvailable == NO) {
				NSLog(@"Audio: Audio Input now unavailable.");
			} else {
				NSLog(@"Audio: Audio Input now available.");
			}

			NSLog(@"Audio: AudioInputAvailable changed...");
			break;
		}
	}
}

@implementation MKAudio

+ (void) initializeAudio {
	NSLog(@"Audio: Initializing...");
	audioSingleton = [[MKAudio alloc] init];
	[[MKAudio audioOutput] setupDevice];
	[[MKAudio audioInput] setupDevice];
}

+ (MKAudioInput *) audioInput {
	return [audioSingleton audioInput];
}

+ (MKAudioOutput *) audioOutput {
	return [audioSingleton audioOutput];
}

+ (MKAudio *) audio {
	return audioSingleton;
}

- (id) init {
	OSStatus err;
	UInt32 val;
	Float64 fval;
	UInt32 valSize;
	BOOL audioInputAvailable;

	self = [super init];
	if (self == nil)
		return nil;

	/*
	 * Initialize Audio Session.
	 */
	err = AudioSessionInitialize(CFRunLoopGetMain(), kCFRunLoopDefaultMode, AudioInterruptionListenerCallback, self);
	if (err != kAudioSessionNoError) {
		NSLog(@"Audio: Unable to initialize AudioSession.");
		return nil;
	}

	/*
	 * To properly determine the right category property (at this time), we need to check
	 * whether we have a microphone available. This will always be the case on an iPhone,
	 * but for the iPod touch, we need the headphones plugged in.
	 */
	valSize = sizeof(UInt32);
	err = AudioSessionGetProperty(kAudioSessionProperty_AudioInputAvailable, &valSize, &val);
	if (err != kAudioSessionNoError || valSize != sizeof(UInt32)) {
		NSLog(@"Audio: Unable to query for input availability.");
	}

	audioInputAvailable = (BOOL) val;
	if (audioInputAvailable == NO) {
		NSLog(@"Audio: Audio Input not available.");
		val = kAudioSessionCategory_MediaPlayback;
	} else {
		NSLog(@"Audio: Audio Input available.");
		val = kAudioSessionCategory_PlayAndRecord;
	}

	err = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(val), &val);
	if (err != kAudioSessionNoError) {
		NSLog(@"Audio: Unable to set AudioCategory property.");
		return nil;
	}

	/*
	 * Override whether we want to allow to be mixed with other applications. We want this to be
	 * a user choice. Some users may want their iPod app to play in the background.
	 */
	val = TRUE;
	err = AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryMixWithOthers, sizeof(val), &val);
	if (err != kAudioSessionNoError) {
		NSLog(@"Audio: Unable to set MixWithOthers property.");
		return nil;
	}

	/*
	 * Set the preferred hardware sample rate.
	 * fixme(mkrautz): The AudioSession *can* reject this, in which case we need
	 *                 to be able to handle whatever input sampling rate is chosen
	 *                 for us. This is apparently 8KHz on a 1st gen iPhone.
	 */
	fval = SAMPLE_RATE;
	err = AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareSampleRate, sizeof(Float64), &fval);
	if (err != kAudioSessionNoError) {
		NSLog(@"Audio: Unable to set preferred hardware sample rate.");
		return nil;
	}

	/*
	 * Activate our Audio Session.
	 */
	err = AudioSessionSetActive(TRUE);
	if (err != kAudioSessionNoError) {
			NSLog(@"Audio: Unable to set session as active.");
			return nil;
	}

	/*
	 * Query for the actual sample rate we are to cope with.
	 */
	valSize = sizeof(Float64);
	err = AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, &valSize, &fval);
	if (err != kAudioSessionNoError) {
		NSLog(@"Audio: Unable to query for current hardware sample rate.");
		return nil;
	}

	NSLog(@"Audio: Current hardware sample rate = %.2fHz.", fval);

	if (audioInputAvailable) {
		ai = [[MKAudioInput alloc] init];
	}

	ao = [[MKAudioOutput alloc] init];

	return self;
}

- (void) dealloc {
	[super dealloc];
	[ai release];
	[ao release];
}

- (MKAudioInput *) audioInput {
	return ai;
}

- (MKAudioOutput *) audioOutput {
	return ao;
}

@end
