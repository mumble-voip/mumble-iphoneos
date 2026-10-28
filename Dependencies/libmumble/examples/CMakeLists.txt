# This file is part of libmumble.
# Use of this source code is governed by a BSD-style license
# that can be found in the LICENSE file at the root of the
# Mumble source tree or at <https://www.mumble.info/LICENSE>.

include(FetchContent)

FetchContent_Declare(
	toml11
	GIT_REPOSITORY https://github.com/ToruNiina/toml11
	GIT_TAG        v3.7.1
	GIT_SHALLOW    ON
)
FetchContent_MakeAvailable(toml11)


list(APPEND EXAMPLES
	"ExampleClient"
	"ExampleServer"
)

add_library(libmumble_example_base OBJECT)

target_include_directories(libmumble_example_base
	PUBLIC
		${CMAKE_CURRENT_SOURCE_DIR}
)

target_sources(libmumble_example_base
	PRIVATE
		"MumbleInit.cpp"
)

target_link_libraries(libmumble_example_base
	PUBLIC
		Mumble::libmumble
		toml11::toml11
)

# All examples follow the convention of naming their subdirectory the same as their target.
# Therefore we can use the TARGET variable to reference the directory as well as the target.
foreach(TARGET IN LISTS EXAMPLES)
	add_subdirectory(${TARGET})

	target_setup_default_flags(${TARGET})

	set_target_properties(${TARGET}
		PROPERTIES
			RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/example"
	)

	target_link_libraries(${TARGET}
		PRIVATE
			libmumble_example_base
	)
endforeach()
