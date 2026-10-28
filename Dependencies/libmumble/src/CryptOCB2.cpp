// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#include "CryptOCB2.hpp"

#include "mumble/Endian.hpp"

#include <algorithm>
#include <cassert>
#include <cstring>
#include <memory>
#include <span>

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

using P = CryptOCB2::P;

using KeyBlock          = P::KeyBlock;
using KeyBlockView      = P::KeyBlockView;
using KeyBlockViewConst = P::KeyBlockViewConst;
using SubBlock          = P::SubBlock;

CryptOCB2::CryptOCB2() : m_p(new P) {
}

CryptOCB2::~CryptOCB2() = default;

CryptOCB2::operator bool() const {
	return m_p && m_p->m_ok;
}

uint32_t CryptOCB2::blockSize() const {
	CHECK

	return P::blockSize;
}

uint32_t CryptOCB2::keySize() const {
	CHECK

	return P::keySize;
}

uint32_t CryptOCB2::nonceSize() const {
	CHECK

	return P::nonceSize;
}

BufViewConst CryptOCB2::key() const {
	CHECK

	return m_p->m_key;
}

Buf CryptOCB2::genKey() const {
	CHECK

	Buf key(P::keySize);
	if (EVP_CIPHER_CTX_rand_key(m_p->m_ctx, CAST_BUF(key.data())) <= 0) {
		return {};
	}

	return key;
}

bool CryptOCB2::setKey(const BufViewConst key) {
	CHECK

	if (key.size() != P::keySize) {
		return false;
	}

	std::copy(key.begin(), key.end(), m_p->m_key.begin());

	return EVP_CipherInit_ex(m_p->m_ctx, nullptr, nullptr, CAST_BUF_CONST(key.data()), nullptr, -1) > 0;
}

BufViewConst CryptOCB2::nonce() const {
	CHECK

	return m_p->m_nonce;
}

Buf CryptOCB2::genNonce() const {
	CHECK

	Buf nonce(P::nonceSize);
	if (RAND_priv_bytes(CAST_BUF(nonce.data()), CAST_SIZE(nonce.size())) <= 0) {
		return {};
	}

	return nonce;
}

bool CryptOCB2::setNonce(const BufViewConst nonce) {
	CHECK

	if (nonce.size() != P::nonceSize) {
		return false;
	}

	std::copy(nonce.begin(), nonce.end(), m_p->m_nonce.begin());

	return true;
}

size_t CryptOCB2::decrypt(BufView out, BufViewConst in, const BufViewConst tag) {
	CHECK

	if (!out.size()) {
		return in.size();
	}
	if (out.size() < in.size() || tag.size() > P::blockSize) {
		return {};
	}

	KeyBlock delta;
	const auto deltaBytes = std::as_writable_bytes(KeyBlockView(delta));

	if (!m_p->process(true, deltaBytes, m_p->m_nonce)) {
		return {};
	}

	size_t written = 0;

	KeyBlock checksum{}, tmp;
	const auto tmpBytes = std::as_writable_bytes(KeyBlockView(tmp));

	while (in.size() > P::blockSize) {
		P::s2(delta);
		P::xorBlock(tmp, delta, P::toBlockView(in));

		if (!m_p->process(false, tmpBytes, tmpBytes)) {
			return {};
		}

		P::xorBlock(P::toBlockView(out), delta, tmp);
		written += P::blockSize;

		P::xorBlock(checksum, checksum, P::toBlockView(out));

		in  = in.subspan(P::blockSize);
		out = out.subspan(P::blockSize);
	}

	P::s2(delta);

	tmp        = {};
	tmp.back() = Endian::swap(static_cast< SubBlock >(in.size() * 8));
	P::xorBlock(tmp, tmp, delta);

	KeyBlock pad;
	const auto padBytes = std::as_writable_bytes(KeyBlockView(pad));

	if (!m_p->process(true, padBytes, tmpBytes)) {
		return {};
	}

	tmp = {};
	std::copy(in.begin(), in.end(), tmpBytes.begin());
	P::xorBlock(tmp, tmp, pad);
	P::xorBlock(checksum, checksum, tmp);

	// Counter-cryptanalysis described in section 9 of https://eprint.iacr.org/2019/311
	// In an attack, the decrypted last block would need to equal `delta ^ len(128)`.
	// With a bit of luck (or many packets), smaller values than 128 (i.e. non-full blocks) are also
	// feasible, so we check `tmp` instead of `plain`.
	// Since our `len` only ever modifies the last byte, we simply check all remaining ones.
	if (std::equal(tmpBytes.begin(), tmpBytes.begin() + P::blockSize - 1, deltaBytes.begin())) {
		return {};
	}

	std::copy_n(tmpBytes.begin(), in.size(), out.begin());
	written += in.size();

	if (tag.empty()) {
		return written;
	}

	P::s3(delta);
	P::xorBlock(tmp, delta, checksum);

	Buf retrievedTag(P::blockSize);
	if (!m_p->process(true, retrievedTag, tmpBytes)) {
		return {};
	}

	if (CRYPTO_memcmp(tag.data(), retrievedTag.data(), tag.size()) != 0) {
		return {};
	}

	return written;
}

size_t CryptOCB2::encrypt(BufView out, BufViewConst in, const BufView tag) {
	CHECK

	if (!out.size()) {
		return in.size();
	}

	if (out.size() < in.size() || (!tag.empty() && tag.size() != P::blockSize)) {
		return {};
	}

	KeyBlock delta;
	if (!m_p->process(true, std::as_writable_bytes(KeyBlockView(delta)), m_p->m_nonce)) {
		return {};
	}

	size_t written = 0;

	KeyBlock checksum{}, tmp;
	const auto tmpBytes = std::as_writable_bytes(KeyBlockView(tmp));

	while (in.size() > P::blockSize) {
		// Counter-cryptanalysis described in section 9 of https://eprint.iacr.org/2019/311
		// For an attack, the second to last block (i.e. the last iteration of this loop)
		// must be all 0 except for the last byte (which may be 0 - 128).
		bool flipABit = false;

		if (in.size() - P::blockSize <= P::blockSize) {
			uint8_t sum = 0;

			for (uint8_t i = 0; i < P::blockSize - 1; ++i) {
				sum |= static_cast< uint8_t >(in[i]);
			}

			if (!sum) {
				// The assumption that critical packets do not turn up by pure chance turned out to be incorrect
				// since digital silence appears to produce them in mass.
				// So instead we now modify the packet in a way which should not affect the audio but will
				// prevent the attack.
				flipABit = true;
			}
		}

		P::s2(delta);
		P::xorBlock(tmp, delta, P::toBlockView(in));

		if (flipABit) {
			*reinterpret_cast< uint8_t * >(tmp.data()) ^= 1;
		}

		if (!m_p->process(true, tmpBytes, tmpBytes)) {
			return {};
		}

		P::xorBlock(P::toBlockView(out), delta, tmp);
		written += P::blockSize;

		P::xorBlock(checksum, checksum, P::toBlockView(in));

		if (flipABit) {
			*reinterpret_cast< uint8_t * >(checksum.data()) ^= 1;
		}

		in  = in.subspan(P::blockSize);
		out = out.subspan(P::blockSize);
	}

	P::s2(delta);

	tmp        = {};
	tmp.back() = Endian::swap(static_cast< SubBlock >(in.size() * 8));
	P::xorBlock(tmp, tmp, delta);

	KeyBlock pad;
	const auto padBytes = std::as_writable_bytes(KeyBlockView(pad));

	if (!m_p->process(true, padBytes, tmpBytes)) {
		return {};
	}

	std::copy(in.begin(), in.end(), tmpBytes.begin());
	std::copy_n(padBytes.begin() + static_cast< long >(in.size()), P::blockSize - in.size(),
				tmpBytes.begin() + static_cast< long >(in.size()));
	m_p->xorBlock(checksum, checksum, tmp);
	m_p->xorBlock(tmp, pad, tmp);

	std::copy_n(tmpBytes.begin(), in.size(), out.begin());
	written += in.size();

	if (tag.empty()) {
		return written;
	}

	P::s3(delta);
	P::xorBlock(tmp, delta, checksum);

	if (!m_p->process(true, tag, tmpBytes)) {
		return {};
	}

	return written;
}

P::P() : m_ok(false), m_key(), m_nonce(), m_ctx(EVP_CIPHER_CTX_new()) {
	if (!m_ctx) {
		return;
	}

	if (EVP_CipherInit_ex(m_ctx, EVP_aes_128_ecb(), nullptr, nullptr, nullptr, -1) <= 0) {
		return;
	}

	if (EVP_CIPHER_CTX_block_size(m_ctx) != blockSize || EVP_CIPHER_CTX_key_length(m_ctx) != keySize) {
		return;
	}

	m_ok = true;
}

P::~P() {
	if (m_ctx) {
		EVP_CIPHER_CTX_free(m_ctx);
	}
}

size_t P::process(const bool encrypt, const BufView out, const BufViewConst in) {
	if (static_cast< bool >(EVP_CIPHER_CTX_encrypting(m_ctx)) == encrypt) {
		if (EVP_CipherInit_ex(m_ctx, nullptr, nullptr, nullptr, nullptr, encrypt) <= 0) {
			return {};
		}
	} else {
		// The AES-128-ECB implementation requires resetting the key when switching operation mode.
		// Not doing so doesn't cause any apparent failure, until you realize the output is messed up.
		if (EVP_CipherInit_ex(m_ctx, nullptr, nullptr, CAST_BUF_CONST(m_key.data()), nullptr, encrypt) <= 0) {
			return {};
		}
	}

	if (EVP_CIPHER_CTX_set_padding(m_ctx, 0) <= 0) {
		return {};
	}

	int written1;

	if (EVP_CipherUpdate(m_ctx, CAST_BUF(out.data()), &written1, CAST_BUF_CONST(in.data()), CAST_SIZE(in.size()))
		<= 0) {
		return {};
	}

	int written2;

	if (EVP_CipherFinal_ex(m_ctx, CAST_BUF(out.data() + written1), &written2) <= 0) {
		return {};
	}

	assert(written1 >= 0);
	assert(written2 >= 0);
	return static_cast< std::size_t >(written1 + written2);
}

void P::xorBlock(const KeyBlockView dst, const KeyBlockViewConst a, const KeyBlockViewConst b) {
	for (uint8_t i = 0; i < subBlocks; ++i) {
		// Datagram payloads start four bytes into their buffer and may not be
		// aligned to SubBlock. Copy instead of dereferencing unaligned integers.
		SubBlock left, right;
		std::memcpy(&left, reinterpret_cast<const std::byte *>(a.data()) + i * sizeof(SubBlock), sizeof(left));
		std::memcpy(&right, reinterpret_cast<const std::byte *>(b.data()) + i * sizeof(SubBlock), sizeof(right));
		const SubBlock value = left ^ right;
		std::memcpy(reinterpret_cast<std::byte *>(dst.data()) + i * sizeof(SubBlock), &value, sizeof(value));
	}
}

void P::s2(const KeyBlockView block) {
	const SubBlock carry = Endian::swap(block[0]) >> shiftBits;

	for (uint8_t i = 0; i < subBlocks - 1; ++i) {
		block[i] = Endian::swap((Endian::swap(block[i]) << 1) | (Endian::swap(block[i + 1]) >> shiftBits));
	}

	block[subBlocks - 1] = Endian::swap((Endian::swap(block[subBlocks - 1]) << 1) ^ (carry * 0x87));
}

void P::s3(const KeyBlockView block) {
	const SubBlock carry = Endian::swap(block[0]) >> shiftBits;

	for (uint8_t i = 0; i < subBlocks - 1; ++i) {
		block[i] ^= Endian::swap((Endian::swap(block[i]) << 1) | (Endian::swap(block[i + 1]) >> shiftBits));
	}

	block[subBlocks - 1] ^= Endian::swap((Endian::swap(block[subBlocks - 1]) << 1) ^ (carry * 0x87));
}

KeyBlockView P::toBlockView(const BufView buf) {
	return KeyBlockView(reinterpret_cast< SubBlock * >(buf.data()), subBlocks);
}

KeyBlockViewConst P::toBlockView(const BufViewConst buf) {
	return KeyBlockViewConst(reinterpret_cast< const SubBlock * >(buf.data()), subBlocks);
}
