// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#include "UDP.hpp"

#ifdef OS_WINDOWS
#	include <WS2tcpip.h>

#	define CAST_BUF(var) reinterpret_cast< char * >(var)
#	define CAST_BUF_CONST(var) reinterpret_cast< const char * >(var)
#	define CAST_SIZE(var) static_cast< int >(var)
#else
#	include <netinet/in.h>
#	include <sys/socket.h>
#endif

#define CAST_SOCKADDR(var) reinterpret_cast< sockaddr * >(var)
#define CAST_SOCKADDR_CONST(var) reinterpret_cast< const sockaddr * >(var)

using namespace mumble;

SocketUDP::SocketUDP() : Socket(Type::UDP) {
}

Code SocketUDP::read(Endpoint &endpoint, BufView &buf) {
	sockaddr_in6 addr;
#ifdef OS_WINDOWS
	auto addrsize = static_cast< int >(sizeof(addr));
	const auto ret =
		recvfrom(m_handle, CAST_BUF(buf.data()), CAST_SIZE(buf.size()), 0, CAST_SOCKADDR(&addr), &addrsize);
#else
	socklen_t addrsize = sizeof(addr);
	const auto ret     = recvfrom(m_handle, buf.data(), buf.size(), 0, CAST_SOCKADDR(&addr), &addrsize);
#endif
	if (ret <= 0) {
		return osErrorToCode(osError());
	}

	endpoint = Endpoint(addr);

	buf = buf.first(static_cast< std::size_t >(ret));

	return Code::Success;
}

Code SocketUDP::write(const Endpoint &endpoint, const BufViewConst buf) {
	sockaddr_in6 addr;
	if (!endpoint.toSockAddr(addr)) {
		return Code::Invalid;
	}
#ifdef OS_WINDOWS
	const auto ret = sendto(m_handle, CAST_BUF_CONST(buf.data()), CAST_SIZE(buf.size()), 0, CAST_SOCKADDR_CONST(&addr),
							sizeof(addr));
#else
	const auto ret = sendto(m_handle, buf.data(), buf.size(), 0, CAST_SOCKADDR_CONST(&addr), sizeof(addr));
#endif
	if (ret <= 0) {
		return osErrorToCode(osError());
	}

	return Code::Success;
}
