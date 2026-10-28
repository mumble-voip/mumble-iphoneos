// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#include "Crypt.hpp"

#include <cassert>
#include <cstddef>
#include <memory>
#include <utility>

#include <openssl/evp.h>
#include <openssl/rand.h>

#define CHECK      \
	if (!*this) {  \
		return {}; \
	}

#define CAST_BUF(var) (reinterpret_cast< unsigned char * >(var))
#define CAST_BUF_CONST(var) (reinterpret_cast< const unsigned char * >(var))
#define CAST_SIZE(var) (static_cast< int >(var))

using namespace mumble;

using P = Crypt::P;

Crypt::Crypt(Crypt &&crypt) : m_p(std::exchange(crypt.m_p, nullptr)) {
}

Crypt::Crypt() : m_p(new P) {
}

Crypt::~Crypt() = default;

Crypt::operator bool() const {
	return m_p && *m_p;
}

Crypt &Crypt::operator=(Crypt &&crypt) {
	m_p = std::exchange(crypt.m_p, nullptr);
	return *this;
}

void *Crypt::handle() const {
	CHECK

	return m_p->m_ctx;
}

std::string_view Crypt::cipher() const {
	CHECK

	return m_p->cipher();
}

bool Crypt::setCipher(const std::string_view name) {
	CHECK

	return m_p->setCipher(name);
}

uint32_t Crypt::blockSize() const {
	CHECK

	return m_p->blockSize();
}

uint32_t Crypt::keySize() const {
	CHECK

	return static_cast< uint32_t >(m_p->m_key.size());
}

uint32_t Crypt::nonceSize() const {
	CHECK

	return static_cast< uint32_t >(m_p->m_nonce.size());
}

BufViewConst Crypt::key() const {
	CHECK

	return m_p->m_key;
}

Buf Crypt::genKey() const {
	const auto size = keySize();
	if (!size) {
		return {};
	}

	Buf key(size);
	if (EVP_CIPHER_CTX_rand_key(m_p->m_ctx, CAST_BUF(key.data())) <= 0) {
		return {};
	}

	return key;
}

bool Crypt::setKey(const BufViewConst key) {
	CHECK

	if (m_p->m_key.size() != key.size()) {
		if (EVP_CIPHER_CTX_set_key_length(m_p->m_ctx, CAST_SIZE(key.size())) <= 0) {
			return false;
		}

		m_p->m_key.resize(key.size());
	}

	m_p->m_key.assign(key.begin(), key.end());

	return EVP_CipherInit_ex(m_p->m_ctx, nullptr, nullptr, CAST_BUF_CONST(key.data()), nullptr, -1) > 0;
}

BufViewConst Crypt::nonce() const {
	CHECK

	return m_p->m_nonce;
}

Buf Crypt::genNonce() const {
	const auto size = nonceSize();
	if (!size) {
		return {};
	}

	Buf nonce(size);
	if (RAND_priv_bytes(CAST_BUF(nonce.data()), CAST_SIZE(nonce.size())) <= 0) {
		return {};
	}

	return nonce;
}

bool Crypt::setNonce(const BufViewConst nonce) {
	CHECK

	if (m_p->m_nonce.size() != nonce.size()) {
		if (EVP_CIPHER_CTX_ctrl(m_p->m_ctx, EVP_CTRL_AEAD_SET_IVLEN, CAST_SIZE(nonce.size()), nullptr) <= 0) {
			return false;
		}

		m_p->m_nonce.resize(nonce.size());
	}

	m_p->m_nonce.assign(nonce.begin(), nonce.end());

	return EVP_CipherInit_ex(m_p->m_ctx, nullptr, nullptr, nullptr, CAST_BUF_CONST(nonce.data()), -1) > 0;
}

bool Crypt::usesPadding() const {
	return m_p->m_padding;
}

bool Crypt::togglePadding(const bool enable) {
	CHECK

	m_p->m_padding = enable;

	return true;
}

bool Crypt::reset() {
	CHECK

	return EVP_CIPHER_CTX_reset(m_p->m_ctx) > 0;
}

size_t Crypt::decrypt(const BufView out, const BufViewConst in, const BufViewConst tag, const BufViewConst aad) {
	CHECK

	return m_p->process(false, out, in, { const_cast< std::byte * >(tag.data()), tag.size() }, aad);
}

size_t Crypt::encrypt(const BufView out, const BufViewConst in, const BufView tag, const BufViewConst aad) {
	CHECK

	return m_p->process(true, out, in, tag, aad);
}

P::P() : m_padding(true), m_ctx(EVP_CIPHER_CTX_new()) {
	if (m_ctx) {
		setCipher();
	}
}

P::~P() {
	if (m_ctx) {
		EVP_CIPHER_CTX_free(m_ctx);
	}
}

P::operator bool() {
	return m_ctx && EVP_CIPHER_CTX_cipher(m_ctx);
}

uint32_t P::blockSize() const {
	const int size = EVP_CIPHER_CTX_block_size(m_ctx);
	return size >= 0 ? static_cast< uint32_t >(size) : 0;
}

std::string_view P::cipher() {
	const auto cipher = EVP_CIPHER_CTX_cipher(m_ctx);
	if (cipher == EVP_enc_null()) {
		return {};
	}

	return EVP_CIPHER_name(cipher);
}

bool P::setCipher(const std::string_view name) {
	const auto cipher = name.empty() ? EVP_enc_null() : EVP_get_cipherbyname(name.data());
	if (!cipher) {
		return false;
	}

	if (EVP_CipherInit_ex(m_ctx, cipher, nullptr, nullptr, nullptr, -1) <= 0) {
		return false;
	}

	m_key.resize(static_cast< std::size_t >(EVP_CIPHER_CTX_key_length(m_ctx)));
	m_nonce.resize(static_cast< std::size_t >(EVP_CIPHER_CTX_iv_length(m_ctx)));

	m_key   = {};
	m_nonce = {};

	return true;
}

size_t P::process(const bool encrypt, const BufView out, const BufViewConst in, const BufView tag,
				  const BufViewConst aad) {
	if (!out.size()) {
		if (m_padding) {
			const auto size = blockSize();
			return size > 1 ? in.size() + size : in.size();
		} else {
			return in.size();
		}
	}

	if (static_cast< bool >(EVP_CIPHER_CTX_encrypting(m_ctx)) == encrypt) {
		if (EVP_CipherInit_ex(m_ctx, nullptr, nullptr, nullptr, nullptr, encrypt) <= 0) {
			return {};
		}
	} else {
		// Certain cipher implementations require resetting the key, nonce or both when switching operation mode.
		// Not doing so doesn't cause any apparent failure, until you realize the output is messed up.
		if (EVP_CipherInit_ex(m_ctx, nullptr, nullptr, CAST_BUF_CONST(m_key.data()), CAST_BUF_CONST(m_nonce.data()),
							  encrypt)
			<= 0) {
			return {};
		}
	}

	if (EVP_CIPHER_CTX_set_padding(m_ctx, m_padding) <= 0) {
		return {};
	}

	if (!encrypt && !tag.empty()) {
		if (EVP_CIPHER_CTX_ctrl(m_ctx, EVP_CTRL_AEAD_SET_TAG, CAST_SIZE(tag.size()), tag.data()) <= 0) {
			return {};
		}
	}

	int written1;

	if (!aad.empty()) {
		if (EVP_CipherUpdate(m_ctx, nullptr, &written1, CAST_BUF_CONST(aad.data()), CAST_SIZE(aad.size())) <= 0) {
			return {};
		}
	}

	if (EVP_CipherUpdate(m_ctx, CAST_BUF(out.data()), &written1, CAST_BUF_CONST(in.data()), CAST_SIZE(in.size()))
		<= 0) {
		return {};
	}

	int written2;

	if (EVP_CipherFinal_ex(m_ctx, CAST_BUF(out.data() + written1), &written2) <= 0) {
		return {};
	}

	if (encrypt && !tag.empty()) {
		if (EVP_CIPHER_CTX_ctrl(m_ctx, EVP_CTRL_AEAD_GET_TAG, CAST_SIZE(tag.size()), tag.data()) <= 0) {
			return {};
		}
	}

	assert(written1 >= 0);
	assert(written2 >= 0);
	return static_cast< std::size_t >(written1 + written2);
}
