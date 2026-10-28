# This file is part of libmumble.
# Use of this source code is governed by a BSD-style license
# that can be found in the LICENSE file at the root of the
# Mumble source tree or at <https://www.mumble.info/LICENSE>.

include(CompilerFlags)

function(target_disable_warnings TARGET)
	get_compiler_flags(
		DISABLE_ALL_WARNINGS
		DISABLE_DEFAULT_FLAGS
		OUTPUT_VARIABLE REQUESTED_FLAGS
	)

	target_compile_options(${TARGET}
		PRIVATE
			${REQUESTED_FLAGS}
	)
endfunction()

function(target_setup_default_flags TARGET)
	set(DESIRED ENABLE_MOST_WARNINGS)

	if (LIBMUMBLE_WARNINGS_AS_ERRORS)
		list(APPEND DESIRED ENABLE_WARNINGS_AS_ERRORS)
	endif()
	if (CMAKE_BUILD_TYPE STREQUAL "Release" OR CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
		list(APPEND DESIRED OPTIMIZE_FOR_SPEED)
	else()
		list(APPEND DESIRED OPTIMIZE_FOR_DEBUG)
	endif()

	get_compiler_flags(
		${DESIRED}
		OUTPUT_VARIABLE REQUESTED_FLAGS
	)

	target_compile_options(${TARGET}
		PRIVATE
			${REQUESTED_FLAGS}
	)

	if (MSVC)
		target_compile_options(${TARGET}
			PRIVATE
				# "PImpl fix" for MSVC
				/wd4251
		)
	endif()
endfunction()
