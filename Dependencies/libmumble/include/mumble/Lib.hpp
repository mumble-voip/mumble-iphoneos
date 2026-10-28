// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_LIB_HPP
#define MUMBLE_LIB_HPP

#include "Macros.hpp"
#include "Types.hpp"

#include <cstddef>

namespace mumble {
namespace lib {
	MUMBLE_EXPORT Version version();

	MUMBLE_EXPORT Code init();
	MUMBLE_EXPORT Code deinit();
	MUMBLE_EXPORT size_t initCount();
} // namespace lib
} // namespace mumble

#endif
