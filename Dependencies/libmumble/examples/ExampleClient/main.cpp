// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#include "MumbleInit.hpp"

#include "mumble/Connection.hpp"
#include "mumble/Lib.hpp"
#include "mumble/Message.hpp"
#include "mumble/Pack.hpp"
#include "mumble/Peer.hpp"
#include "mumble/Types.hpp"

#include <condition_variable>
#include <cstdint>
#include <cstdio>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <string_view>
#include <unordered_map>
#include <utility>

#include <toml/get.hpp>
#include <toml/parser.hpp>
#include <toml/value.hpp>

using namespace mumble;

static Connection::Feedback connectionFeedback(Connection &connection, std::condition_variable &cv) {
	using Message = tcp::Message;
	using Pack    = tcp::Pack;
	using Type    = Message::Type;

	Connection::Feedback feedback;

	feedback.opened = [&connection]() {
		printf("Connection opened!\n");

		Message::Version ver;
		ver.version = lib::version();
		ver.release = "Custom client";
		connection.write(Pack(ver).buf());
	};

	feedback.closed = [&cv]() {
		printf("Connection closed!\n");

		cv.notify_all();
	};

	feedback.failed = [&cv](const Code code) {
		printf("Connection failed with error \"%s\"!\n", text(code).data());

		cv.notify_all();
	};

	feedback.pack = [](Pack &pack) {
		const auto type = Message::type(pack);
		if (type != Type::UDPTunnel) {
			printf("%s received!\n", Message::text(type).data());
		}
	};

	return feedback;
}

static Peer::FeedbackTCP peerFeedback() {
	Peer::FeedbackTCP feedback;

	feedback.started = []() { printf("TCP started!\n"); };
	feedback.stopped = []() { printf("TCP stopped!\n"); };

	feedback.failed = [](const Code code) { printf("TCP failed with error \"%s\"!\n", text(code).data()); };

	feedback.timeout = []() { return 10000; };

	return feedback;
}

int32_t main(const int argc, const char **argv) {
	if (argc > 2) {
		printf("Usage: `example_client <config file>`\n");
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

	const auto local = toml::find(conf, "local");
	const auto peer  = toml::find(conf, "peer");

	const auto localTcpIP   = toml::find< std::string_view >(local, "tcpIP");
	const auto localTcpPort = toml::find< uint16_t >(local, "tcpPort");

	const auto peerTcpIP   = toml::find< std::string_view >(peer, "tcpIP");
	const auto peerTcpPort = toml::find< uint16_t >(peer, "tcpPort");

	const auto ret = Peer::connect({ IP(peerTcpIP), peerTcpPort }, { IP(localTcpIP), localTcpPort });
	if (ret.first != Code::Success) {
		printf("Peer::connect() failed with error \"%s\"!\n", text(ret.first).data());
		return 3;
	}

	std::condition_variable cv;

	auto connection = std::make_shared< Connection >(ret.second, false);
	auto code       = (*connection)(connectionFeedback(*connection, cv));
	if (code != Code::Success) {
		printf("Connection() failed with error \"%s\"!\n", text(code).data());
		return 4;
	}

	Peer client;
	client.addTCP(connection);
	code = client.startTCP(peerFeedback());
	if (code != Code::Success) {
		printf("Peer::startTCP() failed with error \"%s\"!\n", text(code).data());
		return 5;
	}

	std::mutex mutex;
	std::unique_lock< std::mutex > lock(mutex);
	cv.wait(lock);

	return 0;
}
