#!/bin/bash
set -euo pipefail
validation_device="${MU_TEST_DEVICE:-booted}"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
app_path="${1:?Usage: bash Scripts/test-ui-interface.sh /path/to/Simulator/Mumble.app}"
validation_root="$(mktemp -d "${TMPDIR:-/tmp}/mumble-ui-tests.XXXXXX")"
mkdir -p "$validation_root"
xcrun --sdk iphonesimulator clang -fmodules -fmodules-cache-path=/tmp/mumble-preview-clang-modules -arch arm64 -mios-simulator-version-min=27.0 -fobjc-arc -dynamiclib -undefined dynamic_lookup -framework UIKit -framework Foundation -framework PhotosUI -framework UniformTypeIdentifiers -I "$repo_root/Source/Classes" -I "$repo_root/Source/LibMumble" "$repo_root/Tests/UIInterface/MUInterfaceAuditValidation.m" "$repo_root/Tests/MessageStore/MUMessageStoreChecks.m" "$repo_root/Tests/Credentials/MUCredentialStoreChecks.m" "$repo_root/Tests/ConnectionLifecycle/MUConnectionLifecycleChecks.m" -o "$validation_root/MUNativeUIValidation.dylib"
python3 - "$app_path" "$validation_root/Mumble.app" <<'PY'
from pathlib import Path
import shutil,plistlib,sys
source=Path(sys.argv[1])
destination=Path(sys.argv[2])
host_info=plistlib.loads((source/'Info.plist').read_bytes())
if host_info.get('CFBundleIdentifier')!='com.blakebill.mumble.audio-lifecycle-tests' or b'__entitlements' not in (source/host_info['CFBundleExecutable']).read_bytes():
    raise SystemExit('Build the isolated Simulator host with CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- PRODUCT_BUNDLE_IDENTIFIER=com.blakebill.mumble.audio-lifecycle-tests before running the UI/certificate audit.')
if destination.exists(): shutil.rmtree(destination)
shutil.copytree(source,destination)
p=destination/'Info.plist'
info=plistlib.loads(p.read_bytes());info['CFBundleIdentifier']='com.blakebill.mumble.audio-lifecycle-tests';info['CFBundleDisplayName']='Mumble Audio Tests';info.pop('CFBundleURLTypes',None);p.write_bytes(plistlib.dumps(info))
PY
# Certificate tests require a Simulator build with signing enabled, so Xcode
# embeds simulated Keychain entitlements. Use the isolated bundle identifier
# com.blakebill.mumble.audio-lifecycle-tests when building that test host.
validation_bundle=com.blakebill.mumble.audio-lifecycle-tests
xcrun simctl terminate "$validation_device" "$validation_bundle" >/dev/null 2>&1 || true
xcrun simctl install "$validation_device" "$validation_root/Mumble.app"
validation_data=$(xcrun simctl get_app_container "$validation_device" "$validation_bundle" data)
rm -f "$validation_data/Documents/composer-ui-results.txt"
launch_arguments=("$validation_bundle")
if [[ -n "${MU_UI_TEST_LANGUAGE:-}" ]]; then
    launch_arguments+=(-AppleLanguages "($MU_UI_TEST_LANGUAGE)")
fi
SIMCTL_CHILD_DYLD_INSERT_LIBRARIES="$validation_root/MUNativeUIValidation.dylib" SIMCTL_CHILD_MU_UI_TEST_LANGUAGE="${MU_UI_TEST_LANGUAGE:-}" xcrun simctl launch "$validation_device" "${launch_arguments[@]}"
for attempt in {1..600}; do
    if [[ -f "$validation_data/Documents/composer-ui-results.txt" ]]; then
        cat "$validation_data/Documents/composer-ui-results.txt"
        rg -q '^ALL INTERFACE AUDIT CHECKS PASSED$' "$validation_data/Documents/composer-ui-results.txt"
        exit
    fi
    sleep .2
done
exit 1
