// Copyright 2023 The Mumble Developers. All rights reserved.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_PACKETDATASTREAM_HPP
#define MUMBLE_PACKETDATASTREAM_HPP

#include "Types.hpp"

#include <algorithm>
#include <string>

namespace mumble {
class PacketDataStream {
public:
	PacketDataStream(const BufView buf) : m_ok(true), m_buf(buf), m_seek(m_buf), m_overshoot(0) {}

	constexpr explicit operator bool() const { return m_ok; }

	constexpr BufViewConst buf() const { return m_buf; }
	constexpr BufView buf() { return m_buf; }

	constexpr BufViewConst data() const { return { m_buf.data(), m_buf.size() - m_seek.size() }; }
	constexpr BufView data() { return { m_buf.data(), m_buf.size() - m_seek.size() }; }

	constexpr BufViewConst seek() const { return m_seek; }
	constexpr BufView seek() { return m_seek; }

	constexpr uint32_t undersize() const { return m_overshoot; }

	constexpr void rewind() { m_seek = m_buf; }
	constexpr void truncate() { m_buf = m_seek; }

	constexpr void skip(const uint32_t size) {
		if (m_seek.size() >= size) {
			m_seek = m_seek.subspan(size);
		} else {
			m_ok = false;
		}
	}

	constexpr PacketDataStream &operator<<(const uint64_t value) {
		auto tmp = value;

		if ((tmp & 0x8000000000000000LL) && (~tmp < 0x100000000LL)) {
			// Signed number.
			tmp = ~tmp;
			if (tmp <= 0x3) {
				// Shortcase for -1 to -4.
				append(0xFC | tmp);
				return *this;
			} else {
				append(0xF8);
			}
		}

		if (tmp < 0x80) {
			// Need top bit clear.
			append(tmp);
		} else if (tmp < 0x4000) {
			// Need top two bits clear.
			append((tmp >> 8) | 0x80);
			append(tmp & 0xFF);
		} else if (tmp < 0x200000) {
			// Need top three bits clear.
			append((tmp >> 16) | 0xC0);
			append((tmp >> 8) & 0xFF);
			append(tmp & 0xFF);
		} else if (tmp < 0x10000000) {
			// Need top four bits clear.
			append((tmp >> 24) | 0xE0);
			append((tmp >> 16) & 0xFF);
			append((tmp >> 8) & 0xFF);
			append(tmp & 0xFF);
		} else if (tmp < 0x100000000LL) {
			// It's a full 32-bit integer.
			append(0xF0);
			append((tmp >> 24) & 0xFF);
			append((tmp >> 16) & 0xFF);
			append((tmp >> 8) & 0xFF);
			append(tmp & 0xFF);
		} else {
			// It's a 64-bit value.
			append(0xF4);
			append((tmp >> 56) & 0xFF);
			append((tmp >> 48) & 0xFF);
			append((tmp >> 40) & 0xFF);
			append((tmp >> 32) & 0xFF);
			append((tmp >> 24) & 0xFF);
			append((tmp >> 16) & 0xFF);
			append((tmp >> 8) & 0xFF);
			append(tmp & 0xFF);
		}

		return *this;
	}

	constexpr PacketDataStream &operator>>(uint64_t &value) {
		uint64_t tmp = next();

		if ((tmp & 0x80) == 0x00) {
			value = (tmp & 0x7F);
		} else if ((tmp & 0xC0) == 0x80) {
			value = (tmp & 0x3F) << 8 | next();
		} else if ((tmp & 0xF0) == 0xF0) {
			switch (tmp & 0xFC) {
				case 0xF0:
					value = next() << 24 | next() << 16 | next() << 8 | next();
					break;
				case 0xF4:
					value = next() << 56 | next() << 48 | next() << 40 | next() << 32 | next() << 24 | next() << 16
							| next() << 8 | next();
					break;
				case 0xF8:
					*this >> value;
					value = ~value;
					break;
				case 0xFC:
					value = tmp & 0x03;
					value = ~value;
					break;
				default:
					m_ok  = false;
					value = 0;
					break;
			}
		} else if ((tmp & 0xF0) == 0xE0) {
			value = (tmp & 0x0F) << 24 | next() << 16 | next() << 8 | next();
		} else if ((tmp & 0xE0) == 0xC0) {
			value = (tmp & 0x1F) << 16 | next() << 8 | next();
		}

		return *this;
	}

#define INTMAPOPERATOR(type)                                                                                     \
	constexpr PacketDataStream &operator<<(const type value) { return *this << static_cast< uint64_t >(value); } \
	constexpr PacketDataStream &operator>>(type &value) {                                                        \
		uint64_t tmp = 0;                                                                                        \
		*this >> tmp;                                                                                            \
		value = static_cast< type >(tmp);                                                                        \
		return *this;                                                                                            \
	}

	INTMAPOPERATOR(int32_t);
	INTMAPOPERATOR(uint32_t);
	INTMAPOPERATOR(int16_t);
	INTMAPOPERATOR(uint16_t);
	INTMAPOPERATOR(int8_t);
	INTMAPOPERATOR(uint8_t);

	constexpr PacketDataStream &operator<<(const bool value) {
		const uint32_t tmp = value ? 1 : 0;
		return *this << tmp;
	}

	constexpr PacketDataStream &operator>>(bool &value) {
		uint32_t tmp = 0;
		*this >> tmp;
		value = tmp ? true : false;
		return *this;
	}

	union double64u {
		uint64_t ui;
		double d;
	};

	PacketDataStream &operator<<(const double value) {
		double64u u;
		u.d = value;
		return *this << u.ui;
	}

	PacketDataStream &operator>>(double &value) {
		double64u u;
		*this >> u.ui;
		value = u.d;
		return *this;
	}

	union float32u {
		uint8_t ui[4];
		float f;
	};

	PacketDataStream &operator<<(const float value) {
		float32u u;
		u.f = value;
		append(u.ui[0]);
		append(u.ui[1]);
		append(u.ui[2]);
		append(u.ui[3]);
		return *this;
	}

	PacketDataStream &operator>>(float &value) {
		float32u u;
		if (m_seek.size() < 4) {
			m_ok  = false;
			value = 0;
		}
		u.ui[0] = next8();
		u.ui[1] = next8();
		u.ui[2] = next8();
		u.ui[3] = next8();
		value   = u.f;
		return *this;
	}

	PacketDataStream &operator<<(const BufViewConst buf) {
		*this << static_cast< uint64_t >(buf.size());
		append(buf);
		return *this;
	}

	PacketDataStream &operator>>(Buf &buf) {
		uint32_t size = 0;
		*this >> size;

		if (size > m_seek.size()) {
			size = static_cast< decltype(size) >(m_seek.size());
			m_ok = false;
		}

		buf    = { m_seek.begin(), m_seek.begin() + size };
		m_seek = m_seek.subspan(size);

		return *this;
	}

	PacketDataStream &operator<<(const std::string_view str) {
		*this << static_cast< uint32_t >(str.size());
		append({ reinterpret_cast< const std::byte * >(str.data()), str.size() });
		return *this;
	}

	PacketDataStream &operator>>(std::string &str) {
		uint32_t size = 0;
		*this >> size;

		if (size > m_seek.size()) {
			size = static_cast< decltype(size) >(m_seek.size());
			m_ok = false;
		}

		str    = { reinterpret_cast< const char * >(m_seek.data()), size };
		m_seek = m_seek.subspan(size);

		return *this;
	}

private:
	constexpr uint64_t next() {
		if (!m_seek.empty()) {
			const auto value = std::to_integer< uint64_t >(m_seek.front());
			m_seek           = m_seek.subspan(sizeof(std::byte));
			return value;
		}

		m_ok = false;

		return 0;
	}

	constexpr uint8_t next8() {
		if (!m_seek.empty()) {
			const auto value = std::to_integer< uint8_t >(m_seek.front());
			m_seek           = m_seek.subspan(sizeof(std::byte));
			return value;
		}

		m_ok = false;

		return 0;
	}

	constexpr void append(const uint64_t value) {
		if (!m_seek.empty()) {
			m_seek.front() = std::byte(value);
			m_seek         = m_seek.subspan(sizeof(std::byte));
		} else {
			m_ok = false;
			++m_overshoot;
		}
	}

	void append(const BufViewConst buf) {
		if (m_seek.size() >= buf.size()) {
			std::copy(buf.begin(), buf.end(), m_seek.begin());
			m_seek = m_seek.subspan(buf.size());
		} else {
			std::fill(m_seek.begin(), m_seek.end(), std::byte(0));
			m_overshoot += static_cast< decltype(m_overshoot) >(buf.size() - m_seek.size());
			m_seek = m_seek.last(0);
			m_ok   = false;
		}
	}

	bool m_ok;
	BufView m_buf;
	BufView m_seek;
	uint32_t m_overshoot;
};
}; // namespace mumble

#endif
