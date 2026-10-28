// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#include "Hash.hpp"

#include "mumble/Types.hpp"

#include <cassert>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <utility>

#include <openssl/evp.h>
#include <openssl/opensslv.h>

#define CHECK      \
	if (!*this) {  \
		return {}; \
	}

#define CAST_BUF(var) (reinterpret_cast< unsigned char * >(var))

using namespace mumble;

using P = Hash::P;

Hash::Hash(Hash &&crypt) : m_p(std::exchange(crypt.m_p, nullptr)) {
}

Hash::Hash() : m_p(new P) {
}

Hash::~Hash() = default;

Hash::operator bool() const {
	return m_p && *m_p;
}

Hash &Hash::operator=(Hash &&crypt) {
	m_p = std::exchange(crypt.m_p, nullptr);
	return *this;
}

size_t Hash::operator()(const BufView out, const BufViewConst in) {
	CHECK

	if (!out.size()) {
		int size = EVP_MD_CTX_size(m_p->m_ctx);
		assert(size >= 0);
		return static_cast< std::size_t >(size);
	}

	if (EVP_DigestInit_ex(m_p->m_ctx, nullptr, nullptr) <= 0) {
		return {};
	}

	if (EVP_DigestUpdate(m_p->m_ctx, in.data(), in.size()) <= 0) {
		return {};
	}

	uint32_t written;
	if (EVP_DigestFinal_ex(m_p->m_ctx, CAST_BUF(out.data()), &written) <= 0) {
		return {};
	}

	return written;
}

void *Hash::handle() const {
	CHECK

	return m_p->m_ctx;
}

std::string_view Hash::type() const {
	CHECK

	return m_p->type();
}

bool Hash::setType(const std::string_view name) {
	CHECK

	return m_p->setType(name);
}

uint32_t Hash::blockSize() const {
	CHECK

	int size = EVP_MD_CTX_block_size(m_p->m_ctx);
	assert(size >= 0);
	return static_cast< std::uint32_t >(size);
}

bool Hash::reset() {
	CHECK

	return EVP_MD_CTX_reset(m_p->m_ctx) > 0;
}

P::P() : m_ctx(EVP_MD_CTX_new()) {
	if (m_ctx) {
		setType();
	}
}

P::~P() {
	if (m_ctx) {
		EVP_MD_CTX_free(m_ctx);
	}
}

P::operator bool() {
#if OPENSSL_VERSION_MAJOR >= 3
	return m_ctx && EVP_MD_CTX_get0_md(m_ctx);
#else
	return m_ctx && EVP_MD_CTX_md(m_ctx);
#endif
}

std::string_view P::type() {
#if OPENSSL_VERSION_MAJOR >= 3
	const auto type = EVP_MD_CTX_get0_md(m_ctx);
#else
	const auto type = EVP_MD_CTX_md(m_ctx);
#endif
	if (type == EVP_md_null()) {
		return {};
	}

	return EVP_MD_name(type);
}

bool P::setType(const std::string_view name) {
	const auto type = name.empty() ? EVP_md_null() : EVP_get_digestbyname(name.data());
	if (!type) {
		return false;
	}

	return EVP_DigestInit_ex(m_ctx, type, nullptr) > 0;
}
