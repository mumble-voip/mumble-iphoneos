// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#include "Connection.hpp"

#include "mumble/Endian.hpp"
#include "mumble/Key.hpp"
#include "mumble/Message.hpp"
#include "mumble/Pack.hpp"

#include <cstddef>
#include <limits>
#include <memory>
#include <utility>

using namespace mumble;

using Feedback = Connection::Feedback;
using P        = Connection::P;
using UniqueP  = Connection::UniqueP;

Connection::Connection(Connection &&connection) : m_p(std::exchange(connection.m_p, nullptr)) {
}

Connection::Connection(const int32_t socketHandle, const bool server)
	: m_p(std::make_unique< P >(SocketTLS(socketHandle, server))) {
}

Connection::~Connection() = default;

Connection::operator bool() const {
	return m_p && *m_p;
}

Code Connection::operator()(const Feedback &feedback, const std::function< bool() > halt) {
	const auto guard = m_p->lock();

	if (!m_p->m_monitorIn.add(m_p->m_handle, true, false) || !m_p->m_monitorOut.add(m_p->m_handle, false, true)) {
		return Code::Failure;
	}

	m_p->m_feedback = feedback;

	while (!halt()) {
		const auto code = m_p->handleCode(m_p->isServer() ? m_p->accept() : m_p->connect(), true);
		switch (code) {
			case Code::Success:
				m_p->m_closed.clear();
				m_p->m_feedback.opened();
				[[fallthrough]];
			default:
				return code;
			case Code::Retry:
				continue;
		}
	}

	return Code::Cancel;
}

const UniqueP &Connection::p() const {
	return m_p;
}

int32_t Connection::socketHandle() const {
	return m_p->handle();
}

Endpoint Connection::endpoint() const {
	Endpoint endpoint;
	m_p->getEndpoint(endpoint);
	return endpoint;
}

Endpoint Connection::peerEndpoint() const {
	Endpoint endpoint;
	m_p->getPeerEndpoint(endpoint);
	return endpoint;
}

const Cert::Chain &Connection::cert() const {
	return m_p->m_cert;
}

Cert::Chain Connection::peerCert() const {
	return m_p->peerCert();
}

bool Connection::setCert(const Cert::Chain &cert, const Key &key) {
	const auto guard = m_p->lock();

	return m_p->setCert(cert, key);
}

bool Connection::setServerName(const std::string_view hostname) {
	const auto guard = m_p->lock();
	return m_p->setServerName(hostname);
}

Code Connection::process(const bool wait, const std::function< bool() > halt) {
	using NetHeader = tcp::NetHeader;
	using Pack      = tcp::Pack;

	const auto guard = m_p->lock();
	do {
		if (!m_p->m_incoming) {
			BufView header{ reinterpret_cast< std::byte * >(&m_p->m_header) + m_p->m_headerBytes,
						 sizeof(NetHeader) - m_p->m_headerBytes };
			const auto code = m_p->read(header, wait, halt);
			m_p->m_headerBytes = sizeof(NetHeader) - header.size();
			if (code != Code::Success) {
				return code;
			}

			// Mumble control messages may contain textures and exceed 64 KiB.
			if (Endian::toHost(m_p->m_header.size) > 8 * 1024 * 1024) {
				if (!m_p->m_closed.test_and_set()) {
					m_p->m_feedback.failed(Code::Invalid);
				}
				return Code::Invalid;
			}
			m_p->m_incoming = std::make_unique< Pack >(m_p->m_header);
		}

		if (!m_p->m_incoming->data().empty()) {
			BufView payload = m_p->m_incoming->data().subspan(m_p->m_payloadBytes);
			const auto code = m_p->read(payload, wait, halt);
			m_p->m_payloadBytes = m_p->m_incoming->data().size() - payload.size();
			if (code != Code::Success) {
				return code;
			}
		}

		auto pack = std::move(m_p->m_incoming);
		m_p->m_headerBytes = 0;
		m_p->m_payloadBytes = 0;
		m_p->m_feedback.pack(*pack);
	} while (m_p->pending() > 0);

	return Code::Success;
}

Code Connection::write(const BufViewConst data, const bool wait, const std::function< bool() > halt) {
	const auto guard = m_p->lock();

	return m_p->write(data, wait, halt);
}

P::P(SocketTLS &&socket) : SocketTLS(std::move(socket)), m_timeouts(0) {
	m_closed.test_and_set();

	setBlocking(false);
}

P::~P() {
	disconnect();
}

P::operator bool() const {
	return SocketTLS::operator bool() && m_monitorIn && m_monitorOut;
}

Code P::read(BufView &buf, const bool wait, const std::function< bool() > halt) {
	using Code = mumble::Code;

	while (!halt()) {
		const auto code = handleCode(SocketTLS::read(buf), wait);
		if (code == Code::Retry) {
			continue;
		} else {
			return code;
		}
	}

	return Code::Cancel;
}

Code P::write(BufViewConst buf, const bool wait, const std::function< bool() > halt) {
	using Code = mumble::Code;

	while (!halt()) {
		const auto code = handleCode(SocketTLS::write(buf), wait);
		if (code == Code::Retry) {
			continue;
		} else {
			return code;
		}
	}

	return Code::Cancel;
}

Code P::handleCode(const Code code, const bool wait) {
	using Code = mumble::Code;

	auto ret = P::interpretTLSCode(code);
	if (ret == Code::Busy && wait) {
		ret = handleWait(code == WaitIn ? m_monitorIn : m_monitorOut);

		if (ret == Code::Timeout && m_feedback.timeouts && ++m_timeouts < m_feedback.timeouts()) {
			ret = Code::Retry;
		}
	}

	switch (ret) {
		case Code::Disconnect:
			if (!m_closed.test_and_set()) {
				m_feedback.closed();
			}
			[[fallthrough]];
		case Code::Success:
			m_timeouts = 0;
		case Code::Retry:
		case Code::Busy:
			break;
		default:
			if (!m_closed.test_and_set()) {
				m_feedback.failed(ret);
			}
	}

	return ret;
}

Code P::handleWait(Monitor &monitor) {
	using Code = mumble::Code;

	Monitor::Event event;
	if (!monitor.wait({ &event, 1 }, m_feedback.timeout ? m_feedback.timeout() : monitor.timeoutMax)) {
		return Code::Timeout;
	}

	return handleState(event.state);
}

mumble::Code P::handleState(const State state) {
	using Code = mumble::Code;

	if (state & State::Disconnected) {
		if (!m_closed.test_and_set()) {
			m_feedback.closed();
		}

		return Code::Disconnect;
	}

	if (state & State::Error) {
		if (!m_closed.test_and_set()) {
			m_feedback.failed(Code::Failure);
		}

		return Code::Failure;
	}

	if (state & State::Triggered || state & State::InReady || state & State::OutReady) {
		return Code::Retry;
	}

	return Code::Unknown;
}

constexpr mumble::Code P::interpretTLSCode(const Code code) {
	using Code = mumble::Code;

	switch (code) {
		case Memory:
			return Code::Memory;
		case Failure:
			return Code::Failure;
		case Unknown:
			break;
		case Success:
			return Code::Success;
		case Retry:
			return Code::Retry;
		case Shutdown:
			return Code::Disconnect;
		case WaitIn:
		case WaitOut:
			return Code::Busy;
	}

	return Code::Unknown;
}
