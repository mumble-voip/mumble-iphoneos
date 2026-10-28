// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_SRC_CERT_HPP
#define MUMBLE_SRC_CERT_HPP

#include "mumble/Cert.hpp"

#include <string>
#include <string_view>

#include <openssl/ossl_typ.h>

namespace mumble {
class Cert::P {
	friend Cert;

public:
	P(X509 *x509);
	P(const DerViewConst der);
	P(const std::string_view pem, std::string_view password = {});
	~P();

private:
	static std::string parseASN1String(const ASN1_STRING *string);
	static TimePoint parseASN1Time(const ASN1_TIME *time);
	static Attributes parseX509Name(const X509_NAME *name);

	static int passwordCallback(char *buf, const int size, int, void *userdata);

	X509 *m_x509;
};
} // namespace mumble

#endif
