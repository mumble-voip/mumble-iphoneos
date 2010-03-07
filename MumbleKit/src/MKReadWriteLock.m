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

/*
 * MKReadWriteLock - Simple ObjC wrapper around the pthreads read/write lock.
 */

#import <MumbleKit/MKReadWriteLock.h>

@implementation MKReadWriteLock

- (id) init {
	int err;

	self = [super init];
	if (self == nil)
		return nil;

	err = pthread_rwlock_init(&rwlock, NULL);
	if (err != 0) {
		NSLog(@"RWLock: Unable to initialize rwlock. Error=%i", err);
		return nil;
	}

	return self;
}

- (void) dealloc {
	int err;

	[super dealloc];

	err = pthread_rwlock_destroy(&rwlock);
	if (err != 0) {
		NSLog(@"RWLock: Unable to destroy rwlock.");
	}
}

/*
 * Try to acquire a write lock. Returns immediately.
 */
- (BOOL) tryWriteLock {
	int err;

	err = pthread_rwlock_trywrlock(&rwlock);
	if (err != 0) {
		NSLog(@"RWLock: tryWriteLock failed: %i (%s).", err, strerror(err));
		return NO;
	}

	return YES;
}

/*
 * Acquire a write lock. Block until we can get it.
 */
- (void) writeLock {
	int err;

	err = pthread_rwlock_wrlock(&rwlock);
	if (err != 0) {
		NSLog(@"writeLock failed: %i (%s)", err, strerror(err));
	}

	assert(err == 0);
}

/*
 * Try to acquire a read lock. Returns immediately.
 */
- (BOOL) tryReadLock {
	int err;

	err = pthread_rwlock_tryrdlock(&rwlock);
	if (err != 0) {
		return NO;
	}

	return YES;
}

/*
 * Acquire a read lock. Block until it succeeds.
 */
- (void) readLock {
	int err;

	err = pthread_rwlock_rdlock(&rwlock);
	assert(err == 0);
}

/*
 * Unlock.
 */
- (void) unlock {
	int err;

	err = pthread_rwlock_unlock(&rwlock);
	assert(err == 0);
}

@end
