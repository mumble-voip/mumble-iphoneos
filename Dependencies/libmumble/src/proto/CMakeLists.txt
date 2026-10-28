# This file is part of libmumble.
# Use of this source code is governed by a BSD-style license
# that can be found in the LICENSE file at the root of the
# Mumble source tree or at <https://www.mumble.info/LICENSE>.

find_package(Protobuf REQUIRED)

add_library(Proto OBJECT)

target_disable_warnings(Proto)

target_include_directories(Proto
	INTERFACE
		${CMAKE_CURRENT_BINARY_DIR}
)

set_target_properties(Proto PROPERTIES UNITY_BUILD OFF)

target_link_libraries(Proto
	PRIVATE
		protobuf::libprotobuf
)

protobuf_generate(
	TARGET Proto
	PROTOS
		"MumbleTCP.proto"
		"MumbleUDP.proto"
)
