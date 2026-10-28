// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_EXAMPLESERVER_NODE_HPP
#define MUMBLE_EXAMPLESERVER_NODE_HPP

#include "mumble/Cert.hpp"
#include "mumble/Key.hpp"
#include "mumble/Message.hpp"
#include "mumble/Peer.hpp"

#include <cstdint>
#include <memory>
#include <string_view>
#include <vector>

namespace mumble {
class Session;
}

class UserManager;

class Node {
public:
	Node(const std::shared_ptr< UserManager > &userManager, const std::string_view tcpIP, const uint16_t tcpPort,
		 const std::string_view udpIP, const uint16_t udpPort, const uint32_t bandwidth);
	~Node();

	explicit operator bool() const;

	bool start();

	bool setCert(const std::string_view certPath, const std::string_view keyPath);

private:
	using SessionPtr = std::unique_ptr< mumble::Session >;

	bool startTCP();
	bool startUDP();

	bool fillPing(mumble::udp::Message::Ping &ping);

	bool m_ok;
	uint32_t m_bandwidth;

	std::shared_ptr< UserManager > m_userManager;

	std::vector< mumble::Cert > m_certChain;
	mumble::Key m_certKey;

	mumble::Peer m_server;
};

#endif
