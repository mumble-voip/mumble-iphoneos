// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_SRC_TCP_HPP
#define MUMBLE_SRC_TCP_HPP

#include "Socket.hpp"

#include "mumble/Types.hpp"

#include <cstdint>
#include <utility>

namespace mumble {
class SocketTCP : public Socket {
public:
	SocketTCP();
	SocketTCP(const int32_t handle);

	int listen();

	std::pair< int, int32_t > accept(Endpoint &endpoint);
	int connect(const Endpoint &endpoint);

	int getPeerEndpoint(Endpoint &endpoint) const;
};
} // namespace mumble

#endif
