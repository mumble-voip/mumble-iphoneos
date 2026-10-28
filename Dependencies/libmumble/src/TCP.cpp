// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#include "TCP.hpp"

#ifdef OS_WINDOWS
#	include <WS2tcpip.h>
#else
#	include <netinet/in.h>
#	include <sys/socket.h>
#endif

using namespace mumble;

SocketTCP::SocketTCP() : Socket(Type::TCP) {
}

SocketTCP::SocketTCP(const int32_t handle) : Socket(handle) {
}

int SocketTCP::listen() {
	if (::listen(m_handle, SOMAXCONN) != 0) {
		return osError();
	}

	return 0;
}

std::pair< int, int32_t > SocketTCP::accept(Endpoint &endpoint) {
	sockaddr_in6 addr;
#ifdef OS_WINDOWS
	int size = sizeof(addr);
#else
	socklen_t size = sizeof(addr);
#endif
	// Explicit return data type because socket handles are unsigned on Windows.
	const auto handle = static_cast< int32_t >(::accept(m_handle, reinterpret_cast< sockaddr * >(&addr), &size));
	if (handle == invalidHandle) {
		return { osError(), invalidHandle };
	}

	endpoint = Endpoint(addr);

	return { 0, handle };
}

int SocketTCP::connect(const Endpoint &endpoint) {
	sockaddr_in6 addr;
	if (!endpoint.toSockAddr(addr)) {
#ifdef OS_WINDOWS
		return WSAEINVAL;
#else
		return EINVAL;
#endif
	}

	if (::connect(m_handle, reinterpret_cast< sockaddr * >(&addr), sizeof(addr)) != 0) {
		return osError();
	}

	return 0;
}

int SocketTCP::getPeerEndpoint(Endpoint &endpoint) const {
	sockaddr_in6 addr;
#ifdef OS_WINDOWS
	int size = sizeof(addr);
#else
	socklen_t size = sizeof(addr);
#endif
	if (getpeername(m_handle, reinterpret_cast< sockaddr * >(&addr), &size) != 0) {
		return osError();
	}

	endpoint = Endpoint(addr);

	return 0;
}
