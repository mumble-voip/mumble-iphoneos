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

#import "NSInvocation(MumbleKitAdditions).h"

#include <sys/socket.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <netinet/tcp.h>

/*
 * The SecureTransport.h header is not available on the iPhone, so
 * these constants are lifted from the Mac OS X version of the header.
 */
#define errSSLXCertChainInvalid -9807

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
				NSLog(@"MKConnection: Unable to get socket file descriptor from stream. Breakage may occur.");
			}

			if (c->socket != -1) {
				int val = 1;
				setsockopt(c->socket, IPPROTO_TCP, TCP_NODELAY, &val, sizeof(val));
				NSLog(@"MKConnection: TCP_NODELAY=1");
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
			NSLog(@"ERROR!");
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

- (id) init {
	self = [super init];
	if (self == nil)
		return nil;

	packetLength = -1;
	connectionEstablished = NO;
	socket = -1;
	_ignoreSSLVerification = NO;

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

	[self _setupSsl];

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

#pragma mark -

- (void) setDelegate:(id<MKConnectionDelegate>)delegate {
	_delegate = delegate;
}

- (id<MKConnectionDelegate>) delegate {
	return _delegate;
}

- (void) setMessageHandler:(id<MKMessageHandler>)messageHandler {
	_msgHandler = messageHandler;
}

- (id<MKMessageHandler>) messageHandler {
	return _msgHandler;
}

#pragma mark -

/*
 * Setup our CFStreams for SSL.
 */
- (void) _setupSsl {
	CFMutableDictionaryRef sslDictionary = CFDictionaryCreateMutable(kCFAllocatorDefault, 0,
																	 &kCFTypeDictionaryKeyCallBacks,
																	 &kCFTypeDictionaryValueCallBacks);

	if (sslDictionary) {
		CFDictionaryAddValue(sslDictionary, kCFStreamSSLLevel, kCFStreamSocketSecurityLevelTLSv1);
		/*
		 * The CFNetwork headers dictates that using the following properties:
		 *
		 *  - kCFStreamSSLAllowsExpiredCertificates
		 *  - kCFStreamSSLAllowsExpiredRoots
		 *  - kCFSTreamSSLAllowsAnyRoot
		 *
		 * has been deprecated in favor of using kCFStreamSSLValidatesCertificateChain.
		 */
		CFDictionaryAddValue(sslDictionary, kCFStreamSSLValidatesCertificateChain, _ignoreSSLVerification ? kCFBooleanFalse : kCFBooleanTrue);
	}
	
	CFWriteStreamSetProperty(writeStream, kCFStreamPropertySSLSettings, sslDictionary);
	CFReadStreamSetProperty(readStream, kCFStreamPropertySSLSettings, sslDictionary);

	CFRelease(sslDictionary);
}

- (void) setIgnoreSSLVerification:(BOOL)flag {
	_ignoreSSLVerification = flag;
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
		NSLog(@"MKConnection: Error: %s", strerror(streamError.error));
	} else {
		NSLog(@"domain = %u", streamError.domain);
		NSLog(@"MKConnection: Unexpected error. (domain=%u)", streamError.domain);
	}
}

- (void) handleSslError:(CFStreamError)streamError {	
	switch (streamError.error) {
		case errSSLXCertChainInvalid: {
			SecTrustRef trust = (SecTrustRef) CFWriteStreamCopyProperty(writeStream, kCFStreamPropertySSLPeerTrust);
			SecTrustResultType trustResult;
			if (SecTrustEvaluate(trust, &trustResult) != noErr) {
				NSLog(@"SecTrustEvalute: failure.");
			}

			switch (trustResult) {
				case kSecTrustResultInvalid:
					/* Invalid setting or result. Indicates the SecTrustEvaluate() did not finish completely. */
					break;
					
				case kSecTrustResultProceed:
					/* May be trusted for the purposes designated. ('Always Trust' in Keychain) */
					 break;
					
				case kSecTrustResultConfirm:
					/* User confirmation is required before proceeding. ('Ask Permission' in Keychain) */
					break;
					
				case kSecTrustResultDeny:
					/* This certificate is not trusted. ('Never Trust' in Keychain) */
					break;
					
				case kSecTrustResultUnspecified:
					/* No trust setting specified. ('Use System Policy' in Keychain) */
					break;
					
				case kSecTrustResultRecoverableTrustFailure:
					/* A recoverable trust failure. */
					break;
				
				case kSecTrustResultFatalTrustFailure:
					/* Fatal trust failure. Trust cannot be established without replacing the certificate.
					 * This error is thrown when the certificate is corrupt. */
					break;
				
				case kSecTrustResultOtherError:
					/* A non-trust related error. Possibly internal error in SecTrustEvaluate(). */
					break;
			}

			CFRelease(trust);

			NSArray *certificates = (NSArray *) CFWriteStreamCopyProperty(writeStream, kCFStreamPropertySSLPeerCertificates);
			NSInvocation *invocation = [NSInvocation invocationWithTarget:_delegate selector:@selector(connection:trustFailureInCertificateChain:)];
			[invocation setArgument:&self atIndex:2];
			[invocation setArgument:&certificates atIndex:3];
			[invocation invokeOnMainThread];
		}
	}
}

- (void) messageRecieved: (NSData *)data {
	NSInvocation *invocation;
	
	/* No message handler has been assigned. Don't propagate. */
	if (! _msgHandler)
		return;

	switch (packetType) {
		case VersionMessage: {
			MPVersion *v = [MPVersion parseFromData:data];
			invocation = [NSInvocation invocationWithTarget:_msgHandler selector:@selector(handleVersionMessage:)];
			[invocation setArgument:&v atIndex:2];
			[invocation invokeOnMainThread];
			break;
		}
		case AuthenticateMessage: {
			MPAuthenticate *a = [MPAuthenticate parseFromData:data];
			invocation = [NSInvocation invocationWithTarget:_msgHandler selector:@selector(handleAuthenticateMessage:)];
			[invocation setArgument:&a atIndex:2];
			[invocation invokeOnMainThread];
			break;
		}
		case PingMessage: {
			MPPing *p = [MPPing parseFromData:data];
			invocation = [NSInvocation invocationWithTarget:_msgHandler selector:@selector(handlePingMessage:)];
			[invocation setArgument:&p atIndex:2];
			[invocation invokeOnMainThread];
			break;
		}
		case RejectMessage: {
			MPReject *r = [MPReject parseFromData:data];
			invocation = [NSInvocation invocationWithTarget:_msgHandler selector:@selector(handleRejectMessage:)];
			[invocation setArgument:&r atIndex:2];
			[invocation invokeOnMainThread];
			break;
		}
		case ServerSyncMessage: {
			MPServerSync *ss = [MPServerSync parseFromData:data];
			invocation = [NSInvocation invocationWithTarget:_msgHandler selector:@selector(handleServerSyncMessage:)];
			[invocation setArgument:&ss atIndex:2];
			[invocation invokeOnMainThread];
			break;
		}
		case ChannelRemoveMessage: {
			MPChannelRemove *chrm = [MPChannelRemove parseFromData:data];
			invocation = [NSInvocation invocationWithTarget:_msgHandler selector:@selector(handleChannelRemoveMessage:)];
			[invocation setArgument:&chrm atIndex:2];
			[invocation invokeOnMainThread];
			break;
		}
		case ChannelStateMessage: {
			MPChannelState *chs = [MPChannelState parseFromData:data];
			invocation = [NSInvocation invocationWithTarget:_msgHandler selector:@selector(handleChannelStateMessage:)];
			[invocation setArgument:&chs atIndex:2];
			[invocation invokeOnMainThread];
			break;
		}
		case UserRemoveMessage: {
			MPUserRemove *urm = [MPUserRemove parseFromData:data];
			invocation = [NSInvocation invocationWithTarget:_msgHandler selector:@selector(handleUserRemoveMessage:)];
			[invocation setArgument:&urm atIndex:2];
			[invocation invokeOnMainThread];
			break;
		}
		case UserStateMessage: {
			MPUserState *us = [MPUserState parseFromData:data];
			invocation = [NSInvocation invocationWithTarget:_msgHandler selector:@selector(handleUserStateMessage:)];
			[invocation setArgument:&us atIndex:2];
			[invocation invokeOnMainThread];
			break;
		}
		case BanListMessage: {
			MPBanList *bl = [MPBanList parseFromData:data];
			invocation = [NSInvocation invocationWithTarget:_msgHandler selector:@selector(handleBanListMessage:)];
			[invocation setArgument:&bl atIndex:2];
			[invocation invokeOnMainThread];
			break;
		}
		case TextMessageMessage: {
			MPTextMessage *tm = [MPTextMessage parseFromData:data];
			invocation = [NSInvocation invocationWithTarget:_msgHandler selector:@selector(handleTextMessageMessage:)];
			[invocation setArgument:&tm atIndex:2];
			[invocation invokeOnMainThread];
			break;
		}
		case PermissionDeniedMessage: {
			MPPermissionDenied *pm = [MPPermissionDenied parseFromData:data];
			invocation = [NSInvocation invocationWithTarget:_msgHandler selector:@selector(handlePermissionDeniedMessage:)];
			[invocation setArgument:&pm atIndex:2];
			[invocation invokeOnMainThread];
			break;
		}
		case ACLMessage: {
			MPACL *acl = [MPACL parseFromData:data];
			invocation = [NSInvocation invocationWithTarget:_msgHandler selector:@selector(handleACLMessage:)];
			[invocation setArgument:&acl atIndex:2];
			[invocation invokeOnMainThread];
			break;
		}
		case QueryUsersMessage: {
			MPQueryUsers *qu = [MPQueryUsers parseFromData:data];
			invocation = [NSInvocation invocationWithTarget:_msgHandler selector:@selector(handleQueryUsersMessage:)];
			[invocation setArgument:&qu atIndex:2];
			[invocation invokeOnMainThread];
			break;
		}
		case CryptSetupMessage: {
			MPCryptSetup *cs = [MPCryptSetup parseFromData:data];
			invocation = [NSInvocation invocationWithTarget:_msgHandler selector:@selector(handleCryptSetupMessage:)];
			[invocation setArgument:&cs atIndex:2];
			[invocation invokeOnMainThread];
			break;
		}
		case ContextActionAddMessage: {
			MPContextActionAdd *caa = [MPContextActionAdd parseFromData:data];
			invocation = [NSInvocation invocationWithTarget:_msgHandler selector:@selector(handleContextActionAddMessage:)];
			[invocation setArgument:&caa atIndex:2];
			[invocation invokeOnMainThread];
			break;
		}
		case ContextActionMessage: {
			MPContextAction *ca = [MPContextAction parseFromData:data];
			invocation = [NSInvocation invocationWithTarget:_msgHandler selector:@selector(handleContextActionMessage:)];
			[invocation setArgument:&ca atIndex:2];
			[invocation invokeOnMainThread];
			break;
		}
		case UserListMessage: {
			MPUserList *ul = [MPUserList parseFromData:data];
			invocation = [NSInvocation invocationWithTarget:_msgHandler selector:@selector(handleUserListMessage:)];
			[invocation setArgument:&ul atIndex:2];
			[invocation invokeOnMainThread];
			break;
		}
		case VoiceTargetMessage: {
			MPVoiceTarget *vt = [MPVoiceTarget parseFromData:data];
			invocation = [NSInvocation invocationWithTarget:_msgHandler selector:@selector(handleVoiceTargetMessage:)];
			[invocation setArgument:&vt atIndex:2];
			[invocation invokeOnMainThread];
			break;
		}
		case PermissionQueryMessage: {
			MPPermissionQuery *pq = [MPPermissionQuery parseFromData:data];
			invocation = [NSInvocation invocationWithTarget:_msgHandler selector:@selector(handlePermissionQueryMessage:)];
			[invocation setArgument:&pq atIndex:2];
			[invocation invokeOnMainThread];
			break;
		}
		case CodecVersionMessage: {
			MPCodecVersion *cvm = [MPCodecVersion parseFromData:data];
			invocation = [NSInvocation invocationWithTarget:_msgHandler selector:@selector(handleCodecVersionMessage:)];
			[invocation setArgument:&cvm atIndex:2];
			[invocation invokeOnMainThread];
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
					NSLog(@"MKConnection: Unknown UDPTunnel packet received. Discarding...");
					break;
			}

			[pds release];
			break;
		}
		default: {
			NSLog(@"MKConnection: Unknown packet type recieved. Discarding.");
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
