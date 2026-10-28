// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_ENDIAN_HPP
#define MUMBLE_ENDIAN_HPP

#include "Macros.hpp"

#include <cstdint>

#ifdef MUMBLE_COMPILER_MSVC
#	include <cstdlib>
#endif

namespace mumble {
class Endian {
public:
	static constexpr bool isBig() { return SingleSplit64(0x0102030405060708).split[0] == 1; }
	static constexpr bool isLittle() { return SingleSplit64(0x0102030405060708).split[0] == 8; }
#ifdef MUMBLE_COMPILER_MSVC
	static uint16_t swap(const uint16_t value) {
		return _byteswap_ushort(value);
#else
	static constexpr uint16_t swap(const uint16_t value) {
		return __builtin_bswap16(value);
#endif
	}
#ifdef MUMBLE_COMPILER_MSVC
	static uint32_t swap(const uint32_t value) {
		return _byteswap_ulong(value);
#else
	static constexpr uint32_t swap(const uint32_t value) {
		return __builtin_bswap32(value);
#endif
	}
#ifdef MUMBLE_COMPILER_MSVC
	static uint64_t swap(const uint64_t value) {
		return _byteswap_uint64(value);
#else
	static constexpr uint64_t swap(const uint64_t value) {
		return __builtin_bswap64(value);
#endif
	}

	static constexpr uint16_t toNetwork(const uint16_t value) { return isBig() ? value : swap(value); }
	static constexpr uint32_t toNetwork(const uint32_t value) { return isBig() ? value : swap(value); }
	static constexpr uint64_t toNetwork(const uint64_t value) { return isBig() ? value : swap(value); }

	static constexpr uint16_t toHost(const uint16_t value) { return isBig() ? value : swap(value); }
	static constexpr uint32_t toHost(const uint32_t value) { return isBig() ? value : swap(value); }
	static constexpr uint64_t toHost(const uint64_t value) { return isBig() ? value : swap(value); }

private:
	union SingleSplit64 {
		uint64_t single;
		uint8_t split[sizeof(single)];

		constexpr SingleSplit64(const uint64_t value) : single(value) {}
	};
};
} // namespace mumble

#endif
