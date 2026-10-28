// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_SRC_PEER_HPP
#define MUMBLE_SRC_PEER_HPP

#include "mumble/Peer.hpp"

#include "mumble/Types.hpp"

#include "Monitor.hpp"

#include <atomic>
#include <cstdint>
#include <memory>
#include <shared_mutex>
#include <unordered_map>
#include <thread>

namespace mumble {
class SocketTCP;
class SocketUDP;

class Peer::P {
	friend Peer;

public:
	P()  = default;
	~P() = default;

private:
	template< typename Feedback, typename Socket > struct Proto {
		Proto() : m_halt(false) {}

		Code stop();

		Code bind(Endpoint &endpoint, const bool ipv6Only);
		Code unbind();

		Feedback m_feedback;

		std::atomic_bool m_halt;
		Monitor m_monitor;
		std::unique_ptr< Socket > m_socket;
		std::unique_ptr< std::thread > m_thread;
	};

	struct TCP : Proto< FeedbackTCP, SocketTCP > {
		Code start(const FeedbackTCP &feedback, const uint32_t threads);

		Code bind(Endpoint &endpoint, const bool ipv6Only);

		void threadFunc(const uint32_t threads);

		std::shared_mutex m_mutex;
		std::unordered_map< int32_t, SharedConnection > m_connections;
	};

	struct UDP : Proto< FeedbackUDP, SocketUDP > {
		Code start(const FeedbackUDP &feedback, const uint32_t bufferSize);

		void threadFunc(const uint32_t bufferSize);
	};

	P(const P &)            = delete;
	P &operator=(const P &) = delete;

	TCP m_tcp;
	UDP m_udp;
};
} // namespace mumble

#endif
