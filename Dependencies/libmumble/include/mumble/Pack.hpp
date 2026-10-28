// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_PACK_HPP
#define MUMBLE_PACK_HPP

#include "Endian.hpp"
#include "Macros.hpp"
#include "Types.hpp"

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <vector>

namespace google {
namespace protobuf {
	class Message;
}
} // namespace google

namespace mumble {
template< typename NetHeader > class Pack {
public:
	Pack(const Pack &pack) = default;
	Pack(Pack &&pack)      = default;
	Pack(const size_t dataSize = 0) : m_buf(sizeof(NetHeader) + dataSize) {}
	virtual ~Pack() = default;

	Pack &operator=(const Pack &pack) = default;
	Pack &operator=(Pack &&pack)      = default;

	virtual bool operator==(const Pack &pack) const { return pack.m_buf == m_buf; }

	virtual BufViewConst buf() const { return m_buf; }

	virtual BufView buf() { return m_buf; }

	virtual BufViewConst data() const { return { m_buf.data() + sizeof(NetHeader), m_buf.size() - sizeof(NetHeader) }; }

	virtual BufView data() { return { m_buf.data() + sizeof(NetHeader), m_buf.size() - sizeof(NetHeader) }; }

	virtual const NetHeader &header() const { return *reinterpret_cast< const NetHeader * >(m_buf.data()); }

	virtual NetHeader &header() { return *reinterpret_cast< NetHeader * >(m_buf.data()); }

protected:
	Buf m_buf;
};

namespace tcp {
	struct Message;

	MUMBLE_PACK(struct NetHeader {
		uint16_t type = Endian::toNetwork(std::numeric_limits< decltype(type) >::max());
		uint32_t size = 0;
	});

	class MUMBLE_EXPORT Pack : public mumble::Pack< NetHeader > {
	public:
		Pack(const Message &message, const uint32_t extraDataSize = 0);
		Pack(const NetHeader &header = {}, const uint32_t extraDataSize = 0);
		Pack(const google::protobuf::Message &proto, const uint32_t extraDataSize = 0);
		virtual ~Pack();

		virtual bool operator()(Message &message, uint32_t dataSize = std::numeric_limits< uint32_t >::max()) const;
	};
} // namespace tcp

namespace udp {
	struct Message;

	MUMBLE_PACK(struct NetHeader { uint8_t type = std::numeric_limits< decltype(type) >::max(); });

	class MUMBLE_EXPORT Pack : public mumble::Pack< NetHeader > {
	public:
		Pack(const Message &message, const uint32_t extraDataSize = 0);
		Pack(const NetHeader &header = {}, const uint32_t dataSize = 0);
		Pack(const google::protobuf::Message &proto, const uint32_t extraDataSize = 0);
		virtual ~Pack();

		virtual bool operator()(Message &message, uint32_t dataSize = std::numeric_limits< uint32_t >::max()) const;
	};
} // namespace udp
} // namespace mumble

#endif
