// Copyright 2023 The Mumble Developers. All rights reserved.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#include "TestPacketDataStream.hpp"

int main() {
	TestPacketDataStream::integer();
	TestPacketDataStream::floating();
	TestPacketDataStream::string();
	TestPacketDataStream::space();
	TestPacketDataStream::undersize();

	return 0;
}
