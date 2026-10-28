// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#include "Cert.hpp"

#include "mumble/Key.hpp"
#include "mumble/Types.hpp"

#include <cstring>
#include <ctime>
#include <memory>
#include <span>
#include <utility>

#include <openssl/asn1.h>
#include <openssl/bio.h>
#include <openssl/buffer.h>
#include <openssl/crypto.h>
#include <openssl/obj_mac.h>
#include <openssl/objects.h>
#include <openssl/pem.h>
#include <openssl/x509.h>
#include <openssl/x509v3.h>

#define CHECK      \
	if (!*this) {  \
		return {}; \
	}

#define CAST_SIZE(var) (static_cast< int >(var))

using namespace mumble;

using Attributes = Cert::Attributes;
using Der        = Cert::Der;
using P          = Cert::P;
using TimePoint  = Cert::TimePoint;

Cert::Cert() : m_p(new P(X509_new())) {
}

Cert::Cert(const Cert &cert) : m_p(new P(X509_dup(cert.m_p->m_x509))) {
}

Cert::Cert(Cert &&cert) : m_p(std::exchange(cert.m_p, nullptr)) {
}

Cert::Cert(void *handle) : m_p(new P(static_cast< X509 * >(handle))) {
}

Cert::Cert(const DerViewConst der) : m_p(new P(der)) {
}

Cert::Cert(const std::string_view pem, std::string_view password) : m_p(new P(pem, password)) {
}

Cert::~Cert() = default;

Cert::operator bool() const {
	return m_p && m_p->m_x509;
}

Cert &Cert::operator=(const Cert &cert) {
	m_p = std::make_unique< P >(cert ? X509_dup(cert.m_p->m_x509) : nullptr);
	return *this;
}

Cert &Cert::operator=(Cert &&cert) {
	m_p = std::exchange(cert.m_p, nullptr);
	return *this;
}

bool Cert::operator==(const Cert &cert) const {
	if (!*this || !cert) {
		return !*this && !cert;
	}

	return X509_cmp(m_p->m_x509, cert.m_p->m_x509) == 0;
}

void *Cert::handle() const {
	CHECK

	return m_p->m_x509;
}

Der Cert::der() const {
	CHECK

	auto bio = BIO_new(BIO_s_secmem());
	if (!bio) {
		return {};
	}

	Der der;

	if (i2d_X509_bio(bio, m_p->m_x509) > 0) {
		BUF_MEM *mem;
		if (BIO_get_mem_ptr(bio, &mem) > 0) {
			der.resize(mem->length);
			memcpy(der.data(), mem->data, der.size());
		}
	}

	BIO_free_all(bio);

	return der;
}

std::string Cert::pem() const {
	CHECK

	auto bio = BIO_new(BIO_s_secmem());
	if (!bio) {
		return {};
	}

	std::string pem;

	if (PEM_write_bio_X509(bio, m_p->m_x509) > 0) {
		BUF_MEM *mem;
		if (BIO_get_mem_ptr(bio, &mem) > 0) {
			pem.append(mem->data, mem->length);
		}
	}

	BIO_free_all(bio);

	return pem;
}

Key Cert::publicKey() const {
	CHECK

	return X509_get_pubkey(m_p->m_x509);
}

TimePoint Cert::since() const {
	CHECK

	return P::parseASN1Time(X509_get0_notBefore(m_p->m_x509));
}

TimePoint Cert::until() const {
	CHECK

	return P::parseASN1Time(X509_get0_notAfter(m_p->m_x509));
}

bool Cert::isAuthority() const {
	CHECK

	return X509_check_ca(m_p->m_x509);
}

bool Cert::isIssuer(const Cert &cert) const {
	CHECK

	return cert ? X509_check_issued(m_p->m_x509, cert.m_p->m_x509) == X509_V_OK : false;
}

bool Cert::isSelfIssued() const {
	return isIssuer(*this);
}

Attributes Cert::subjectAttributes() const {
	CHECK

	return P::parseX509Name(X509_get_subject_name(m_p->m_x509));
}

Attributes Cert::issuerAttributes() const {
	CHECK

	return P::parseX509Name(X509_get_issuer_name(m_p->m_x509));
}

P::P(X509 *x509) : m_x509(x509) {
}

P::P(const DerViewConst der) : m_x509(nullptr) {
	auto bytes = reinterpret_cast<const unsigned char *>(der.data());
	m_x509 = d2i_X509(nullptr, &bytes, static_cast<long>(der.size()));
}

P::P(const std::string_view pem, std::string_view password) : m_x509(nullptr) {
	auto bio = BIO_new_mem_buf(pem.data(), CAST_SIZE(pem.size()));
	if (!bio) {
		return;
	}

	PEM_read_bio_X509(bio, &m_x509, &P::passwordCallback, &password);

	BIO_free_all(bio);
}

P::~P() {
	if (m_x509) {
		X509_free(m_x509);
	}
}

std::string P::parseASN1String(const ASN1_STRING *string) {
	if (!string) {
		return {};
	}

	unsigned char *buf;
	const int size = ASN1_STRING_to_UTF8(&buf, string);
	if (size < 0) {
		return {};
	}

	std::string ret(reinterpret_cast< char * >(buf), static_cast< std::size_t >(size));

	OPENSSL_free(buf);

	return ret;
}

TimePoint P::parseASN1Time(const ASN1_TIME *time) {
	if (!time) {
		return {};
	}

	tm tm{};
	if (ASN1_TIME_to_tm(time, &tm) <= 0) {
		return {};
	}

	// ASN.1 certificate timestamps are UTC, independent of the device timezone.
	using namespace std::chrono;
	return sys_days(year(tm.tm_year + 1900) / month(static_cast<unsigned>(tm.tm_mon + 1))
					/ day(static_cast<unsigned>(tm.tm_mday)))
		   + hours(tm.tm_hour) + minutes(tm.tm_min) + seconds(tm.tm_sec);
}

Attributes P::parseX509Name(const X509_NAME *name) {
	if (!name) {
		return {};
	}

	Attributes attributes;

	for (auto i = 0; i < X509_NAME_entry_count(name); ++i) {
		const auto entry = X509_NAME_get_entry(name, i);
		if (!entry) {
			continue;
		}

		const auto object = X509_NAME_ENTRY_get_object(entry);
		if (!object) {
			continue;
		}

		const auto nid = OBJ_obj2nid(object);
		if (nid == NID_undef) {
			continue;
		}

		const auto string = X509_NAME_ENTRY_get_data(entry);
		if (!string) {
			continue;
		}

		attributes.insert({ OBJ_nid2sn(nid), parseASN1String(string) });
	}

	return attributes;
}

int P::passwordCallback(char *buf, const int size, int, void *userdata) {
	auto password = static_cast< const std::string_view * >(userdata);

	int length = CAST_SIZE(password->size());
	if (length > size) {
		length = size;
	}

	memcpy(buf, password->data(), static_cast< std::size_t >(length));

	return length;
}
