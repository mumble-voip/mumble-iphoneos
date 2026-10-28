// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_CONNECTION_HPP
#define MUMBLE_CONNECTION_HPP

#include "Cert.hpp"
#include "Endpoint.hpp"
#include "Key.hpp"
#include "Macros.hpp"

#include <functional>

namespace mumble {
namespace tcp {
	class Pack;
}

class MUMBLE_EXPORT Connection {
public:
	class P;
	using UniqueP = std::unique_ptr< P >;

	struct Feedback {
		std::function< void() > opened;
		std::function< void() > closed;

		std::function< void(Code code) > failed;

		std::function< uint32_t() > timeout;
		std::function< uint32_t() > timeouts;

		std::function< void(tcp::Pack &pack) > pack;
	};

	Connection(Connection &&connection);
	Connection(const int32_t socketHandle, const bool server);
	virtual ~Connection();

	virtual explicit operator bool() const;

	virtual Code operator()(const Feedback &feedback, const std::function< bool() > halt = []() { return false; });

	virtual const UniqueP &p() const;
	virtual int32_t socketHandle() const;

	virtual Endpoint endpoint() const;
	virtual Endpoint peerEndpoint() const;

	virtual const Cert::Chain &cert() const;
	virtual Cert::Chain peerCert() const;

	virtual bool setCert(const Cert::Chain &cert, const Key &key);
	virtual bool setServerName(const std::string_view hostname);

	virtual Code process(const bool wait = true, const std::function< bool() > halt = []() { return false; });
	virtual Code write(
		const BufViewConst data, const bool wait = true, const std::function< bool() > halt = []() { return false; });

private:
	UniqueP m_p;
};
} // namespace mumble

#endif
