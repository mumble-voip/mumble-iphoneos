// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#include "Peer.hpp"

#include "Connection.hpp"
#include "Socket.hpp"
#include "TCP.hpp"
#include "UDP.hpp"

#include "mumble/Connection.hpp"
#include "mumble/Macros.hpp"
#include "mumble/Message.hpp"
#include "mumble/Pack.hpp"
#include "mumble/Types.hpp"

#include <algorithm>
#include <functional>
#include <mutex>
#include <span>
#include <utility>
#include <vector>

#include <thread>

#ifndef MUMBLE_COMPILER_MSVC
#	include <quickpool.hpp>
#else
#	pragma warning(push)
#	pragma warning(disable : 4244)
#	pragma warning(disable : 4324)
#	include <quickpool.hpp>
#	pragma warning(pop)
#endif

using namespace mumble;

using P = Peer::P;

Peer::Peer() : m_p(new P) {
}

Peer::Peer(Peer &&peer) : m_p(std::exchange(peer.m_p, nullptr)) {
}

Peer::~Peer() {
	stopTCP();
	stopUDP();
}

Peer &Peer::operator=(Peer &&peer) {
	m_p = std::exchange(peer.m_p, nullptr);
	return *this;
}

Peer::operator bool() const {
	return static_cast< bool >(m_p);
}

std::pair< Code, int32_t > Peer::connect(const Endpoint &peerEndpoint, const Endpoint &endpoint) {
	SocketTCP socket;

	auto code = Socket::osErrorToCode(socket.setEndpoint(endpoint));
	if (code != Code::Success) {
		return { code, {} };
	}

	code = Socket::osErrorToCode(socket.connect(peerEndpoint));
	if (code != Code::Success) {
		return { code, {} };
	}

	return { Code::Success, socket.stealHandle() };
}

Code Peer::startTCP(const FeedbackTCP &feedback, const uint32_t threads) {
	return m_p->m_tcp.start(feedback, threads);
}

Code Peer::stopTCP() {
	return m_p->m_tcp.stop();
}

Code Peer::startUDP(const FeedbackUDP &feedback, const uint32_t bufferSize) {
	return m_p->m_udp.start(feedback, bufferSize);
}

Code Peer::stopUDP() {
	return m_p->m_udp.stop();
}

Code Peer::bindTCP(Endpoint &endpoint, const bool ipv6Only) {
	return m_p->m_tcp.bind(endpoint, ipv6Only);
}

Code Peer::unbindTCP() {
	return m_p->m_tcp.unbind();
}

Code Peer::bindUDP(Endpoint &endpoint, const bool ipv6Only) {
	return m_p->m_udp.bind(endpoint, ipv6Only);
}

Code Peer::unbindUDP() {
	return m_p->m_udp.unbind();
}

Code Peer::addTCP(const SharedConnection &connection) {
	auto &tcp = m_p->m_tcp;

	std::unique_lock< std::shared_mutex > lock(tcp.m_mutex);

	tcp.m_connections[connection->socketHandle()] = connection;
	tcp.m_monitor.add(connection->socketHandle(), true, false);

	return Code::Success;
}

Code Peer::delTCP(const SharedConnection &connection) {
	auto &tcp = m_p->m_tcp;

	std::unique_lock< std::shared_mutex > lock(tcp.m_mutex);

	tcp.m_monitor.del(connection->socketHandle());
	tcp.m_connections.extract(connection->socketHandle());

	return Code::Success;
}

Code Peer::sendUDP(const Endpoint &endpoint, const BufViewConst data) {
	if (!m_p->m_udp.m_socket) {
		return Code::Init;
	}

	return m_p->m_udp.m_socket->write(endpoint, data);
}

template< typename Feedback, typename Socket > Code P::Proto< Feedback, Socket >::stop() {
	if (!m_thread) {
		return Code::Success;
	}

	m_halt = true;
	m_monitor.trigger();
	m_thread->join();
	m_thread.reset();

	return Code::Success;
}

template< typename Feedback, typename Socket >
Code P::Proto< Feedback, Socket >::bind(Endpoint &endpoint, const bool ipv6Only) {
	if (m_thread) {
		return Code::Busy;
	}

	m_socket = std::make_unique< Socket >();
	if (!*m_socket) {
		return Code::Open;
	}

	if (!m_monitor.add(m_socket->handle(), true, false)) {
		return Code::Failure;
	}

	m_socket->setBlocking(false);

	auto ret = m_socket->setEndpoint(endpoint, ipv6Only);
	if (ret != 0) {
		return Socket::osErrorToCode(ret);
	}

	return Code::Success;
}

template< typename Feedback, typename Socket > Code P::Proto< Feedback, Socket >::unbind() {
	if (m_thread) {
		return Code::Busy;
	}

	m_socket.reset();

	return Code::Success;
}

Code P::TCP::start(const FeedbackTCP &feedback, const uint32_t threads) {
	if (m_thread) {
		return Code::Busy;
	}

	m_halt     = false;
	m_feedback = feedback;
	m_thread   = std::make_unique< std::thread >(&TCP::threadFunc, this, threads);

	return Code::Success;
}

Code P::UDP::start(const FeedbackUDP &feedback, const uint32_t bufferSize) {
	if (m_thread) {
		return Code::Busy;
	}

	if (!m_socket) {
		return Code::Init;
	}

	m_halt     = false;
	m_feedback = feedback;
	m_thread   = std::make_unique< std::thread >(&UDP::threadFunc, this, bufferSize);

	return Code::Success;
}

Code P::TCP::bind(Endpoint &endpoint, const bool ipv6Only) {
	const Code code = Proto::bind(endpoint, ipv6Only);
	if (code != Code::Success) {
		return code;
	}

	const auto ret = m_socket->listen();
	if (ret != 0) {
		return Socket::osErrorToCode(ret);
	}

	return Code::Success;
}

void P::TCP::threadFunc(const uint32_t threads) {
	using Event = Monitor::Event;
	using Pool  = quickpool::ThreadPool;

	if (m_feedback.started) {
		m_feedback.started();
	}

	std::unique_ptr< Pool > pool;
	pool = threads ? std::make_unique< Pool >(threads) : std::make_unique< Pool >();

	std::vector< Event > events(m_monitor.num());

	uint32_t num = 0;

	while (!m_halt) {
		std::span< Event > view(events.data(), num);
		pool->parallel_for_each(view, [this](Event &event) {
			if (m_socket && event.fd == m_socket->handle()) {
				if (event.state & Event::Error) {
					m_feedback.failed(Code::Failure);
					return;
				}

				while (event.state & Event::InReady) {
					Endpoint endpoint;
					const auto ret = m_socket->accept(endpoint);

					const auto code = Socket::osErrorToCode(ret.first);
					switch (code) {
						case Code::Success: {
							if (!m_feedback.connection || !m_feedback.connection(endpoint, ret.second)) {
								Socket::close(ret.second);
							}

							break;
						}
						default:
							m_feedback.failed(code);
							[[fallthrough]];
						case Code::Timeout:
						case Code::Cancel:
						case Code::Retry:
						case Code::Busy:
						case Code::Disconnect:
							event.state = Event::None;
					}
				}
			} else {
				SharedConnection connection;

				{
					std::shared_lock< std::shared_mutex > lock(m_mutex);

					const auto iter = m_connections.find(event.fd);
					if (iter != m_connections.cend()) {
						connection = iter->second;
					} else {
						return;
					}
				}

				if (event.state & Event::Disconnected || event.state & Event::Error) {
					connection->p()->handleState(event.state);
					return;
				}

				while (event.state & Event::InReady) {
					const auto code = connection->process(false, [this]() { return m_halt.load(); });
					switch (code) {
						case Code::Success:
							break;
						default:
							event.state = Event::None;
					}
				}
			}
		});

		if (events.size() != m_monitor.num()) {
			events.resize(m_monitor.num());
		}

		num = m_monitor.wait(events, m_feedback.timeout ? m_feedback.timeout() : m_monitor.timeoutMax);
	}

	if (m_feedback.stopped) {
		m_feedback.stopped();
	}
}

void P::UDP::threadFunc(const uint32_t bufferSize) {
	using namespace udp;
	using namespace legacy::udp;

	using Event   = Monitor::Event;
	using Message = udp::Message;
	using Pack    = udp::Pack;
	using Type    = Message::Type;

	if (m_feedback.started) {
		m_feedback.started();
	}

	Pack pack(NetHeader(), bufferSize ? bufferSize : 1024);
	Event event(m_socket->handle());

	while (!m_halt) {
		if (event.state & Event::Error) {
			m_feedback.failed(Code::Failure);
			return;
		}

		while (event.state & Event::InReady) {
			Endpoint endpoint;
			BufView packet(pack.buf());

			const auto code = m_socket->read(endpoint, packet);
			switch (code) {
				case Code::Success: {
					if (Message::type(pack) == Type::Ping) {
						Message::Ping ping;
						if (pack(ping, static_cast< uint32_t >(packet.size() - sizeof(NetHeader)))) {
							if (m_feedback.ping) {
								m_feedback.ping(endpoint, ping);
							}

							continue;
						}
					}

					if (isPlainPing(packet)) {
						if (m_feedback.legacyPing) {
							m_feedback.legacyPing(endpoint, *reinterpret_cast< Ping * >(packet.data()));
						}

						continue;
					}

					if (m_feedback.encrypted) {
						m_feedback.encrypted(endpoint, packet);
					}

					continue;
				}
				case Code::Timeout:
				case Code::Retry:
				case Code::Busy:
					event.state = Event::None;
					continue;
				default:
					m_feedback.failed(code);
					return;
			}
		}

		m_monitor.wait({ &event, 1 }, m_feedback.timeout ? m_feedback.timeout() : m_monitor.timeoutMax);
	}

	if (m_feedback.stopped) {
		m_feedback.stopped();
	}
}
