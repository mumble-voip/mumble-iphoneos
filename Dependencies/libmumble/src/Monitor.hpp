// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_SRC_MONITOR_HPP
#define MUMBLE_SRC_MONITOR_HPP

#include "mumble/Macros.hpp"

#include "Socket.hpp"

#include <cstdint>
#include <limits>
#include <span>
#include <unordered_set>
#include <vector>

#if defined(HAVE_EPOLL) || defined(HAVE_WEPOLL)
struct epoll_event;
#else
struct pollfd;
#endif

namespace mumble {
class Monitor {
public:
	struct Event {
		enum State : uint8_t {
			None         = 0b00000000,
			Triggered    = 0b00000001,
			InReady      = 0b00000010,
			OutReady     = 0b00000100,
			Disconnected = 0b00001000,
			Error        = 0b00010000
		};

		int32_t fd;
		State state;

		Event() : fd(Socket::invalidHandle), state(None) {}
		Event(const int32_t fd) : fd(fd), state(None) {}
	};

	static constexpr auto timeoutMax = std::numeric_limits< uint32_t >::max();

	using EventsView = std::span< Event >;

	Monitor();
	~Monitor();

	explicit operator bool() const;

	uint32_t num() const;

	bool add(const int32_t fd, const bool in, const bool out);
	bool del(const int32_t fd);

	bool trigger();
	bool untrigger();

	uint32_t wait(const EventsView events, const uint32_t timeout);

private:
	Monitor(const Monitor &)            = delete;
	Monitor &operator=(const Monitor &) = delete;
#if defined(HAVE_EPOLL) || defined(HAVE_WEPOLL)
	using Target = epoll_event;
	uint32_t waitEpoll(const EventsView events, const uint32_t timeout);
#	ifdef HAVE_EPOLL
	int m_handle;
#	else
	HANDLE m_handle;
#	endif
#else
	using Target = pollfd;
	uint32_t waitPoll(const EventsView events, const uint32_t timeout);
#endif
	Socket::Pair m_trigger;
	std::vector< Target > m_targets;
	std::unordered_set< int32_t > m_fds;
};
} // namespace mumble

MUMBLE_ENUM_OPERATORS(mumble::Monitor::Event::State)

#endif
