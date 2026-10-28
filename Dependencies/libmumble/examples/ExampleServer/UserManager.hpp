// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_EXAMPLESERVER_USERMANAGER_HPP
#define MUMBLE_EXAMPLESERVER_USERMANAGER_HPP

#include "Endpoints.hpp"

#include "mumble/Types.hpp"

#include <cstdint>
#include <memory>
#include <optional>
#include <shared_mutex>
#include <unordered_map>

class User;

class UserManager {
public:
	UserManager(const uint32_t max);
	~UserManager();

	using BufView      = mumble::BufView;
	using BufViewConst = mumble::BufViewConst;
	using UserPtr      = std::shared_ptr< User >;

	UserPtr operator[](const uint32_t id);
	UserPtr operator[](const Endpoint &endpoint);

	bool full();

	uint32_t max();
	uint32_t num();

	std::optional< uint32_t > reserveID();

	void add(const UserPtr &user);
	void del(const uint32_t id);

	UserPtr tryDecrypt(const BufView out, const BufViewConst in, const Endpoint &endpoint);

private:
	void thread();

	uint32_t m_minID, m_maxID;
	std::shared_mutex m_mutex;
	std::unordered_map< uint32_t, UserPtr > m_users;
	std::unordered_map< Endpoint, UserPtr > m_endpoints;
};

#endif
