#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/mumble-audio-buffers.XXXXXX")"
xcrun --sdk macosx clang++ -std=c++20 -fobjc-arc -O2 -Wall -Wextra -Werror \
    -framework AVFoundation -framework Foundation -I "$root/Source/LibMumble" \
    "$root/Tests/AudioBuffers/MLCaptureBufferQueueTests.mm" -o "$test_dir/MLCaptureBufferQueueTests"
"$test_dir/MLCaptureBufferQueueTests"
