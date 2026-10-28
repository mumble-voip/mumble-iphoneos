// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_SRC_TLS_HPP
#define MUMBLE_SRC_TLS_HPP

#include "TCP.hpp"

#include "mumble/Cert.hpp"
#include "mumble/Key.hpp"
#include "mumble/Types.hpp"

#include <atomic>
#include <cstdint>

#include <openssl/ossl_typ.h>

namespace mumble {
class SocketTLS : public SocketTCP {
public:
	enum Code : int8_t { Memory = -3, Failure, Unknown, Success, Retry, Shutdown, WaitIn, WaitOut };

	SocketTLS(SocketTLS &&socket);
	SocketTLS(const int32_t handle, const bool server);
	~SocketTLS();

	explicit operator bool() const;

	bool isServer() const;

	bool setCert(const Cert::Chain &cert, const Key &key);
	bool setServerName(const std::string_view hostname);

	Cert::Chain peerCert() const;

	uint32_t pending() const;

	Code accept();
	Code connect();
	Code disconnect();

	Code read(BufView &buf);
	Code write(BufViewConst &buf);

private:
	Code interpretLibCode(const int code, const bool processed = true, const bool remaining = false);
	static int verifyCallback(int, X509_STORE_CTX *);

	SSL *m_ssl;
	SSL_CTX *m_sslCtx;
	std::atomic_bool m_closed;
};
} // namespace mumble

#endif
