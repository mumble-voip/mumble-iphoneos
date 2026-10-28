// Application-owned iOS interface to libmumble. No libmumble dependency.
#pragma once
#import <Foundation/Foundation.h>
#import <Security/Security.h>

@class MLConnection, MLServerModel, MLChannel, MLUser, MLTextMessage, MLCertificate, MLAudio;
typedef NS_ENUM(NSUInteger, MLTalkState) { MLTalkStatePassive, MLTalkStateTalking, MLTalkStateWhispering, MLTalkStateShouting };
typedef NS_ENUM(NSUInteger, MLRejectReason) {
    MLRejectReasonNone, MLRejectReasonWrongVersion, MLRejectReasonInvalidUsername,
    MLRejectReasonWrongUserPassword, MLRejectReasonWrongServerPassword,
    MLRejectReasonUsernameInUse, MLRejectReasonServerIsFull, MLRejectReasonNoCertificate,
    MLRejectReasonAuthenticatorFailure
};
typedef NS_OPTIONS(NSUInteger, MLPermission) {
    MLPermissionNone=0, MLPermissionWrite=1, MLPermissionTraverse=2, MLPermissionEnter=4,
    MLPermissionSpeak=8, MLPermissionMuteDeafen=16, MLPermissionMove=32,
    MLPermissionMakeChannel=64, MLPermissionLinkChannel=128, MLPermissionWhisper=256,
    MLPermissionTextMessage=512, MLPermissionMakeTempChannel=1024,
    MLPermissionKick=65536, MLPermissionBan=131072, MLPermissionRegister=262144,
    MLPermissionSelfRegister=524288, MLPermissionAll=0xf07ff
};

@interface MLUser : NSObject
@property(nonatomic) NSInteger userId;
@property(nonatomic) NSUInteger session;
@property(nonatomic,copy) NSString *userName, *userHash, *comment;
@property(nonatomic,copy) NSData *commentHash, *textureHash, *texture;
@property(nonatomic) MLTalkState talkState;
@property(nonatomic,weak) MLChannel *channel;
@property(nonatomic,getter=isMuted) BOOL muted;
@property(nonatomic,getter=isDeafened) BOOL deafened;
@property(nonatomic,getter=isSuppressed) BOOL suppressed;
@property(nonatomic,getter=isSelfMuted) BOOL selfMuted;
@property(nonatomic,getter=isSelfDeafened) BOOL selfDeafened;
@property(nonatomic,getter=isLocalMuted) BOOL localMuted;
@property(nonatomic,getter=isPrioritySpeaker) BOOL prioritySpeaker;
@property(nonatomic,getter=isRecording) BOOL recording;
- (BOOL)isAuthenticated;
- (BOOL)isFriend;
@end

@interface MLChannel : NSObject
@property(nonatomic) NSUInteger channelId;
@property(nonatomic,copy) NSString *channelName, *channelDescription;
@property(nonatomic,copy) NSData *channelDescriptionHash;
@property(nonatomic,getter=isTemporary) BOOL temporary;
@property(nonatomic) NSInteger position;
@property(nonatomic,weak) MLChannel *parent;
@property(nonatomic,readonly) NSArray<MLChannel *> *channels, *linkedChannels;
@property(nonatomic,readonly) NSArray<MLUser *> *users;
- (BOOL)isLinkedToChannel:(MLChannel *)channel;
@end

@interface MLTextMessage : NSObject
+ (instancetype)messageWithPlainText:(NSString *)text;
+ (instancetype)messageWithHTML:(NSString *)html;
+ (instancetype)messageWithString:(NSString *)text;
- (NSString *)plainTextString;
- (NSString *)HTMLString;
- (NSArray *)embeddedLinks;
- (NSArray *)embeddedImages;
@end

@protocol MLConnectionDelegate <NSObject>
@optional
- (void)connectionOpened:(MLConnection *)connection;
- (void)connection:(MLConnection *)connection willReconnectAfterDelay:(NSTimeInterval)delay attempt:(NSUInteger)attempt;
- (void)connectionDidRestoreSession:(MLConnection *)connection;
- (void)connection:(MLConnection *)connection closedWithError:(NSError *)error;
- (void)connection:(MLConnection *)connection unableToConnectWithError:(NSError *)error;
- (void)connection:(MLConnection *)connection trustFailureInCertificateChain:(NSArray *)chain;
- (void)connection:(MLConnection *)connection rejectedWithReason:(MLRejectReason)reason explanation:(NSString *)explanation;
@end

@interface MLConnection : NSObject
@property(nonatomic,weak) id<MLConnectionDelegate> delegate;
@property(nonatomic,weak) MLServerModel *model;
@property(nonatomic,readonly,copy) NSString *hostname;
@property(nonatomic,readonly) NSUInteger port;
@property(nonatomic,readonly,getter=connected) BOOL connected;
@property(nonatomic) BOOL forceTCP;
@property(nonatomic) BOOL automaticReconnectEnabled;
@property(nonatomic,readonly,getter=isRestoringSession) BOOL restoringSession;
@property(nonatomic,copy) NSArray *certificateChain;
@property(nonatomic,readonly,copy) NSArray<MLCertificate *> *peerCertificates;
@property(nonatomic,readonly) BOOL peerCertificateChainTrusted;
@property(nonatomic,readonly,copy) NSString *serverVersion, *serverRelease, *serverOSName, *serverOSVersion;
- (void)connectToHost:(NSString *)hostname port:(NSUInteger)port;
- (void)disconnect;
- (void)reconnect;
- (void)setIgnoreSSLVerification:(BOOL)ignore;
- (void)authenticateWithUsername:(NSString *)username password:(NSString *)password accessTokens:(NSArray *)tokens;
@end

@protocol MLServerModelDelegate <NSObject>
@optional
- (void)serverModel:(MLServerModel *)model joinedServerAsUser:(MLUser *)user;
- (void)serverModel:(MLServerModel *)model joinedServerAsUser:(MLUser *)user withWelcomeMessage:(MLTextMessage *)message;
- (void)serverModelDisconnected:(MLServerModel *)model;
- (void)serverModel:(MLServerModel *)model userJoined:(MLUser *)user;
- (void)serverModel:(MLServerModel *)model userLeft:(MLUser *)user;
- (void)serverModel:(MLServerModel *)model userDisconnected:(MLUser *)user;
- (void)serverModel:(MLServerModel *)model userTalkStateChanged:(MLUser *)user;
- (void)serverModel:(MLServerModel *)model userRenamed:(MLUser *)user;
- (void)serverModel:(MLServerModel *)model userMoved:(MLUser *)user toChannel:(MLChannel *)channel fromChannel:(MLChannel *)previous byUser:(MLUser *)actor;
- (void)serverModel:(MLServerModel *)model userMuteStateChanged:(MLUser *)user;
- (void)serverModel:(MLServerModel *)model userSelfMuteDeafenStateChanged:(MLUser *)user;
- (void)serverModel:(MLServerModel *)model userSelfMuted:(MLUser *)user;
- (void)serverModel:(MLServerModel *)model userRemovedSelfMute:(MLUser *)user;
- (void)serverModel:(MLServerModel *)model userSelfMutedAndDeafened:(MLUser *)user;
- (void)serverModel:(MLServerModel *)model userRemovedSelfMuteAndDeafen:(MLUser *)user;
- (void)serverModel:(MLServerModel *)model userMuted:(MLUser *)user byUser:(MLUser *)actor;
- (void)serverModel:(MLServerModel *)model userUnmuted:(MLUser *)user byUser:(MLUser *)actor;
- (void)serverModel:(MLServerModel *)model userDeafened:(MLUser *)user byUser:(MLUser *)actor;
- (void)serverModel:(MLServerModel *)model userUndeafened:(MLUser *)user byUser:(MLUser *)actor;
- (void)serverModel:(MLServerModel *)model userMutedAndDeafened:(MLUser *)user byUser:(MLUser *)actor;
- (void)serverModel:(MLServerModel *)model userUnmutedAndUndeafened:(MLUser *)user byUser:(MLUser *)actor;
- (void)serverModel:(MLServerModel *)model userSuppressed:(MLUser *)user byUser:(MLUser *)actor;
- (void)serverModel:(MLServerModel *)model userUnsuppressed:(MLUser *)user byUser:(MLUser *)actor;
- (void)serverModel:(MLServerModel *)model userAuthenticatedStateChanged:(MLUser *)user;
- (void)serverModel:(MLServerModel *)model userPrioritySpeakerChanged:(MLUser *)user;
- (void)serverModel:(MLServerModel *)model userRecordingStateChanged:(MLUser *)user;
- (void)serverModel:(MLServerModel *)model userCommentChanged:(MLUser *)user;
- (void)serverModel:(MLServerModel *)model userTextureChanged:(MLUser *)user;
- (void)serverModel:(MLServerModel *)model userKicked:(MLUser *)user byUser:(MLUser *)actor forReason:(NSString *)reason;
- (void)serverModel:(MLServerModel *)model userBanned:(MLUser *)user byUser:(MLUser *)actor forReason:(NSString *)reason;
- (void)serverModel:(MLServerModel *)model channelAdded:(MLChannel *)channel;
- (void)serverModel:(MLServerModel *)model channelRemoved:(MLChannel *)channel;
- (void)serverModel:(MLServerModel *)model channelMoved:(MLChannel *)channel;
- (void)serverModel:(MLServerModel *)model channelRenamed:(MLChannel *)channel;
- (void)serverModel:(MLServerModel *)model channelPositionChanged:(MLChannel *)channel;
- (void)serverModel:(MLServerModel *)model channelDescriptionChanged:(MLChannel *)channel;
- (void)serverModel:(MLServerModel *)model linksChangedForChannel:(MLChannel *)channel;
- (void)serverModel:(MLServerModel *)model textMessageReceived:(MLTextMessage *)message fromUser:(MLUser *)user;
- (void)serverModel:(MLServerModel *)model permissionDenied:(MLPermission)permission forUser:(MLUser *)user inChannel:(MLChannel *)channel;
- (void)serverModel:(MLServerModel *)model missingCertificateErrorForUser:(MLUser *)user;
- (void)serverModel:(MLServerModel *)model invalidUsernameErrorForName:(NSString *)name;
- (void)serverModel:(MLServerModel *)model permissionDeniedForReason:(NSString *)reason;
@end

@interface MLServerModel : NSObject
@property(nonatomic,readonly) MLUser *connectedUser;
@property(nonatomic,readonly) MLChannel *rootChannel;
@property(nonatomic,readonly) NSUInteger maximumImageMessageLength;
@property(nonatomic,readonly) BOOL allowsHTMLMessages;
- (instancetype)initWithConnection:(MLConnection *)connection;
- (void)addDelegate:(id<MLServerModelDelegate>)delegate;
- (void)removeDelegate:(id<MLServerModelDelegate>)delegate;
- (NSString *)hostname;
- (NSInteger)port;
- (MLUser *)userWithSession:(NSUInteger)session;
- (MLUser *)userWithHash:(NSString *)hash;
- (MLChannel *)channelWithId:(NSUInteger)channelId;
- (void)joinChannel:(MLChannel *)channel;
- (void)createChannelWithName:(NSString *)name parent:(MLChannel *)parent temporary:(BOOL)temporary;
- (void)sendTextMessage:(MLTextMessage *)message toTreeChannels:(NSArray *)trees andChannels:(NSArray *)channels andUsers:(NSArray *)users;
- (void)sendTextMessage:(MLTextMessage *)message toTree:(MLChannel *)channel;
- (void)sendTextMessage:(MLTextMessage *)message toChannel:(MLChannel *)channel;
- (void)sendTextMessage:(MLTextMessage *)message toUser:(MLUser *)user;
- (void)setAccessTokens:(NSArray *)tokens;
- (NSArray *)serverCertificates;
- (BOOL)serverCertificatesTrusted;
- (void)setSelfMuted:(BOOL)muted andSelfDeafened:(BOOL)deafened;
- (void)registerConnectedUser;
@end

FOUNDATION_EXPORT NSString *MLCertificateItemCommonName, *MLCertificateItemOrganization;
@interface MLCertificate : NSObject
+ (instancetype)certificateWithCertificate:(NSData *)certificate privateKey:(NSData *)key;
+ (instancetype)selfSignedCertificateWithName:(NSString *)name email:(NSString *)email;
+ (instancetype)certificateWithPKCS12:(NSData *)data password:(NSString *)password;
+ (NSArray *)certificatesWithPKCS12:(NSData *)data password:(NSString *)password;
+ (NSData *)exportCertificateChainAsPKCS12:(NSArray *)chain withPassword:(NSString *)password;
- (BOOL)hasCertificate;
- (BOOL)hasPrivateKey;
- (NSData *)certificate;
- (NSData *)privateKey;
- (NSData *)exportPKCS12WithPassword:(NSString *)password;
- (NSData *)digest;
- (NSData *)digestOfKind:(NSString *)kind;
- (NSString *)hexDigest;
- (NSString *)hexDigestOfKind:(NSString *)kind;
- (NSDate *)notBefore;
- (NSDate *)notAfter;
- (BOOL)isSignedBy:(MLCertificate *)parent;
- (BOOL)isValidOnDate:(NSDate *)date;
- (NSString *)subjectName;
- (NSString *)commonName;
- (NSString *)emailAddress;
- (NSString *)issuerName;
- (NSString *)subjectItem:(NSString *)item;
- (NSString *)issuerItem:(NSString *)item;
@end

typedef NS_ENUM(NSUInteger, MLTransmitType) { MLTransmitTypeVAD, MLTransmitTypeToggle, MLTransmitTypeContinuous };
typedef NS_ENUM(NSUInteger, MLVADKind) { MLVADKindSignalToNoise, MLVADKindAmplitude };
typedef struct {
    MLTransmitType transmitType;
    MLVADKind vadKind;
    float vadMax, vadMin;
    int quality, audioPerPacket, noiseSuppression;
    float amplification;
    int jitterBufferSize;
    float volume;
    int outputDelay;
    float micBoost;
    BOOL enablePreprocessor, enableEchoCancellation, enableSideTone;
    float sidetoneVolume;
    BOOL preferReceiverOverSpeaker, opusForceCELTMode;
} MLAudioSettings;
FOUNDATION_EXPORT NSString *MLAudioDidRestartNotification;
@protocol MLAudioDelegate <NSObject>
@optional
- (BOOL)audioShouldBeRunning:(MLAudio *)audio;
@end
@interface MLAudio : NSObject
@property(nonatomic,weak) id<MLAudioDelegate> delegate;
@property(nonatomic) BOOL forceTransmit;
@property(nonatomic,readonly) MLTransmitType transmitType;
+ (instancetype)sharedAudio;
- (BOOL)isRunning;
- (void)start;
- (void)resumeIfNeeded;
- (void)stop;
- (void)restart;
- (void)readAudioSettings:(MLAudioSettings *)settings;
- (void)updateAudioSettings:(MLAudioSettings *)settings;
- (BOOL)echoCancellationAvailable;
- (void)setMainConnectionForAudio:(MLConnection *)connection;
- (float)speechProbablity;
- (float)peakCleanMic;
- (void)beginMetering;
- (void)endMetering;
- (NSDictionary *)copyAudioOutputMixerDebugInfo;
@end

@interface MLVersion : NSObject
+ (instancetype)sharedVersion;
- (void)setOverrideReleaseString:(NSString *)release;
- (NSString *)releaseString;
@end
typedef struct { uint32_t version, cur_users, max_users, bandwidth; double ping; } MLServerPingerResult;
@protocol MLServerPingerDelegate <NSObject>
- (void)serverPingerResult:(MLServerPingerResult *)result;
@end
@interface MLServerPinger : NSObject
@property(nonatomic,weak) id<MLServerPingerDelegate> delegate;
- (instancetype)initWithHostname:(NSString *)hostname port:(NSString *)port;
@end
@interface MLServices : NSObject
+ (NSString *)regionalServerList;
+ (NSURL *)regionalServerListURL;
@end
