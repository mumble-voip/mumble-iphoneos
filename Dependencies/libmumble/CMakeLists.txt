# This file is part of libmumble.
# Use of this source code is governed by a BSD-style license
# that can be found in the LICENSE file at the root of the
# Mumble source tree or at <https://www.mumble.info/LICENSE>.

cmake_minimum_required(VERSION 3.16)

set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# vcpkg evaluates manifest features when project() loads its toolchain.
option(LIBMUMBLE_BUILD_TESTS "Build tests" ON)
if(LIBMUMBLE_BUILD_TESTS)
	list(APPEND VCPKG_MANIFEST_FEATURES tests)
	list(REMOVE_DUPLICATES VCPKG_MANIFEST_FEATURES)
endif()

project(libmumble
	VERSION "0.1.0"
	DESCRIPTION "The official Mumble library."
	HOMEPAGE_URL "https://www.mumble.info"
	LANGUAGES "C" "CXX"
)

option(LIBMUMBLE_BUILD_EXAMPLES "Build example client and server" OFF)
option(LIBMUMBLE_STATIC "Build the library as static instead of shared" OFF)
option(LIBMUMBLE_WARNINGS_AS_ERRORS "Treat warnings as errors" OFF)


include(setup_dependencies)
include(compiler_utilities)


set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_FIND_PACKAGE_PREFER_CONFIG ON)


if(WIN32)
	add_definitions(
		"-DOS_WINDOWS"
		"-DNOMINMAX"
		"-DWIN32_LEAN_AND_MEAN"
		"-D_CRT_SECURE_NO_WARNINGS"
	)
else()
	add_definitions(
		"-DOS_UNIX"
	)
endif()

if(MSVC)
	add_compile_options(
		# https://devblogs.microsoft.com/cppblog/msvc-now-correctly-reports-__cplusplus
		"/Zc:__cplusplus"
	)
endif()


add_subdirectory(src)


if (LIBMUMBLE_BUILD_EXAMPLES)
	add_subdirectory(examples)
endif()

if (LIBMUMBLE_BUILD_TESTS)
	include(CTest)
	add_subdirectory(tests)
endif()
