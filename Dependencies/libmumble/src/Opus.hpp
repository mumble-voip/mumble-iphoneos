// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_SRC_OPUS_HPP
#define MUMBLE_SRC_OPUS_HPP

#include "mumble/Opus.hpp"

#include <cstddef>
#include <cstdint>
#include <memory>

struct OpusDecoder;
struct OpusEncoder;

namespace mumble {
template< typename T > class OpusBase {
public:
	OpusBase(const uint8_t channels);

	explicit operator bool();

	template< typename R > bool get(const int32_t request, R *value);
	template< typename R > bool set(const int32_t request, const R value);

protected:
	struct Destructor {
		void operator()(T *ctx) {
			auto bytes = reinterpret_cast< std::byte * >(ctx);
			delete[] bytes;
		}
	};

	bool m_inited;
	uint8_t m_channels;
	std::unique_ptr< T, Destructor > m_ctx;
};

class Opus::Decoder::P : public OpusBase< ::OpusDecoder > {
	friend Opus::Decoder;

public:
	P(const uint8_t channels);
	~P() = default;
};

class Opus::Encoder::P : public OpusBase< ::OpusEncoder > {
	friend Opus::Encoder;

public:
	P(const uint8_t channels);
	~P() = default;

	static int32_t toApplication(const Preset preset);
	static Preset toPreset(const int32_t application);
};
} // namespace mumble

#endif
