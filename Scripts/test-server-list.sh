#!/bin/bash
# Run channel-tree regression tests against a built iOS 27 Simulator app.
set -euo pipefail
validation_device="${MU_TEST_DEVICE:-booted}"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
app_path="${1:?Usage: bash Scripts/test-server-list.sh /path/to/Simulator/Mumble.app}"
validation_dir="$(mktemp -d "${TMPDIR:-/tmp}/mumble-server-tests.XXXXXX")"
# Reuse the existing isolated test bundle; generated apps never enter the repo.
validation_bundle="com.blakebill.mumble.audio-lifecycle-tests"
trap 'xcrun simctl terminate "$validation_device" "$validation_bundle" >/dev/null 2>&1 || true' EXIT
xcrun --sdk iphonesimulator clang -arch arm64 -mios-simulator-version-min=27.0 \
    -fobjc-arc -dynamiclib -undefined dynamic_lookup -framework UIKit -framework Foundation \
    -I"$repo_root/Source/LibMumble" -I"$repo_root/Source/Classes" \
    "$repo_root/Tests/ServerList/MUServerListTests.m" -o "$validation_dir/MUServerListTests.dylib"
python3 - "$app_path" "$validation_dir/Mumble.app" "$validation_bundle" <<'PY'
import sys, shutil, plistlib
from pathlib import Path
source, destination, bundle = sys.argv[1:]
shutil.copytree(source, destination)
path = Path(destination) / 'Info.plist'
info = plistlib.loads(path.read_bytes())
info['CFBundleIdentifier'] = bundle
info['CFBundleDisplayName'] = 'Mumble UI Tests'
info.pop('CFBundleURLTypes', None)
path.write_bytes(plistlib.dumps(info))
PY
xcrun simctl terminate "$validation_device" "$validation_bundle" >/dev/null 2>&1 || true
xcrun simctl install "$validation_device" "$validation_dir/Mumble.app"
container_path="$(xcrun simctl get_app_container "$validation_device" "$validation_bundle" data)"
result_path="$container_path/Documents/server-list-results.txt"
rm -f "$result_path"
SIMCTL_CHILD_DYLD_INSERT_LIBRARIES="$validation_dir/MUServerListTests.dylib" xcrun simctl launch "$validation_device" "$validation_bundle"
for attempt in {1..150}; do
    if [[ -f "$result_path" ]]; then
        cat "$result_path"
        rg -q '^ALL SERVER LIST TESTS PASSED$' "$result_path"
        exit
    fi
    sleep .2
done
printf 'Server list tests did not finish. Validation files: %s\n' "$validation_dir" >&2
exit 1
