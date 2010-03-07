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

#import <MumbleKit/MKUser.h>
#import <MumbleKit/MKChannel.h>
#import <MumbleKit/MKReadWriteLock.h>

@interface MKServerModel : NSObject {
	MKChannel *root;
	NSMutableArray *array;
	
	MKReadWriteLock *userMapLock;
	NSMutableDictionary *userMap;

	MKReadWriteLock *channelMapLock;
	NSMutableDictionary *channelMap;
}

- (id) init;
- (void) dealloc;

- (void) updateModelArray;
- (void) addChannelTreeToArray:(MKChannel *)tree depth:(NSUInteger)currentDepth;

- (NSUInteger) count;
- (id) objectAtIndex:(NSUInteger)idx;

#pragma mark -

- (MKUser *) addUserWithSession:(NSUInteger)userSession name:(NSString *)userName;
- (MKUser *) userWithSession:(NSUInteger)session;
- (MKUser *) userWithHash:(NSString *)hash;
- (void) renameUser:(MKUser *)user to:(NSString *)newName;
- (void) setIdForUser:(MKUser *)user to:(NSUInteger)newId;
- (void) setHashForUser:(MKUser *)user to:(NSString *)newHash;
- (void) setFriendNameForUser:(MKUser *)user to:(NSString *)newFriendName;
- (void) setCommentForUser:(MKUser *) to:(NSString *)newComment;
- (void) setSeenCommentForUser:(MKUser *)user;
- (void) moveUser:(MKUser *)user toChannel:(MKChannel *)chan;
- (void) removeUser:(MKUser *)user;

#pragma mark -

- (MKChannel *) rootChannel;
- (MKChannel *) addChannelWithId:(NSUInteger)chanId name:(NSString *)chanName parent:(MKChannel *)p;
- (MKChannel *) channelWithId:(NSUInteger)chanId;
- (void) renameChannel:(MKChannel *)chan to:(NSString *)newName;
- (void) repositionChannel:(MKChannel *)chan to:(NSInteger)pos;
- (void) setCommentForChannel:(MKChannel *)chan to:(NSString *)newComment;
- (void) moveChannel:(MKChannel *)chan toChannel:(MKChannel *)newParent;
- (void) removeChannel:(MKChannel *)chan;
- (void) linkChannel:(MKChannel *)chan withChannels:(NSArray *)channelLinks;
- (void) unlinkChannel:(MKChannel *)chan fromChannels:(NSArray *)channelLinks;
- (void) unlinkAllFromChannel:(MKChannel *)chan;

@end
