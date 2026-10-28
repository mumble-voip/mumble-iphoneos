# This file is part of libmumble.
# Use of this source code is governed by a BSD-style license
# that can be found in the LICENSE file at the root of the
# Mumble source tree or at <https://www.mumble.info/LICENSE>.

# We use pkg-config to search for Opus
find_package(PkgConfig REQUIRED)

pkg_check_modules(Opus opus QUIET)

if (Opus_FOUND)
	# Define an actual CMake target that can be used conveniently
	add_library(opus_interface INTERFACE)
	target_include_directories(opus_interface INTERFACE ${Opus_INCLUDE_DIRS})
	target_link_libraries(opus_interface INTERFACE ${Opus_LINK_LIBRARIES})

	add_library(Opus::opus ALIAS opus_interface)
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Opus
	REQUIRED_VARS Opus_LINK_LIBRARIES Opus_INCLUDE_DIRS
	VERSION_VAR   Opus_VERSION
)
