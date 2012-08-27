/* Copyright (C) 2012 Mikkel Krautz <mikkel@krautz.dk>

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

#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <pthread.h>

#import "MURemoteControlServer.h"

#import <MumbleKit/MKAudio.h>

@interface MURemoteControlServer () {
    NSMutableArray *_activeSocks;
    CFSocketRef    _sock;
}
- (void) addSocket:(NSNumber *)socketNumber;
- (void) removeSocket:(NSNumber *)socketNumber;
@end

static void *serverThread(void *udata) {
    int sock = (int) udata;
    unsigned char action;
    
    int val = 1;
    if (setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &val, sizeof(val)) == -1)
        goto out;

    while (1) {
        ssize_t nread = read(sock, &action, 1);
        if (nread == 0) {
            goto out;
        }
        if (nread == -1) {
            NSLog(@"MURemoteControlServer: aborted server thread: %s", strerror(errno));
            goto out;
        }
        
        unsigned char on = action & 0x1;
        unsigned char code = action & ~0x1;
        if (code == 0) { // PTT
            MKAudio *audio = [MKAudio sharedAudio];
            [audio setForceTransmit:on > 0];
        }
    }
out:
    @autoreleasepool {
        MURemoteControlServer *remoteControlServer = [MURemoteControlServer sharedRemoteControlServer];
        NSNumber *socketNumber = [NSNumber numberWithInt:sock];
        [remoteControlServer performSelector:@selector(removeSocket:) onThread:[NSThread mainThread] withObject:socketNumber waitUntilDone:NO];
    }
    return NULL;
}

static void acceptCallBack(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
    MURemoteControlServer *remoteControl = (MURemoteControlServer *) info;
    int sock = *(int *)data;
    [remoteControl addSocket:[NSNumber numberWithInt:sock]];
    if (type == kCFSocketAcceptCallBack) {
        pthread_t thr;
        pthread_create(&thr, NULL, serverThread, (void *)((uintptr_t)sock));
    }
}

@implementation MURemoteControlServer

+ (MURemoteControlServer *) sharedRemoteControlServer {
    static dispatch_once_t token;
    static MURemoteControlServer *remoteControlServer;
    dispatch_once(&token, ^{
        remoteControlServer = [[MURemoteControlServer alloc] init];
    });
    return remoteControlServer;
}

- (id) init {
    if ((self = [super init])) {
    }
    return self;
}

- (void) addSocket:(NSNumber *)socketNumber {
    [_activeSocks addObject:socketNumber];
}

- (void) removeSocket:(NSNumber *)socketNumber {
    [_activeSocks removeObjectIdenticalTo:socketNumber];
}

- (void) closeAllSockets {
    for (NSNumber *numberSocket in _activeSocks) {
        int sock = [numberSocket intValue];
        close(sock);
    }
}

- (BOOL) start {
    [_activeSocks release];
    _activeSocks = [[NSMutableArray alloc] init];
    
    CFSocketContext ctx = {0, self, NULL, NULL, NULL};
    _sock = CFSocketCreate(NULL, PF_INET6, SOCK_STREAM, IPPROTO_TCP,
                           kCFSocketAcceptCallBack, (CFSocketCallBack)acceptCallBack, &ctx);
    if (_sock == NULL) {
        return NO;
    }
    
    int val = 1;
    setsockopt(CFSocketGetNative(_sock), SOL_SOCKET, SO_REUSEADDR, &val, sizeof(val));
	
    struct sockaddr_in6 addr6;
    memset(&addr6, 0, sizeof(addr6));
    addr6.sin6_len = sizeof(addr6);
    addr6.sin6_family = AF_INET6;
    addr6.sin6_port = htons(54295);
    addr6.sin6_flowinfo = 0;
    addr6.sin6_addr = in6addr_any;
		
    CFSocketError err = CFSocketSetAddress(_sock, (CFDataRef) [NSData dataWithBytes:&addr6 length:sizeof(addr6)]);
    if (err != kCFSocketSuccess) {
        CFSocketInvalidate(_sock);
        CFRelease(_sock);
        _sock = NULL;
        return NO;
    }

    CFRunLoopRef loop = CFRunLoopGetCurrent();
    CFRunLoopSourceRef src = CFSocketCreateRunLoopSource(NULL, _sock, 0);
    CFRunLoopAddSource(loop, src, kCFRunLoopCommonModes);
    CFRelease(src);
    
    return YES;
}

- (BOOL) stop {
    [self closeAllSockets];
    if (_sock != NULL) {
        CFSocketInvalidate(_sock);
        CFRelease(_sock);
        _sock = NULL;
    }
    return YES;
}

- (BOOL) isRunning {
    return _sock != NULL;
}

@end
