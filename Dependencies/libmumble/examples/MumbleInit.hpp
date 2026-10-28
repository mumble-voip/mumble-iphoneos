// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_EXAMPLE_MUMBLEINIT_HPP
#define MUMBLE_EXAMPLE_MUMBLEINIT_HPP

class MumbleInit {
public:
	MumbleInit();
	~MumbleInit();

	explicit operator bool() const;

private:
	bool m_ok;
};

#endif
