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

#import "User.h"
#import "Channel.h"
#import "RWLock.h"

@interface ServerModel : NSObject {
	Channel *root;
	NSMutableArray *array;
	
	RWLock *userMapLock;
	NSMutableDictionary *userMap;

	RWLock *channelMapLock;
	NSMutableDictionary *channelMap;
}

- (id) init;
- (void) dealloc;

- (void) updateModelArray;
- (void) addChannelTreeToArray:(Channel *)tree depth:(NSUInteger)currentDepth;

- (NSUInteger) count;
- (id) objectAtIndex:(NSUInteger)idx;

#pragma mark -

- (User *) addUserWithSession:(NSUInteger)userSession name:(NSString *)userName;
- (User *) userWithSession:(NSUInteger)session;
- (User *) userWithHash:(NSString *)hash;
- (void) renameUser:(User *)user to:(NSString *)newName;
- (void) setIdForUser:(User *)user to:(NSUInteger)newId;
- (void) setHashForUser:(User *)user to:(NSString *)newHash;
- (void) setFriendNameForUser:(User *)user to:(NSString *)newFriendName;
- (void) setCommentForUser:(User *) to:(NSString *)newComment;
- (void) setSeenCommentForUser:(User *)user;
- (void) moveUser:(User *)user toChannel:(Channel *)chan;
- (void) removeUser:(User *)user;

#pragma mark -

- (Channel *) rootChannel;
- (Channel *) addChannelWithId:(NSUInteger)chanId name:(NSString *)chanName parent:(Channel *)p;
- (Channel *) channelWithId:(NSUInteger)chanId;
- (void) renameChannel:(Channel *)chan to:(NSString *)newName;
- (void) repositionChannel:(Channel *)chan to:(NSInteger)pos;
- (void) setCommentForChannel:(Channel *)chan to:(NSString *)newComment;
- (void) moveChannel:(Channel *)chan toChannel:(Channel *)newParent;
- (void) removeChannel:(Channel *)chan;
- (void) linkChannel:(Channel *)chan withChannels:(NSArray *)channelLinks;
- (void) unlinkChannel:(Channel *)chan fromChannels:(NSArray *)channelLinks;
- (void) unlinkAllFromChannel:(Channel *)chan;

@end
