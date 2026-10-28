#!/bin/bash
# Own every Simulator created here; never replace or reset a developer's device.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
app="${1:?Usage: bash Scripts/test-simulator.sh /path/to/isolated/Mumble.app}"
reports="${2:-$(mktemp -d "${TMPDIR:-/tmp}/mumble-simulator-reports.XXXXXX")}"
configuration="$(mktemp -d "${TMPDIR:-/tmp}/mumble-simulator-config.XXXXXX")"
mkdir -p "$reports"
bundle=com.blakebill.mumble.audio-lifecycle-tests
primary_device=""; duo_device=""
cleanup() {
    for device in "$primary_device" "$duo_device"; do
        if [[ -n "$device" ]]; then
            xcrun simctl shutdown "$device" >/dev/null 2>&1 || true
            xcrun simctl delete "$device" >/dev/null 2>&1 || true
        fi
    done
}
trap cleanup EXIT
xcrun simctl list runtimes --json > "$configuration/runtimes.json"
xcrun simctl list devicetypes --json > "$configuration/types.json"
xcrun --sdk iphonesimulator --show-sdk-version > "$configuration/sdk.txt"
python3 - "$configuration" <<'PY'
import json,sys
from pathlib import Path
folder=Path(sys.argv[1])
version=lambda text:tuple(int(p) for p in text.split('.'))
runtimes=sorted((r for r in json.loads((folder/'runtimes.json').read_text())['runtimes'] if r.get('isAvailable') and '.iOS-' in r['identifier'] and version(r['version'])>=(27,0)),key=lambda r:version(r['version']),reverse=True)
types=json.loads((folder/'types.json').read_text())['devicetypes']
primary=None;duo=None
for runtime in runtimes:
    supported=runtime.get('supportedDeviceTypes',types)
    phones=[t for t in supported if t.get('productFamily')=='iPhone' or '.iPhone-' in t['identifier']]
    ordinary=[t for t in phones if 'Duo' not in t['name']]
    if ordinary and primary is None:
        preferred=next((t for t in ordinary if t['name']=='iPhone 18 Pro'),None) or next((t for t in ordinary if 'Pro' in t['name']),ordinary[0])
        primary=(preferred['identifier'],runtime['identifier'])
    fold=next((t for t in phones if 'Duo' in t['name']),None)
    if fold and duo is None and version(runtime['version'])>=(27,1) and version((folder/'sdk.txt').read_text().strip())>=(27,1):duo=(fold['identifier'],runtime['identifier'])
if primary is None:raise SystemExit('An available iOS 27+ runtime with an iPhone Simulator is required. Install it with xcodebuild -downloadPlatform iOS -architectureVariant arm64.')
(folder/'primary.txt').write_text('\n'.join(primary)+'\n')
if duo:(folder/'duo.txt').write_text('\n'.join(duo)+'\n')
PY
primary_type="$(sed -n '1p' "$configuration/primary.txt")"
primary_runtime="$(sed -n '2p' "$configuration/primary.txt")"
primary_device="$(xcrun simctl create 'Mumble Regression' "$primary_type" "$primary_runtime")"
xcrun simctl boot "$primary_device"
xcrun simctl bootstatus "$primary_device" -b
collect_reports() {
    local device="$1" stage="$2" container
    container="$(xcrun simctl get_app_container "$device" "$bundle" data 2>/dev/null)" || return 0
    python3 - "$container/Documents" "$reports/$stage" <<'PY'
import shutil,sys
from pathlib import Path
source,destination=map(Path,sys.argv[1:])
destination.mkdir(parents=True,exist_ok=True)
for pattern in ('*-results.txt','*.png','duo-state.json','duo-failure.txt'):
    for path in source.glob(pattern):shutil.copy2(path,destination/path.name)
PY
}
run_check() {
    local stage="$1" device="$2" status=0
    shift 2
    MU_TEST_DEVICE="$device" "$@" 2>&1 | tee "$reports/$stage.log" || status=$?
    collect_reports "$device" "$stage"
    return "$status"
}
run_check audio-async "$primary_device" bash "$root/Scripts/test-audio-lifecycle.sh" "$app" async
run_check audio-legacy "$primary_device" bash "$root/Scripts/test-audio-lifecycle.sh" "$app" legacy
run_check server-list "$primary_device" bash "$root/Scripts/test-server-list.sh" "$app"
run_check interface "$primary_device" bash "$root/Scripts/test-ui-interface.sh" "$app"
if [[ -f "$configuration/duo.txt" ]]; then
    duo_type="$(sed -n '1p' "$configuration/duo.txt")"
    duo_runtime="$(sed -n '2p' "$configuration/duo.txt")"
    duo_device="$(xcrun simctl create 'Mumble Duo Regression' "$duo_type" "$duo_runtime")"
    xcrun simctl boot "$duo_device"
    xcrun simctl bootstatus "$duo_device" -b
    run_check duo "$duo_device" bash "$root/Scripts/test-duo-layout.sh" "$app"
    run_check duo-home "$duo_device" env SIMCTL_CHILD_MU_UI_TEST_HOME_ONLY=1 MU_UI_TEST_LANGUAGE=de bash "$root/Scripts/test-ui-interface.sh" "$app"
else
    printf '::notice::Duo runtime/device unavailable; single/dual-column resize checks still run in the interface audit.\n' | tee "$reports/duo-availability.log"
fi
