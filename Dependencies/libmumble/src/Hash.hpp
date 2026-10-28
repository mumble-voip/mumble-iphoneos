// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_SRC_HASH_HPP
#define MUMBLE_SRC_HASH_HPP

#include "mumble/Hash.hpp"

#include <string_view>

#include <openssl/ossl_typ.h>

namespace mumble {
class Hash::P {
	friend Hash;

public:
	P();
	~P();

	explicit operator bool();

	std::string_view type();
	bool setType(const std::string_view name = {});

private:
	EVP_MD_CTX *m_ctx;
};
} // namespace mumble

#endif
