# This file is part of libmumble.
# Use of this source code is governed by a BSD-style license
# that can be found in the LICENSE file at the root of the
# Mumble source tree or at <https://www.mumble.info/LICENSE>.

list(APPEND TESTS
	"TestBase64"
	"TestCrypt"
	"TestHash"
	"TestOpus"
	"TestPacketDataStream"
)

add_library(libmumble_test_base OBJECT
	"ThreadManager.cpp"
)

target_include_directories(libmumble_test_base
	PUBLIC
		${CMAKE_CURRENT_SOURCE_DIR}
)

find_package(Boost REQUIRED
	COMPONENTS
		thread
)

target_link_libraries(libmumble_test_base
	PUBLIC
	Mumble::libmumble
	Boost::thread
)

# All tests follow the convention of naming their subdirectory the same as their target.
# Therefore we can use the TARGET variable to reference the directory as well as the target.
foreach(TARGET IN LISTS TESTS)
	add_subdirectory(${TARGET})
	add_test(
		NAME ${TARGET}
		COMMAND ${TARGET}
		WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
	)

	target_setup_default_flags(${TARGET})

	set_target_properties(${TARGET}
		PROPERTIES
			RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/test"
	)

	target_link_libraries(${TARGET}
		PRIVATE
			libmumble_test_base
	)
endforeach()
