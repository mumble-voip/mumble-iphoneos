// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_SRC_BASE64_HPP
#define MUMBLE_SRC_BASE64_HPP

#include "mumble/Base64.hpp"

#include <openssl/ossl_typ.h>

namespace mumble {
class Base64::P {
	friend Base64;

public:
	P();
	~P();

private:
	EVP_ENCODE_CTX *m_ctx;
};
} // namespace mumble

#endif
