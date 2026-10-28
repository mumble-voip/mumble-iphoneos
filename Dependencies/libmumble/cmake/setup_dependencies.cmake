# This file is part of libmumble.
# Use of this source code is governed by a BSD-style license
# that can be found in the LICENSE file at the root of the
# Mumble source tree or at <https://www.mumble.info/LICENSE>.

include(FetchContent)

set(LIBMUMBLE_DEPENDENCY_DIR "${PROJECT_SOURCE_DIR}/_dependencies" CACHE STRING "Directory into which dependencies shall be downloaded into")

set(FETCHCONTENT_BASE_DIR "${LIBMUMBLE_DEPENDENCY_DIR}")

FetchContent_Declare(
	ipxx
	GIT_REPOSITORY https://github.com/davidebeatrici/ipxx.git
	GIT_TAG        ab1e1195f0f43392730d3bb42e837c1591d8a6fb
	GIT_SHALLOW    OFF
)
FetchContent_Declare(
	quickpool
	GIT_REPOSITORY https://github.com/tnagler/quickpool.git
	GIT_TAG        v1.8.0
	GIT_SHALLOW    ON
)
FetchContent_Declare(
	wepoll
	GIT_REPOSITORY https://github.com/piscisaureus/wepoll.git
	GIT_TAG        v1.5.8
	GIT_SHALLOW    ON
	PATCH_COMMAND  "${CMAKE_COMMAND}" -E copy "${PROJECT_SOURCE_DIR}/cmake/wepoll_cmakelists.txt" "./CMakeLists.txt"
)
FetchContent_Declare(
	cmake_compiler_flags
	GIT_REPOSITORY https://github.com/Krzmbrzl/cmake-compiler-flags.git
	GIT_TAG        v2.1.0
	GIT_SHALLOW    ON
)

# Set some options for the dependencies
set(QUICKPOOL_TEST ${LIBMUMBLE_BUILD_TESTS} CACHE INTERNAL "")


message(STATUS ">>> Configuring dependencies (potentially includes downloading)")

FetchContent_MakeAvailable(ipxx quickpool cmake_compiler_flags)

if (WIN32)
	FetchContent_MakeAvailable(wepoll)
endif()

# Append the compiler flags CMake module to the module path
FetchContent_GetProperties(cmake_compiler_flags SOURCE_DIR COMPILER_FLAGS_SRC_DIR)
list(APPEND CMAKE_MODULE_PATH "${COMPILER_FLAGS_SRC_DIR}")

message(STATUS "<<< Dependency configuration finished")
