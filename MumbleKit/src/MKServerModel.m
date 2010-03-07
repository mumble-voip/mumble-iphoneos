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

#import <MumbleKit/MKServerModel.h>

#define STUB \
	NSLog(@"%@: %s", [self class], __FUNCTION__)

static NSInteger stringSort(NSString *str1, NSString *str2, void *reverse) {
	if (reverse)
		return [str2 compare:str1];
	else
		return [str1 compare:str2];
}

static NSInteger channelSort(MKChannel *chan1, MKChannel *chan2, void *reverse) {
	if ([chan1 position] != [chan2 position]) {
		return reverse ? ([chan1 position] > [chan2 position]) : ([chan2 position] > [chan1 position]);
	} else {
		return stringSort([chan1 channelName], [chan2 channelName], reverse);
	}
}

@implementation MKServerModel

- (id) init {
	self = [super init];
	if (self == nil)
		return nil;

	userMapLock = [[MKReadWriteLock alloc] init];
	userMap = [[NSMutableDictionary alloc] init];

	channelMapLock = [[MKReadWriteLock alloc] init];
	channelMap = [[NSMutableDictionary alloc] init];

	array = [[NSMutableArray alloc] init];

	root = [[MKChannel alloc] init];
	[root setChannelId:0];
	[root setChannelName:@"Root"];
	[channelMap setObject:root forKey:[NSNumber numberWithUnsignedInt:0]];

	return self;
}

- (void) dealloc {
	/* dealloc all. */
	[super dealloc];
}

- (void) updateModelArray {
	[array removeAllObjects];
	[self addChannelTreeToArray:root depth:0];
}

- (void) addChannelTreeToArray:(MKChannel *)tree depth:(NSUInteger)currentDepth {
	[array addObject:tree];
	
	for (MKChannel *c in tree->channelList) {
		[c setTreeDepth:currentDepth+1];
		[array addObject:c];
		[self addChannelTreeToArray:c depth:currentDepth+1];
	}
	for (MKUser *u in tree->userList) {
		[array addObject:u];
		[u setTreeDepth:currentDepth+1];
	}
}

- (NSUInteger) count {
	return [array count];
}

- (id) objectAtIndex:(NSUInteger)idx {
	return [array objectAtIndex:idx];
}

#pragma mark -

/*
 * Add a new user.
 *
 * @param  userSession   The session of the new user.
 * @param  userName      The username of the new user.
 *
 * @return
 * Returns the allocated User on success. Returns nil on failure. The returned User
 * is owned by the User module itself, and should not be retained or otherwise fiddled
 * with.
 */
- (MKUser *) addUserWithSession:(NSUInteger)userSession name:(NSString *)userName {
	MKUser *user = [[MKUser alloc] init];
	[user setSession:userSession];
	[user setUserName:userName];

	[userMapLock writeLock];
	[userMap setObject:user forKey:[NSNumber numberWithUnsignedInt:userSession]];
	[userMapLock unlock];
	[root addUser:user];

	[self updateModelArray];

	return user;
}

- (MKUser *) userWithSession:(NSUInteger)session {
	[userMapLock readLock];
	MKUser *u = [userMap objectForKey:[NSNumber numberWithUnsignedInt:session]];
	[userMapLock unlock];
	return u;
}

- (MKUser *) userWithHash:(NSString *)hash {
	NSLog(@"userWithHash: notimpl.");
	return nil;
}

- (void) renameUser:(MKUser *)user to:(NSString *)newName {
	STUB;
}

- (void) setIdForUser:(MKUser *)user to:(NSUInteger)newId {
	STUB;
}

- (void) setHashForUser:(MKUser *)user to:(NSString *)newHash {
	STUB;
}

- (void) setFriendNameForUser:(MKUser *)user to:(NSString *)newFriendName {
	STUB;
}

- (void) setCommentForUser:(MKUser *) to:(NSString *)newComment {
	STUB;
}

- (void) setSeenCommentForUser:(MKUser *)user {
	STUB;
}

/*
 * Move a user to a channel.
 *
 * @param  user   The user to move.
 * @param  chan   The channel to move the user to.
 */
- (void) moveUser:(MKUser *)user toChannel:(MKChannel *)chan {
	STUB;
}

/*
 * Remove a user from the model (in case a user leaves).
 * This cleans up all references of the user in the model.
 */
- (void) removeUser:(MKUser *)user {
	STUB;
}

#pragma mark -

- (MKChannel *) rootChannel {
	return root;
}

/*
 * Add a channel.
 */
- (MKChannel *) addChannelWithId:(NSUInteger)chanId name:(NSString *)chanName parent:(MKChannel *)parent {
	MKChannel *chan = [[MKChannel alloc] init];
	[chan setChannelId:chanId];
	[chan setChannelName:chanName];
	[chan setParent:parent];
	
	[channelMapLock writeLock];
	[channelMap setObject:chan forKey:[NSNumber numberWithUnsignedInt:chanId]];
	[channelMapLock unlock];

	[parent addChannel:chan];
	
	[self updateModelArray];
	
	return chan;
}

- (MKChannel *) channelWithId:(NSUInteger)chanId {
	[channelMapLock readLock];
	MKChannel *c = [channelMap objectForKey:[NSNumber numberWithUnsignedInt:chanId]];
	[channelMapLock unlock];
	return c;
}

- (void) renameChannel:(MKChannel *)chan to:(NSString *)newName {
	STUB;
}

- (void) repositionChannel:(MKChannel *)chan to:(NSInteger)pos {
	STUB;
}

- (void) setCommentForChannel:(MKChannel *)chan to:(NSString *)newComment {
	STUB;
}

- (void) moveChannel:(MKChannel *)chan toChannel:(MKChannel *)newParent {
	STUB;
}

- (void) removeChannel:(MKChannel *)chan {
	STUB;
}

- (void) linkChannel:(MKChannel *)chan withChannels:(NSArray *)channelLinks {
	STUB;
}

- (void) unlinkChannel:(MKChannel *)chan fromChannels:(NSArray *)channelLinks {
	STUB;
}

- (void) unlinkAllFromChannel:(MKChannel *)chan {
	STUB;
}

@end
