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

#import <MumbleKit/MKUtils.h>
#import <MumbleKit/MKConnection.h>
#import <MumbleKit/MKPacketDataStream.h>
#import <MumbleKit/MKUser.h>
#import <MumbleKit/MKAudioOutput.h>

#import <CFNetwork/CFNetwork.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <netinet/tcp.h>


static void writeStreamCallback(CFWriteStreamRef writeStream, CFStreamEventType event, void *udata) {
	MKConnection *c = (MKConnection *) udata;

	switch (event) {

		case kCFStreamEventOpenCompleted: {
			/*
			 * The OpenCompleted is a bad indicator of 'ready to use' for a
			 * TLS socket, since it will fire even before the TLS handshake
			 * has even begun. Instead, we rely on the first CanAcceptBytes
			 * event we receive to determine that a connection was established.
			 *
			 * We only use this event to extract our underlying socket.
			 */
			CFDataRef nativeHandle = CFWriteStreamCopyProperty(writeStream, kCFStreamPropertySocketNativeHandle);
			if (nativeHandle) {
				c->socket = *(int *)CFDataGetBytePtr(nativeHandle);
				CFRelease(nativeHandle);
			} else {
				NSLog(@"Connection: Unable to get socket file descriptor from stream. Breakage may occur.");
			}

			if (c->socket != -1) {
				int val = 1;
				setsockopt(c->socket, IPPROTO_TCP, TCP_NODELAY, &val, sizeof(val));
				NSLog(@"Connection: TCP_NODELAY=1");
			}
			break;
		}

		case kCFStreamEventCanAcceptBytes: {
			if (! c->connectionEstablished) {
				/*
				 * OK, so we seem to have established our connection.
				 *
				 * First we need to check if we were told to ignore invalid
				 * certificates in the certificate chain.
				 */
				c->connectionEstablished = YES;
				[[c delegate] performSelectorOnMainThread:@selector(connectionOpened:) withObject:c waitUntilDone:NO];
			}
			break;
		}

		case kCFStreamEventErrorOccurred: {
			CFStreamError err = CFWriteStreamGetError(writeStream);
			[c handleError:err];
			break;
		}

		case kCFStreamEventEndEncountered:
			NSLog(@"Connection: WriteStream -> EndEncountered");
			break;

		default:
			NSLog(@"Connection: WriteStream -> Unknown event!");
			break;
	}
}

static void readStreamCallback(CFReadStreamRef *readStream, CFStreamEventType event, void *udata) {
	MKConnection *c = (MKConnection *) udata;

	switch (event) {
		case kCFStreamEventHasBytesAvailable:
			[c dataReady];
			break;

		case kCFStreamEventOpenCompleted:
		case kCFStreamEventErrorOccurred:
		case kCFStreamEventEndEncountered:
		default:
			/*
			 * Implemented in writeStreamCallback.
			 */
			break;
	}
}

@implementation MKConnection

@synthesize delegate;

- (id) init {
	self = [super init];
	if (self == nil)
		return nil;

	forceAllowedCertificateList = nil;
	packetLength = -1;
	connectionEstablished = NO;
	socket = -1;

	return self;
}

- (void) dealloc {
	[super dealloc];
	[self closeStreams];
}

- (void) connectToHost:(NSString *)hostName port:(NSUInteger)portNumber {

	packetLength = -1;
	connectionEstablished = NO;

	hostname = hostName;
	port = portNumber;

	CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, (CFStringRef)hostname, port, &readStream, &writeStream);

	if (readStream == NULL || writeStream == NULL) {
		NSLog(@"Connection: Unable to create stream pair.");
		return;
	}

	CFOptionFlags writeEvents = kCFStreamEventOpenCompleted |
	                            kCFStreamEventCanAcceptBytes |
	                            kCFStreamEventErrorOccurred |
	                            kCFStreamEventEndEncountered;

	CFStreamClientContext wctx;
	wctx.version = 0;
	wctx.info = self;
	wctx.retain = NULL;
	wctx.release = NULL;
	wctx.copyDescription = NULL;

	if (! CFWriteStreamSetClient(writeStream, writeEvents, writeStreamCallback, &wctx)) {
		NSLog(@"Connection: Unable to set client for CFWriteStream.");
	}

	CFWriteStreamScheduleWithRunLoop(writeStream, CFRunLoopGetMain(), kCFRunLoopDefaultMode);

	CFOptionFlags readEvents = kCFStreamEventOpenCompleted |
	                           kCFStreamEventHasBytesAvailable |
							   kCFStreamEventErrorOccurred |
	                           kCFStreamEventEndEncountered;

	CFStreamClientContext rctx;
	rctx.version = 0;
	rctx.info = (void *)self;
	rctx.retain = NULL;
	rctx.release = NULL;
	rctx.copyDescription = NULL;

	if (! CFReadStreamSetClient(readStream, readEvents, (void *)readStreamCallback, &rctx)) {
		NSLog(@"Connection: Unable to set client for CFReadStream.");
		return;
	}

	CFReadStreamScheduleWithRunLoop(readStream, CFRunLoopGetMain(), kCFRunLoopDefaultMode);

	[self setupSsl];

	if (! CFWriteStreamOpen(writeStream)) {
		NSLog(@"Connection: Unable to open write stream.");
	}

	if (! CFReadStreamOpen(readStream)) {
		NSLog(@"Connection: Unable to open read stream.");
	}
}

- (void) closeStreams {
	NSLog(@"Connection: Closing streams.");

	if (writeStream) {
		CFWriteStreamClose(writeStream);
		CFRelease(writeStream);
		writeStream = nil;
	}

	if (readStream) {
		CFReadStreamClose(readStream);
		CFRelease(readStream);
		readStream = nil;
	}
}

- (void) reconnect {
	[self closeStreams];

	NSLog(@"Connection: Reconnecting...");
	[self connectToHost:hostname port:port];
}

- (BOOL) connected {
	return connectionEstablished;
}

- (void) setDelegate:(id)messageHandler {
	delegate = messageHandler;
}

- (void) setupSsl {
	CFMutableDictionaryRef sslDictionary = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

	if (sslDictionary) {
		CFDictionaryAddValue(sslDictionary, kCFStreamSSLLevel, kCFStreamSocketSecurityLevelTLSv1);

		/*
		 * The following three properties have been replaced by 'CFStreamSSLValidatesCertificateChain'.
		 */
#if 0
		 CFDictionaryAddValue(sslDictionary, kCFStreamSSLAllowsExpiredCertificates, kCFBooleanFalse);
		 CFDictionaryAddValue(sslDictionary, kCFStreamSSLAllowsExpiredRoots, kCFBooleanFalse);
		 CFDictionaryAddValue(sslDictionary, kCFStreamSSLAllowsAnyRoot, kCFBooleanFalse);
#endif
		NSLog(@"forceAllowedCertificates = %i", [forceAllowedCertificateList count]);

		/* Check if we should force through a particular list of certificates no matter what. */
		if ([forceAllowedCertificateList count] > 0) {
			NSLog(@"Connection: Disabling automatic validation of certificate chain.");
			CFDictionaryAddValue(sslDictionary, kCFStreamSSLValidatesCertificateChain, kCFBooleanFalse);
		} else {
			CFDictionaryAddValue(sslDictionary, kCFStreamSSLValidatesCertificateChain, kCFBooleanTrue);
		}
	}

	CFWriteStreamSetProperty(writeStream, kCFStreamPropertySSLSettings, sslDictionary);
	CFReadStreamSetProperty(readStream, kCFStreamPropertySSLSettings, sslDictionary);

	CFRelease(sslDictionary);
}

- (void) sendMessageWithType:(MKMessageType)messageType buffer:(unsigned char *)buf length:(NSUInteger)len {
	UInt16 type = CFSwapInt16HostToBig((UInt16)messageType);
	UInt32 length = CFSwapInt32HostToBig(len);

	CFWriteStreamWrite(writeStream, (unsigned char *)&type, sizeof(UInt16));
	CFWriteStreamWrite(writeStream, (unsigned char *)&length, sizeof(UInt32));
	CFWriteStreamWrite(writeStream, buf, len);
}

- (void) sendMessageWithType:(MKMessageType)messageType data:(NSData *)data {
	[self sendMessageWithType:messageType buffer:(unsigned char *)[data bytes] length:[data length]];
}

- (NSArray *) peerCertificates {
	NSArray *peerCertificates = (NSArray *)CFWriteStreamCopyProperty(writeStream, kCFStreamPropertySSLPeerCertificates);
	return [peerCertificates autorelease];
}

/*
 * Mechanism to force invalid certificates through.
 */
- (void) setForceAllowedCertificates:(NSArray *)forcedCerts {
	NSLog(@"setForceAllowedCertificates to list of length = %i", [forcedCerts count]);
	if (forceAllowedCertificateList)
		[forceAllowedCertificateList release];
	forceAllowedCertificateList = [[forcedCerts copy] retain];
}

-(NSArray *) forceAllowedCertificates {
	NSLog(@"Bla.... length at the moment = %i", [forceAllowedCertificateList count]);
	return forceAllowedCertificateList;
}

-(void) dataReady {
	char buffer[6];

	if (! packetBuffer) {
		packetBuffer = [[NSMutableData alloc] initWithLength:0];
	}

	/* We aren't currently retrieveing a packet. */
	if (packetLength == -1) {
		CFIndex availableBytes = CFReadStreamRead(readStream, (UInt8 *) &buffer[0], 6);

		if (availableBytes < 6) {
			return;
		}

		packetType = (MKMessageType) CFSwapInt16BigToHost(*(UInt16 *)(&buffer[0]));
		packetLength = (int) CFSwapInt32BigToHost(*(UInt32 *)(&buffer[2]));

		packetBufferOffset = 0;
		[packetBuffer setLength:packetLength];
	}

	/* We're recv'ing a packet. */
	if (packetLength > 0) {
		UInt8 *packetBytes = [packetBuffer mutableBytes];
		if (! packetBytes) {
			NSLog(@"Connection: NSMutableData is stubborn.");
			return;
		}

		CFIndex availableBytes = CFReadStreamRead(readStream, packetBytes + packetBufferOffset, packetLength);
		packetLength -= availableBytes;
		packetBufferOffset += availableBytes;
	}

	/* Done! */
	if (packetLength == 0) {
		[self messageRecieved:packetBuffer];
		[packetBuffer setLength:0]; // fixme(mkrautz): Is this one needed?
		packetLength = -1;
	}
}

- (void) handleError:(CFStreamError)streamError {
	if (streamError.domain == kCFStreamErrorDomainSSL) {
		[self handleSslError:streamError];
	} else if (streamError.domain == kCFStreamErrorDomainPOSIX) {
		/* yay, posix error! */
		NSLog(@"Connection: Error: %s", strerror(streamError.error));
	} else {
		NSLog(@"domain = %u", streamError.domain);
		NSLog(@"Connection: Unexpected error. (domain=%u)", streamError.domain);
	}
}

- (void) handleSslError:(CFStreamError)streamError {
	switch (streamError.error) {
		/*
		 * An invalid certificate chain was encountered. This error
		 * is pretty typical amongst Mumble servers, because many
		 * server operators use self-signed certificates.
		 */
		case errSSLXCertChainInvalid: {
			/*
			 * Get a list of our peer certificates, so we can pass them to
			 * our delegate.
			 */
			SecTrustRef trust = (SecTrustRef )CFWriteStreamCopyProperty(writeStream, kCFStreamPropertySSLPeerTrust);
			SecTrustResultType trustResult;
			if (SecTrustEvaluate(trust, &trustResult) != noErr) {
				NSLog(@"SecTrustEvalute: failure.");
			}
			NSLog(@"resultType = %i", trustResult);
			CFRelease(trust);

			NSArray *peerCertificates = [self peerCertificates];
			if ([delegate respondsToSelector:@selector(invalidSslCertificateChain:)]) {
				[delegate performSelectorOnMainThread:@selector(invalidSslCertificateChain:) withObject:peerCertificates waitUntilDone:NO];
			} else {
				NSLog(@"Connection: Delegate has no 'invalidSslCertificateChain:' method.");
			}
			break;
		}
	}
}

- (void) messageRecieved: (NSData *)data {

	switch (packetType) {
		case VersionMessage: {
			MPVersion *v = [MPVersion parseFromData:data];
			if ([delegate respondsToSelector:@selector(handleVersionMessage:)])
				[delegate handleVersionMessage:v];
			break;
		}
		case AuthenticateMessage: {
			MPAuthenticate *a = [MPAuthenticate parseFromData:data];
			if ([delegate respondsToSelector:@selector(handleAuthenticateMessage:)])
				[delegate handleAuthenticateMessage:a];
			break;
		}
		case PingMessage: {
			MPPing *p = [MPPing parseFromData:data];
			if ([delegate respondsToSelector:@selector(handlePingMessage:)])
				[delegate handlePingMessage:p];
			break;
		}
		case RejectMessage: {
			MPReject *r = [MPReject parseFromData:data];
			if ([delegate respondsToSelector:@selector(handleRejectMessage:)])
				[delegate handleRejectMessage:r];
			break;
		}
		case ServerSyncMessage: {
			MPServerSync *ss = [MPServerSync parseFromData:data];
			if ([delegate respondsToSelector:@selector(handleServerSyncMessage:)])
				[delegate handleServerSyncMessage:ss];
			break;
		}
		case ChannelRemoveMessage: {
			MPChannelRemove *chrm = [MPChannelRemove parseFromData:data];
			if ([delegate respondsToSelector:@selector(handleChannelRemoveMessage:)])
				[delegate handleChannelRemoveMessage:chrm];
			break;
		}
		case ChannelStateMessage: {
			MPChannelState *chs = [MPChannelState parseFromData:data];
			if ([delegate respondsToSelector:@selector(handleChannelStateMessage:)]);
				[delegate handleChannelStateMessage:chs];
			break;
		}
		case UserRemoveMessage: {
			MPUserRemove *urm = [MPUserRemove parseFromData:data];
			if ([delegate respondsToSelector:@selector(handleUserRemoveMessage:)])
				[delegate handleUserRemoveMessage:urm];
			break;
		}
		case UserStateMessage: {
			MPUserState *us = [MPUserState parseFromData:data];
			if ([delegate respondsToSelector:@selector(handleUserStateMessage:)])
				[delegate handleUserStateMessage:us];
			break;
		}
		case BanListMessage: {
			MPBanList *bl = [MPBanList parseFromData:data];
			if ([delegate respondsToSelector:@selector(handleBanListMessage:)])
				[delegate handleBanListMessage:bl];
			break;
		}
		case TextMessageMessage: {
			MPTextMessage *tm = [MPTextMessage parseFromData:data];
			if ([delegate respondsToSelector:@selector(handleTextMessageMessage:)])
				[delegate handleTextMessageMessage:tm];
			break;
		}
		case PermissionDeniedMessage: {
			MPPermissionDenied *pm = [MPPermissionDenied parseFromData:data];
			if ([delegate respondsToSelector:@selector(handlePermissionDeniedMessage:)])
				[delegate handlePermissionDeniedMessage:pm];
			break;
		}
		case ACLMessage: {
			MPACL *acl = [MPACL parseFromData:data];
			if ([delegate respondsToSelector:@selector(handleACLMessage:)])
				[delegate handleACLMessage:acl];
			break;
		}
		case QueryUsersMessage: {
			MPQueryUsers *qu = [MPQueryUsers parseFromData:data];
			if ([delegate respondsToSelector:@selector(handleQueryUsersMessage:)])
				[delegate handleQueryUsersMessage:qu];
			break;
		}
		case CryptSetupMessage: {
			MPCryptSetup *cs = [MPCryptSetup parseFromData:data];
			if ([delegate respondsToSelector:@selector(handleCryptSetupMessage:)])
				[delegate handleCryptSetupMessage:cs];
			break;
		}
		case ContextActionAddMessage: {
			MPContextActionAdd *caa = [MPContextActionAdd parseFromData:data];
			if ([delegate respondsToSelector:@selector(handleContextActionAddMessage:)])
				[delegate handleContextActionAddMessage:caa];
			break;
		}
		case ContextActionMessage: {
			MPContextAction *ca = [MPContextAction parseFromData:data];
			if ([delegate respondsToSelector:@selector(handleContextActionMessage:)])
				[delegate handleContextActionMessage:ca];
			break;
		}
		case UserListMessage: {
			MPUserList *ul = [MPUserList parseFromData:data];
			if ([delegate respondsToSelector:@selector(handleUserListMessage:)])
				[delegate handleUserListMessage:ul];
			break;
		}
		case VoiceTargetMessage: {
			MPVoiceTarget *vt = [MPVoiceTarget parseFromData:data];
			if ([delegate respondsToSelector:@selector(handleVoiceTargetMessage:)])
				[delegate handleVoiceTargetMessage:vt];
			break;
		}
		case PermissionQueryMessage: {
			MPPermissionQuery *pq = [MPPermissionQuery parseFromData:data];
			if ([delegate respondsToSelector:@selector(handlePermissionQueryMessage:)])
				[delegate handlePermissionQueryMessage:pq];
			break;
		}
		case CodecVersionMessage: {
			MPCodecVersion *cvm = [MPCodecVersion parseFromData:data];
			if ([delegate respondsToSelector:@selector(handleCodecVersionMessage:)])
				[delegate handleCodecVersionMessage:cvm];
			break;
		}
		case UDPTunnelMessage: {
			unsigned char *buf = (unsigned char *)[data bytes];
			MKUDPMessageType messageType = ((buf[0] >> 5) & 0x7);
			unsigned int messageFlags = buf[0] & 0x1f;
			MKPacketDataStream *pds = [[MKPacketDataStream alloc] initWithBuffer:buf+1 length:[data length]-1]; // fixme(-1)?

			switch (messageType) {
				case UDPVoiceCELTAlphaMessage:
				case UDPVoiceCELTBetaMessage:
				case UDPVoiceSpeexMessage:
					[self handleVoicePacketOfType:messageType flags:messageFlags datastream:pds];
					break;
				default:
					NSLog(@"Connection: Unknown UDPTunnel packet received. Discarding...");
					break;
			}

			[pds release];
			break;
		}
		default: {
			NSLog(@"Connection: Unknown packet type recieved. Discarding.");
			break;
		}
	}
}

- (void) handleVoicePacketOfType:(MKUDPMessageType)msgType flags:(NSUInteger)msgflags datastream:(MKPacketDataStream *)pds {
	MK_UNUSED NSUInteger session = [pds getUnsignedInt];
	NSUInteger seq = [pds getUnsignedInt];

	NSMutableData *voicePacketData = [[NSMutableData alloc] initWithCapacity:[pds left]+1];
	[voicePacketData setLength:[pds left]+1];

	unsigned char *bytes = [voicePacketData mutableBytes];
	bytes[0] = (unsigned char)msgflags;
	memcpy(bytes+1, [pds dataPtr], [pds left]);

	MKUser *user = nil;//[User lookupBySession:session];
	MKAudioOutput *ao = [MKAudio audioOutput];
	[ao addFrameToBufferWithUser:user data:voicePacketData sequence:seq type:msgType];

	[voicePacketData release];
}

@end
