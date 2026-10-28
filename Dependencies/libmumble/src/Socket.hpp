// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_SRC_SOCKET_HPP
#define MUMBLE_SRC_SOCKET_HPP

#include "mumble/Endpoint.hpp"
#include "mumble/Types.hpp"

#include <utility>

#ifdef OS_WINDOWS
#	include <WinSock2.h>
#else
#	include <errno.h>
#endif

namespace mumble {
class Socket {
public:
	using Pair = std::pair< Socket, Socket >;

	enum class Type : uint8_t { Unknown, Local, TCP, UDP };

	static constexpr int8_t invalidHandle = -1;

	Socket();
	Socket(Socket &&socket);
	Socket(const int32_t handle);
	Socket(const Type type);
	~Socket();

	explicit operator bool() const;

	int32_t handle() const;
	int32_t stealHandle();

	int getEndpoint(Endpoint &endpoint) const;
	int setEndpoint(const Endpoint &endpoint, const bool ipv6Only = false);

	int setBlocking(const bool enable);

	static Pair localPair();

	static void close(const int32_t handle);

	static int osError();
	static constexpr Code osErrorToCode(const int error) {
		switch (error) {
			case 0:
				return Code::Success;
#ifdef OS_WINDOWS
			case WSAEACCES:
			case WSAECONNREFUSED:
				return Code::Refuse;
			case WSAEHOSTUNREACH:
			case WSAENETUNREACH:
				return Code::Reach;
			case WSAEADDRNOTAVAIL:
			case WSAEAFNOSUPPORT:
			case WSAEDESTADDRREQ:
			case WSAEFAULT:
			case WSAEINVAL:
			case WSAEISCONN:
			case WSAENETDOWN:
			case WSAENOTCONN:
			case WSAENOTSOCK:
			case WSAEOPNOTSUPP:
				return Code::Invalid;
			case WSAEMSGSIZE:
			case WSAENOBUFS:
				return Code::Memory;
			case WSANOTINITIALISED:
				return Code::Init;
			case WSAETIMEDOUT:
				return Code::Timeout;
			case WSAECONNABORTED:
				return Code::Cancel;
			case WSAEINTR:
			case WSAEWOULDBLOCK:
				return Code::Retry;
			case WSAEADDRINUSE:
			case WSAEALREADY:
			case WSAEINPROGRESS:
				return Code::Busy;
			case WSAECONNRESET:
			case WSAENETRESET:
			case WSAESHUTDOWN:
				return Code::Disconnect;
#else
			case EACCES:
			case ECONNREFUSED:
				return Code::Refuse;
			case EHOSTUNREACH:
			case ENETUNREACH:
				return Code::Reach;
			case EADDRNOTAVAIL:
			case EAFNOSUPPORT:
			case EBADF:
			case EDESTADDRREQ:
			case EFAULT:
			case EINVAL:
			case EISCONN:
			case ENOTCONN:
			case ENOTSOCK:
			case EOPNOTSUPP:
			case EPROTOTYPE:
				return Code::Invalid;
			case EMSGSIZE:
			case ENOBUFS:
			case ENOMEM:
				return Code::Memory;
			case ETIMEDOUT:
				return Code::Timeout;
			case ECONNABORTED:
				return Code::Cancel;
#	if EAGAIN != EWOULDBLOCK
			case EAGAIN:
#	endif
			case EWOULDBLOCK:
			case EINTR:
				return Code::Retry;
			case EADDRINUSE:
			case EALREADY:
			case EINPROGRESS:
				return Code::Busy;
			case ECONNRESET:
			case EPIPE:
				return Code::Disconnect;
#endif
		}

		return Code::Unknown;
	}

protected:
	int32_t m_handle;
};
} // namespace mumble

#endif
