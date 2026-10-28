// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_HASH_HPP
#define MUMBLE_HASH_HPP

#include "Macros.hpp"
#include "Types.hpp"

#include <memory>

namespace mumble {
class MUMBLE_EXPORT Hash {
public:
	class P;

	Hash(Hash &&crypt);
	Hash();
	virtual ~Hash();

	virtual explicit operator bool() const;

	virtual Hash &operator=(Hash &&crypt);

	virtual size_t operator()(const BufView out, const BufViewConst in);

	virtual void *handle() const;

	virtual std::string_view type() const;
	virtual bool setType(const std::string_view name);

	virtual uint32_t blockSize() const;

	virtual bool reset();

private:
	Hash(const Hash &)            = delete;
	Hash &operator=(const Hash &) = delete;

	std::unique_ptr< P > m_p;
};
} // namespace mumble

#endif
