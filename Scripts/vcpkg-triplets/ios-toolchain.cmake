# Keep every dependency compatible with the application's minimum iOS version.
set(CMAKE_OSX_DEPLOYMENT_TARGET 18.0 CACHE STRING "Minimum iOS version" FORCE)
include("$ENV{VCPKG_ROOT}/scripts/toolchains/ios.cmake")
