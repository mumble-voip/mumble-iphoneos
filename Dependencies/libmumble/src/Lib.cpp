// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#include "mumble/Lib.hpp"

#include "mumble/Types.hpp"

#include <atomic>

#ifdef OS_WINDOWS
#	include <WinSock2.h>
#endif

using namespace mumble;

static std::atomic_size_t g_initCount;

Version lib::version() {
	return { 1, 5, 0 };
}

Code lib::init() {
#ifdef OS_WINDOWS
	if (g_initCount == 0) {
		WSADATA data;
		switch (WSAStartup(MAKEWORD(2, 2), &data)) {
			case 0:
				break;
			case WSAVERNOTSUPPORTED:
				return Code::Unsupport;
			case WSAEINPROGRESS:
			case WSAEPROCLIM:
			case WSASYSNOTREADY:
				return Code::Busy;
			default:
				return Code::Failure;
		}

		if (LOBYTE(data.wVersion) != 2 || HIBYTE(data.wVersion) != 2) {
			WSACleanup();
			return Code::Unsupport;
		}
	}
#endif
	++g_initCount;

	return Code::Success;
}

Code lib::deinit() {
	if (g_initCount == 0) {
		return Code::Init;
	}
#ifdef OS_WINDOWS
	if (--g_initCount == 0) {
		WSACleanup();
	}
#else
	--g_initCount;
#endif
	return Code::Success;
}

size_t lib::initCount() {
	return g_initCount;
}
