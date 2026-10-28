// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#include "ThreadManager.hpp"

#include "mumble/Opus.hpp"
#include "mumble/Types.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <vector>

#include <boost/thread/interruption.hpp>

static constexpr size_t iterations = 1000;

static constexpr uint32_t sampleRate = 48000;

static constexpr std::array< uint16_t, 6 > bufferSamples = { 120, 240, 480, 960, 1920, 2880 };

using namespace mumble;

template< typename T > static bool initOpus(T &opus) {
	const auto code = opus.init(sampleRate);
	if (code != Code::Success) {
		printf("Failed to init Opus with error \"%s\"!\n", text(code).data());
		return false;
	}

	return true;
}

template< typename T > static constexpr T toView(const BufView buf, const uint32_t samples) {
	return { reinterpret_cast< typename T::value_type * >(buf.data()), samples };
}

static uint8_t thread(const uint8_t channels) {
	using FView = Opus::FloatView;
	using IView = Opus::IntegerView;

	Opus::Decoder decoder(channels);
	if (!initOpus(decoder)) {
		return 1;
	}

	Opus::Encoder encoder(channels);
	if (!initOpus(encoder)) {
		return 2;
	}

	for (size_t i = 0; i < iterations; ++i) {
		if (boost::this_thread::interruption_requested()) {
			return 0;
		}

		Buf in(sizeof(float) * bufferSamples.back() * channels);
		Buf out(in.size());

		for (const auto frames : bufferSamples) {
			const uint32_t samples = frames * channels;

			auto encoded = encoder(out, toView< FView >(in, samples));
			if (!encoded.size()) {
				return 3;
			}

			if (!decoder(toView< FView >(out, samples), encoded).size()) {
				return 4;
			}

			encoded = encoder(out, toView< IView >(in, samples));
			if (!encoded.size()) {
				return 5;
			}

			if (!decoder(toView< IView >(out, samples), encoded).size()) {
				return 6;
			}
		}
	}

	return 0;
}

int32_t main() {
	int32_t ret = 0;

	ThreadManager manager;

	for (uint8_t i = 0; i < 2; ++i) {
		const ThreadManager::ThreadFunc func = [&ret, &manager, i]() {
			const auto threadRet = thread(i + 1);
			if (threadRet != 0) {
				ret = threadRet;
				manager.requestStop();
			}
		};

		manager.add(func);
	}

	manager.wait();

	return ret;
}
