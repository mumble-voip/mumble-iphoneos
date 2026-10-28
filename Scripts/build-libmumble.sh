#!/bin/bash
# Build one self-contained static XCFramework for device and Simulator.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
: "${VCPKG_ROOT:?Set VCPKG_ROOT to a bootstrapped vcpkg checkout}"
bash "$root/Scripts/prepare-fmdb.sh"
build_root="${LIBMUMBLE_BUILD_ROOT:-$root/build/libmumble}"
source_root="$root/Dependencies/libmumble"
mkdir -p "$build_root" "$root/Dependencies/Generated"
args=()
for platform in iphoneos iphonesimulator; do
    if [[ "$platform" == iphoneos ]]; then triplet=arm64-ios; else triplet=arm64-ios-simulator; fi
    installed="$build_root/installed-$triplet"
    "$VCPKG_ROOT/vcpkg" install --x-manifest-root="$source_root" --x-install-root="$installed" \
        --triplet="$triplet" --host-triplet=arm64-osx --overlay-triplets="$root/Scripts/vcpkg-triplets"
    slice="$build_root/$platform"
    cmake --fresh -S "$source_root" -B "$slice" -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" \
        -DVCPKG_INSTALLED_DIR="$installed" -DVCPKG_MANIFEST_INSTALL=OFF \
        -DVCPKG_TARGET_TRIPLET="$triplet" -DVCPKG_HOST_TRIPLET=arm64-osx \
        -DVCPKG_OVERLAY_TRIPLETS="$root/Scripts/vcpkg-triplets" \
        -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$platform" \
        -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=18.0 \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DLIBMUMBLE_STATIC=ON -DLIBMUMBLE_BUILD_TESTS=OFF -DLIBMUMBLE_BUILD_EXAMPLES=OFF \
        -DLIBMUMBLE_DEPENDENCY_DIR="$build_root/fetch"
    cmake --build "$slice" --parallel "${LIBMUMBLE_BUILD_JOBS:-8}"
    mkdir -p "$slice/headers"
    cp -R "$source_root/include/mumble" "$slice/headers/"
    cp -R "$installed/$triplet/include/" "$slice/headers/"
    cp -R "$build_root/fetch/ipxx-src/include/ipxx" "$slice/headers/"
    cp "$slice/src/proto/"*.pb.h "$slice/headers/"
    archives=("$slice/libmumble_library.a")
    while IFS= read -r archive; do
        # These alternative runtimes/compiler tools duplicate protobuf symbols.
        case "$(basename "$archive")" in libprotobuf-lite.a|libprotoc.a) continue;; esac
        archives+=("$archive")
    done < <(find "$installed/$triplet/lib" "$slice/_deps" "$build_root/fetch/ipxx-build" -name '*.a' -type f 2>/dev/null || true)
    /usr/bin/libtool -static -o "$slice/libmumble.a" "${archives[@]}"
    args+=(-library "$slice/libmumble.a" -headers "$slice/headers")
done
output="$root/Dependencies/Generated/libmumble.xcframework"
if [[ -e "$output" ]]; then
    mv "$output" "$build_root/previous-xcframework-$(date +%s)"
fi
xcodebuild -create-xcframework "${args[@]}" -output "$output"
mkdir -p "$root/Dependencies/Generated/licenses"
cp "$source_root/LICENSE" "$root/Dependencies/Generated/licenses/libmumble.txt"
for dependency in openssl opus protobuf abseil utf8-range speexdsp; do
    cp "$build_root/installed-arm64-ios/arm64-ios/share/$dependency/copyright" "$root/Dependencies/Generated/licenses/$dependency.txt"
done
cp "$build_root/fetch/ipxx-src/LICENSE" "$root/Dependencies/Generated/licenses/ipxx.txt"
sed -n '1,/^#pragma once/p' "$build_root/fetch/quickpool-src/quickpool.hpp" | sed '$d; s@^// @@; s@^//$@@' > "$root/Dependencies/Generated/licenses/quickpool.txt"
python3 "$root/Scripts/update-libmumble-licenses.py"
echo "Built $output"
