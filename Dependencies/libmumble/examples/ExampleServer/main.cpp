// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#include "MumbleInit.hpp"
#include "Node.hpp"
#include "UserManager.hpp"

#include "mumble/Types.hpp"

#include <cstdint>
#include <cstdio>
#include <memory>
#include <string>
#include <string_view>
#include <unordered_map>
#include <utility>
#include <vector>

#include <toml/comments.hpp>
#include <toml/get.hpp>
#include <toml/parser.hpp>
#include <toml/value.hpp>

using namespace mumble;

int32_t main(const int argc, const char **argv) {
	if (argc > 2) {
		printf("Usage: `example_server <config file>`\n");
		return 1;
	}

	std::string confPath = "config.toml";
	if (argc > 1) {
		confPath = argv[1];
	}

	const auto conf = toml::parse(confPath);

	MumbleInit mumbleInit;
	if (!mumbleInit) {
		return 2;
	}

	auto userManager = std::make_shared< UserManager >(toml::find< uint32_t >(conf, "maxUsers"));

	std::vector< std::unique_ptr< Node > > nodes;

	for (const auto &nodeConf : toml::find(conf, "nodes").as_table()) {
		const auto bandwidth = toml::find< uint32_t >(nodeConf.second, "bandwidth");

		const auto &identity = toml::find(nodeConf.second, "identity");
		const auto cert      = toml::find< std::string_view >(identity, "cert");
		const auto key       = toml::find< std::string_view >(identity, "key");

		const auto &tcp    = toml::find(nodeConf.second, "tcp");
		const auto tcpIP   = toml::find< std::string_view >(tcp, "ip");
		const auto tcpPort = toml::find< uint32_t >(tcp, "port");

		const auto &udp    = toml::find(nodeConf.second, "udp");
		const auto udpIP   = toml::find< std::string_view >(udp, "ip");
		const auto udpPort = toml::find< uint32_t >(udp, "port");

		auto node = std::make_unique< Node >(userManager, tcpIP, tcpPort, udpIP, udpPort, bandwidth);
		if (!*node) {
			return 3;
		}

		if (!node->setCert(cert, key)) {
			return 4;
		}

		if (!node->start()) {
			return 5;
		}

		nodes.push_back(std::move(node));
	}

	getchar();

	printf("Shutting down...\n");

	return 0;
}
