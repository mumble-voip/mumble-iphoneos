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

#import "MumbleApplication.h"

static char crashhandler_fn[PATH_MAX] = { 0, };
static void crashhandler_signal_handler();
static void crashhandler_signals_setup();
static void crashhandler_signals_restore();
static void crashhandler_handle_crash();
static void crashhandler_init();

static void crashhandler_signal_handler(int signal) {
	switch (signal) {
		case SIGQUIT:
		case SIGILL:
		case SIGTRAP:
		case SIGABRT:
		case SIGEMT:
		case SIGFPE:
		case SIGBUS:
		case SIGSEGV:
		case SIGSYS:
			crashhandler_signals_restore();
			crashhandler_handle_crash();
			break;
		default:
			break;
	}
}

// These are the signals that according to signal(3) produce a coredump by default.
int sigs[] = { SIGQUIT, SIGILL, SIGTRAP, SIGABRT, SIGEMT, SIGFPE, SIGBUS, SIGSEGV, SIGSYS };
#define NSIGS sizeof(sigs)/sizeof(sigs[0])

static void crashhandler_signals_setup() {
	for (int i = 0; i < NSIGS; i++) {
		signal(sigs[i], crashhandler_signal_handler);
	}
}

static void crashhandler_signals_restore() {
	for (int i = 0; i < NSIGS; i++) {
		signal(sigs[i], NULL);
	}
}

static void crashhandler_handle_crash() {
	// Abuse mtime for figuring out which crashdump we should send.
	FILE *f = fopen(crashhandler_fn, "w");
	fflush(f);
	fclose(f);
}

@interface MumbleApplication (Private)
- (void) setupCrashHandler;
@end

@implementation MumbleApplication

- (id) init {
	if (self = [super init]) {
		[self setupCrashHandler];
	}
	return self;
}

- (void) dealloc {
	[_crashTokenPath release];
	[super dealloc];
}

// Setup the crash notification handler
- (void) setupCrashHandler {
	NSArray *documentDirectories = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
																	   NSUserDomainMask,
																	   YES);
	_crashTokenPath = [[[documentDirectories objectAtIndex:0]
						stringByAppendingPathComponent:@".crashtoken"] retain];
	strlcpy(crashhandler_fn, [_crashTokenPath UTF8String], PATH_MAX);
	crashhandler_signals_setup();
}

// Did we crash recently?
- (BOOL) didCrashRecently {
	return [[NSFileManager defaultManager] fileExistsAtPath:_crashTokenPath];
}

// Reset our crash count (delete our crashtoken file)
- (void) resetCrashCount {
	[[NSFileManager defaultManager] removeItemAtPath:_crashTokenPath error:nil];
}

@end