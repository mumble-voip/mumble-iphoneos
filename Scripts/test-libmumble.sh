#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
: "${VCPKG_ROOT:?Set VCPKG_ROOT to a bootstrapped vcpkg checkout}"
test_root="${LIBMUMBLE_TEST_ROOT:-$root/build/libmumble-tests}"
installed="$test_root/installed"
"$VCPKG_ROOT/vcpkg" install --x-manifest-root="$root/Dependencies/libmumble" \
    --x-install-root="$installed" --triplet=arm64-osx --host-triplet=arm64-osx
cmake -S "$root/Tests/LibMumble" -B "$test_root/build" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" \
    -DVCPKG_INSTALLED_DIR="$installed" -DVCPKG_MANIFEST_INSTALL=OFF \
    -DVCPKG_TARGET_TRIPLET=arm64-osx -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DLIBMUMBLE_DEPENDENCY_DIR="$test_root/fetch"
cmake --build "$test_root/build" --parallel "${LIBMUMBLE_BUILD_JOBS:-8}"
ctest --test-dir "$test_root/build" --output-on-failure
