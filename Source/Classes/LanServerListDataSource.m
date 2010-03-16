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

#import <CFNetwork/CFNetwork.h>
#import "LanServerListDataSource.h"

static void LanServerListBrowserCallback(CFNetServiceBrowserRef browser, CFOptionFlags flags, CFTypeRef netService, CFStreamError *error, void *udata) {
	MUMBLE_UNUSED LanServerListDataSource *ds = (LanServerListDataSource *)udata;
	BOOL removeEntry = flags & kCFNetServiceFlagRemove;

	if (removeEntry) {
		NSLog(@"LanServerListDataSource: Service removed.");
	} else {
		NSLog(@"LanServerListDataSource: Service added.");
	}
}

@implementation LanServerListDataSource

- (id) init {
	self = [super init];
	if (self == nil)
		return nil;

	CFNetServiceClientContext ctx = { 0, self, NULL, NULL, NULL };
	CFStreamError err;

	browser = CFNetServiceBrowserCreate(kCFAllocatorDefault, LanServerListBrowserCallback, &ctx);
	if (! browser) {
		NSLog(@"LanServerListDataSource: Unable to allocate net service browser.");
		return nil;
	}

	CFNetServiceBrowserScheduleWithRunLoop(browser, CFRunLoopGetMain(), kCFRunLoopCommonModes);

	BOOL result = CFNetServiceBrowserSearchForServices(browser, CFSTR("local."), CFSTR("_mumble._tcp"), &err);
	if (result == NO) {
		NSLog(@"LanServerListDataSource: Unable to search for services.");
		return nil;
	}

	return self;
}

- (void) dealloc {
	[super dealloc];
	CFRelease(browser);
}

@end
