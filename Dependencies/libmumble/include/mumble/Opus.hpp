// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_OPUS_HPP
#define MUMBLE_OPUS_HPP

#include "Macros.hpp"
#include "Types.hpp"

#include <memory>

namespace mumble {
class MUMBLE_EXPORT Opus {
public:
	class Decoder;
	class Encoder;

	using FloatView        = std::span< float >;
	using FloatViewConst   = std::span< const float >;
	using IntegerView      = std::span< int16_t >;
	using IntegerViewConst = std::span< const int16_t >;

	virtual explicit operator bool() const = 0;

	virtual uint8_t channels() const    = 0;
	virtual uint32_t sampleRate() const = 0;

	virtual bool inDTX() const = 0;

	virtual bool usesPhaseInversion() const              = 0;
	virtual bool togglePhaseInversion(const bool enable) = 0;

	static uint8_t packetChannels(const BufViewConst packet);
	static uint32_t packetEncodedFrames(const BufViewConst packet);
	static uint32_t packetFrames(const BufViewConst packet, const uint32_t sampleRate);
	static uint32_t packetFramesPerEncodedFrame(const BufViewConst packet, const uint32_t sampleRate);
};

class MUMBLE_EXPORT Opus::Decoder : public Opus {
public:
	class P;

	Decoder(Decoder &&decoder);
	Decoder(const uint8_t channels);
	virtual ~Decoder();

	virtual explicit operator bool() const override;

	virtual FloatView operator()(const FloatView out, const BufViewConst in, const bool decodeFEC = false);
	virtual IntegerView operator()(const IntegerView out, const BufViewConst in, const bool decodeFEC = false);

	virtual Code init(const uint32_t sampleRate = 48000);
	virtual Code reset();

	virtual uint8_t channels() const override;
	virtual uint32_t sampleRate() const override;

	virtual bool inDTX() const override;

	virtual bool usesPhaseInversion() const override;
	virtual bool togglePhaseInversion(const bool enable) override;

	virtual uint32_t packetFrames(const BufViewConst packet);

private:
	std::unique_ptr< P > m_p;
};

class MUMBLE_EXPORT Opus::Encoder : public Opus {
public:
	enum class Preset : uint8_t { Unknown, VoIP, Audio, LowDelay };

	class P;

	Encoder(Encoder &&encoder);
	Encoder(const uint8_t channels);
	virtual ~Encoder();

	virtual explicit operator bool() const override;

	virtual BufView operator()(const BufView out, const FloatViewConst in);
	virtual BufView operator()(const BufView out, const IntegerViewConst in);

	virtual Code init(const uint32_t sampleRate = 48000, const Preset preset = Preset::VoIP);
	virtual Code reset();

	virtual uint8_t channels() const override;
	virtual uint32_t sampleRate() const override;

	virtual Preset preset() const;
	virtual bool setPreset(const Preset preset);

	virtual uint32_t bitrate() const;
	virtual bool setBitrate(const uint32_t bitrate);

	virtual bool inDTX() const override;

	virtual bool usesPhaseInversion() const override;
	virtual bool togglePhaseInversion(const bool enable) override;

	virtual bool usesVBR() const;
	virtual bool toggleVBR(const bool enable);

private:
	std::unique_ptr< P > m_p;
};
} // namespace mumble

#endif
