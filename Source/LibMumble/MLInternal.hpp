#pragma once
#import "MLClient.h"
#include <mumble/Types.hpp>
#include <mumble/Pack.hpp>
#include <mumble/Message.hpp>
#include "MumbleTCP.pb.h"
#include <google/protobuf/message.h>

inline NSString *MLString(const std::string &value) {
    return [[NSString alloc] initWithBytes:value.data() length:value.size() encoding:NSUTF8StringEncoding] ?: @"";
}
inline std::string MLUTF8(NSString *value) { return value ? std::string(value.UTF8String ?: "") : std::string(); }
inline NSData *MLData(mumble::BufViewConst bytes) { return [NSData dataWithBytes:bytes.data() length:bytes.size()]; }
inline mumble::BufViewConst MLBytes(NSData *data) {
    return {reinterpret_cast<const std::byte *>(data.bytes), data.length};
}

@interface MLConnection (Internal)
- (void)sendProto:(const google::protobuf::Message &)message;
- (void)restoreSessionForUser:(MLUser *)user;
- (void)didRestoreSession;
- (void)updateAccessTokens:(NSArray *)tokens;
- (void)rememberSelfMuted:(BOOL)muted deafened:(BOOL)deafened;
- (void)sendOpus:(NSData *)data sequence:(uint64_t)sequence terminator:(BOOL)terminator;
@end
@interface MLServerModel (Internal)
- (void)receiveType:(uint16_t)type data:(NSData *)data;
- (void)reset;
- (void)setTalkState:(MLTalkState)state forSession:(NSUInteger)session;
- (void)receivedVoiceForSession:(NSUInteger)session talkState:(MLTalkState)state hasAudio:(BOOL)hasAudio terminator:(BOOL)terminator;
- (void)userLocalMuteChanged:(MLUser *)user;
@end
@interface MLAudio (Internal)
- (void)receiveOpus:(NSData *)data session:(NSUInteger)session sequence:(uint64_t)sequence terminator:(BOOL)terminator;
- (void)receiveOpus:(NSData *)data session:(NSUInteger)session sequence:(uint64_t)sequence terminator:(BOOL)terminator fromConnection:(MLConnection *)connection;
- (void)setUserLocalMuted:(BOOL)muted session:(NSUInteger)session connection:(MLConnection *)connection;
- (void)setLocalMuted:(BOOL)muted deafened:(BOOL)deafened;
- (void)setBandwidthLimit:(uint32_t)bandwidth;
@end
@interface MLUser ()
@property(nonatomic,weak) MLServerModel *audioModel;
@end
@interface MLChannel ()
@property(nonatomic,strong) NSMutableArray<MLChannel *> *childStorage, *linkStorage;
@property(nonatomic,strong) NSMutableArray<MLUser *> *userStorage;
@end
