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

@class MKUser;

@interface MKChannel : NSObject {
	MKChannel *channelParent;

	NSUInteger channelId;
	NSString *channelName;
	NSInteger position;

	BOOL inheritACL;
	BOOL temporary;

	@public
	NSMutableArray *channelList;
	NSMutableArray *userList;
	NSMutableArray *ACLList;
	NSMutableArray *linkedList;
	NSUInteger depth;
}

- (id) init;
- (void) dealloc;

#pragma mark -

- (void) addChannel:(MKChannel *)chan;
- (void) removeChannel:(MKChannel *)chan;
- (void) addUser:(MKUser *)user;
- (void) removeUser:(MKUser *)user;
- (NSUInteger) numChildren;

#pragma mark -

- (NSUInteger) treeDepth;
- (void) setTreeDepth:(NSUInteger)depth;

#pragma mark -

- (BOOL) linkedToChannel:(MKChannel *)chan;
- (void) linkToChannel:(MKChannel *)chan;
- (void) unlinkFromChannel:(MKChannel *)chan;
- (void) unlinkAll;

#pragma mark -

- (NSString *) channelName;
- (void) setChannelName:(NSString *)name;

- (void) setParent:(MKChannel *)chan;
- (MKChannel *) parent;

- (void) setChannelId:(NSUInteger)chanId;
- (NSUInteger) channelId;

- (void) setTemporary:(BOOL)flag;
- (BOOL) temporary;

- (NSInteger) position;
- (void) setPosition:(NSInteger)pos;

@end
