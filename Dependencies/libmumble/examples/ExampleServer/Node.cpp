// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#include "Node.hpp"

#include "Endpoints.hpp"
#include "User.hpp"
#include "UserManager.hpp"

#include "mumble/Connection.hpp"
#include "mumble/Endian.hpp"
#include "mumble/IP.hpp"
#include "mumble/Lib.hpp"
#include "mumble/Message.hpp"
#include "mumble/Pack.hpp"
#include "mumble/Types.hpp"

#include <algorithm>
#include <cstddef>
#include <cstdio>
#include <fstream>
#include <functional>
#include <map>
#include <optional>
#include <sstream>
#include <string>
#include <utility>

using namespace mumble;

Node::Node(const std::shared_ptr< UserManager > &userManager, const std::string_view tcpIP, const uint16_t tcpPort,
		   const std::string_view udpIP, const uint16_t udpPort, const uint32_t bandwidth)
	: m_ok(false), m_bandwidth(bandwidth), m_userManager(userManager) {
	Endpoint endpoint(IP(tcpIP), tcpPort);
	auto code = m_server.bindTCP(endpoint);
	if (code != Code::Success) {
		printf("Node(): TCP bind failed with error \"%s\"!\n", text(code).data());
		return;
	}

	printf("TCP: %s\n", endpoint.text().data());

	endpoint = Endpoint(IP(udpIP), udpPort);
	code     = m_server.bindUDP(endpoint);
	if (code != Code::Success) {
		printf("Node(): UDP bind failed with error \"%s\"!\n", text(code).data());
		return;
	}

	printf("UDP: %s\n", endpoint.text().data());

	m_ok = true;
}

Node::~Node() = default;

Node::operator bool() const {
	return m_ok;
}

bool Node::start() {
	if (!startTCP()) {
		return false;
	}

	return startUDP();
}

bool Node::startTCP() {
	using Message = tcp::Message;
	using Pack    = tcp::Pack;
	using Type    = Message::Type;

	Peer::FeedbackTCP feedbackTCP;

	feedbackTCP.started = []() { printf("TCP started!\n"); };
	feedbackTCP.stopped = []() { printf("TCP stopped!\n"); };

	feedbackTCP.failed = [](const Code code) { printf("TCP failed with error \"%s\"!\n", text(code).data()); };

	feedbackTCP.timeout = []() { return 10000; };

	feedbackTCP.connection = [this](const Endpoint &endpoint, int32_t socketHandle) {
		printf("Incoming connection from %s\n", endpoint.text().data());

		if (m_userManager->full()) {
			return false;
		}

		const auto id = m_userManager->reserveID();
		if (!id) {
			return false;
		}

		auto user    = std::make_shared< User >(socketHandle, id.value());
		auto userPtr = std::weak_ptr< User >(user);

		Connection::Feedback feedback;

		feedback.opened = [this, userPtr]() {
			if (const auto user = userPtr.lock()) {
				m_userManager->add(user);

				printf("[#%u] Created!\n", user->id());

				const auto certChain = user->connection()->peerCert();
				if (certChain.size()) {
					const auto attributes = certChain[0].subjectAttributes();
					for (const auto &attribute : attributes) {
						printf("[#%u] %s: %s\n", user->id(), attribute.first.data(), attribute.second.data());
					}
				} else {
					printf("[#%u] Didn't provide a certificate!\n", user->id());
				}

				const auto code = user->connection()->process();
				if (code != Code::Success) {
					printf("[#%u] Connection::process() failed with error \"%s\"!\n", user->id(), text(code).data());
					return;
				}

				m_server.addTCP(user->connection());
			}
		};

		feedback.closed = [this, userPtr]() {
			if (auto user = userPtr.lock()) {
				m_server.delTCP(user->connection());

				const auto id = user->id();
				user.reset();
				m_userManager->del(id);

				printf("[#%u] Closed!\n", id);
			}
		};

		feedback.failed = [this, userPtr](const Code code) {
			if (auto user = userPtr.lock()) {
				m_server.delTCP(user->connection());

				const auto id = user->id();
				user.reset();
				m_userManager->del(id);

				printf("[#%u] Failed with error \"%s\"!\n", id, text(code).data());
			}
		};

		feedback.pack = [this, userPtr](Pack &pack) {
			const auto user = userPtr.lock();
			if (!user) {
				return;
			}

			const auto type = Message::type(pack);
			if (type != Type::UDPTunnel) {
				printf("[#%u] (TCP) %s received!\n", user->id(), Message::text(type).data());
			}

			using Perm = Message::Perm;

			switch (type) {
				case Type::Version: {
					Message::Version ver;
					ver.version = lib::version();
					ver.release = "Custom server";
					user->send(ver);

					break;
				}
				case Type::UDPTunnel:
					break;
				case Type::Authenticate: {
					Message::Authenticate auth;
					if (!pack(auth)) {
						break;
					}

					printf("username: %s | password: %s\n", auth.username.c_str(), auth.password.c_str());

					Message::CryptSetup crypt;
					crypt.key.assign(user->key().begin(), user->key().end());
					crypt.clientNonce.assign(user->decryptNonce().begin(), user->decryptNonce().end());
					crypt.serverNonce.assign(user->encryptNonce().begin(), user->encryptNonce().end());
					user->send(crypt);

					Message::CodecVersion codec;
					codec.opus = true;
					user->send(codec);

					Message::ChannelState channel;
					channel.name              = "Root";
					channel.channelID         = 0;
					channel.position          = 0;
					channel.isEnterRestricted = false;
					channel.canEnter          = true;
					user->send(channel);

					Message::UserState state;
					state.session   = user->id();
					state.name      = auth.username;
					state.channelID = channel.channelID;
					user->send(state);

					Message::ServerSync sync;
					sync.session      = user->id();
					sync.maxBandwidth = m_bandwidth;
					sync.welcomeText  = "Welcome to the best server in the world!";
					sync.permissions  = static_cast< uint32_t >(Perm::Enter | Perm::Speak | Perm::TextMessage);
					user->send(sync);

					Message::ServerConfig config;
					config.maxBandwidth     = sync.maxBandwidth;
					config.welcomeText      = sync.welcomeText;
					config.allowHTML        = true;
					config.maxUsers         = m_userManager->max();
					config.recordingAllowed = true;
					user->send(config);

					break;
				}
				case Type::Ping:
					user->send(pack);
					break;
				case Type::Reject:
					break;
				case Type::ServerSync:
					break;
				case Type::ChannelRemove:
					break;
				case Type::ChannelState:
					break;
				case Type::UserRemove:
					break;
				case Type::UserState:
					break;
				case Type::BanList:
					break;
				case Type::TextMessage:
					break;
				case Type::PermissionDenied:
					break;
				case Type::ACL:
					break;
				case Type::QueryUsers:
					break;
				case Type::CryptSetup:
					break;
				case Type::ContextActionModify:
					break;
				case Type::ContextAction:
					break;
				case Type::UserList:
					break;
				case Type::VoiceTarget:
					break;
				case Type::PermissionQuery: {
					Message::PermissionQuery query;
					if (!pack(query)) {
						break;
					}

					query.permissions = static_cast< uint32_t >(Perm::Enter | Perm::Speak | Perm::TextMessage);

					user->send(query);
					break;
				}
				case Type::CodecVersion:
					break;
				case Type::UserStats: {
					Message::UserStats stats;
					if (!pack(stats)) {
						break;
					}

					const auto target = (*m_userManager)[stats.session];
					if (!target) {
						break;
					}

					stats.fromClient.good = target->good();
					stats.fromClient.late = target->late();
					stats.fromClient.lost = target->lost();

					stats.address      = target->connection()->peerEndpoint().address;
					stats.certificates = target->connection()->peerCert();
					stats.opus         = true;

					user->send(stats);
					break;
				}
				case Type::RequestBlob:
					break;
				case Type::ServerConfig:
					break;
				case Type::SuggestConfig:
					break;
				case Type::PluginDataTransmission:
					break;
			}
		};

		const auto code = user->connect(feedback, m_certChain, m_certKey);
		if (code != Code::Success) {
			return false;
		}

		return true;
	};

	const auto code = m_server.startTCP(feedbackTCP);
	if (code != Code::Success) {
		printf("Peer::startTCP() failed with error \"%s\"!\n", text(code).data());
		return false;
	}

	return true;
}

bool Node::startUDP() {
	using Message   = udp::Message;
	using NetHeader = udp::NetHeader;
	using Pack      = udp::Pack;
	using Type      = Message::Type;

	Peer::FeedbackUDP feedbackUDP;

	feedbackUDP.started = []() { printf("UDP started!\n"); };
	feedbackUDP.stopped = []() { printf("UDP stopped!\n"); };

	feedbackUDP.failed = [](const Code code) { printf("UDP failed with error \"%s\"!\n", text(code).data()); };

	feedbackUDP.timeout = []() { return 10000; };

	feedbackUDP.legacyPing = [this](Endpoint &endpoint, legacy::udp::Ping &ping) {
		ping.versionBlob  = Endian::toNetwork(lib::version().blob32());
		ping.sessions     = Endian::toNetwork(m_userManager->num());
		ping.maxSessions  = Endian::toNetwork(m_userManager->max());
		ping.maxBandwidth = Endian::toNetwork(m_bandwidth);

		m_server.sendUDP(endpoint, { reinterpret_cast< std::byte * >(&ping), sizeof(ping) });
	};

	feedbackUDP.ping = [this](Endpoint &endpoint, Message::Ping &ping) {
		fillPing(ping);

		m_server.sendUDP(endpoint, Pack(ping).buf());
	};

	feedbackUDP.encrypted = [this](Endpoint &endpoint, BufView buf) {
		auto user = (*m_userManager)[endpoint];

		Buf decrypted(buf.size());

		if (!user) {
			user = m_userManager->tryDecrypt(decrypted, buf, endpoint);
			if (user) {
				printf("%s <-> #%u association added to cache!\n", endpoint.text().data(), user->id());
			} else {
				return;
			}
		}

		auto size = user->decrypt(decrypted, buf);
		if (!size) {
			user->delEndpoint(endpoint);
			return;
		}

		BufViewConst packet = { decrypted.data(), size };

		if (legacy::udp::type(packet) == legacy::udp::Type::Ping) {
			printf("[#%u] (UDP) Legacy ping received!\n", user->id());

			size = user->encrypt(buf, packet);
			if (size) {
				m_server.sendUDP(endpoint, buf.first(size));
			}

			return;
		}

		auto header = reinterpret_cast< const NetHeader * >(packet.data());
		packet      = packet.subspan(sizeof(*header));

		Pack pack(*header, packet.size());

		const auto type = Message::type(pack);
		if (type != Type::Audio) {
			printf("[#%u] (UDP) %s received!\n", user->id(), Message::text(type).data());
		}

		switch (type) {
			case Type::Audio:
				break;
			case Type::Ping: {
				std::copy(packet.begin(), packet.end(), pack.data().begin());

				Message::Ping ping;
				if (!pack(ping)) {
					break;
				}

				if (fillPing(ping)) {
					pack = Pack(ping);
				}

				size = user->encrypt(buf, pack.buf());
				if (size) {
					m_server.sendUDP(endpoint, buf.first(size));
				}

				break;
			}
		}
	};

	auto code = m_server.startUDP(feedbackUDP);
	if (code != Code::Success) {
		printf("Peer::startUDP() failed with error \"%s\"!\n", text(code).data());
		return false;
	}

	return true;
}

bool Node::fillPing(udp::Message::Ping &ping) {
	if (!ping.requestExtendedInformation) {
		return false;
	}

	ping.version             = lib::version();
	ping.userCount           = m_userManager->num();
	ping.maxUserCount        = m_userManager->max();
	ping.maxBandwidthPerUser = m_bandwidth;

	return true;
}

bool Node::setCert(const std::string_view certPath, const std::string_view keyPath) {
	std::ifstream certStream(certPath.data());
	std::stringstream buffer;
	buffer << certStream.rdbuf();

	Cert cert(buffer.str());
	if (!cert) {
		printf("Node::setCert(): Failed to load certificate!\n");
		return false;
	}

	std::ifstream keyStream(keyPath.data());
	buffer.str({});
	buffer.clear();
	buffer << keyStream.rdbuf();

	Key key(buffer.str(), true);
	if (!key) {
		printf("Node::setCert(): Failed to load key!\n");
		return false;
	}

	m_certChain = { cert };
	m_certKey   = key;

	return true;
}
