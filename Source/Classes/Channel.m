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

#import "RWLock.h"
#import "Channel.h"
#import "User.h"

static NSMutableDictionary *channelIdMap = nil;
static RWLock *channelLock = nil;

@implementation Channel

+ (void) moduleSetup {
	channelIdMap = [[NSMutableDictionary alloc] init];
	channelLock = [[RWLock alloc] init];
}

+ (void) moduleTeardown {
	[channelIdMap release];
	[channelLock release];
}

/*
 * Lookup a channel by id.
 */
+ (Channel *) getWithId:(NSUInteger)channelId {
	if (channelIdMap == nil)
		return nil;

	[channelLock readLock];
	Channel *chan = [channelIdMap objectForKey:[NSNumber numberWithUnsignedInt:channelId]];
	[channelLock unlock];
	return chan;
}

/*
 * Add a new channel with an id.
 */
+ (Channel *) addNewWithId:(NSUInteger)channelId {
	if (channelIdMap == nil || channelLock == nil)
		[self moduleSetup];

	[channelLock writeLock];
	Channel *chan = [channelIdMap objectForKey:[NSNumber numberWithUnsignedInt:channelId]];
	if (chan != nil) {
		NSLog(@"Channel: Attempted to add already-existing channel ID.");
		return nil;
	}

	chan = [[Channel alloc] initWithId:channelId];
	[channelIdMap setObject:chan forKey:[NSNumber numberWithUnsignedInt:channelId]];
	[chan release];
	[channelLock unlock];

	return chan;
}

/*
 * Remove channel by id.
 */
+ (void) removeWithId:(NSUInteger)channelId {
	if (channelIdMap == nil)
		return;

	[channelLock writeLock];
	[channelIdMap removeObjectForKey:[NSNumber numberWithUnsignedInt:channelId]];
	[channelLock unlock];
}

#pragma mark -

- (id) initWithId:(NSUInteger)chanId name:(NSString *)chanName parent:(Channel *)parent {
	self = [super init];
	if (self == nil)
		return nil;

	channelId = chanId;
	channelName = [chanName copy];
	inheritACL = YES;
	temporary = NO;

	channelList = [[NSMutableArray alloc] init];
	userList = [[NSMutableArray alloc] init];
	aclList = [[NSMutableArray alloc] init];

	if (parent) {
		channelParent = parent;
		[channelParent addChannel:self];
	}

	return self;
}

- (id) initWithId:(NSUInteger)chanId name:(NSString *)chanName {
	return [self initWithId:chanId name:chanName parent:nil];
}

- (id) initWithId:(NSUInteger)chanId {
	return [self initWithId:chanId name:nil parent:nil];
}

- (void) dealloc {
	[channelParent removeChannel:self];
	[channelName release];

	[userList release];
	[channelList release];
	[aclList release];

	[super dealloc];
}

#pragma mark -

- (void) addChannel:(Channel *)chan {
	[chan setParent:self];
	[channelList addObject:chan];
}

- (void) removeChannel:(Channel *)chan {
	[chan setParent:nil];
	[channelList removeObject:chan];
}

#pragma mark -

- (void) addUser:(User *)user {
	Channel *chan = [user channel];
	[chan removeUser:user];
	[user setChannel:self];
	[userList addObject:user];
}

- (void) removeUser:(User *)user {
	[userList removeObject:user];
}

#pragma mark -

- (BOOL) linkedToChannel:(Channel *)chan {
	for (Channel *c in linkedList) {
		if (c == chan) {
			return YES;
		}
	}
	return NO;
}

- (void) linkToChannel:(Channel *)chan {
	if ([self linkedToChannel:chan])
		return;

	[linkedList addObject:chan];
	[chan->linkedList addObject:self];
}

- (void) unlinkFromChannel:(Channel *)chan {
	[linkedList removeObject:chan];
	[chan->linkedList removeObject:self];
}

- (void) unlinkAll {
	for (Channel *chan in linkedList) {
		[self unlinkFromChannel:chan];
	}
}

#pragma mark -

- (void) setParent:(Channel *)chan {
	channelParent = chan;
}

- (Channel *) parent {
	return channelParent;
}


@end
