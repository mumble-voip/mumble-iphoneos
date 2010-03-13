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
#define errSSLProtocol             -9800
#define errSSLXCertChainInvalid    -9807
#define errSSLLast                 -9849

@implementation MKConnection

- (id) init {
	self = [super init];
	if (self == nil)
		return nil;

	packetLength = -1;
	_connectionEstablished = NO;
	_socket = -1;
	_ignoreSSLVerification = NO;

	return self;
}

- (void) dealloc {
	[self closeStreams];

	[super dealloc];
}

- (void) connectToHost:(NSString *)hostName port:(NSUInteger)portNumber {

	packetLength = -1;
	_connectionEstablished = NO;

	hostname = hostName;
	port = portNumber;

	CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
									   (CFStringRef)hostname, port,
									   (CFReadStreamRef *) &_inputStream,
									   (CFWriteStreamRef *) &_outputStream);

	if (_inputStream == nil || _outputStream == nil) {
		NSLog(@"MKConnection: Unable to create stream pair.");
		return;
	}

	[_inputStream setDelegate:self];
	[_outputStream setDelegate:self];

	[_inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	[_outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

	[self _setupSsl];

	[_inputStream open];
	[_outputStream open];
}

- (void) closeStreams {
	NSLog(@"MKConnection: Closing streams.");

	if (_inputStream) {
		[_inputStream close];
		[_inputStream release];
		_inputStream = nil;
	}

	if (_outputStream) {
		[_outputStream close];
		[_outputStream release];
		_outputStream = nil;
	}

	[_pingTimer invalidate];
	_pingTimer = nil;
}

- (void) reconnect {
	[self closeStreams];

	NSLog(@"MKConnection: Reconnecting...");
	[self connectToHost:hostname port:port];
}

- (BOOL) connected {
	return _connectionEstablished;
}

#pragma mark NSStream event handlers

- (void) stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode {

	if (stream == _inputStream) {
		if (eventCode == NSStreamEventHasBytesAvailable)
			[self dataReady];
		return;
	}

	switch (eventCode) {
		case NSStreamEventOpenCompleted: {
			/*
			 * The OpenCompleted is a bad indicator of 'ready to use' for a
			 * TLS socket, since it will fire even before the TLS handshake
			 * has even begun. Instead, we rely on the first CanAcceptBytes
			 * event we receive to determine that a connection was established.
			 *
			 * We only use this event to extract our underlying socket.
			 */
			CFDataRef nativeHandle = CFWriteStreamCopyProperty((CFWriteStreamRef) _outputStream, kCFStreamPropertySocketNativeHandle);
			if (nativeHandle) {
				_socket = *(int *)CFDataGetBytePtr(nativeHandle);
				CFRelease(nativeHandle);
			} else {
				NSLog(@"MKConnection: Unable to get socket file descriptor from stream. Breakage may occur.");
			}

			if (_socket != -1) {
				int val = 1;
				setsockopt(_socket, IPPROTO_TCP, TCP_NODELAY, &val, sizeof(val));
				NSLog(@"MKConnection: TCP_NODELAY=1");
			}
			break;
		}

		case NSStreamEventHasSpaceAvailable: {
			if (! _connectionEstablished) {
				_connectionEstablished = YES;

				/* First, schedule our ping timer. */
				NSInvocation *timerInvocation = [NSInvocation invocationWithTarget:self selector:@selector(_pingTimerFired)];
				_pingTimer = [NSTimer timerWithTimeInterval:MKConnectionPingInterval invocation:timerInvocation repeats:YES];
				[[NSRunLoop currentRunLoop] addTimer:_pingTimer forMode:NSRunLoopCommonModes];

				/* Invoke connectionOpened: on our delegate. */
				NSInvocation *delegateInvoker = [NSInvocation invocationWithTarget:_delegate selector:@selector(connectionOpened:)];
				[delegateInvoker setArgument:&self atIndex:2];
				[delegateInvoker invokeOnMainThread];
			}
			break;
		}

		case NSStreamEventErrorOccurred: {
			NSLog(@"MKConnection: ErrorOccurred");
			NSError *err = [_outputStream streamError];
			[self handleError:err];
			break;
		}

		case NSStreamEventEndEncountered:
			NSLog(@"MKConnection: EndEncountered");
			break;

		default:
			NSLog(@"MKConnection: Unknown event (%u)", eventCode);
			break;
	}
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

	CFWriteStreamSetProperty((CFWriteStreamRef) _outputStream, kCFStreamPropertySSLSettings, sslDictionary);
	CFReadStreamSetProperty((CFReadStreamRef) _inputStream, kCFStreamPropertySSLSettings, sslDictionary);

	CFRelease(sslDictionary);
}

- (void) setIgnoreSSLVerification:(BOOL)flag {
	_ignoreSSLVerification = flag;
}

- (NSArray *) certificates {
	NSArray *certs = (NSArray *) CFWriteStreamCopyProperty((CFWriteStreamRef) _outputStream, kCFStreamPropertySSLPeerCertificates);
	return [certs autorelease];
}

- (void) sendMessageWithType:(MKMessageType)messageType buffer:(unsigned char *)buf length:(NSUInteger)len {
	UInt16 type = CFSwapInt16HostToBig((UInt16)messageType);
	UInt32 length = CFSwapInt32HostToBig(len);

	[_outputStream write:(unsigned char *)&type maxLength:sizeof(UInt16)];
	[_outputStream write:(unsigned char *)&length maxLength:sizeof(UInt32)];
	[_outputStream	write:buf maxLength:len];
}

- (void) sendMessageWithType:(MKMessageType)messageType data:(NSData *)data {
	[self sendMessageWithType:messageType buffer:(unsigned char *)[data bytes] length:[data length]];
}

-(void) dataReady {
	unsigned char buffer[6];

	if (! packetBuffer) {
		packetBuffer = [[NSMutableData alloc] initWithLength:0];
	}

	/* We aren't currently retrieveing a packet. */
	if (packetLength == -1) {
		NSInteger availableBytes = [_inputStream read:&buffer[0] maxLength:6];
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
			NSLog(@"MKConnection: NSMutableData is stubborn.");
			return;
		}

		NSInteger availableBytes = [_inputStream read:packetBytes + packetBufferOffset maxLength:packetLength];
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

/*
 * Ping timer fired.
 */
- (void) _pingTimerFired {
	NSData *data;
	MPPing_Builder *ping = [MPPing builder];

	[ping setTimestamp:0];
	[ping setGood:0];
	[ping setLate:0];
	[ping setLost:0];
	[ping setResync:0];

	[ping setUdpPingAvg:0.0f];
	[ping setUdpPingVar:0.0f];
	[ping setUdpPackets:0];
	[ping setTcpPingAvg:0.0f];
	[ping setTcpPingVar:0.0f];
	[ping setTcpPackets:0];

	data = [[ping build] data];
	[self sendMessageWithType:PingMessage data:data];

	NSLog(@"MKConnection: Sent ping message.");
}

- (void) _pingResponseFromServer:(MPPing *)pingMessage {
	NSLog(@"MKConnection: pingResponseFromServer");
}

- (void) handleError:(NSError *)streamError {
	NSInteger errorCode = [streamError code];

	/* Is the error an SSL-related error? (OSStatus errors are negative, so the
	 * greater than and less than signs are sort-of reversed here. */
	if (errorCode <= errSSLProtocol && errorCode > errSSLLast) {
		[self handleSslError:streamError];
	}

	NSLog(@"MKConnection: Error: %@", streamError);
}

- (void) handleSslError:(NSError *)streamError {

	if ([streamError code] == errSSLXCertChainInvalid) {
		SecTrustRef trust = (SecTrustRef) CFWriteStreamCopyProperty((CFWriteStreamRef) _outputStream, kCFStreamPropertySSLPeerTrust);
		SecTrustResultType trustResult;
		if (SecTrustEvaluate(trust, &trustResult) != noErr) {
			/* Unable to evaluate trust. */
		}

		switch (trustResult) {
			/* Invalid setting or result. Indicates the SecTrustEvaluate() did not finish completely. */
			case kSecTrustResultInvalid:
			/* May be trusted for the purposes designated. ('Always Trust' in Keychain) */
			case kSecTrustResultProceed:
			/* User confirmation is required before proceeding. ('Ask Permission' in Keychain) */
			case kSecTrustResultConfirm:
			/* This certificate is not trusted. ('Never Trust' in Keychain) */
			case kSecTrustResultDeny:
			/* No trust setting specified. ('Use System Policy' in Keychain) */
			case kSecTrustResultUnspecified:
			/* Fatal trust failure. Trust cannot be established without replacing the certificate.
			 * This error is thrown when the certificate is corrupt. */
			case kSecTrustResultFatalTrustFailure:
			/* A non-trust related error. Possibly internal error in SecTrustEvaluate(). */
			case kSecTrustResultOtherError:
				break;

			/* A recoverable trust failure. */
			case kSecTrustResultRecoverableTrustFailure: {
				NSArray *certificates = [self certificates];
				NSInvocation *invocation = [NSInvocation invocationWithTarget:_delegate selector:@selector(connection:trustFailureInCertificateChain:)];
				[invocation setArgument:&self atIndex:2];
				[invocation setArgument:&certificates atIndex:3];
				[invocation invokeOnMainThread];
				break;
			}
		}

		CFRelease(trust);
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
		case PingMessage: {
			MPPing *p = [MPPing parseFromData:data];
			[self _pingResponseFromServer:p];
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
