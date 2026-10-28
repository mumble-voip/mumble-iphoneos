#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/mumble-text-messages.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
xcrun --sdk macosx clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation \
    -include Foundation/Foundation.h -I "$root/Source/Classes" \
    "$root/Source/Classes/MUTextMessageProcessor.m" \
    "$root/Tests/TextMessages/MUTextMessageProcessorTests.m" -o "$test_dir/text-messages"
"$test_dir/text-messages"
