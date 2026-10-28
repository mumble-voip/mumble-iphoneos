#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/mumble-jitter.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
xcrun --sdk macosx clang++ -std=c++20 -O2 -Wall -Wextra -Werror \
    -I "$root/Source/LibMumble" "$root/Tests/AudioBuffers/MLAdaptiveJitterBufferTests.cpp" -o "$test_dir/jitter"
"$test_dir/jitter"
