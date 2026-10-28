#!/bin/bash
# Install a network-free interactive fold/resize fixture in an isolated Simulator app.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
app="${1:?Usage: test-duo-layout.sh /path/to/Simulator/Mumble.app}"
device="${MU_TEST_DEVICE:-booted}"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/mumble-duo-tests.XXXXXX")"
bundle=com.blakebill.mumble.audio-lifecycle-tests
python3 - "$app/Info.plist" "$bundle" <<'PY'
import plistlib,sys
from pathlib import Path
if plistlib.loads(Path(sys.argv[1]).read_bytes()).get('CFBundleIdentifier') != sys.argv[2]:
    raise SystemExit('Build the isolated com.blakebill.mumble.audio-lifecycle-tests host before running the Duo fixture.')
PY
xcrun --sdk iphonesimulator clang -arch arm64 -mios-simulator-version-min=27.1 \
    -fobjc-arc -dynamiclib -undefined dynamic_lookup -framework UIKit -framework Foundation \
    -I "$root/Source/Classes" -I "$root/Source/LibMumble" "$root/Tests/Duo/MUDuoLayoutTests.m" -o "$fixture/MUDuoLayoutTests.dylib"
cp -R "$app" "$fixture/Mumble.app"
xcrun simctl terminate "$device" "$bundle" >/dev/null 2>&1 || true
xcrun simctl install "$device" "$fixture/Mumble.app"
container="$(xcrun simctl get_app_container "$device" "$bundle" data)"
rm -f "$container/Documents/duo-state.json" "$container/Documents/duo-failure.txt" "$container/Documents/duo-command.txt"
SIMCTL_CHILD_DYLD_INSERT_LIBRARIES="$fixture/MUDuoLayoutTests.dylib" SIMCTL_CHILD_MU_DUO_TEST_ONBOARDING="${MU_DUO_TEST_ONBOARDING:-}" xcrun simctl launch "$device" "$bundle"
printf 'Fixture data: %s/Documents\n' "$container"
for attempt in {1..100}; do
    if [[ -f "$container/Documents/duo-state.json" ]]; then
        cat "$container/Documents/duo-state.json"
        python3 - "$container/Documents/duo-state.json" <<'PY'
import json,sys
from pathlib import Path
state=json.loads(Path(sys.argv[1]).read_text())
if state['failures']: raise SystemExit('\n'.join(state['failures']))
PY
        exit
    fi
    if [[ -f "$container/Documents/duo-failure.txt" ]]; then
        cat "$container/Documents/duo-failure.txt"
        exit 1
    fi
    sleep .2
done
exit 1
