// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#include "Opus.hpp"

#include "mumble/Types.hpp"

#include <limits>
#include <utility>

#include <opus.h>
#include <opus_defines.h>
#include <opus_types.h>

#define CHECK      \
	if (!*this) {  \
		return {}; \
	}

#define CAST_BUF(var) (reinterpret_cast< unsigned char * >(var))
#define CAST_BUF_CONST(var) (reinterpret_cast< const unsigned char * >(var))
#define CAST_FPTR(var) (reinterpret_cast< float * >(var))
#define CAST_FPTR_CONST(var) (reinterpret_cast< const float * >(var))
#define CAST_IPTR(var) (reinterpret_cast< opus_int16 * >(var))
#define CAST_IPTR_CONST(var) (reinterpret_cast< const opus_int16 * >(var))
#define CAST_SIZE(var) (static_cast< opus_int32 >(var))

using namespace mumble;

using Decoder     = Opus::Decoder;
using Encoder     = Opus::Encoder;
using FloatView   = Opus::FloatView;
using IntegerView = Opus::IntegerView;

using Preset = Encoder::Preset;

static constexpr Code interpretLibCode(const int code) {
	switch (code) {
		case OPUS_OK:
			return Code::Success;
		case OPUS_UNIMPLEMENTED:
			return Code::Unsupport;
		case OPUS_BAD_ARG:
		case OPUS_INVALID_PACKET:
		case OPUS_INVALID_STATE:
			return Code::Invalid;
		case OPUS_ALLOC_FAIL:
		case OPUS_BUFFER_TOO_SMALL:
			return Code::Memory;
		case OPUS_INTERNAL_ERROR:
			return Code::Failure;
	}

	return Code::Unknown;
}

uint8_t Opus::packetChannels(const BufViewConst packet) {
	const auto ret = opus_packet_get_nb_channels(CAST_BUF_CONST(packet.data()));
	return ret >= 0 ? static_cast< uint8_t >(ret) : 0;
}

uint32_t Opus::packetEncodedFrames(const BufViewConst packet) {
	const int ret = opus_packet_get_nb_frames(CAST_BUF_CONST(packet.data()), CAST_SIZE(packet.size()));
	return ret >= 0 ? static_cast< uint32_t >(ret) : 0;
}

uint32_t Opus::packetFrames(const BufViewConst packet, const uint32_t sampleRate) {
	const int ret = opus_packet_get_nb_samples(CAST_BUF_CONST(packet.data()), CAST_SIZE(packet.size()),
											   static_cast< int32_t >(sampleRate));
	return ret >= 0 ? static_cast< uint32_t >(ret) : 0;
}

uint32_t Opus::packetFramesPerEncodedFrame(const BufViewConst packet, const uint32_t sampleRate) {
	const int ret =
		opus_packet_get_samples_per_frame(CAST_BUF_CONST(packet.data()), static_cast< int32_t >(sampleRate));
	return ret >= 0 ? static_cast< uint32_t >(ret) : 0;
}

Decoder::Decoder(Decoder &&decoder) : m_p(std::exchange(decoder.m_p, nullptr)) {
}

Decoder::Decoder(const uint8_t channels) : m_p(new P(channels)) {
}

Decoder::~Decoder() = default;

Decoder::operator bool() const {
	return m_p && *m_p;
}

FloatView Decoder::operator()(const FloatView out, const BufViewConst in, const bool decodeFEC) {
	const auto samples = static_cast< int >(out.size() / m_p->m_channels);

	const int written = opus_decode_float(m_p->m_ctx.get(), CAST_BUF_CONST(in.data()), CAST_SIZE(in.size()),
										  CAST_FPTR(out.data()), samples, decodeFEC);

	return written >= 0 ? FloatView(out.data(), static_cast< std::size_t >(written) * m_p->m_channels) : FloatView();
}

IntegerView Decoder::operator()(const IntegerView out, const BufViewConst in, const bool decodeFEC) {
	const auto samples = static_cast< int >(out.size() / m_p->m_channels);

	const int written = opus_decode(m_p->m_ctx.get(), CAST_BUF_CONST(in.data()), CAST_SIZE(in.size()),
									CAST_IPTR(out.data()), samples, decodeFEC);

	return written >= 0 ? IntegerView(out.data(), static_cast< std::size_t >(written) * m_p->m_channels)
						: IntegerView();
}

Code Decoder::init(const uint32_t sampleRate) {
	const Code ret =
		interpretLibCode(opus_decoder_init(m_p->m_ctx.get(), static_cast< int32_t >(sampleRate), m_p->m_channels));

	if (ret == Code::Success) {
		m_p->m_inited = true;
	}

	return ret;
}

Code Decoder::reset() {
	return interpretLibCode(opus_decoder_ctl(m_p->m_ctx.get(), OPUS_RESET_STATE));
}

uint8_t Decoder::channels() const {
	return m_p->m_channels;
}

uint32_t Decoder::sampleRate() const {
	opus_int32 ret = 0;
	return m_p->get(OPUS_GET_SAMPLE_RATE(&ret)) ? static_cast< uint32_t >(ret) : 0;
}

bool Decoder::inDTX() const {
	opus_int32 ret = 0;
	return m_p->get(OPUS_GET_IN_DTX(&ret)) ? ret : 0;
}

bool Decoder::usesPhaseInversion() const {
	opus_int32 ret = 0;
	return m_p->get(OPUS_GET_PHASE_INVERSION_DISABLED(&ret)) ? !ret : 0;
}

bool Decoder::togglePhaseInversion(const bool enable) {
	return m_p->set(OPUS_SET_PHASE_INVERSION_DISABLED(!enable));
}

uint32_t Decoder::packetFrames(const BufViewConst packet) {
	const int ret =
		opus_decoder_get_nb_samples(m_p->m_ctx.get(), CAST_BUF_CONST(packet.data()), CAST_SIZE(packet.size()));
	return ret >= 0 ? static_cast< uint32_t >(ret) : 0;
}

Decoder::P::P(const uint8_t channels) : OpusBase(channels) {
}

Encoder::Encoder(Encoder &&encoder) : m_p(std::exchange(encoder.m_p, nullptr)) {
}

Encoder::Encoder(const uint8_t channels) : m_p(new P(channels)) {
}

Encoder::~Encoder() = default;

Encoder::operator bool() const {
	return m_p && *m_p;
}

BufView Encoder::operator()(const BufView out, const FloatViewConst in) {
	const auto samples = static_cast< int >(in.size() / m_p->m_channels);

	const int written = opus_encode_float(m_p->m_ctx.get(), CAST_FPTR_CONST(in.data()), samples, CAST_BUF(out.data()),
										  CAST_SIZE(out.size()));

	return written >= 0 ? BufView(out.data(), static_cast< std::size_t >(written)) : BufView();
}

BufView Encoder::operator()(const BufView out, const IntegerViewConst in) {
	const auto samples = static_cast< int >(in.size() / m_p->m_channels);

	const int written =
		opus_encode(m_p->m_ctx.get(), CAST_IPTR_CONST(in.data()), samples, CAST_BUF(out.data()), CAST_SIZE(out.size()));

	return written >= 0 ? BufView(out.data(), static_cast< std::size_t >(written)) : BufView();
}

Code Encoder::init(const uint32_t sampleRate, const Preset preset) {
	const auto application = P::toApplication(preset);
	if (application < 0) {
		return Code::Invalid;
	}

	const Code ret = interpretLibCode(
		opus_encoder_init(m_p->m_ctx.get(), static_cast< int32_t >(sampleRate), m_p->m_channels, application));

	if (ret == Code::Success) {
		m_p->m_inited = true;
	}

	return ret;
}

Code Encoder::reset() {
	return interpretLibCode(opus_encoder_ctl(m_p->m_ctx.get(), OPUS_RESET_STATE));
}

uint8_t Encoder::channels() const {
	return m_p->m_channels;
}

uint32_t Encoder::sampleRate() const {
	opus_int32 ret = 0;
	return m_p->get(OPUS_GET_SAMPLE_RATE(&ret)) ? static_cast< uint32_t >(ret) : 0;
}

Preset Encoder::preset() const {
	opus_int32 ret = 0;
	if (!m_p->get(OPUS_GET_APPLICATION(&ret))) {
		return Preset::Unknown;
	}

	return P::toPreset(ret);
}

bool Encoder::setPreset(const Preset preset) {
	const auto application = P::toApplication(preset);
	if (application < 0) {
		return false;
	}

	return m_p->set(OPUS_SET_APPLICATION(application));
}

uint32_t Encoder::bitrate() const {
	opus_int32 ret = 0;
	return m_p->get(OPUS_GET_BITRATE(&ret)) ? static_cast< uint32_t >(ret) : 0;
}

bool Encoder::setBitrate(const uint32_t bitrate) {
	opus_int32 value;
	if (bitrate == std::numeric_limits< decltype(bitrate) >::max()) {
		value = OPUS_BITRATE_MAX;
	} else if (!bitrate) {
		value = OPUS_AUTO;
	} else {
		value = static_cast< int32_t >(bitrate);
	}

	return m_p->set(OPUS_SET_BITRATE(value));
}

bool Encoder::inDTX() const {
	opus_int32 ret = 0;
	return m_p->get(OPUS_GET_IN_DTX(&ret)) ? ret : 0;
}

bool Encoder::usesPhaseInversion() const {
	opus_int32 ret = 0;
	return m_p->get(OPUS_GET_PHASE_INVERSION_DISABLED(&ret)) ? !ret : 0;
}

bool Encoder::togglePhaseInversion(const bool enable) {
	return m_p->set(OPUS_SET_PHASE_INVERSION_DISABLED(!enable));
}

bool Encoder::usesVBR() const {
	opus_int32 ret = 0;
	return m_p->get(OPUS_GET_VBR(&ret)) ? ret : 0;
}

bool Encoder::toggleVBR(const bool enable) {
	return m_p->set(OPUS_SET_VBR(enable));
}

Encoder::P::P(const uint8_t channels) : OpusBase(channels) {
}

int32_t Encoder::P::toApplication(const Preset preset) {
	switch (preset) {
		case Preset::Unknown:
			break;
		case Preset::VoIP:
			return OPUS_APPLICATION_VOIP;
		case Preset::Audio:
			return OPUS_APPLICATION_AUDIO;
		case Preset::LowDelay:
			return OPUS_APPLICATION_RESTRICTED_LOWDELAY;
	}

	return -1;
}

Preset Encoder::P::toPreset(const int32_t application) {
	switch (application) {
		case OPUS_APPLICATION_VOIP:
			return Preset::VoIP;
		case OPUS_APPLICATION_AUDIO:
			return Preset::Audio;
		case OPUS_APPLICATION_RESTRICTED_LOWDELAY:
			return Preset::LowDelay;
	}

	return Preset::Unknown;
}

template< typename T > OpusBase< T >::OpusBase(const uint8_t channels) : m_inited(false), m_channels(channels) {
	if constexpr (std::is_same_v< T, ::OpusDecoder >) {
		m_ctx.reset(
			reinterpret_cast< T * >(new std::byte[static_cast< std::size_t >(opus_decoder_get_size(channels))]));
	} else if constexpr (std::is_same_v< T, ::OpusEncoder >) {
		m_ctx.reset(
			reinterpret_cast< T * >(new std::byte[static_cast< std::size_t >(opus_encoder_get_size(channels))]));
	} else {
		static_assert(std::is_same_v< T, ::OpusEncoder > && "Invalid template type!");
	}
}

template< typename T > OpusBase< T >::operator bool() {
	return m_inited;
}

template< typename T > template< typename R > bool OpusBase< T >::get(const int32_t request, R *value) {
	CHECK

	if constexpr (std::is_same_v< T, ::OpusDecoder >) {
		return opus_decoder_ctl(m_ctx.get(), request, value) == OPUS_OK;
	}

	if constexpr (std::is_same_v< T, ::OpusEncoder >) {
		return opus_encoder_ctl(m_ctx.get(), request, value) == OPUS_OK;
	}
}

template< typename T > template< typename R > bool OpusBase< T >::set(const int32_t request, const R value) {
	CHECK

	if constexpr (std::is_same_v< T, ::OpusDecoder >) {
		return opus_decoder_ctl(m_ctx.get(), request, value) == OPUS_OK;
	}

	if constexpr (std::is_same_v< T, ::OpusEncoder >) {
		return opus_encoder_ctl(m_ctx.get(), request, value) == OPUS_OK;
	}
}
