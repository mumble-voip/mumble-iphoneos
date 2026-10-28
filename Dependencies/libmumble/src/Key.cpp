// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#include "Key.hpp"

#include <cassert>
#include <cstring>
#include <memory>
#include <string>
#include <utility>

#include <openssl/bio.h>
#include <openssl/buffer.h>
#include <openssl/evp.h>
#include <openssl/opensslv.h>
#include <openssl/pem.h>

#define CHECK      \
	if (!*this) {  \
		return {}; \
	}

#define CAST_SIZE(var) (static_cast< int >(var))

using namespace mumble;

using P = Key::P;

Key::Key() : m_p(new P(EVP_PKEY_new())) {
}

Key::Key(const Key &key) : m_p(new P(key.pem(), key.isPrivate())) {
}

Key::Key(Key &&key) : m_p(std::exchange(key.m_p, nullptr)) {
}

Key::Key(void *handle) : m_p(new P(static_cast< EVP_PKEY * >(handle))) {
}

Key::Key(const std::string_view pem, const bool isPrivate, std::string_view password)
	: m_p(new P(pem, isPrivate, password)) {
}

Key::~Key() = default;

Key::operator bool() const {
	return m_p && m_p->m_pkey;
}

Key &Key::operator=(const Key &key) {
#if OPENSSL_VERSION_MAJOR >= 3
	m_p = std::make_unique< P >(EVP_PKEY_dup(key.m_p->m_pkey));
#else
	m_p = std::make_unique< P >(key.pem(), key.isPrivate());
#endif
	return *this;
}

Key &Key::operator=(Key &&key) {
	m_p = std::exchange(key.m_p, nullptr);
	return *this;
}

bool Key::operator==(const Key &key) const {
	if (!*this || !key) {
		return !*this && !key;
	}
#if OPENSSL_VERSION_MAJOR >= 3
	return EVP_PKEY_eq(m_p->m_pkey, key.m_p->m_pkey) == 1;
#else
	return EVP_PKEY_cmp(m_p->m_pkey, key.m_p->m_pkey) == 1;
#endif
}

void *Key::handle() const {
	return m_p->m_pkey;
}

bool Key::isPrivate() const {
	CHECK

	return i2d_PrivateKey(m_p->m_pkey, nullptr) > 0;
}

std::string Key::pem() const {
	CHECK

	auto bio = BIO_new(BIO_s_secmem());
	if (!bio) {
		return {};
	}

	int ret;

	if (isPrivate()) {
		ret = PEM_write_bio_PrivateKey(bio, m_p->m_pkey, nullptr, nullptr, 0, nullptr, nullptr);
	} else {
		ret = PEM_write_bio_PUBKEY(bio, m_p->m_pkey);
	}

	std::string pem;

	if (ret > 0) {
		BUF_MEM *mem;
		if (BIO_get_mem_ptr(bio, &mem) > 0) {
			pem.append(mem->data, mem->length);
		}
	}

	BIO_free_all(bio);

	return pem;
}

P::P(EVP_PKEY *pkey) : m_pkey(pkey) {
}

P::P(const std::string_view pem, const bool isPrivate, std::string_view password) : m_pkey(nullptr) {
	auto bio = BIO_new_mem_buf(pem.data(), CAST_SIZE(pem.size()));
	if (!bio) {
		return;
	}

	if (isPrivate) {
		PEM_read_bio_PrivateKey(bio, &m_pkey, &P::passwordCallback, &password);
	} else {
		PEM_read_bio_PUBKEY(bio, &m_pkey, &P::passwordCallback, &password);
	}

	BIO_free_all(bio);
}

P::~P() {
	if (m_pkey) {
		EVP_PKEY_free(m_pkey);
	}
}

int P::passwordCallback(char *buf, const int size, int, void *userdata) {
	auto password = static_cast< const std::string_view * >(userdata);

	int length = CAST_SIZE(password->size());
	if (length > size) {
		length = size;
	}

	assert(length >= 0);
	memcpy(buf, password->data(), static_cast< std::size_t >(length));

	return length;
}
