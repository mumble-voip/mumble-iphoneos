// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_BASE64_HPP
#define MUMBLE_BASE64_HPP

#include "Macros.hpp"
#include "Types.hpp"

#include <memory>

namespace mumble {
class MUMBLE_EXPORT Base64 {
public:
	class P;

	Base64();
	virtual ~Base64();

	virtual explicit operator bool();

	virtual size_t decode(const BufView out, const BufViewConst in);
	static size_t encode(const BufView out, const BufViewConst in);

private:
	Base64(const Base64 &)            = delete;
	Base64 &operator=(const Base64 &) = delete;

	std::unique_ptr< P > m_p;
};
} // namespace mumble

#endif
