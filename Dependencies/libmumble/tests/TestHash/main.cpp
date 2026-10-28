// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#include "Data.hpp"
#include "ThreadManager.hpp"

#include "mumble/Hash.hpp"
#include "mumble/Types.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <iomanip>
#include <random>
#include <span>
#include <sstream>
#include <string>
#include <string_view>

#include <boost/thread/interruption.hpp>

static constexpr size_t iterations = 100000;

using namespace mumble;

static std::string toHex(const BufViewConst bytes) {
	std::ostringstream stream;

	stream << std::hex << std::setfill('0');

	for (const auto byte : bytes) {
		stream << std::setw(2) << static_cast< int >(byte);
	}

	return stream.str();
}

static uint8_t test(Hash &hash, const Data::List &list, const size_t index) {
	const auto &input = Data::input[index];
	const BufViewConst in(reinterpret_cast< const std::byte * >(input.data()), input.size());

	Buf digest(hash({}, in));

	if (!hash(digest, in)) {
		return 10;
	}

	if (toHex(digest) != list[index]) {
		return 11;
	}

	return 0;
}

static uint8_t thread() {
	Hash sha2;
	if (!sha2.setType("SHA512")) {
		return 1;
	}

	Hash sha3;
	if (!sha3.setType("SHA3-512")) {
		return 2;
	}

	Hash blake2b;
	if (!blake2b.setType("BLAKE2b512")) {
		return 3;
	}

	std::random_device device;
	std::mt19937 algorithm(device());
	std::uniform_int_distribution< size_t > gen(0, std::tuple_size< Data::List >() - 1);

	for (size_t i = 0; i < iterations; ++i) {
		if (boost::this_thread::interruption_requested()) {
			return 0;
		}

		const auto index = gen(algorithm);

		auto ret = test(sha2, Data::sha2, index);
		if (ret != 0) {
			return ret;
		}

		ret = test(sha3, Data::sha3, index);
		if (ret != 0) {
			return ret;
		}

		ret = test(blake2b, Data::blake2b, index);
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
