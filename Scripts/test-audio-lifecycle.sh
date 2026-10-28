#!/bin/bash
# Run deterministic lifecycle tests against MLAudio in a built iOS 27 Simulator app.
set -euo pipefail
validation_device="${MU_TEST_DEVICE:-booted}"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
app_path="${1:?Usage: bash Scripts/test-audio-lifecycle.sh /path/to/Simulator/Mumble.app}"
test_mode="${2:-async}"
[[ "$test_mode" == async || "$test_mode" == legacy ]] || { printf 'Mode must be async or legacy\n' >&2; exit 1; }
validation_dir="$(mktemp -d "${TMPDIR:-/tmp}/mumble-audio-tests.XXXXXX")"
validation_bundle="com.blakebill.mumble.audio-lifecycle-tests"
trap 'xcrun simctl terminate "$validation_device" "$validation_bundle" >/dev/null 2>&1 || true' EXIT
xcrun --sdk iphonesimulator clang -arch arm64 -mios-simulator-version-min=27.0 \
    -std=c++20 -fobjc-arc -dynamiclib -undefined dynamic_lookup \
    -framework UIKit -framework Foundation -framework AVFoundation \
    -I"$repo_root/Source/LibMumble" "$repo_root/Tests/AudioLifecycle/MLAudioLifecycleTests.mm" "$repo_root/Tests/AudioRouting/MLVoiceIngressTests.mm" \
    -o "$validation_dir/MLAudioLifecycleTests.dylib"
python3 - "$app_path" "$validation_dir/Mumble.app" "$validation_bundle" <<'PY'
import sys, shutil, plistlib
from pathlib import Path
source, destination, bundle = sys.argv[1:]
shutil.copytree(source, destination)
path = Path(destination) / 'Info.plist'
info = plistlib.loads(path.read_bytes())
info['CFBundleIdentifier'] = bundle
info['CFBundleDisplayName'] = 'Mumble Audio Tests'
info.pop('CFBundleURLTypes', None)
path.write_bytes(plistlib.dumps(info))
PY
xcrun simctl terminate "$validation_device" "$validation_bundle" >/dev/null 2>&1 || true
xcrun simctl install "$validation_device" "$validation_dir/Mumble.app"
container_path="$(xcrun simctl get_app_container "$validation_device" "$validation_bundle" data)"
result_path="$container_path/Documents/audio-lifecycle-results.txt"
rm -f "$result_path"
if [[ "$test_mode" == legacy ]]; then export SIMCTL_CHILD_ML_AUDIO_TEST_LEGACY=1; else unset SIMCTL_CHILD_ML_AUDIO_TEST_LEGACY; fi
SIMCTL_CHILD_DYLD_INSERT_LIBRARIES="$validation_dir/MLAudioLifecycleTests.dylib" \
    xcrun simctl launch "$validation_device" "$validation_bundle"
for attempt in {1..300}; do
    if [[ -f "$result_path" ]]; then
        cat "$result_path"
        rg -q '^ALL TESTS PASSED$' "$result_path"
        exit
    fi
    sleep .2
done
printf 'Audio lifecycle tests did not finish. Validation files: %s\n' "$validation_dir" >&2
exit 1
