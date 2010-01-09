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

@class User;

@interface Channel : NSObject {
	Channel *channelParent;

	NSUInteger channelId;
	NSString *channelName;
	NSInteger position;

	BOOL inheritACL;
	BOOL temporary;

	NSMutableArray *channelList;
	NSMutableArray *userList;
	NSMutableArray *aclList;
	NSMutableArray *linkedList;
}

+ (void) moduleSetup;
+ (void) moduleTeardown;

#pragma mark -

+ (Channel *) getWithId:(NSUInteger)channelId;
+ (Channel *) addNewWithId:(NSUInteger)channelId;
+ (void) removeWithId:(NSUInteger)channelId;

#pragma mark -

- (id) initWithId:(NSUInteger)chanId name:(NSString *)chanName parent:(Channel *)parent;
- (id) initWithId:(NSUInteger)chanId name:(NSString *)chanName;
- (id) initWithId:(NSUInteger)chanId;
- (void) dealloc;

#pragma mark -

- (void) addChannel:(Channel *)chan;
- (void) removeChannel:(Channel *)chan;

#pragma mark -

- (void) addUser:(User *)user;
- (void) removeUser:(User *)user;

#pragma mark -

- (BOOL) linkedToChannel:(Channel *)chan;
- (void) linkToChannel:(Channel *)chan;
- (void) unlinkFromChannel:(Channel *)chan;
- (void) unlinkAll;

#pragma mark -

- (void) setParent:(Channel *)chan;
- (Channel *) parent;

@end
