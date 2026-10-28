// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_SRC_CRYPT_HPP
#define MUMBLE_SRC_CRYPT_HPP

#include "mumble/Crypt.hpp"

#include "mumble/Types.hpp"

#include <cstddef>
#include <cstdint>
#include <string_view>

#include <openssl/ossl_typ.h>

namespace mumble {
class Crypt::P {
	friend Crypt;

public:
	P();
	~P();

	explicit operator bool();

	uint32_t blockSize() const;

	std::string_view cipher();
	bool setCipher(const std::string_view name = {});

	size_t process(const bool encrypt, const BufView out, const BufViewConst in, const BufView tag,
				   const BufViewConst aad);

private:
	Buf m_key;
	Buf m_nonce;
	bool m_padding;
	EVP_CIPHER_CTX *m_ctx;
};
} // namespace mumble

#endif
