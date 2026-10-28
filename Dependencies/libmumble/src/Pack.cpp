// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#include "mumble/Pack.hpp"

#include "mumble/Cert.hpp"
#include "mumble/Endian.hpp"
#include "mumble/IP.hpp"
#include "mumble/Message.hpp"
#include "mumble/Types.hpp"

#include "MumbleTCP.pb.h"
#include "MumbleUDP.pb.h"

#include <algorithm>
#include <cassert>
#include <cstdint>
#include <cstring>
#include <limits>
#include <optional>
#include <span>
#include <string>
#include <vector>

#include <google/protobuf/descriptor.h>
#include <google/protobuf/message.h>

#define SET_BUF_AND_BREAK                          \
	*this = std::move(Pack(proto, extraDataSize)); \
	break;

#define PARSE_PROTO_MESSAGE(msg, data, size)                               \
	assert(static_cast< int >(size) <= std::numeric_limits< int >::max()); \
	if (!msg.ParseFromArray(data, static_cast< int >(size))) {             \
		return false;                                                      \
	}

using namespace mumble;

using TCP = tcp::Pack;
using UDP = udp::Pack;

TCP::Pack(const NetHeader &header, const uint32_t extraDataSize)
	: mumble::Pack< NetHeader >(Endian::toHost(header.size) + extraDataSize) {
	memcpy(m_buf.data(), &header, sizeof(header));
}

UDP::Pack(const NetHeader &header, const uint32_t dataSize) : mumble::Pack< NetHeader >(dataSize) {
	memcpy(m_buf.data(), &header, sizeof(header));
}

TCP::Pack(const google::protobuf::Message &proto, const uint32_t extraDataSize)
	: mumble::Pack< NetHeader >(proto.ByteSizeLong() + extraDataSize) {
	auto buf = data();
	if (proto.SerializeToArray(buf.data(), static_cast< int >(buf.size() - extraDataSize))) {
		header().type = Endian::toNetwork(static_cast< uint16_t >(proto.GetDescriptor()->index()));
		header().size = Endian::toNetwork(static_cast< uint32_t >(buf.size() - extraDataSize));
	}
}

UDP::Pack(const google::protobuf::Message &proto, const uint32_t extraDataSize)
	: mumble::Pack< NetHeader >(proto.ByteSizeLong() + extraDataSize) {
	auto buf = data();
	if (proto.SerializeToArray(buf.data(), static_cast< int >(buf.size() - extraDataSize))) {
		header().type = static_cast< uint8_t >(proto.GetDescriptor()->index());
	}
}

TCP::Pack(const Message &message, const uint32_t extraDataSize) {
	using Type = Message::Type;

	switch (message.type()) {
		case Type::Version: {
			auto &msg = static_cast< const Message::Version & >(message);

			MumbleTCP::Version proto;
			proto.set_version_v1(msg.version.blob32());
			proto.set_version_v2(msg.version.blob64());
			proto.set_release(msg.release);
			proto.set_os(msg.os);
			proto.set_os_version(msg.osVersion);

			SET_BUF_AND_BREAK
		}
		case Type::UDPTunnel: {
			auto &msg = static_cast< const Message::UDPTunnel & >(message);

			auto &pack = msg.pack;

			const NetHeader header = { Endian::toNetwork(static_cast< uint16_t >(Type::UDPTunnel)),
									   Endian::toNetwork(static_cast< uint32_t >(pack.buf().size())) };

			*this = Pack(header, extraDataSize);

			std::copy(pack.buf().begin(), pack.buf().end(), data().begin());

			break;
		}
		case Type::Authenticate: {
			auto &msg = static_cast< const Message::Authenticate & >(message);

			MumbleTCP::Authenticate proto;
			proto.set_username(msg.username);
			proto.set_password(msg.password);
			for (const auto &token : msg.tokens) {
				proto.add_tokens(token);
			}
			for (const auto version : msg.celtVersions) {
				proto.add_celt_versions(version);
			}
			proto.set_opus(msg.opus);

			SET_BUF_AND_BREAK
		}
		case Type::Ping: {
			auto &msg = static_cast< const Message::Ping & >(message);

			MumbleTCP::Ping proto;
			std::int64_t timestamp =
				std::chrono::duration_cast< std::chrono::nanoseconds >(msg.timestamp.time_since_epoch()).count();
			assert(timestamp >= 0);
			proto.set_timestamp(static_cast< std::uint64_t >(timestamp));

			proto.set_good(msg.good);
			proto.set_late(msg.late);
			proto.set_lost(msg.lost);
			proto.set_resync(msg.resync);
			proto.set_udp_packets(msg.udpPackets);
			proto.set_tcp_packets(msg.tcpPackets);
			proto.set_udp_ping_avg(msg.udpPingAvg);
			proto.set_udp_ping_var(msg.udpPingVar);
			proto.set_tcp_ping_avg(msg.tcpPingAvg);
			proto.set_tcp_ping_var(msg.tcpPingVar);

			SET_BUF_AND_BREAK
		}
		case Type::Reject: {
			auto &msg = static_cast< const Message::Reject & >(message);

			MumbleTCP::Reject proto;
			proto.set_type(static_cast< decltype(proto)::RejectType >(msg.rejectType));
			proto.set_reason(msg.reason);

			SET_BUF_AND_BREAK
		}
		case Type::ServerSync: {
			auto &msg = static_cast< const Message::ServerSync & >(message);

			MumbleTCP::ServerSync proto;
			proto.set_session(msg.session);
			proto.set_max_bandwidth(msg.maxBandwidth);
			proto.set_welcome_text(msg.welcomeText);
			proto.set_permissions(msg.permissions);

			SET_BUF_AND_BREAK
		}
		case Type::ChannelRemove: {
			auto &msg = static_cast< const Message::ChannelRemove & >(message);

			MumbleTCP::ChannelRemove proto;
			proto.set_channel_id(msg.channelID);

			SET_BUF_AND_BREAK
		}
		case Type::ChannelState: {
			auto &msg = static_cast< const Message::ChannelState & >(message);

			MumbleTCP::ChannelState proto;
			proto.set_channel_id(msg.channelID);
			if (msg.parent) {
				proto.set_parent(msg.parent.value());
			}
			proto.set_name(msg.name);
			for (const auto link : msg.links) {
				proto.add_links(link);
			}
			proto.set_description(msg.description);
			for (const auto link : msg.linksAdd) {
				proto.add_links_add(link);
			}
			for (const auto link : msg.linksRemove) {
				proto.add_links_remove(link);
			}
			proto.set_temporary(msg.temporary);
			proto.set_position(msg.position);
			proto.set_description_hash(msg.descriptionHash.data(), msg.descriptionHash.size());
			proto.set_max_users(msg.maxUsers);
			proto.set_is_enter_restricted(msg.isEnterRestricted);
			proto.set_can_enter(msg.canEnter);

			SET_BUF_AND_BREAK
		}
		case Type::UserRemove: {
			auto &msg = static_cast< const Message::UserRemove & >(message);

			MumbleTCP::UserRemove proto;
			proto.set_session(msg.session);
			proto.set_actor(msg.actor);
			proto.set_reason(msg.reason);
			proto.set_ban(msg.ban);

			SET_BUF_AND_BREAK
		}
		case Type::UserState: {
			auto &msg = static_cast< const Message::UserState & >(message);

			MumbleTCP::UserState proto;
			proto.set_session(msg.session);
			proto.set_actor(msg.actor);
			proto.set_name(msg.name);
			if (msg.userID) {
				proto.set_user_id(msg.userID.value());
			}
			proto.set_channel_id(msg.channelID);
			proto.set_mute(msg.mute);
			proto.set_deaf(msg.deaf);
			proto.set_suppress(msg.suppress);
			proto.set_self_mute(msg.selfMute);
			proto.set_self_deaf(msg.selfDeaf);
			proto.set_texture(msg.texture.data(), msg.texture.size());
			proto.set_plugin_context(msg.pluginContext.data(), msg.pluginContext.size());
			proto.set_plugin_identity(msg.pluginIdentity);
			proto.set_comment(msg.comment);
			proto.set_hash(msg.hash);
			proto.set_comment_hash(msg.commentHash.data(), msg.commentHash.size());
			proto.set_texture_hash(msg.textureHash.data(), msg.textureHash.size());
			proto.set_priority_speaker(msg.prioritySpeaker);
			proto.set_recording(msg.recording);
			for (const auto &token : msg.temporaryAccessTokens) {
				proto.add_temporary_access_tokens(token);
			}
			for (const auto channel : msg.listeningChannelAdd) {
				proto.add_listening_channel_add(channel);
			}
			for (const auto channel : msg.listeningChannelRemove) {
				proto.add_listening_channel_remove(channel);
			}

			SET_BUF_AND_BREAK
		}
		case Type::BanList: {
			auto &msg = static_cast< const Message::BanList & >(message);

			MumbleTCP::BanList proto;
			for (const auto &ban : msg.bans) {
				auto entry      = proto.add_bans();
				const auto ipv6 = ban.address.v6();
				entry->set_address(ipv6.data(), ipv6.size());
				entry->set_mask(ban.mask);
				entry->set_name(ban.name);
				entry->set_hash(ban.hash);
				entry->set_reason(ban.reason);
				entry->set_start(ban.start);
				entry->set_duration(ban.duration);
			}
			proto.set_query(msg.query);

			SET_BUF_AND_BREAK
		}
		case Type::TextMessage: {
			auto &msg = static_cast< const Message::TextMessage & >(message);

			MumbleTCP::TextMessage proto;
			proto.set_actor(msg.actor);
			for (const auto session : msg.session) {
				proto.add_session(session);
			}
			for (const auto channel : msg.channelID) {
				proto.add_channel_id(channel);
			}
			for (const auto tree : msg.treeID) {
				proto.add_tree_id(tree);
			}
			proto.set_message(msg.message);

			SET_BUF_AND_BREAK
		}
		case Type::PermissionDenied: {
			auto &msg = static_cast< const Message::PermissionDenied & >(message);

			MumbleTCP::PermissionDenied proto;
			if (msg.permission) {
				proto.set_permission(msg.permission.value());
			}
			if (msg.channelID) {
				proto.set_channel_id(msg.channelID.value());
			}
			proto.set_session(msg.session);
			proto.set_reason(msg.reason);
			proto.set_type(static_cast< decltype(proto)::DenyType >(msg.denyType));
			if (msg.name) {
				proto.set_name(msg.name.value());
			}

			SET_BUF_AND_BREAK
		}
		case Type::ACL: {
			auto &msg = static_cast< const Message::ACL & >(message);

			MumbleTCP::ACL proto;
			proto.set_channel_id(msg.channelID);
			proto.set_inherit_acls(msg.inheritACLs);
			for (const auto &group : msg.groups) {
				auto entry = proto.add_groups();
				entry->set_name(group.name);
				entry->set_inherited(group.inherited);
				entry->set_inherit(group.inherit);
				entry->set_inheritable(group.inheritable);
				for (auto add : group.add) {
					entry->add_add(add);
				}
				for (auto remove : group.remove) {
					entry->add_remove(remove);
				}
				for (auto member : group.inheritedMembers) {
					entry->add_inherited_members(member);
				}
			}
			for (const auto &acl : msg.acls) {
				auto entry = proto.add_acls();
				entry->set_apply_here(acl.applyHere);
				entry->set_apply_subs(acl.applySubs);
				entry->set_inherited(acl.inherited);
				if (acl.userID) {
					entry->set_user_id(acl.userID.value());
				}
				entry->set_group(acl.group);
				entry->set_grant(acl.grant);
				entry->set_deny(acl.deny);
			}
			proto.set_query(msg.query);

			SET_BUF_AND_BREAK
		}
		case Type::QueryUsers: {
			auto &msg = static_cast< const Message::QueryUsers & >(message);

			MumbleTCP::QueryUsers proto;
			for (const auto id : msg.ids) {
				proto.add_ids(id);
			}
			for (const auto &name : msg.names) {
				proto.add_names(name);
			}

			SET_BUF_AND_BREAK
		}
		case Type::CryptSetup: {
			auto &msg = static_cast< const Message::CryptSetup & >(message);

			MumbleTCP::CryptSetup proto;

			if (!msg.key.empty()) {
				proto.set_key(msg.key.data(), msg.key.size());
			}

			if (!msg.clientNonce.empty()) {
				proto.set_client_nonce(msg.clientNonce.data(), msg.clientNonce.size());
			}

			if (!msg.serverNonce.empty()) {
				proto.set_server_nonce(msg.serverNonce.data(), msg.serverNonce.size());
			}

			SET_BUF_AND_BREAK
		}
		case Type::ContextActionModify: {
			auto &msg = static_cast< const Message::ContextActionModify & >(message);

			MumbleTCP::ContextActionModify proto;
			proto.set_action(msg.action);
			proto.set_text(msg.text);
			proto.set_context(msg.context);
			proto.set_operation(static_cast< decltype(proto)::Operation >(msg.operation));

			SET_BUF_AND_BREAK
		}
		case Type::ContextAction: {
			auto &msg = static_cast< const Message::ContextAction & >(message);

			MumbleTCP::ContextAction proto;
			if (msg.session) {
				proto.set_session(msg.session.value());
			}
			if (msg.channelID) {
				proto.set_channel_id(msg.channelID.value());
			}
			proto.set_action(msg.action);

			SET_BUF_AND_BREAK
		}
		case Type::UserList: {
			auto &msg = static_cast< const Message::UserList & >(message);

			MumbleTCP::UserList proto;
			for (const auto &user : msg.users) {
				auto entry = proto.add_users();
				entry->set_user_id(user.userID);
				entry->set_name(user.name);
				entry->set_last_seen(user.lastSeen);
				if (user.lastChannel) {
					entry->set_last_channel(user.lastChannel.value());
				}
			}

			SET_BUF_AND_BREAK
		}
		case Type::VoiceTarget: {
			auto &msg = static_cast< const Message::VoiceTarget & >(message);

			MumbleTCP::VoiceTarget proto;
			proto.set_id(msg.id);
			for (const auto &target : msg.targets) {
				auto entry = proto.add_targets();
				for (const auto session : target.session) {
					entry->add_session(session);
				}
				if (target.channelID) {
					entry->set_channel_id(target.channelID.value());
				}
				entry->set_group(target.group);
				entry->set_links(target.links);
				entry->set_children(target.children);
			}

			SET_BUF_AND_BREAK
		}
		case Type::PermissionQuery: {
			auto &msg = static_cast< const Message::PermissionQuery & >(message);

			MumbleTCP::PermissionQuery proto;
			proto.set_channel_id(msg.channelID);
			proto.set_permissions(msg.permissions);
			proto.set_flush(msg.flush);

			SET_BUF_AND_BREAK
		}
		case Type::CodecVersion: {
			auto &msg = static_cast< const Message::CodecVersion & >(message);

			MumbleTCP::CodecVersion proto;
			proto.set_alpha(msg.alpha);
			proto.set_beta(msg.beta);
			proto.set_prefer_alpha(msg.preferAlpha);
			proto.set_opus(msg.opus);

			SET_BUF_AND_BREAK
		}
		case Type::UserStats: {
			auto &msg = static_cast< const Message::UserStats & >(message);

			MumbleTCP::UserStats proto;
			proto.set_session(msg.session);
			proto.set_stats_only(msg.statsOnly);
			for (const auto &cert : msg.certificates) {
				const auto der = cert.der();
				proto.add_certificates(der.data(), der.size());
			}
			auto stats = proto.mutable_from_client();
			stats->set_good(msg.fromClient.good);
			stats->set_late(msg.fromClient.late);
			stats->set_lost(msg.fromClient.lost);
			stats->set_resync(msg.fromClient.resync);

			stats = proto.mutable_from_server();
			stats->set_good(msg.fromServer.good);
			stats->set_late(msg.fromServer.late);
			stats->set_lost(msg.fromServer.lost);
			stats->set_resync(msg.fromServer.resync);

			proto.set_udp_packets(msg.udpPackets);
			proto.set_tcp_packets(msg.tcpPackets);
			proto.set_udp_ping_avg(msg.udpPingAvg);
			proto.set_udp_ping_var(msg.udpPingVar);
			proto.set_tcp_ping_avg(msg.tcpPingAvg);
			proto.set_tcp_ping_var(msg.tcpPingVar);

			auto version = proto.mutable_version();
			version->set_version_v1(msg.version.version.blob32());
			version->set_version_v2(msg.version.version.blob64());
			version->set_release(msg.version.release);
			version->set_os(msg.version.os);
			version->set_os_version(msg.version.osVersion);

			for (auto ver : msg.celtVersions) {
				proto.add_celt_versions(ver);
			}
			const auto ipv6 = msg.address.v6();
			proto.set_address(ipv6.data(), ipv6.size());
			proto.set_bandwidth(msg.bandwidth);
			proto.set_onlinesecs(msg.onlinesecs);
			proto.set_idlesecs(msg.idlesecs);
			proto.set_strong_certificate(msg.strongCertificate);
			proto.set_opus(msg.opus);

			SET_BUF_AND_BREAK
		}
		case Type::RequestBlob: {
			auto &msg = static_cast< const Message::RequestBlob & >(message);

			MumbleTCP::RequestBlob proto;
			for (const auto texture : msg.sessionTexture) {
				proto.add_session_texture(texture);
			}
			for (const auto comment : msg.sessionComment) {
				proto.add_session_comment(comment);
			}
			for (const auto description : msg.channelDescription) {
				proto.add_channel_description(description);
			}

			SET_BUF_AND_BREAK
		}
		case Type::ServerConfig: {
			auto &msg = static_cast< const Message::ServerConfig & >(message);

			MumbleTCP::ServerConfig proto;
			proto.set_max_bandwidth(msg.maxBandwidth);
			proto.set_welcome_text(msg.welcomeText);
			proto.set_allow_html(msg.allowHTML);
			proto.set_message_length(msg.messageLength);
			proto.set_image_message_length(msg.imageMessageLength);
			proto.set_max_users(msg.maxUsers);
			proto.set_recording_allowed(msg.recordingAllowed);

			SET_BUF_AND_BREAK
		}
		case Type::SuggestConfig: {
			auto &msg = static_cast< const Message::SuggestConfig & >(message);

			MumbleTCP::SuggestConfig proto;
			if (msg.version && msg.version.value().isValid()) {
				proto.set_version_v1(msg.version.value().blob32());
				proto.set_version_v2(msg.version.value().blob64());
			}
			if (msg.positional) {
				proto.set_positional(msg.positional.value());
			}
			if (msg.pushToTalk) {
				proto.set_push_to_talk(msg.pushToTalk.value());
			}

			SET_BUF_AND_BREAK
		}
		case Type::PluginDataTransmission: {
			auto &msg = static_cast< const Message::PluginDataTransmission & >(message);

			MumbleTCP::PluginDataTransmission proto;
			proto.set_sendersession(msg.senderSession);
			for (const auto session : msg.receiverSessions) {
				proto.add_receiversessions(session);
			}
			proto.set_data(msg.data.data(), msg.data.size());
			proto.set_dataid(msg.dataID);

			SET_BUF_AND_BREAK
		}
	}
}

UDP::Pack(const Message &message, const uint32_t extraDataSize) {
	using Type = Message::Type;

	switch (message.type()) {
		case Type::Audio: {
			auto &msg = static_cast< const Message::Audio & >(message);

			MumbleUDP::Audio proto;
			switch (msg.direction) {
				case Message::Audio::ClientToServer:
					proto.set_target(msg.target);
					break;
				case Message::Audio::ServerToClient:
					proto.set_context(msg.context);
					break;
				case Message::Audio::Unknown:
					break;
			}

			if (msg.senderSession) {
				proto.set_sender_session(msg.senderSession.value());
			}

			proto.set_frame_number(msg.frameNumber);
			proto.set_opus_data(msg.opusData.data(), msg.opusData.size());
			for (const auto data : msg.positionalData) {
				proto.add_positional_data(data);
			}

			proto.set_volume_adjustment(msg.volumeAdjustment);

			proto.set_is_terminator(msg.isTerminator);

			SET_BUF_AND_BREAK
		}
		case Type::Ping: {
			auto &msg = static_cast< const Message::Ping & >(message);

			MumbleUDP::Ping proto;
			std::int64_t timestamp =
				std::chrono::duration_cast< std::chrono::nanoseconds >(msg.timestamp.time_since_epoch()).count();
			assert(timestamp >= 0);
			proto.set_timestamp(static_cast< std::uint64_t >(timestamp));

			proto.set_request_extended_information(msg.requestExtendedInformation);

			if (msg.version && msg.version.value().isValid()) {
				proto.set_server_version_v2(msg.version.value().blob64());
			}
			if (msg.userCount) {
				proto.set_user_count(msg.userCount.value());
			}
			if (msg.maxUserCount) {
				proto.set_max_user_count(msg.maxUserCount.value());
			}
			if (msg.maxBandwidthPerUser) {
				proto.set_max_bandwidth_per_user(msg.maxBandwidthPerUser.value());
			}

			SET_BUF_AND_BREAK
		}
	}
}

TCP::~Pack() = default;
UDP::~Pack() = default;

bool TCP::operator()(Message &message, uint32_t dataSize) const {
	using Type = Message::Type;

	if (message.type() != Message::type(*this)) {
		return false;
	}

	if (dataSize > data().size()) {
		dataSize = static_cast< decltype(dataSize) >(data().size());
	}

	switch (message.type()) {
		case Type::Version: {
			MumbleTCP::Version proto;
			PARSE_PROTO_MESSAGE(proto, data().data(), dataSize)

			auto &msg = static_cast< Message::Version & >(message);
			if (proto.has_version_v2()) {
				msg.version = mumble::Version(proto.version_v2());
			} else {
				msg.version = mumble::Version(proto.version_v1());
			}
			msg.release   = proto.release();
			msg.os        = proto.os();
			msg.osVersion = proto.os_version();

			return true;
		}
		case Type::UDPTunnel: {
			auto &msg = static_cast< Message::UDPTunnel & >(message);

			if (dataSize < sizeof(udp::NetHeader)) {
				msg.pack = std::move(udp::Pack());
				break;
			}

			auto packet = data();

			auto &header = *reinterpret_cast< const udp::NetHeader * >(packet.data());
			msg.pack     = std::move(udp::Pack(header, dataSize - static_cast< decltype(dataSize) >(sizeof(header))));

			packet = packet.subspan(sizeof(header));

			std::copy(packet.begin(), packet.end(), msg.pack.data().begin());

			return true;
		}
		case Type::Authenticate: {
			MumbleTCP::Authenticate proto;
			PARSE_PROTO_MESSAGE(proto, data().data(), dataSize)

			auto &msg    = static_cast< Message::Authenticate & >(message);
			msg.username = proto.username();
			msg.password = proto.password();
			for (const auto &token : proto.tokens()) {
				msg.tokens.push_back(token);
			}
			for (const auto version : proto.celt_versions()) {
				msg.celtVersions.push_back(version);
			}
			msg.opus = proto.opus();

			return true;
		}
		case Type::Ping: {
			MumbleTCP::Ping proto;
			PARSE_PROTO_MESSAGE(proto, data().data(), dataSize)

			auto &msg      = static_cast< Message::Ping & >(message);
			msg.timestamp  = Message::Timestamp(std::chrono::nanoseconds(proto.timestamp()));
			msg.good       = proto.good();
			msg.late       = proto.late();
			msg.lost       = proto.lost();
			msg.resync     = proto.resync();
			msg.udpPackets = proto.udp_packets();
			msg.tcpPackets = proto.tcp_packets();
			msg.udpPingAvg = proto.udp_ping_avg();
			msg.udpPingVar = proto.udp_ping_var();
			msg.tcpPingAvg = proto.tcp_ping_avg();
			msg.tcpPingVar = proto.tcp_ping_var();

			return true;
		}
		case Type::Reject: {
			MumbleTCP::Reject proto;
			PARSE_PROTO_MESSAGE(proto, data().data(), dataSize)

			auto &msg      = static_cast< Message::Reject & >(message);
			msg.rejectType = static_cast< Message::Reject::RejectType >(proto.type());
			msg.reason     = proto.reason();

			return true;
		}
		case Type::ServerSync: {
			MumbleTCP::ServerSync proto;
			PARSE_PROTO_MESSAGE(proto, data().data(), dataSize)

			auto &msg        = static_cast< Message::ServerSync & >(message);
			msg.session      = proto.session();
			msg.maxBandwidth = proto.max_bandwidth();
			msg.welcomeText  = proto.welcome_text();
			msg.permissions  = proto.permissions();

			return true;
		}
		case Type::ChannelRemove: {
			MumbleTCP::ChannelRemove proto;
			PARSE_PROTO_MESSAGE(proto, data().data(), dataSize)

			auto &msg     = static_cast< Message::ChannelRemove & >(message);
			msg.channelID = proto.channel_id();

			return true;
		}
		case Type::ChannelState: {
			MumbleTCP::ChannelState proto;
			PARSE_PROTO_MESSAGE(proto, data().data(), dataSize)

			auto &msg     = static_cast< Message::ChannelState & >(message);
			msg.channelID = proto.channel_id();
			if (proto.has_parent()) {
				msg.parent = proto.parent();
			}
			msg.name = proto.name();
			for (const auto link : proto.links()) {
				msg.links.push_back(link);
			}
			msg.description = proto.description();
			for (const auto link : proto.links_add()) {
				msg.linksAdd.push_back(link);
			}
			for (const auto link : proto.links_remove()) {
				msg.linksRemove.push_back(link);
			}
			msg.temporary = proto.temporary();
			msg.position  = proto.position();
			toBuf(msg.descriptionHash, proto.description_hash());
			msg.maxUsers          = proto.max_users();
			msg.isEnterRestricted = proto.is_enter_restricted();
			msg.canEnter          = proto.can_enter();

			return true;
		}
		case Type::UserRemove: {
			MumbleTCP::UserRemove proto;
			PARSE_PROTO_MESSAGE(proto, data().data(), dataSize)

			auto &msg   = static_cast< Message::UserRemove & >(message);
			msg.session = proto.session();
			msg.actor   = proto.actor();
			msg.reason  = proto.reason();
			msg.ban     = proto.ban();

			return true;
		}
		case Type::UserState: {
			MumbleTCP::UserState proto;
			PARSE_PROTO_MESSAGE(proto, data().data(), dataSize)

			auto &msg     = static_cast< Message::UserState & >(message);
			msg.session   = proto.session();
			msg.actor     = proto.actor();
			msg.name      = proto.name();
			msg.userID    = proto.user_id();
			msg.channelID = proto.channel_id();
			msg.mute      = proto.mute();
			msg.deaf      = proto.deaf();
			msg.suppress  = proto.suppress();
			msg.selfMute  = proto.self_mute();
			msg.selfDeaf  = proto.self_deaf();
			toBuf(msg.texture, proto.texture());
			toBuf(msg.pluginContext, proto.plugin_context());
			msg.pluginIdentity = proto.plugin_identity();
			msg.comment        = proto.comment();
			msg.hash           = proto.hash();
			toBuf(msg.commentHash, proto.comment_hash());
			toBuf(msg.textureHash, proto.texture_hash());
			msg.prioritySpeaker = proto.priority_speaker();
			msg.recording       = proto.recording();
			for (const auto &token : proto.temporary_access_tokens()) {
				msg.temporaryAccessTokens.push_back(token);
			}
			for (const auto channel : proto.listening_channel_add()) {
				msg.listeningChannelAdd.push_back(channel);
			}
			for (const auto channel : proto.listening_channel_remove()) {
				msg.listeningChannelRemove.push_back(channel);
			}

			return true;
		}
		case Type::BanList: {
			MumbleTCP::BanList proto;
			PARSE_PROTO_MESSAGE(proto, data().data(), dataSize)

			auto &msg = static_cast< Message::BanList & >(message);
			for (const auto &ban : proto.bans()) {
				auto &entry    = msg.bans.emplace_back();
				entry.address  = IP(ban.address());
				entry.mask     = ban.mask();
				entry.name     = ban.name();
				entry.hash     = ban.hash();
				entry.reason   = ban.reason();
				entry.start    = ban.start();
				entry.duration = ban.duration();
			}
			msg.query = proto.query();

			return true;
		}
		case Type::TextMessage: {
			MumbleTCP::TextMessage proto;
			PARSE_PROTO_MESSAGE(proto, data().data(), dataSize)

			auto &msg = static_cast< Message::TextMessage & >(message);
			msg.actor = proto.actor();
			for (const auto session : proto.session()) {
				msg.session.push_back(session);
			}
			for (const auto channel : proto.channel_id()) {
				msg.channelID.push_back(channel);
			}
			for (const auto tree : proto.tree_id()) {
				msg.treeID.push_back(tree);
			}
			msg.message = proto.message();

			return true;
		}
		case Type::PermissionDenied: {
			MumbleTCP::PermissionDenied proto;
			PARSE_PROTO_MESSAGE(proto, data().data(), dataSize)

			auto &msg = static_cast< Message::PermissionDenied & >(message);
			if (proto.has_permission()) {
				msg.permission = proto.permission();
			}
			if (proto.has_channel_id()) {
				msg.channelID = proto.channel_id();
			}
			msg.session  = proto.session();
			msg.reason   = proto.reason();
			msg.denyType = static_cast< Message::PermissionDenied::DenyType >(proto.type());
			if (proto.has_name()) {
				msg.name = proto.name();
			}

			return true;
		}
		case Type::ACL: {
			MumbleTCP::ACL proto;
			PARSE_PROTO_MESSAGE(proto, data().data(), dataSize)

			auto &msg       = static_cast< Message::ACL & >(message);
			msg.channelID   = proto.channel_id();
			msg.inheritACLs = proto.inherit_acls();
			for (const auto &group : proto.groups()) {
				auto &entry       = msg.groups.emplace_back();
				entry.name        = group.name();
				entry.inherited   = group.inherited();
				entry.inherit     = group.inherit();
				entry.inheritable = group.inheritable();
				for (const auto add : group.add()) {
					entry.add.push_back(add);
				}
				for (const auto remove : group.remove()) {
					entry.remove.push_back(remove);
				}
				for (const auto member : group.inherited_members()) {
					entry.inheritedMembers.push_back(member);
				}
			}
			for (const auto &acl : proto.acls()) {
				auto &entry     = msg.acls.emplace_back();
				entry.applyHere = acl.apply_here();
				entry.applySubs = acl.apply_subs();
				entry.inherited = acl.inherited();
				if (acl.has_user_id()) {
					entry.userID = acl.user_id();
				}
				entry.group = acl.group();
				entry.grant = acl.grant();
				entry.deny  = acl.deny();
			}
			msg.query = proto.query();

			return true;
		}
		case Type::QueryUsers: {
			MumbleTCP::QueryUsers proto;
			PARSE_PROTO_MESSAGE(proto, data().data(), dataSize)

			auto &msg = static_cast< Message::QueryUsers & >(message);
			for (const auto id : proto.ids()) {
				msg.ids.push_back(id);
			}
			for (const auto &name : proto.names()) {
				msg.names.push_back(name);
			}

			return true;
		}
		case Type::CryptSetup: {
			MumbleTCP::CryptSetup proto;
			PARSE_PROTO_MESSAGE(proto, data().data(), dataSize)

			auto &msg = static_cast< Message::CryptSetup & >(message);

			if (proto.has_key()) {
				toBuf(msg.key, proto.key());
			}

			if (proto.has_client_nonce()) {
				toBuf(msg.clientNonce, proto.client_nonce());
			}

			if (proto.has_server_nonce()) {
				toBuf(msg.serverNonce, proto.server_nonce());
			}

			return true;
		}
		case Type::ContextActionModify: {
			MumbleTCP::ContextActionModify proto;
			PARSE_PROTO_MESSAGE(proto, data().data(), dataSize)

			auto &msg     = static_cast< Message::ContextActionModify & >(message);
			msg.action    = proto.action();
			msg.text      = proto.text();
			msg.context   = proto.context();
			msg.operation = static_cast< Message::ContextActionModify::Operation >(proto.operation());

			return true;
		}
		case Type::ContextAction: {
			MumbleTCP::ContextAction proto;
			PARSE_PROTO_MESSAGE(proto, data().data(), dataSize)

			auto &msg = static_cast< Message::ContextAction & >(message);
			if (proto.has_session()) {
				msg.session = proto.session();
			}
			if (proto.has_channel_id()) {
				msg.channelID = proto.channel_id();
			}
			msg.action = proto.action();

			return true;
		}
		case Type::UserList: {
			MumbleTCP::UserList proto;
			PARSE_PROTO_MESSAGE(proto, data().data(), dataSize)

			auto &msg = static_cast< Message::UserList & >(message);
			for (const auto &user : proto.users()) {
				auto &entry       = msg.users.emplace_back();
				entry.userID      = user.user_id();
				entry.name        = user.name();
				entry.lastSeen    = user.last_seen();
				entry.lastChannel = user.last_channel();
			}

			return true;
		}
		case Type::VoiceTarget: {
			MumbleTCP::VoiceTarget proto;
			PARSE_PROTO_MESSAGE(proto, data().data(), dataSize)

			auto &msg = static_cast< Message::VoiceTarget & >(message);
			msg.id    = proto.id();
			for (const auto &target : proto.targets()) {
				auto &entry = msg.targets.emplace_back();
				for (const auto session : target.session()) {
					entry.session.push_back(session);
				}
				if (target.has_channel_id()) {
					entry.channelID = target.channel_id();
				}
				entry.group    = target.group();
				entry.links    = target.links();
				entry.children = target.children();
			}

			return true;
		}
		case Type::PermissionQuery: {
			MumbleTCP::PermissionQuery proto;
			PARSE_PROTO_MESSAGE(proto, data().data(), dataSize)

			auto &msg       = static_cast< Message::PermissionQuery & >(message);
			msg.channelID   = proto.channel_id();
			msg.permissions = proto.permissions();
			msg.flush       = proto.flush();

			return true;
		}
		case Type::CodecVersion: {
			MumbleTCP::CodecVersion proto;
			PARSE_PROTO_MESSAGE(proto, data().data(), dataSize)

			auto &msg       = static_cast< Message::CodecVersion & >(message);
			msg.alpha       = proto.alpha();
			msg.beta        = proto.beta();
			msg.preferAlpha = proto.prefer_alpha();
			msg.opus        = proto.opus();

			return true;
		}
		case Type::UserStats: {
			MumbleTCP::UserStats proto;
			PARSE_PROTO_MESSAGE(proto, data().data(), dataSize)

			auto &msg     = static_cast< Message::UserStats & >(message);
			msg.session   = proto.session();
			msg.statsOnly = proto.stats_only();
			for (const auto &cert : proto.certificates()) {
				Cert::Der der;
				toBuf(der, cert);
				msg.certificates.push_back(Cert(der));
			}
			msg.fromClient.good   = proto.from_client().good();
			msg.fromClient.late   = proto.from_client().late();
			msg.fromClient.lost   = proto.from_client().lost();
			msg.fromClient.resync = proto.from_client().resync();
			msg.fromServer.good   = proto.from_server().good();
			msg.fromServer.late   = proto.from_server().late();
			msg.fromServer.lost   = proto.from_server().lost();
			msg.fromServer.resync = proto.from_server().resync();

			msg.udpPackets = proto.udp_packets();
			msg.tcpPackets = proto.tcp_packets();
			msg.udpPingAvg = proto.udp_ping_avg();
			msg.udpPingVar = proto.udp_ping_var();
			msg.tcpPingAvg = proto.tcp_ping_avg();
			msg.tcpPingVar = proto.tcp_ping_var();


			if (proto.version().has_version_v2()) {
				msg.version.version = mumble::Version(proto.version().version_v2());
			} else {
				msg.version.version = mumble::Version(proto.version().version_v1());
			}
			msg.version.release   = proto.version().release();
			msg.version.os        = proto.version().os();
			msg.version.osVersion = proto.version().os_version();
			for (const auto version : proto.celt_versions()) {
				msg.celtVersions.push_back(version);
			}
			msg.address           = IP(proto.address());
			msg.bandwidth         = proto.bandwidth();
			msg.onlinesecs        = proto.onlinesecs();
			msg.idlesecs          = proto.idlesecs();
			msg.strongCertificate = proto.strong_certificate();
			msg.opus              = proto.opus();

			return true;
		}
		case Type::RequestBlob: {
			MumbleTCP::RequestBlob proto;
			PARSE_PROTO_MESSAGE(proto, data().data(), dataSize)

			auto &msg = static_cast< Message::RequestBlob & >(message);
			for (const auto texture : proto.session_texture()) {
				msg.sessionTexture.push_back(texture);
			}
			for (const auto comment : proto.session_comment()) {
				msg.sessionComment.push_back(comment);
			}
			for (const auto description : proto.channel_description()) {
				msg.channelDescription.push_back(description);
			}

			return true;
		}
		case Type::ServerConfig: {
			MumbleTCP::ServerConfig proto;
			PARSE_PROTO_MESSAGE(proto, data().data(), dataSize)

			auto &msg              = static_cast< Message::ServerConfig & >(message);
			msg.maxBandwidth       = proto.max_bandwidth();
			msg.welcomeText        = proto.welcome_text();
			msg.allowHTML          = proto.allow_html();
			msg.messageLength      = proto.message_length();
			msg.imageMessageLength = proto.image_message_length();
			msg.maxUsers           = proto.max_users();
			msg.recordingAllowed   = proto.recording_allowed();

			return true;
		}
		case Type::SuggestConfig: {
			MumbleTCP::SuggestConfig proto;
			PARSE_PROTO_MESSAGE(proto, data().data(), dataSize)

			auto &msg = static_cast< Message::SuggestConfig & >(message);
			if (proto.has_version_v2()) {
				msg.version = mumble::Version(proto.version_v2());
			} else if (proto.has_version_v1()) {
				msg.version = mumble::Version(proto.version_v1());
			}
			if (proto.has_positional()) {
				msg.positional = proto.positional();
			}
			if (proto.has_push_to_talk()) {
				msg.pushToTalk = proto.push_to_talk();
			}

			return true;
		}
		case Type::PluginDataTransmission: {
			MumbleTCP::PluginDataTransmission proto;
			PARSE_PROTO_MESSAGE(proto, data().data(), dataSize)

			auto &msg         = static_cast< Message::PluginDataTransmission & >(message);
			msg.senderSession = proto.sendersession();
			for (const auto session : proto.receiversessions()) {
				msg.receiverSessions.push_back(session);
			}
			toBuf(msg.data, proto.data());
			msg.dataID = proto.dataid();

			return true;
		}
	}

	return false;
}

bool UDP::operator()(Message &message, uint32_t dataSize) const {
	using Type = Message::Type;

	if (message.type() != Message::type(*this)) {
		return false;
	}

	if (dataSize > data().size()) {
		dataSize = static_cast< decltype(dataSize) >(data().size());
	}

	switch (message.type()) {
		case Type::Audio: {
			MumbleUDP::Audio proto;
			PARSE_PROTO_MESSAGE(proto, data().data(), dataSize)

			auto &msg = static_cast< Message::Audio & >(message);
			switch (proto.Header_case()) {
				case MumbleUDP::Audio::kTarget:
					msg.direction = Message::Audio::ClientToServer;
					msg.target = proto.target();
					break;
				case MumbleUDP::Audio::kContext:
					msg.direction = Message::Audio::ServerToClient;
					msg.context = proto.context();
					break;
				case MumbleUDP::Audio::HEADER_NOT_SET:
					msg.direction = Message::Audio::Unknown;
					break;
			}

			// FIXME: Check if field is set once "optional" is in .proto file.
			msg.senderSession = proto.sender_session();

			msg.frameNumber = proto.frame_number();
			toBuf(msg.opusData, proto.opus_data());
			for (const auto data : proto.positional_data()) {
				msg.positionalData.push_back(data);
			}

			msg.volumeAdjustment = proto.volume_adjustment();

			msg.isTerminator = proto.is_terminator();

			return true;
		}
		case Type::Ping: {
			MumbleUDP::Ping proto;
			PARSE_PROTO_MESSAGE(proto, data().data(), dataSize)

			auto &msg     = static_cast< Message::Ping & >(message);
			msg.timestamp = Message::Timestamp(std::chrono::nanoseconds(proto.timestamp()));

			msg.requestExtendedInformation = proto.request_extended_information();

			// FIXME: Check if fields are set once "optional" is in .proto file.
			msg.version             = mumble::Version(proto.server_version_v2());
			msg.userCount           = proto.user_count();
			msg.maxUserCount        = proto.max_user_count();
			msg.maxBandwidthPerUser = proto.max_bandwidth_per_user();

			return true;
		}
	}

	return false;
}
