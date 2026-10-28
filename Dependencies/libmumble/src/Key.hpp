// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_SRC_KEY_HPP
#define MUMBLE_SRC_KEY_HPP

#include "mumble/Key.hpp"

#include <string_view>

#include <openssl/ossl_typ.h>

namespace mumble {
class Key::P {
	friend Key;

public:
	P(EVP_PKEY *pkey);
	P(const std::string_view pem, const bool isPrivate, std::string_view password = {});
	~P();

private:
	static int passwordCallback(char *buf, const int size, int, void *userdata);

	EVP_PKEY *m_pkey;
};
} // namespace mumble

#endif
