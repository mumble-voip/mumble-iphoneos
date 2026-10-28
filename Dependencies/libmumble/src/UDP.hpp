// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_SRC_UDP_HPP
#define MUMBLE_SRC_UDP_HPP

#include "mumble/Types.hpp"

#include "Socket.hpp"

namespace mumble {
class SocketUDP : public Socket {
public:
	SocketUDP();

	Code read(Endpoint &endpoint, BufView &buf);
	Code write(const Endpoint &endpoint, const BufViewConst buf);
};
} // namespace mumble

#endif
