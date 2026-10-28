// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_EXAMPLESERVER_USER_HPP
#define MUMBLE_EXAMPLESERVER_USER_HPP

#include "Endpoints.hpp"

#include "mumble/Cert.hpp"
#include "mumble/Connection.hpp"
#include "mumble/CryptOCB2.hpp"
#include "mumble/Types.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <utility>
#include <vector>

namespace mumble {
class Key;

namespace tcp {
	struct Message;
	class Pack;
} // namespace tcp
} // namespace mumble

class User {
public:
	using BufView      = mumble::BufView;
	using BufViewConst = mumble::BufViewConst;
	using Cert         = mumble::Cert;
	using Code         = mumble::Code;
	using Connection   = mumble::Connection;
	using CryptOCB2    = mumble::CryptOCB2;
	using Key          = mumble::Key;
	using Message      = mumble::tcp::Message;
	using Pack         = mumble::tcp::Pack;

	struct Packet {
		mumble::Endpoint endpoint;
		mumble::Buf buf;

		Packet() noexcept = default;

		Packet(const Packet &packet) noexcept : endpoint(packet.endpoint), buf(packet.buf) {}

		Packet(const mumble::Endpoint &endpoint, const BufViewConst buf) noexcept
			: endpoint(endpoint), buf(buf.begin(), buf.end()) {}

		Packet &operator=(const Packet &&packet) noexcept {
			endpoint = packet.endpoint;
			buf      = std::move(packet.buf);

			return *this;
		}
	};

	User(const int32_t socketHandle, const uint32_t id);
	virtual ~User();

	uint32_t id() const;

	const std::shared_ptr< Connection > &connection() const;

	bool cryptOK() const;

	uint32_t good() const;
	uint32_t late() const;
	uint32_t lost() const;

	BufViewConst key() const;

	BufViewConst decryptNonce() const;
	BufViewConst encryptNonce() const;

	size_t decrypt(const BufView out, const BufViewConst in);
	size_t encrypt(const BufView out, const BufViewConst in);

	const Endpoints &endpoints() const;
	void addEndpoint(const Endpoint &endpoint);
	void delEndpoint(const Endpoint &endpoint);

	Code connect(const Connection::Feedback &feedback, const Cert::Chain &cert, const Key &key);

	void send(const Message &message);
	void send(const Pack &pack);

private:
	uint32_t m_id;
	bool m_cryptOK;
	uint32_t m_good;
	uint32_t m_late;
	uint32_t m_lost;
	Endpoints m_endpoints;
	CryptOCB2 m_decrypt;
	CryptOCB2 m_encrypt;
	std::vector< std::byte > m_decryptNonce;
	std::vector< std::byte > m_encryptNonce;
	std::array< uint8_t, UINT8_MAX + 1 > m_decryptHistory;
	std::shared_ptr< Connection > m_connection;
};

#endif
