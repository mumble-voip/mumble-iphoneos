// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#include "ThreadManager.hpp"

#include "mumble/Crypt.hpp"
#include "mumble/CryptOCB2.hpp"
#include "mumble/Types.hpp"

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <random>
#include <span>
#include <vector>

#include <boost/thread/interruption.hpp>

static constexpr size_t iterations = 100000;

static constexpr size_t minBufSize = 1;
static constexpr size_t maxBufSize = 1024;

using namespace mumble;

static size_t bufSize(std::mt19937 &algorithm) {
	std::uniform_int_distribution< size_t > gen(minBufSize, maxBufSize);
	return gen(algorithm);
}

template< typename T > static uint8_t test(T &crypt, const BufViewConst in) {
	if (!crypt.setKey(crypt.genKey())) {
		return 10;
	}

	if (!crypt.setNonce(crypt.genNonce())) {
		return 11;
	}

	Buf out(crypt.encrypt({}, in));
	Buf tag(crypt.blockSize());

	auto written = crypt.encrypt(out, in, tag);
	if (!written) {
		return 12;
	}

	written = crypt.decrypt(out, out, tag);
	if (!written) {
		return 13;
	}

	if (!std::equal(out.cbegin(), out.cend(), in.begin())) {
		return 14;
	}

	return 0;
}

static uint8_t thread() {
	Crypt cryptChaCha20;
	if (!cryptChaCha20.setCipher("ChaCha20-Poly1305")) {
		return 1;
	}

	Crypt cryptGCM;
	if (!cryptGCM.setCipher("AES-256-GCM")) {
		return 2;
	}

	CryptOCB2 cryptOCB2;

	std::random_device device;
	std::mt19937 algorithm(device());

	for (size_t i = 0; i < iterations; ++i) {
		if (boost::this_thread::interruption_requested()) {
			return 0;
		}

		std::vector< std::byte > in(bufSize(algorithm));

		std::generate(in.begin(), in.end(), [&algorithm]() {
			// We use < uint16_t > because the minimum size allowed is 2 bytes.
			std::uniform_int_distribution< uint16_t > gen(0, UINT8_MAX);
			return static_cast< std::byte >(gen(algorithm));
		});

		auto ret = test(cryptChaCha20, in);
		if (ret != 0) {
			return ret;
		}

		ret = test(cryptGCM, in);
		if (ret != 0) {
			return ret;
		}

		ret = test(cryptOCB2, in);
		if (ret != 0) {
			return ret;
		}
	}

	return 0;
}

int32_t main() {
	int32_t ret = 0;

	ThreadManager manager;

	for (uint32_t i = 0; i < manager.physicalNum(); ++i) {
		const ThreadManager::ThreadFunc func = [&ret, &manager]() {
			const auto threadRet = thread();
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
