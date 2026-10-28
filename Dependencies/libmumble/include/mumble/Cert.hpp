// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_CERT_HPP
#define MUMBLE_CERT_HPP

#include "Macros.hpp"
#include "Types.hpp"

#include "mumble/Key.hpp"

#include <chrono>
#include <map>
#include <memory>

namespace mumble {
class MUMBLE_EXPORT Cert {
public:
	class P;

	using Attributes   = std::map< std::string_view, std::string >;
	using Chain        = std::vector< Cert >;
	using Der          = std::vector< std::byte >;
	using DerView      = std::span< std::byte >;
	using DerViewConst = std::span< const std::byte >;
	using TimePoint    = std::chrono::system_clock::time_point;

	Cert();
	Cert(const Cert &cert);
	Cert(Cert &&cert);
	Cert(void *handle);
	Cert(const DerViewConst der);
	Cert(const std::string_view pem, std::string_view password = {});
	virtual ~Cert();

	virtual explicit operator bool() const;

	virtual Cert &operator=(const Cert &cert);
	virtual Cert &operator=(Cert &&cert);

	virtual bool operator==(const Cert &cert) const;

	virtual void *handle() const;

	virtual Der der() const;
	virtual std::string pem() const;

	virtual Key publicKey() const;

	virtual TimePoint since() const;
	virtual TimePoint until() const;

	virtual bool isAuthority() const;
	virtual bool isIssuer(const Cert &cert) const;
	virtual bool isSelfIssued() const;

	virtual Attributes subjectAttributes() const;
	virtual Attributes issuerAttributes() const;

private:
	std::unique_ptr< P > m_p;
};
} // namespace mumble

#endif
