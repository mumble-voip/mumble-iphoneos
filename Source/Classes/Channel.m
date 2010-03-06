/* Copyright (C) 2010 Mikkel Krautz <mikkel@krautz.dk>

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

@implementation Channel

- (id) init {
	self = [super init];
	if (self == nil)
		return nil;

	inheritACL = YES;
	channelList = [[NSMutableArray alloc] init];
	userList = [[NSMutableArray alloc] init];
	ACLList = [[NSMutableArray alloc] init];

	return self;
}

- (void) dealloc {
	[channelName release];

	[userList release];
	[channelList release];
	[ACLList release];

	[super dealloc];
}

#pragma mark -

- (NSUInteger) treeDepth {
	return depth;
}

- (void) setTreeDepth:(NSUInteger)treeDepth {
	depth = treeDepth;
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

- (void) addUser:(User *)user {
	Channel *chan = [user channel];
	[chan removeUser:user];
	[user setChannel:self];
	[userList addObject:user];
}

- (void) removeUser:(User *)user {
	[userList removeObject:user];
}

- (NSUInteger) numChildren {
	NSUInteger count = 0;
	for (Channel *c in channelList) {
		count += 1 + [c numChildren];
	}
	return count + [userList count];
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

- (void) setChannelName:(NSString *)name {
	[channelName release];
	channelName = [name copy];
}

- (NSString *) channelName {
	return channelName;
}

- (void) setParent:(Channel *)chan {
	channelParent = chan;
}

- (Channel *) parent {
	return channelParent;
}

- (void) setChannelId:(NSUInteger)chanId {
	channelId = chanId;
}

- (NSUInteger) channelId {
	return channelId;
}

- (void) setTemporary:(BOOL)flag {
	temporary = flag;
}

- (BOOL) temporary {
	return temporary;
}

- (NSInteger) position {
	return position;
}

- (void) setPosition:(NSInteger)pos {
	position = pos;
}

@end
