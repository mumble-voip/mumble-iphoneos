// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_TYPES_HPP
#define MUMBLE_TYPES_HPP

// For "include-what-you-use":
// https://github.com/include-what-you-use/include-what-you-use/issues/828
namespace mumble {}

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint> // TODO: Drop and use `std::` with fixed-width integers.
#include <limits>
#include <span>
#include <string_view>
#include <vector>

namespace mumble {
enum class Code : int8_t {
	Ssl = -12,
	Refuse,
	Reach,
	Listen,
	Open,
	Unsupport,
	Invalid,
	Init,
	Timeout,
	Memory,
	Failure,
	Unknown,
	Success,
	Cancel,
	Retry,
	Busy,
	Disconnect
};

struct Version {
	uint16_t major;
	uint16_t minor;
	uint16_t patch;
	uint16_t extra;

	Version(const uint16_t major = 0, const uint16_t minor = 0, const uint16_t patch = 0, const uint16_t extra = 0)
		: major(major), minor(minor), patch(patch), extra(extra) {}

	Version(const uint64_t blob)
		: Version(static_cast< uint16_t >((blob & maskMajor64) >> offsetMajor64),
				  static_cast< uint16_t >((blob & maskMinor64) >> offsetMinor64),
				  static_cast< uint16_t >((blob & maskPatch64) >> offsetPatch64),
				  static_cast< uint16_t >((blob & maskExtra64) >> offsetExtra64)) {}

	Version(const uint32_t blob)
		: Version(static_cast< uint16_t >((blob & maskMajor32) >> offsetMajor32),
				  static_cast< uint16_t >((blob & maskMinor32) >> offsetMinor32),
				  static_cast< uint16_t >((blob & maskPatch32) >> offsetPatch32)) {}

	uint64_t blob64() const {
		return (static_cast< uint64_t >(major) << offsetMajor64) | (static_cast< uint64_t >(minor) << offsetMinor64)
			   | (static_cast< uint64_t >(patch) << offsetPatch64) | (static_cast< uint64_t >(extra) << offsetExtra64);
	}

	uint32_t blob32() const {
		return (std::min< uint32_t >(major, std::numeric_limits< uint16_t >::max()) << offsetMajor32)
			   | (std::min< uint32_t >(minor, std::numeric_limits< uint8_t >::max()) << offsetMinor32)
			   | (std::min< uint32_t >(patch, std::numeric_limits< uint8_t >::max()) << offsetPatch32);
	}

	constexpr bool isValid() const { return (major | minor | patch | extra) != 0; }

	static constexpr auto maskMajor64 = 0xFFFF000000000000;
	static constexpr auto maskMinor64 = 0xFFFF00000000;
	static constexpr auto maskPatch64 = 0xFFFF0000;
	static constexpr auto maskExtra64 = 0xFFFF;
	static constexpr auto maskMajor32 = 0xFFFF0000;
	static constexpr auto maskMinor32 = 0xFF00;
	static constexpr auto maskPatch32 = 0xFF;

	static constexpr auto offsetMajor64 = 48;
	static constexpr auto offsetMinor64 = 32;
	static constexpr auto offsetPatch64 = 16;
	static constexpr auto offsetExtra64 = 0;
	static constexpr auto offsetMajor32 = 16;
	static constexpr auto offsetMinor32 = 8;
	static constexpr auto offsetPatch32 = 0;
};

using Buf          = std::vector< std::byte >;
using BufView      = std::span< std::byte >;
using BufViewConst = std::span< const std::byte >;

template< size_t size > using FixedBuf = std::array< std::byte, size >;

static constexpr std::string_view text(const Code code) {
	switch (code) {
		case Code::Ssl:
			return "Ssl";
		case Code::Refuse:
			return "Refuse";
		case Code::Reach:
			return "Reach";
		case Code::Listen:
			return "Listen";
		case Code::Open:
			return "Open";
		case Code::Unsupport:
			return "Unsupport";
		case Code::Invalid:
			return "Invalid";
		case Code::Init:
			return "Init";
		case Code::Timeout:
			return "Timeout";
		case Code::Memory:
			return "Memory";
		case Code::Failure:
			return "Failure";
		case Code::Unknown:
			return "Unknown";
		case Code::Success:
			return "Success";
		case Code::Cancel:
			return "Cancel";
		case Code::Retry:
			return "Retry";
		case Code::Busy:
			return "Busy";
		case Code::Disconnect:
			return "Disconnect";
	}

	return {};
}

static constexpr std::byte toByte(const char byte) {
	return static_cast< std::byte >(byte);
}

static inline void toBuf(Buf &buf, const std::string_view str) {
	buf.resize(str.size());
	std::transform(str.cbegin(), str.cend(), buf.begin(), toByte);
}

} // namespace mumble

#endif
