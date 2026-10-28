// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#include "UserManager.hpp"

#include "Endpoints.hpp"
#include "User.hpp"

#include <mutex>
#include <unordered_set>
#include <utility>

using namespace mumble;

using UserPtr = UserManager::UserPtr;

UserManager::UserManager(const uint32_t max) : m_minID(1), m_maxID(max) {
}

UserManager::~UserManager() = default;

UserPtr UserManager::operator[](const uint32_t id) {
	std::shared_lock lock(m_mutex);

	const auto iter = m_users.find(id);
	if (iter != m_users.cend()) {
		return iter->second;
	}

	return {};
}

UserPtr UserManager::operator[](const Endpoint &endpoint) {
	std::shared_lock lock(m_mutex);

	const auto iter = m_endpoints.find(endpoint);
	if (iter != m_endpoints.cend()) {
		return iter->second;
	}

	return {};
}

bool UserManager::full() {
	std::shared_lock lock(m_mutex);

	return m_users.size() >= max();
}

uint32_t UserManager::max() {
	return m_maxID - m_minID + 1;
}

uint32_t UserManager::num() {
	std::shared_lock lock(m_mutex);

	return m_users.size();
}

std::optional< uint32_t > UserManager::reserveID() {
	std::unique_lock lock(m_mutex);

	if (m_users.size() >= max()) {
		return {};
	}

	for (uint32_t id = m_minID; id < m_maxID; ++id) {
		if (m_users.find(id) == m_users.cend()) {
			m_users.emplace(id, nullptr);

			return id;
		}
	}

	return {};
}

void UserManager::add(const UserPtr &user) {
	std::unique_lock lock(m_mutex);

	m_users[user->id()] = user;
}

void UserManager::del(const uint32_t id) {
	std::unique_lock lock(m_mutex);

	const auto user = m_users.extract(id).mapped();
	if (!user) {
		return;
	}

	for (const auto &endpoint : user->endpoints()) {
		m_endpoints.erase(endpoint);
	}
}

UserPtr UserManager::tryDecrypt(const BufView out, const BufViewConst in, const Endpoint &endpoint) {
	UserPtr user;

	{
		std::shared_lock lock(m_mutex);

		for (auto &iter : m_users) {
			if (iter.second && iter.second->decrypt(out, in)) {
				user = iter.second;
			}
		}
	}

	if (!user) {
		return {};
	}

	{
		std::unique_lock lock(m_mutex);

		user->addEndpoint(endpoint);

		m_endpoints.insert_or_assign(endpoint, user);
	}

	return user;
}
