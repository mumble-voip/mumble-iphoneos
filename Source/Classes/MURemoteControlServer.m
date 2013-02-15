// Copyright 2012 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

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
