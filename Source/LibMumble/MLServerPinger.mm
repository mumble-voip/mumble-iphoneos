#import "MLInternal.hpp"
#include <netdb.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <chrono>

@implementation MLServerPinger {
    dispatch_queue_t _queue;
    dispatch_source_t _reader, _timer;
    int _socket;
}
- (instancetype)initWithHostname:(NSString *)hostname port:(NSString *)port {
    if ((self=[super init])) {
        _socket=-1; _queue=dispatch_queue_create("info.mumble.libmumble.pinger",DISPATCH_QUEUE_SERIAL);
        __weak MLServerPinger *weakSelf=self;
        dispatch_async(_queue, ^{ @autoreleasepool {
            addrinfo hints{}; hints.ai_socktype=SOCK_DGRAM; hints.ai_family=AF_UNSPEC; addrinfo *addresses=nullptr;
            if (getaddrinfo(hostname.UTF8String,port.UTF8String,&hints,&addresses)) return;
            MLServerPinger *owner=weakSelf;
            if (!owner) { freeaddrinfo(addresses); return; }
            int fd=-1;
            for (auto address=addresses; address; address=address->ai_next) {
                fd=socket(address->ai_family,SOCK_DGRAM,IPPROTO_UDP);
                if (fd<0) continue;
                if (!connect(fd,address->ai_addr,(socklen_t)address->ai_addrlen)) break;
                close(fd); fd=-1;
            }
            freeaddrinfo(addresses); if (fd<0) return;
            fcntl(fd,F_SETFL,fcntl(fd,F_GETFL,0)|O_NONBLOCK); owner->_socket=fd;
            owner->_reader=dispatch_source_create(DISPATCH_SOURCE_TYPE_READ,fd,0,owner->_queue);
            dispatch_source_set_cancel_handler(owner->_reader, ^{ close(fd); });
            dispatch_source_set_event_handler(owner->_reader, ^{
                MLServerPinger *pinger=weakSelf; if (!pinger) return;
                mumble::legacy::udp::Ping wire{};
                ssize_t size=recv(fd,&wire,sizeof(wire),0);
                if (size!=sizeof(wire)) return;
                uint64_t sent=mumble::Endian::toHost(wire.timestamp);
                uint64_t now=(uint64_t)std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now().time_since_epoch()).count();
                if (sent>now || now-sent>10000000) return;
                MLServerPingerResult result{mumble::Endian::toHost(wire.versionBlob),mumble::Endian::toHost(wire.sessions),mumble::Endian::toHost(wire.maxSessions),mumble::Endian::toHost(wire.maxBandwidth),(now-sent)/1000000.0};
                dispatch_async(dispatch_get_main_queue(), ^{
                    MLServerPinger *pinger=weakSelf; MLServerPingerResult copy=result;
                    [pinger.delegate serverPingerResult:&copy];
                });
            });
            dispatch_resume(owner->_reader);
            owner->_timer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,owner->_queue);
            dispatch_source_set_timer(owner->_timer,DISPATCH_TIME_NOW,5*NSEC_PER_SEC,100*NSEC_PER_MSEC);
            dispatch_source_set_event_handler(owner->_timer, ^{
                if (!weakSelf) return;
                mumble::legacy::udp::Ping packet{};
                uint64_t time=(uint64_t)std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now().time_since_epoch()).count();
                packet.timestamp=mumble::Endian::toNetwork(time); send(fd,&packet,12,0);
            }); dispatch_resume(owner->_timer);
        } });
    }
    return self;
}
- (void)dealloc { if (_timer) dispatch_source_cancel(_timer); if (_reader) dispatch_source_cancel(_reader); }
@end
