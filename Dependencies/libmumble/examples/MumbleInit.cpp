// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#include "MumbleInit.hpp"

#include "mumble/IP.hpp"
#include "mumble/Lib.hpp"
#include "mumble/Types.hpp"

#include <cstdio>
#include <string_view>

using namespace mumble;

MumbleInit::MumbleInit() {
	const auto code = lib::init();
	m_ok            = code == Code::Success;
	if (!m_ok) {
		printf("MumbleInit() failed with error \"%s\"!\n", text(code).data());
	}
}

MumbleInit::~MumbleInit() {
	const auto code = lib::deinit();
	if (code != Code::Success) {
		printf("~MumbleInit() failed with error \"%s\"!\n", text(code).data());
	}
}

MumbleInit::operator bool() const {
	return m_ok;
};
