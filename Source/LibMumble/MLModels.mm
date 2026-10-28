#import "MLInternal.hpp"

@implementation MLUser
@synthesize localMuted=_localMuted;
- (void)setLocalMuted:(BOOL)muted {
    if (_localMuted==muted) return;
    _localMuted=muted; [_audioModel userLocalMuteChanged:self];
}
- (instancetype)init { if ((self=[super init])) { _userId=-1; _userName=@""; } return self; }
- (BOOL)isAuthenticated { return _userId >= 0; }
- (BOOL)isFriend { return NO; }
@end
@implementation MLChannel
- (instancetype)init {
    if ((self=[super init])) {
        _channelName=@""; _childStorage=[NSMutableArray array];
        _userStorage=[NSMutableArray array]; _linkStorage=[NSMutableArray array];
    }
    return self;
}
- (NSArray *)channels {
    return [_childStorage sortedArrayUsingComparator:^NSComparisonResult(MLChannel *a, MLChannel *b) {
        if (a.position != b.position) return a.position < b.position ? NSOrderedAscending : NSOrderedDescending;
        return [a.channelName localizedCaseInsensitiveCompare:b.channelName];
    }];
}
- (NSArray *)users {
    return [_userStorage sortedArrayUsingComparator:^NSComparisonResult(MLUser *a, MLUser *b) {
        return [a.userName localizedCaseInsensitiveCompare:b.userName];
    }];
}
- (NSArray *)linkedChannels { return [_linkStorage copy]; }
- (BOOL)isLinkedToChannel:(MLChannel *)channel { return [_linkStorage containsObject:channel]; }
@end

@implementation MLTextMessage {
    NSString *_html, *_plain;
    NSArray *_links, *_images;
}
static NSString *MLEscape(NSString *text) {
    return [[[text stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"]
        stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"] stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
}
+ (instancetype)messageWithPlainText:(NSString *)text {
    MLTextMessage *message=[self new]; message->_plain=[text copy] ?: @"";
    message->_html=[MLEscape(message->_plain) stringByReplacingOccurrencesOfString:@"\n" withString:@"<br/>"];
    message->_links=@[]; message->_images=@[]; return message;
}
+ (instancetype)messageWithString:(NSString *)text { return [self messageWithHTML:text]; }
+ (instancetype)messageWithHTML:(NSString *)html {
    MLTextMessage *message=[self new]; message->_html=[html copy] ?: @"";
    NSMutableArray *links=[NSMutableArray array], *images=[NSMutableArray array];
    NSRegularExpression *attributes=[NSRegularExpression regularExpressionWithPattern:@"(?i)<(a|img)\\b[^>]*?\\b(href|src)\\s*=\\s*['\"]([^'\"]*)['\"][^>]*>" options:0 error:nil];
    for (NSTextCheckingResult *match in [attributes matchesInString:message->_html options:0 range:NSMakeRange(0,message->_html.length)]) {
        NSString *tag=[message->_html substringWithRange:[match rangeAtIndex:1]];
        NSString *value=[message->_html substringWithRange:[match rangeAtIndex:3]];
        if ([tag.lowercaseString isEqual:@"img"]) [images addObject:value]; else [links addObject:value];
    }
    message->_links=links; message->_images=images;
    NSString *text=[message->_html stringByReplacingOccurrencesOfString:@"(?i)<br\\s*/?>|</p\\s*>" withString:@"\n" options:NSRegularExpressionSearch range:NSMakeRange(0,message->_html.length)];
    text=[text stringByReplacingOccurrencesOfString:@"<[^>]*>" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0,text.length)];
    NSDictionary *entities=@{@"&lt;":@"<", @"&gt;":@">", @"&quot;":@"\"", @"&apos;":@"'", @"&nbsp;":@" "};
    for (NSString *entity in entities) text=[text stringByReplacingOccurrencesOfString:entity withString:entities[entity]];
    message->_plain=[text stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
    return message;
}
- (NSString *)plainTextString { return _plain; }
- (NSString *)HTMLString { return _html; }
- (NSArray *)embeddedLinks { return _links; }
- (NSArray *)embeddedImages { return _images; }
@end

@implementation MLVersion { NSString *_release; }
+ (instancetype)sharedVersion { static MLVersion *version; static dispatch_once_t once; dispatch_once(&once, ^{ version=[self new]; }); return version; }
- (void)setOverrideReleaseString:(NSString *)release { _release=[release copy]; }
- (NSString *)releaseString { return _release ?: @"Mumble iOS (libmumble)"; }
@end
@implementation MLServices
+ (NSString *)regionalServerList { return @"https://publist.mumble.info/v1/list"; }
+ (NSURL *)regionalServerListURL { return [NSURL URLWithString:self.regionalServerList]; }
@end

#define MLNotify(sel, ...) [self notify:^(id<MLServerModelDelegate> delegate) { if ([delegate respondsToSelector:@selector(sel)]) [delegate __VA_ARGS__]; }]

@implementation MLServerModel {
    MLConnection *_connection;
    NSHashTable *_delegates;
    NSMutableDictionary<NSNumber *, MLUser *> *_users;
    NSMutableDictionary<NSNumber *, MLChannel *> *_channels;
    NSMutableDictionary<NSNumber *, NSTimer *> *_talkTimers;
    MLUser *_connectedUser;
}
- (instancetype)initWithConnection:(MLConnection *)connection {
    if ((self=[super init])) {
        _connection=connection; connection.model=self;
        _delegates=[NSHashTable weakObjectsHashTable]; [self reset];
    }
    return self;
}
- (void)reset {
    _maximumImageMessageLength=131072; _allowsHTMLMessages=YES;
    for (NSTimer *timer in _talkTimers.allValues) [timer invalidate];
    _talkTimers=[NSMutableDictionary dictionary];
    for (MLChannel *channel in _channels.allValues) [channel.linkStorage removeAllObjects];
    _users=[NSMutableDictionary dictionary]; _channels=[NSMutableDictionary dictionary]; _connectedUser=nil;
    MLChannel *root=[MLChannel new]; root.channelName=@"Root"; root.channelId=0; _channels[@0]=root;
}
- (void)dealloc {
    for (NSTimer *timer in _talkTimers.allValues) [timer invalidate];
    for (MLChannel *channel in _channels.allValues) [channel.linkStorage removeAllObjects];
}
- (void)notify:(void (^)(id<MLServerModelDelegate>))block { for (id delegate in _delegates.allObjects) block(delegate); }
- (void)addDelegate:(id<MLServerModelDelegate>)delegate { if (delegate) [_delegates addObject:delegate]; }
- (void)removeDelegate:(id<MLServerModelDelegate>)delegate { [_delegates removeObject:delegate]; }
- (NSString *)hostname { return _connection.hostname; }
- (NSInteger)port { return _connection.port; }
- (MLUser *)connectedUser { return _connectedUser; }
- (MLChannel *)rootChannel { return _channels[@0]; }
- (MLUser *)userWithSession:(NSUInteger)session { return _users[@(session)]; }
- (MLUser *)userWithHash:(NSString *)hash { for (MLUser *user in _users.allValues) if ([user.userHash isEqual:hash]) return user; return nil; }
- (MLChannel *)channelWithId:(NSUInteger)channelId { return _channels[@(channelId)]; }
- (MLChannel *)ensureChannel:(uint32_t)channelId {
    MLChannel *channel=_channels[@(channelId)];
    if (!channel) { channel=[MLChannel new]; channel.channelId=channelId; _channels[@(channelId)]=channel; }
    return channel;
}
- (void)receiveType:(uint16_t)type data:(NSData *)data {
    NSAssert(NSThread.isMainThread, @"Models are confined to the main thread");
    switch (static_cast<mumble::tcp::Message::Type>(type)) {
        case mumble::tcp::Message::Type::ServerConfig: {
            MumbleTCP::ServerConfig message;
            if (!message.ParseFromArray(data.bytes,(int)data.length)) return;
            if (message.has_allow_html()) _allowsHTMLMessages=message.allow_html();
            if (message.has_image_message_length()) _maximumImageMessageLength=message.image_message_length();
            break;
        }
        case mumble::tcp::Message::Type::ChannelState: {
            MumbleTCP::ChannelState message;
            if (!message.ParseFromArray(data.bytes,(int)data.length) || !message.has_channel_id()) return;
            BOOL added=!_channels[@(message.channel_id())];
            MLChannel *channel=[self ensureChannel:message.channel_id()];
            if (message.has_name()) { channel.channelName=MLString(message.name()); MLNotify(serverModel:channelRenamed:, serverModel:self channelRenamed:channel); }
            if (message.has_parent() && channel.channelId != 0 && message.parent()!=channel.channelId) {
                MLChannel *parent=[self ensureChannel:message.parent()];
                // Reject cycles rather than recurse forever in the channel view.
                BOOL cycle=NO; for (MLChannel *ancestor=parent; ancestor; ancestor=ancestor.parent) if (ancestor==channel) { cycle=YES; break; }
                if (!cycle) { [channel.parent.childStorage removeObject:channel]; channel.parent=parent; if (![parent.childStorage containsObject:channel]) [parent.childStorage addObject:channel]; }
                MLNotify(serverModel:channelMoved:, serverModel:self channelMoved:channel);
            }
            if (message.has_temporary()) channel.temporary=message.temporary();
            if (message.has_position()) { channel.position=message.position(); MLNotify(serverModel:channelPositionChanged:, serverModel:self channelPositionChanged:channel); }
            if (message.has_description()) channel.channelDescription=MLString(message.description());
            if (message.has_description_hash()) channel.channelDescriptionHash=[NSData dataWithBytes:message.description_hash().data() length:message.description_hash().size()];
            if (message.has_description() || message.has_description_hash()) MLNotify(serverModel:channelDescriptionChanged:, serverModel:self channelDescriptionChanged:channel);
            if (message.links_size()) {
                for (MLChannel *old in channel.linkStorage.copy) [old.linkStorage removeObject:channel];
                [channel.linkStorage removeAllObjects];
                for (uint32_t id : message.links()) { MLChannel *link=[self ensureChannel:id]; if (link!=channel) { [channel.linkStorage addObject:link]; if (![link.linkStorage containsObject:channel]) [link.linkStorage addObject:channel]; } }
            }
            for (uint32_t id : message.links_add()) { MLChannel *link=[self ensureChannel:id]; if (link!=channel && ![channel.linkStorage containsObject:link]) { [channel.linkStorage addObject:link]; [link.linkStorage addObject:channel]; } }
            for (uint32_t id : message.links_remove()) { MLChannel *link=_channels[@(id)]; if (link) { [channel.linkStorage removeObject:link]; [link.linkStorage removeObject:channel]; } }
            if (message.links_size() || message.links_add_size() || message.links_remove_size()) MLNotify(serverModel:linksChangedForChannel:, serverModel:self linksChangedForChannel:channel);
            if (added) MLNotify(serverModel:channelAdded:, serverModel:self channelAdded:channel);
            break;
        }
        case mumble::tcp::Message::Type::ChannelRemove: {
            MumbleTCP::ChannelRemove message; if (!message.ParseFromArray(data.bytes,(int)data.length) || !message.has_channel_id() || !message.channel_id()) return;
            MLChannel *channel=_channels[@(message.channel_id())]; if (!channel) return;
            [channel.parent.childStorage removeObject:channel];
            for (MLChannel *link in channel.linkStorage.copy) [link.linkStorage removeObject:channel];
            for (MLChannel *child in channel.childStorage.copy) { child.parent=self.rootChannel; [self.rootChannel.childStorage addObject:child]; }
            for (MLUser *user in channel.userStorage.copy) { user.channel=self.rootChannel; [self.rootChannel.userStorage addObject:user]; }
            [_channels removeObjectForKey:@(message.channel_id())]; MLNotify(serverModel:channelRemoved:, serverModel:self channelRemoved:channel); break;
        }
        case mumble::tcp::Message::Type::UserState: {
            MumbleTCP::UserState message; if (!message.ParseFromArray(data.bytes,(int)data.length) || !message.has_session()) return;
            MLUser *user=_users[@(message.session())]; BOOL added=!user;
            if (!user) {
                user=[MLUser new]; user.session=message.session(); user.audioModel=self; _users[@(message.session())]=user;
                [[MLAudio sharedAudio] setUserLocalMuted:NO session:user.session connection:_connection];
            }
            MLUser *actor=_users[@(message.actor())];
            if (message.has_name()) { user.userName=MLString(message.name()); MLNotify(serverModel:userRenamed:, serverModel:self userRenamed:user); }
            if (message.has_hash()) user.userHash=MLString(message.hash());
            if (message.has_user_id()) { user.userId=message.user_id(); MLNotify(serverModel:userAuthenticatedStateChanged:, serverModel:self userAuthenticatedStateChanged:user); }
            if (message.has_channel_id() || added) {
                MLChannel *old=user.channel, *channel=[self ensureChannel:message.has_channel_id()?message.channel_id():0];
                [old.userStorage removeObject:user]; user.channel=channel;
                if (![channel.userStorage containsObject:user]) [channel.userStorage addObject:user];
                if (old!=channel) MLNotify(serverModel:userMoved:toChannel:fromChannel:byUser:, serverModel:self userMoved:user toChannel:channel fromChannel:old byUser:actor);
            }
            if (message.has_mute()) user.muted=message.mute();
            if (message.has_deaf()) user.deafened=message.deaf();
            if (message.has_suppress()) user.suppressed=message.suppress();
            if (message.has_mute() || message.has_deaf() || message.has_suppress()) MLNotify(serverModel:userMuteStateChanged:, serverModel:self userMuteStateChanged:user);
            if (message.has_self_mute()) user.selfMuted=message.self_mute();
            if (message.has_self_deaf()) user.selfDeafened=message.self_deaf();
            if (message.has_self_mute() || message.has_self_deaf()) MLNotify(serverModel:userSelfMuteDeafenStateChanged:, serverModel:self userSelfMuteDeafenStateChanged:user);
            if (user.isMuted || user.isSelfMuted || user.isSuppressed || user.isDeafened || user.isSelfDeafened)
                [self setTalkState:MLTalkStatePassive forSession:user.session];
            if (message.has_priority_speaker()) { user.prioritySpeaker=message.priority_speaker(); MLNotify(serverModel:userPrioritySpeakerChanged:, serverModel:self userPrioritySpeakerChanged:user); }
            if (message.has_recording()) { user.recording=message.recording(); MLNotify(serverModel:userRecordingStateChanged:, serverModel:self userRecordingStateChanged:user); }
            if (message.has_comment()) user.comment=MLString(message.comment());
            if (message.has_comment_hash()) user.commentHash=[NSData dataWithBytes:message.comment_hash().data() length:message.comment_hash().size()];
            if (message.has_comment() || message.has_comment_hash()) MLNotify(serverModel:userCommentChanged:, serverModel:self userCommentChanged:user);
            if (message.has_texture()) user.texture=[NSData dataWithBytes:message.texture().data() length:message.texture().size()];
            if (message.has_texture_hash()) user.textureHash=[NSData dataWithBytes:message.texture_hash().data() length:message.texture_hash().size()];
            if (message.has_texture() || message.has_texture_hash()) MLNotify(serverModel:userTextureChanged:, serverModel:self userTextureChanged:user);
            if (user==_connectedUser) [[MLAudio sharedAudio] setLocalMuted:user.isSelfMuted || user.isMuted || user.isSuppressed deafened:user.isSelfDeafened || user.isDeafened];
            if (added) MLNotify(serverModel:userJoined:, serverModel:self userJoined:user); break;
        }
        case mumble::tcp::Message::Type::UserRemove: {
            MumbleTCP::UserRemove message; if (!message.ParseFromArray(data.bytes,(int)data.length) || !message.has_session()) return;
            MLUser *user=_users[@(message.session())], *actor=_users[@(message.actor())]; if (!user) return;
            [[MLAudio sharedAudio] setUserLocalMuted:YES session:user.session connection:_connection];
            [_talkTimers[@(message.session())] invalidate]; [_talkTimers removeObjectForKey:@(message.session())];
            if (message.has_actor()) {
                if (message.ban()) MLNotify(serverModel:userBanned:byUser:forReason:, serverModel:self userBanned:user byUser:actor forReason:MLString(message.reason()));
                else MLNotify(serverModel:userKicked:byUser:forReason:, serverModel:self userKicked:user byUser:actor forReason:MLString(message.reason()));
            } else MLNotify(serverModel:userDisconnected:, serverModel:self userDisconnected:user);
            [user.channel.userStorage removeObject:user]; [_users removeObjectForKey:@(message.session())];
            MLNotify(serverModel:userLeft:, serverModel:self userLeft:user); break;
        }
        case mumble::tcp::Message::Type::ServerSync: {
            MumbleTCP::ServerSync message; if (!message.ParseFromArray(data.bytes,(int)data.length) || !message.has_session()) return;
            _connectedUser=_users[@(message.session())]; if (!_connectedUser) return;
            [_connection restoreSessionForUser:_connectedUser];
            MLTextMessage *welcome=[MLTextMessage messageWithHTML:MLString(message.welcome_text())];
            [[MLAudio sharedAudio] setMainConnectionForAudio:_connection];
            for (MLUser *user in _users.allValues) [[MLAudio sharedAudio] setUserLocalMuted:user.isLocalMuted session:user.session connection:_connection];
            [[MLAudio sharedAudio] setLocalMuted:_connectedUser.isSelfMuted || _connectedUser.isMuted || _connectedUser.isSuppressed deafened:_connectedUser.isSelfDeafened || _connectedUser.isDeafened];
            MLNotify(serverModel:joinedServerAsUser:, serverModel:self joinedServerAsUser:self->_connectedUser);
            if(!_connection.isRestoringSession)MLNotify(serverModel:joinedServerAsUser:withWelcomeMessage:, serverModel:self joinedServerAsUser:self->_connectedUser withWelcomeMessage:welcome);
            [_connection didRestoreSession];break;
        }
        case mumble::tcp::Message::Type::TextMessage: {
            MumbleTCP::TextMessage message; if (!message.ParseFromArray(data.bytes,(int)data.length)) return;
            MLUser *sender=_users[@(message.actor())]; MLTextMessage *text=[MLTextMessage messageWithHTML:MLString(message.message())];
            MLNotify(serverModel:textMessageReceived:fromUser:, serverModel:self textMessageReceived:text fromUser:sender); break;
        }
        case mumble::tcp::Message::Type::PermissionDenied: {
            MumbleTCP::PermissionDenied message; if (!message.ParseFromArray(data.bytes,(int)data.length)) return;
            if (message.type()==MumbleTCP::PermissionDenied::Permission) MLNotify(serverModel:permissionDenied:forUser:inChannel:, serverModel:self permissionDenied:(MLPermission)message.permission() forUser:self->_users[@(message.session())] inChannel:self->_channels[@(message.channel_id())]);
            else if (message.type()==MumbleTCP::PermissionDenied::MissingCertificate) MLNotify(serverModel:missingCertificateErrorForUser:, serverModel:self missingCertificateErrorForUser:self->_users[@(message.session())]);
            else if (message.type()==MumbleTCP::PermissionDenied::UserName) MLNotify(serverModel:invalidUsernameErrorForName:, serverModel:self invalidUsernameErrorForName:MLString(message.name()));
            else MLNotify(serverModel:permissionDeniedForReason:, serverModel:self permissionDeniedForReason:MLString(message.reason())); break;
        }
        default: break;
    }
}
- (void)userLocalMuteChanged:(MLUser *)user {
    NSAssert(NSThread.isMainThread,@"User mute settings run on the main thread");
    if (_users[@(user.session)]==user) [[MLAudio sharedAudio] setUserLocalMuted:user.isLocalMuted session:user.session connection:_connection];
}
- (void)applyTalkState:(MLTalkState)state toUser:(MLUser *)user {
    if (user.talkState==state) return;
    user.talkState=state; MLNotify(serverModel:userTalkStateChanged:, serverModel:self userTalkStateChanged:user);
}
- (void)scheduleTalkStopForUser:(MLUser *)user after:(NSTimeInterval)delay {
    NSNumber *session=@(user.session);
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:delay];
    NSTimer *timer=_talkTimers[session];
    if (timer) { timer.fireDate=deadline; return; }
    __weak MLServerModel *weakSelf=self;
    timer=[NSTimer timerWithTimeInterval:delay repeats:NO block:^(NSTimer *expired) {
        MLServerModel *model=weakSelf;
        if (!model || model->_talkTimers[session]!=expired) return;
        [model->_talkTimers removeObjectForKey:session];
        if ([model userWithSession:user.session]==user) [model applyTalkState:MLTalkStatePassive toUser:user];
    }];
    _talkTimers[session]=timer;
    [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
}
- (void)setTalkState:(MLTalkState)state forSession:(NSUInteger)session {
    NSAssert(NSThread.isMainThread, @"Speaking indicators run on the main thread");
    MLUser *user=_users[@(session)]; if (!user) return;
    BOOL muted=user.isMuted || user.isSelfMuted || user.isSuppressed || user.isDeafened || user.isSelfDeafened;
    if (state==MLTalkStatePassive && !muted) {
        if (user.talkState!=MLTalkStatePassive) [self scheduleTalkStopForUser:user after:.3];
        return;
    }
    [_talkTimers[@(session)] invalidate]; [_talkTimers removeObjectForKey:@(session)];
    [self applyTalkState:muted ? MLTalkStatePassive : state toUser:user];
}
- (void)receivedVoiceForSession:(NSUInteger)session talkState:(MLTalkState)state hasAudio:(BOOL)hasAudio terminator:(BOOL)terminator {
    NSAssert(NSThread.isMainThread, @"Speaking indicators run on the main thread");
    MLUser *user=_users[@(session)];
    if (!user || user.isMuted || user.isSelfMuted || user.isSuppressed || user.isDeafened || user.isSelfDeafened) return;
    if (hasAudio) [self applyTalkState:state toUser:user];
    if (user.talkState==MLTalkStatePassive) return;
    // Keep brief speech visible after the final packet; recover even if that packet is lost.
    [self scheduleTalkStopForUser:user after:terminator ? .3 : .8];
}
- (void)joinChannel:(MLChannel *)channel {
    if (!_connectedUser || !channel) return;
    MumbleTCP::UserState message; message.set_session((uint32_t)_connectedUser.session); message.set_channel_id((uint32_t)channel.channelId); [_connection sendProto:message];
}
- (void)createChannelWithName:(NSString *)name parent:(MLChannel *)parent temporary:(BOOL)temporary {
    MumbleTCP::ChannelState message; message.set_name(MLUTF8(name)); message.set_parent((uint32_t)parent.channelId); message.set_temporary(temporary); [_connection sendProto:message];
}
- (void)sendTextMessage:(MLTextMessage *)text toTreeChannels:(NSArray *)trees andChannels:(NSArray *)channels andUsers:(NSArray *)users {
    MumbleTCP::TextMessage message; message.set_message(MLUTF8(text.HTMLString));
    for (MLChannel *channel in trees) message.add_tree_id((uint32_t)channel.channelId);
    for (MLChannel *channel in channels) message.add_channel_id((uint32_t)channel.channelId);
    for (MLUser *user in users) message.add_session((uint32_t)user.session); [_connection sendProto:message];
}
- (void)sendTextMessage:(MLTextMessage *)message toTree:(MLChannel *)channel { [self sendTextMessage:message toTreeChannels:@[channel] andChannels:@[] andUsers:@[]]; }
- (void)sendTextMessage:(MLTextMessage *)message toChannel:(MLChannel *)channel { [self sendTextMessage:message toTreeChannels:@[] andChannels:@[channel] andUsers:@[]]; }
- (void)sendTextMessage:(MLTextMessage *)message toUser:(MLUser *)user { [self sendTextMessage:message toTreeChannels:@[] andChannels:@[] andUsers:@[user]]; }
- (void)setAccessTokens:(NSArray *)tokens { [_connection updateAccessTokens:tokens]; }
- (NSArray *)serverCertificates { return _connection.peerCertificates; }
- (BOOL)serverCertificatesTrusted { return _connection.peerCertificateChainTrusted; }
- (void)setSelfMuted:(BOOL)muted andSelfDeafened:(BOOL)deafened {
    [_connection rememberSelfMuted:muted deafened:deafened];
    MumbleTCP::UserState message; message.set_self_mute(muted || deafened); message.set_self_deaf(deafened); [_connection sendProto:message];
}
- (void)registerConnectedUser { MumbleTCP::UserState message; message.set_session((uint32_t)_connectedUser.session); message.set_user_id(0); [_connection sendProto:message]; }
@end
