// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_CRYPT_HPP
#define MUMBLE_CRYPT_HPP

#include "Macros.hpp"
#include "Types.hpp"

#include <memory>

namespace mumble {
class MUMBLE_EXPORT Crypt {
public:
	class P;

	Crypt(Crypt &&crypt);
	Crypt();
	virtual ~Crypt();

	virtual explicit operator bool() const;

	virtual Crypt &operator=(Crypt &&crypt);

	virtual void *handle() const;

	virtual std::string_view cipher() const;
	virtual bool setCipher(const std::string_view name);

	virtual uint32_t blockSize() const;
	virtual uint32_t keySize() const;
	virtual uint32_t nonceSize() const;

	virtual BufViewConst key() const;
	virtual Buf genKey() const;
	virtual bool setKey(const BufViewConst key);

	virtual BufViewConst nonce() const;
	virtual Buf genNonce() const;
	virtual bool setNonce(const BufViewConst nonce);

	virtual bool usesPadding() const;
	virtual bool togglePadding(const bool enable);

	virtual bool reset();

	virtual size_t decrypt(const BufView out, const BufViewConst in, const BufViewConst tag = {},
						   const BufViewConst aad = {});
	virtual size_t encrypt(const BufView out, const BufViewConst in, const BufView tag = {},
						   const BufViewConst aad = {});

private:
	std::unique_ptr< P > m_p;
};
} // namespace mumble

#endif
