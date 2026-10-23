#!/bin/bash
# Replay the application's FMDB build/linker adjustments after a recursive clone.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
fmdb_root="$repo_root/Dependencies/fmdb"
patch_path="$repo_root/Patches/fmdb-ios-modernization.patch"
if [[ ! -e "$fmdb_root/.git" ]]; then
    echo "Initialize FMDB with git submodule update --init --recursive first." >&2
    exit 1
fi
if git -C "$fmdb_root" apply --reverse --check "$patch_path" >/dev/null 2>&1; then
    echo "FMDB integration patch is already applied."
    exit 0
fi
# A failed check preserves any unrelated local dependency changes.
git -C "$fmdb_root" apply --check "$patch_path"
git -C "$fmdb_root" apply "$patch_path"
echo "Applied FMDB integration patch."
