// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#include "Monitor.hpp"

#include "mumble/Types.hpp"

#ifdef OS_WINDOWS
#	include <WinSock2.h>
#else
#	include <sys/socket.h>
#endif

#if defined(HAVE_EPOLL)
#	include <unistd.h>
#	include <sys/epoll.h>
#elif defined(HAVE_WEPOLL)
#	include <wepoll.h>
#	define close epoll_close
#else
#	include <algorithm>

#	ifdef OS_WINDOWS
#		define poll WSAPoll
#	else
#		include <poll.h>
#	endif
#endif

using namespace mumble;

Monitor::Monitor() : m_trigger(Socket::localPair()) {
#if defined(HAVE_EPOLL) || defined(HAVE_WEPOLL)
	m_handle = epoll_create(1);
#endif
	if (*this) {
		add(m_trigger.first.handle(), true, false);
	}
}

Monitor::~Monitor() {
#if defined(HAVE_EPOLL) || defined(HAVE_WEPOLL)
	if (*this) {
		close(m_handle);
	}
#endif
}

Monitor::operator bool() const {
#if defined(HAVE_EPOLL)
	return m_handle != -1;
#elif defined(HAVE_WEPOLL)
	return m_handle;
#else
	return true;
#endif
}

uint32_t Monitor::num() const {
	return static_cast< uint32_t >(m_fds.size());
}

bool Monitor::add(const int32_t fd, const bool in, const bool out) {
	if (m_fds.find(fd) != m_fds.cend()) {
		return false;
	}

	Target target = {};
#if defined(HAVE_EPOLL) || defined(HAVE_WEPOLL)
	target.data.fd = fd;
	target.events  = EPOLLRDHUP;

	if (in) {
		target.events |= EPOLLIN;
	}

	if (out) {
		target.events |= EPOLLOUT;
	}

	if (epoll_ctl(m_handle, EPOLL_CTL_ADD, fd, &target) != 0) {
		return false;
	}
#else
	target.fd = fd;

	if (in) {
		target.events |= POLLIN;
	}

	if (out) {
		target.events |= POLLOUT;
	}
#endif
	m_targets.push_back(target);

	m_fds.insert(fd);

	return true;
}

bool Monitor::del(const int32_t fd) {
	if (!m_fds.erase(fd)) {
		return false;
	}
#if defined(HAVE_EPOLL) || defined(HAVE_WEPOLL)
	epoll_ctl(m_handle, EPOLL_CTL_DEL, fd, nullptr);

	m_targets.pop_back();
#else
	const auto iter =
		std::find_if(m_targets.cbegin(), m_targets.cend(), [fd](const Target &target) { return target.fd == fd; });
	m_targets.erase(iter);
#endif
	return true;
}

bool Monitor::trigger() {
	if (!m_trigger.second) {
		return false;
	}
#ifdef OS_WINDOWS
	constexpr char byte = 0;
#else
	constexpr uint8_t byte = 0;
#endif
	static_assert(sizeof(byte) == 1);

	return send(m_trigger.second.handle(), &byte, sizeof(byte), 0) >= 1;
}

bool Monitor::untrigger() {
	if (!m_trigger.first) {
		return false;
	}
#ifdef OS_WINDOWS
	char byte;
#else
	uint8_t byte;
#endif
	static_assert(sizeof(byte) == 1);

	return recv(m_trigger.first.handle(), &byte, sizeof(byte), 0) >= 1;
}

uint32_t Monitor::wait(const EventsView events, const uint32_t timeout) {
	if (!events.size()) {
		return {};
	}
#if defined(HAVE_EPOLL) || defined(HAVE_WEPOLL)
	return waitEpoll(events, timeout);
#else
	return waitPoll(events, timeout);
#endif
}

#if defined(HAVE_EPOLL) || defined(HAVE_WEPOLL)
#	include <span>

uint32_t Monitor::waitEpoll(const EventsView events, const uint32_t timeout) {
	const int32_t ret = epoll_wait(m_handle, m_targets.data(), static_cast< int >(m_targets.size()),
								   timeout == timeoutMax ? -1 : static_cast< int >(timeout));
	if (ret < 1) {
		return {};
	}

	uint32_t num = 0;

	for (const auto &target : std::span< Target >(m_targets.data(), static_cast< std::size_t >(ret))) {
		if (num >= events.size()) {
			break;
		}

		auto &event = events[num++];

		event.fd    = target.data.fd;
		event.state = Event::None;

		if (target.events & EPOLLIN) {
			if (target.data.fd != m_trigger.first.handle()) {
				event.state |= Event::InReady;
			} else {
				event.state |= Event::Triggered;
				untrigger();
				continue;
			}
		}

		if (target.events & EPOLLOUT) {
			event.state |= Event::OutReady;
		}

		if (target.events & EPOLLHUP || target.events & EPOLLRDHUP) {
			event.state |= Event::Disconnected;
		}

		if (target.events & EPOLLERR) {
			event.state |= Event::Error;
		}
	}

	return num;
}
#else
uint32_t Monitor::waitPoll(const EventsView events, const uint32_t timeout) {
	const int32_t ret = poll(m_targets.data(), static_cast< nfds_t >(m_targets.size()),
							 timeout == timeoutMax ? -1 : static_cast< int >(timeout));
	if (ret < 1) {
		return {};
	}

	uint32_t num = 0;

	for (const auto &target : m_targets) {
		if (num >= events.size() || num >= static_cast< uint32_t >(ret)) {
			break;
		}

		if (!target.revents) {
			continue;
		}

		auto &event = events[num++];

		event.fd    = target.fd;
		event.state = Event::None;

		if (target.revents & POLLIN) {
			if (target.fd != m_trigger.first.handle()) {
				event.state |= Event::InReady;
			} else {
				event.state |= Event::Triggered;
				untrigger();
				continue;
			}
		}

		if (target.revents & POLLOUT) {
			event.state |= Event::OutReady;
		}

		if (target.revents & POLLHUP) {
			event.state |= Event::Disconnected;
		}

		if (target.revents & POLLERR) {
			event.state |= Event::Error;
		}
	}

	return num;
}
#endif
