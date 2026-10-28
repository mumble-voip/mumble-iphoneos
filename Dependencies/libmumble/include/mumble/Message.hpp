// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_MESSAGE_HPP
#define MUMBLE_MESSAGE_HPP

#include "Cert.hpp"
#include "Endian.hpp"
#include "IP.hpp"
#include "Pack.hpp"
#include "Types.hpp"

#include <chrono>
#include <optional>

#define MUMBLE_MESSAGE_DECL(name) struct Message::name : public Message

#define MUMBLE_MESSAGE_COMMON(name) \
	Type type() const override {    \
		return Type::name;          \
	}

namespace mumble {
namespace legacy {
	namespace udp {
		enum class Type : uint8_t { VoiceCELTAlpha, Ping, VoiceSpeex, VoiceCELTBeta, VoiceOpus };

		MUMBLE_PACK(struct Ping {
			uint32_t versionBlob  = 0;
			uint64_t timestamp    = 0;
			uint32_t sessions     = 0;
			uint32_t maxSessions  = 0;
			uint32_t maxBandwidth = 0;
		});

		static constexpr bool isPlainPing(const BufViewConst data) {
			if (data.size() != 12 && data.size() != 24) {
				return false;
			}

			auto ping = reinterpret_cast< const Ping * >(data.data());

			return !ping->versionBlob;
		}

		static constexpr Type type(const BufViewConst data) {
			const auto byte = (std::to_integer< uint8_t >(data[0]) >> 5) & 0x7;
			return static_cast< Type >(byte);
		}
	} // namespace udp
} // namespace legacy

struct Message {
	enum class Protocol : uint8_t { TCP, UDP };

	using Clock     = std::chrono::high_resolution_clock;
	using Timestamp = std::chrono::time_point< Clock >;

	Message(const Message &) = default;
	Message(Message &&)      = default;
	Message() : timestamp(Clock::now()) {}
	virtual ~Message() = default;

	Message &operator=(const Message &) = default;
	Message &operator=(Message &&)      = default;

	virtual Protocol protocol() const = 0;

	Timestamp timestamp;
};

namespace udp {
	struct Message : public mumble::Message {
		struct Audio;
		struct Ping;

		enum class Type : uint8_t { Audio, Ping };

		Message()          = default;
		virtual ~Message() = default;

		Protocol protocol() const override { return Protocol::UDP; }

		virtual Type type() const = 0;

		static Type type(const Pack &pack) { return static_cast< Type >(pack.header().type); }

		static constexpr std::string_view text(const Type type) {
			switch (type) {
				case Type::Audio: {
					return "Audio";
				}
				case Type::Ping: {
					return "Ping";
				}
			}

			return "";
		}
	};

	MUMBLE_MESSAGE_DECL(Audio) {
		enum : uint8_t { Unknown, ClientToServer, ServerToClient } direction = Unknown;

		union {
			// Client to server.
			uint32_t target = UINT32_MAX;
			// Server to client.
			uint32_t context;
		};

		std::optional< uint32_t > senderSession = {};

		uint64_t frameNumber                = 0;
		std::vector< std::byte > opusData   = {};
		std::vector< float > positionalData = {};

		float volumeAdjustment = 0.f;

		bool isTerminator = false;

		MUMBLE_MESSAGE_COMMON(Audio)
	};

	MUMBLE_MESSAGE_DECL(Ping) {
		bool requestExtendedInformation = false;

		std::optional< mumble::Version > version      = {};
		std::optional< uint32_t > userCount           = {};
		std::optional< uint32_t > maxUserCount        = {};
		std::optional< uint32_t > maxBandwidthPerUser = {};

		MUMBLE_MESSAGE_COMMON(Ping)
	};
} // namespace udp

namespace tcp {
	struct Message : public mumble::Message {
		struct Version;
		struct UDPTunnel;
		struct Authenticate;
		struct Ping;
		struct Reject;
		struct ServerSync;
		struct ChannelRemove;
		struct ChannelState;
		struct UserRemove;
		struct UserState;
		struct BanList;
		struct TextMessage;
		struct PermissionDenied;
		struct ACL;
		struct QueryUsers;
		struct CryptSetup;
		struct ContextActionModify;
		struct ContextAction;
		struct UserList;
		struct VoiceTarget;
		struct PermissionQuery;
		struct CodecVersion;
		struct UserStats;
		struct RequestBlob;
		struct ServerConfig;
		struct SuggestConfig;
		struct PluginDataTransmission;

		enum class Type : uint16_t {
			Version,
			UDPTunnel,
			Authenticate,
			Ping,
			Reject,
			ServerSync,
			ChannelRemove,
			ChannelState,
			UserRemove,
			UserState,
			BanList,
			TextMessage,
			PermissionDenied,
			ACL,
			QueryUsers,
			CryptSetup,
			ContextActionModify,
			ContextAction,
			UserList,
			VoiceTarget,
			PermissionQuery,
			CodecVersion,
			UserStats,
			RequestBlob,
			ServerConfig,
			SuggestConfig,
			PluginDataTransmission
		};

		enum class Perm : uint32_t {
			None            = 0b00000000'00000000'00000000'00000000,
			Write           = 0b00000000'00000000'00000000'00000001,
			Traverse        = 0b00000000'00000000'00000000'00000010,
			Enter           = 0b00000000'00000000'00000000'00000100,
			Speak           = 0b00000000'00000000'00000000'00001000,
			MuteDeafen      = 0b00000000'00000000'00000000'00010000,
			Move            = 0b00000000'00000000'00000000'00100000,
			MakeChannel     = 0b00000000'00000000'00000000'01000000,
			LinkChannel     = 0b00000000'00000000'00000000'10000000,
			Whisper         = 0b00000000'00000000'00000001'00000000,
			TextMessage     = 0b00000000'00000000'00000010'00000000,
			MakeTempChannel = 0b00000000'00000000'00000100'00000000,
			Listen          = 0b00000000'00000000'00001000'00000000,

			// Root channel only
			Kick             = 0b00000000'00000001'00000000'00000000,
			Ban              = 0b00000000'00000010'00000000'00000000,
			Register         = 0b00000000'00000100'00000000'00000000,
			SelfRegister     = 0b00000000'00001000'00000000'00000000,
			ResetUserContent = 0b00000000'00010000'00000000'00000000,

			All = Write + Traverse + Enter + Speak + MuteDeafen + Move + MakeChannel + LinkChannel + Whisper
				  + TextMessage + MakeTempChannel + Listen + Kick + Ban + Register + SelfRegister + ResetUserContent
		};

		Message()          = default;
		virtual ~Message() = default;

		Protocol protocol() const override { return Protocol::TCP; }

		virtual Type type() const = 0;

		static Type type(const Pack &pack) { return static_cast< Type >(Endian::toHost(pack.header().type)); }

		static constexpr std::string_view text(const Type type) {
			switch (type) {
				case Type::Version: {
					return "Version";
				}
				case Type::UDPTunnel: {
					return "UDPTunnel";
				}
				case Type::Authenticate: {
					return "Authenticate";
				}
				case Type::Ping: {
					return "Ping";
				}
				case Type::Reject: {
					return "Reject";
				}
				case Type::ServerSync: {
					return "ServerSync";
				}
				case Type::ChannelRemove: {
					return "ChannelRemove";
				}
				case Type::ChannelState: {
					return "ChannelState";
				}
				case Type::UserRemove: {
					return "UserRemove";
				}
				case Type::UserState: {
					return "UserState";
				}
				case Type::BanList: {
					return "BanList";
				}
				case Type::TextMessage: {
					return "TextMessage";
				}
				case Type::PermissionDenied: {
					return "PermissionDenied";
				}
				case Type::ACL: {
					return "ACL";
				}
				case Type::QueryUsers: {
					return "QueryUsers";
				}
				case Type::CryptSetup: {
					return "CryptSetup";
				}
				case Type::ContextActionModify: {
					return "ContextActionModify";
				}
				case Type::ContextAction: {
					return "ContextAction";
				}
				case Type::UserList: {
					return "UserList";
				}
				case Type::VoiceTarget: {
					return "VoiceTarget";
				}
				case Type::PermissionQuery: {
					return "PermissionQuery";
				}
				case Type::CodecVersion: {
					return "CodecVersion";
				}
				case Type::UserStats: {
					return "UserStats";
				}
				case Type::RequestBlob: {
					return "RequestBlob";
				}
				case Type::ServerConfig: {
					return "ServerConfig";
				}
				case Type::SuggestConfig: {
					return "SuggestConfig";
				}
				case Type::PluginDataTransmission: {
					return "PluginDataTransmission";
				}
			}

			return "";
		}
	};

	MUMBLE_MESSAGE_DECL(Version) {
		mumble::Version version = {};
		std::string release     = {};
		std::string os          = {};
		std::string osVersion   = {};

		MUMBLE_MESSAGE_COMMON(Version)
	};

	MUMBLE_MESSAGE_DECL(UDPTunnel) {
		udp::Pack pack = {};

		MUMBLE_MESSAGE_COMMON(UDPTunnel)
	};

	MUMBLE_MESSAGE_DECL(Authenticate) {
		std::string username                = {};
		std::string password                = {};
		std::vector< std::string > tokens   = {};
		std::vector< int32_t > celtVersions = {};
		bool opus                           = false;

		MUMBLE_MESSAGE_COMMON(Authenticate)
	};

	MUMBLE_MESSAGE_DECL(Ping) {
		uint32_t good       = 0;
		uint32_t late       = 0;
		uint32_t lost       = 0;
		uint32_t resync     = 0;
		uint32_t udpPackets = 0;
		uint32_t tcpPackets = 0;
		float udpPingAvg    = 0.f;
		float udpPingVar    = 0.f;
		float tcpPingAvg    = 0.f;
		float tcpPingVar    = 0.f;

		MUMBLE_MESSAGE_COMMON(Ping)
	};

	MUMBLE_MESSAGE_DECL(Reject) {
		enum RejectType : uint8_t {
			None,
			WrongVersion,
			InvalidUsername,
			WrongUserPW,
			WrongServerPW,
			UsernameInUse,
			ServerFull,
			NoCertificate,
			AuthenticatorFail
		};

		RejectType rejectType = None;
		std::string reason    = {};

		MUMBLE_MESSAGE_COMMON(Reject)
	};

	MUMBLE_MESSAGE_DECL(ServerSync) {
		uint32_t session        = UINT32_MAX;
		uint32_t maxBandwidth   = 0;
		std::string welcomeText = {};
		uint64_t permissions    = 0;

		MUMBLE_MESSAGE_COMMON(ServerSync)
	};

	MUMBLE_MESSAGE_DECL(ChannelRemove) {
		uint32_t channelID = UINT32_MAX;

		MUMBLE_MESSAGE_COMMON(ChannelRemove)
	};

	MUMBLE_MESSAGE_DECL(ChannelState) {
		uint32_t channelID                       = UINT32_MAX;
		std::optional< uint32_t > parent         = {};
		std::string name                         = {};
		std::vector< uint32_t > links            = {};
		std::string description                  = {};
		std::vector< uint32_t > linksAdd         = {};
		std::vector< uint32_t > linksRemove      = {};
		bool temporary                           = false;
		int32_t position                         = 0;
		std::vector< std::byte > descriptionHash = {};
		uint32_t maxUsers                        = 0;
		bool isEnterRestricted                   = false;
		bool canEnter                            = true;

		MUMBLE_MESSAGE_COMMON(ChannelState)
	};

	MUMBLE_MESSAGE_DECL(UserRemove) {
		uint32_t session   = UINT32_MAX;
		uint32_t actor     = UINT32_MAX;
		std::string reason = {};
		bool ban           = false;

		MUMBLE_MESSAGE_COMMON(UserRemove)
	};

	MUMBLE_MESSAGE_DECL(UserState) {
		uint32_t session                                 = UINT32_MAX;
		uint32_t actor                                   = UINT32_MAX;
		std::string name                                 = {};
		std::optional< uint32_t > userID                 = {};
		uint32_t channelID                               = UINT32_MAX;
		bool mute                                        = false;
		bool deaf                                        = false;
		bool suppress                                    = false;
		bool selfMute                                    = false;
		bool selfDeaf                                    = false;
		std::vector< std::byte > texture                 = {};
		std::vector< std::byte > pluginContext           = {};
		std::string pluginIdentity                       = {};
		std::string comment                              = {};
		std::string hash                                 = {};
		std::vector< std::byte > commentHash             = {};
		std::vector< std::byte > textureHash             = {};
		bool prioritySpeaker                             = false;
		bool recording                                   = false;
		std::vector< std::string > temporaryAccessTokens = {};
		std::vector< uint32_t > listeningChannelAdd      = {};
		std::vector< uint32_t > listeningChannelRemove   = {};

		MUMBLE_MESSAGE_COMMON(UserState)
	};

	MUMBLE_MESSAGE_DECL(BanList) {
		struct BanEntry {
			IP address         = {};
			uint32_t mask      = UINT32_MAX;
			std::string name   = {};
			std::string hash   = {};
			std::string reason = {};
			std::string start  = {};
			uint32_t duration  = 0;
		};

		std::vector< BanEntry > bans = {};
		bool query                   = false;

		MUMBLE_MESSAGE_COMMON(BanList)
	};

	MUMBLE_MESSAGE_DECL(TextMessage) {
		uint32_t actor                    = UINT32_MAX;
		std::vector< uint32_t > session   = {};
		std::vector< uint32_t > channelID = {};
		std::vector< uint32_t > treeID    = {};
		std::string message               = {};

		MUMBLE_MESSAGE_COMMON(TextMessage)
	};

	MUMBLE_MESSAGE_DECL(PermissionDenied) {
		enum DenyType : uint8_t {
			Text,
			Permission,
			SuperUser,
			ChannelName,
			TextTooLong,
			H9K,
			TemporaryChannel,
			MissingCertificate,
			UserName,
			ChannelFull,
			NestingLimit,
			ChannelCountLimit,
			ChannelListenerLimit,
			UserListenerLimit
		};

		std::optional< uint32_t > permission = {};
		std::optional< uint32_t > channelID  = {};
		uint32_t session                     = UINT32_MAX;
		std::string reason                   = {};
		DenyType denyType                    = H9K;
		std::optional< std::string > name    = {};

		MUMBLE_MESSAGE_COMMON(PermissionDenied)
	};

	MUMBLE_MESSAGE_DECL(ACL) {
		struct ChanGroup {
			std::string name;
			bool inherited                           = true;
			bool inherit                             = true;
			bool inheritable                         = true;
			std::vector< uint32_t > add              = {};
			std::vector< uint32_t > remove           = {};
			std::vector< uint32_t > inheritedMembers = {};
		};

		struct ChanACL {
			bool applyHere                   = true;
			bool applySubs                   = true;
			bool inherited                   = true;
			std::optional< uint32_t > userID = {};
			std::string group                = {};
			uint32_t grant                   = 0;
			uint32_t deny                    = 0;
		};

		uint32_t channelID              = {};
		bool inheritACLs                = true;
		std::vector< ChanGroup > groups = {};
		std::vector< ChanACL > acls     = {};
		bool query                      = false;

		MUMBLE_MESSAGE_COMMON(ACL)
	};

	MUMBLE_MESSAGE_DECL(QueryUsers) {
		std::vector< uint32_t > ids      = {};
		std::vector< std::string > names = {};

		MUMBLE_MESSAGE_COMMON(QueryUsers)
	};

	MUMBLE_MESSAGE_DECL(CryptSetup) {
		std::vector< std::byte > key         = {};
		std::vector< std::byte > clientNonce = {};
		std::vector< std::byte > serverNonce = {};

		MUMBLE_MESSAGE_COMMON(CryptSetup)
	};

	MUMBLE_MESSAGE_DECL(ContextActionModify) {
		enum Context : uint8_t {
			Server  = 0b00000001,
			Channel = 0b00000010,
			User    = 0b00000100,
		};

		enum Operation : uint8_t { Add, Remove };

		std::string action  = {};
		std::string text    = {};
		uint32_t context    = 0;
		Operation operation = Add;

		MUMBLE_MESSAGE_COMMON(ContextActionModify)
	};

	MUMBLE_MESSAGE_DECL(ContextAction) {
		std::optional< uint32_t > session   = {};
		std::optional< uint32_t > channelID = {};
		std::string action                  = {};

		MUMBLE_MESSAGE_COMMON(ContextAction)
	};

	MUMBLE_MESSAGE_DECL(UserList) {
		struct User {
			uint32_t userID                       = UINT32_MAX;
			std::string name                      = {};
			std::string lastSeen                  = {};
			std::optional< uint32_t > lastChannel = {};
		};

		std::vector< User > users = {};

		MUMBLE_MESSAGE_COMMON(UserList)
	};

	MUMBLE_MESSAGE_DECL(VoiceTarget) {
		struct Target {
			std::vector< uint32_t > session     = {};
			std::optional< uint32_t > channelID = {};
			std::string group                   = {};
			bool links                          = false;
			bool children                       = false;
		};

		uint32_t id                   = UINT32_MAX;
		std::vector< Target > targets = {};

		MUMBLE_MESSAGE_COMMON(VoiceTarget)
	};

	MUMBLE_MESSAGE_DECL(PermissionQuery) {
		uint32_t channelID   = UINT32_MAX;
		uint32_t permissions = 0;
		bool flush           = false;

		MUMBLE_MESSAGE_COMMON(PermissionQuery)
	};

	MUMBLE_MESSAGE_DECL(CodecVersion) {
		int32_t alpha    = 0;
		int32_t beta     = 0;
		bool preferAlpha = true;
		bool opus        = false;

		MUMBLE_MESSAGE_COMMON(CodecVersion)
	};

	MUMBLE_MESSAGE_DECL(UserStats) {
		struct Stats {
			uint32_t good   = 0;
			uint32_t late   = 0;
			uint32_t lost   = 0;
			uint32_t resync = 0;
		};

		uint32_t session         = UINT32_MAX;
		bool statsOnly           = false;
		Cert::Chain certificates = {};
		Stats fromClient         = {};
		Stats fromServer         = {};

		uint32_t udpPackets = 0;
		uint32_t tcpPackets = 0;
		float udpPingAvg    = 0;
		float udpPingVar    = 0;
		float tcpPingAvg    = 0;
		float tcpPingVar    = 0;

		mumble::tcp::Message::Version version = {};
		std::vector< int32_t > celtVersions   = {};
		IP address                            = {};
		uint32_t bandwidth                    = 0;
		uint32_t onlinesecs                   = 0;
		uint32_t idlesecs                     = 0;
		bool strongCertificate                = false;
		bool opus                             = false;

		MUMBLE_MESSAGE_COMMON(UserStats)
	};

	MUMBLE_MESSAGE_DECL(RequestBlob) {
		std::vector< uint32_t > sessionTexture     = {};
		std::vector< uint32_t > sessionComment     = {};
		std::vector< uint32_t > channelDescription = {};

		MUMBLE_MESSAGE_COMMON(RequestBlob)
	};

	MUMBLE_MESSAGE_DECL(ServerConfig) {
		uint32_t maxBandwidth       = 0;
		std::string welcomeText     = {};
		bool allowHTML              = false;
		uint32_t messageLength      = 0;
		uint32_t imageMessageLength = 0;
		uint32_t maxUsers           = 0;
		bool recordingAllowed       = false;

		MUMBLE_MESSAGE_COMMON(ServerConfig)
	};

	MUMBLE_MESSAGE_DECL(SuggestConfig) {
		std::optional< mumble::Version > version = {};
		std::optional< bool > positional         = {};
		std::optional< bool > pushToTalk         = {};

		MUMBLE_MESSAGE_COMMON(SuggestConfig)
	};

	MUMBLE_MESSAGE_DECL(PluginDataTransmission) {
		uint32_t senderSession                   = UINT32_MAX;
		std::vector< uint32_t > receiverSessions = {};
		std::vector< std::byte > data            = {};
		std::string dataID                       = {};

		MUMBLE_MESSAGE_COMMON(PluginDataTransmission)
	};
} // namespace tcp
} // namespace mumble

MUMBLE_ENUM_OPERATORS(mumble::tcp::Message::Perm)

#endif
