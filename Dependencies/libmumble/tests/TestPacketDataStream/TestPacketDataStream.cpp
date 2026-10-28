// Copyright 2023 The Mumble Developers. All rights reserved.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#include "TestPacketDataStream.hpp"

#include "mumble/PacketDataStream.hpp"

#include <array>
#include <cassert>

using namespace mumble;

static constexpr auto bufferSize = 256;

void TestPacketDataStream::integer() {
	std::array< std::byte, bufferSize > buffer{};

	for (uint8_t i = 0; i < 64; ++i) {
		for (const uint64_t valueOut : { 1ULL << i, ~(1ULL << i) }) {
			uint64_t valueIn;

			PacketDataStream out(buffer);
			out << valueOut;
			PacketDataStream in({ buffer.data(), out.data().size() });
			in >> valueIn;

			assert(valueIn == valueOut);
			assert(in);
			assert(in.seek().empty());
		}
	}
}

void TestPacketDataStream::floating() {
	std::array< std::byte, bufferSize > buffer{};

	for (uint16_t i = 1; i < 256; ++i) {
		for (const double valueOut : { 1.0 / (1.0 * i), 1.0 / (-1.0 * i) }) {
			double valueIn;

			PacketDataStream out(buffer);
			out << valueOut;
			PacketDataStream in({ buffer.data(), out.data().size() });
			in >> valueIn;

			assert(valueIn == valueOut);
			assert(in);
			assert(in.seek().empty());
		}
	}
}

void TestPacketDataStream::string() {
	std::array< std::byte, bufferSize > buffer{};

	for (const auto valueOut :
		 { std::string_view(), std::string_view(""), std::string_view("String"), std::string_view("Bærtur") }) {
		std::string valueIn;

		PacketDataStream out(buffer);
		out << valueOut;
		PacketDataStream in({ buffer.data(), out.data().size() });
		in >> valueIn;

		assert(valueIn == valueOut);
		assert(in);
		assert(in.seek().empty());
	}
}

void TestPacketDataStream::space() {
	std::array< std::byte, bufferSize > buffer;
	buffer.fill(std::byte(0x55));

	PacketDataStream out({ buffer.data(), 1 });

	const int8_t valueOut = -2;

	out << valueOut;
	assert(out);
	assert(out.data().size() == 1);
	assert(out.seek().empty());
	assert(buffer[1] == std::byte(0x55));

	out << valueOut;
	assert(!out);
	assert(out.data().size() == 1);
	assert(out.seek().empty());
	assert(buffer[1] == std::byte(0x55));

	PacketDataStream in({ buffer.data(), 1 });

	int8_t valueIn;

	in >> valueIn;
	assert(valueIn == valueOut);
	assert(in);
	assert(in.data().size() == 1);
	assert(in.seek().empty());

	in >> valueIn;
	assert(!in);
	assert(in.data().size() == 1);
	assert(in.seek().empty());
}

void TestPacketDataStream::undersize() {
	std::array< std::byte, bufferSize > buffer{};

	std::array< std::byte, 32 > data;
	data.fill(std::byte('Z'));

	for (uint8_t i = 0; i < data.size(); ++i) {
		PacketDataStream out({ buffer.data(), i });
		out << data;

		assert(data.size() + 1 - i == out.undersize());
		assert(!out);
		assert(out.seek().empty());
	}

	PacketDataStream out({ buffer.data(), data.size() + 1 });
	out << data;

	assert(out.undersize() == 0);
	assert(out);
	assert(out.seek().empty());
}
