#!/usr/bin/env python3
"""Validate shipped language coverage and printf argument contracts."""
import argparse
import collections
import json
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile

LANGUAGES = {"en", "zh-Hans", "zh-Hant", "ja", "ko", "de", "fr", "es", "pt-BR", "it", "ru", "da"}
FORMAT = re.compile(r"%(?:(\d+)\$)?([-+ #0]*(?:\d+|\*)?(?:\.(?:\d+|\*))?(?:hh|ll|h|l|z|t|j)?[@diuoxXfFeEgGaAcsp])")
PAIR = re.compile(r'"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;')
# Desktop Qt access-key suffixes have no meaning in the iOS interface.
DESKTOP_MNEMONIC = re.compile(r"[(（]\s*&?[A-Za-z]\s*[)）]")


def read_strings(path):
    data = path.read_bytes()
    if data.startswith(b"bplist") or data.startswith(b"<?xml"):
        return plistlib.loads(data)
    text = data.decode("utf-16" if data.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8")
    pairs = [(json.loads('"' + k + '"'), json.loads('"' + v + '"')) for k, v in PAIR.findall(text)]
    assert len(pairs) == len(dict(pairs)), f"Duplicate keys: {path}"
    return dict(pairs)


def signature(text):
    result = collections.Counter()
    for sequential, match in enumerate(FORMAT.finditer(text.replace("%%", "")), 1):
        result[(int(match[1]) if match[1] else sequential, match[2])] += 1
    return result


def check(folder, info):
    actual = {p.stem for p in folder.glob("*.lproj")}
    assert LANGUAGES <= actual, f"Missing languages: {sorted(LANGUAGES - actual)}"
    assert info["CFBundleDevelopmentRegion"] == "en", "Invalid development language"
    assert info.get("UIPrefersShowingLanguageSettings") is True, "System language setting is not enabled"
    english = read_strings(folder / "en.lproj/Localizable.strings")
    for language in sorted(LANGUAGES):
        strings = read_strings(folder / f"{language}.lproj/Localizable.strings")
        assert strings.keys() == english.keys(), f"Key coverage differs: {language}"
        for key, value in strings.items():
            assert value.strip(), f"Empty translation: {language}: {key}"
            assert not DESKTOP_MNEMONIC.search(value), f"Desktop shortcut marker: {language}: {key}: {value}"
            assert signature(key) == signature(value), f"Format mismatch: {language}: {key}: {value}"
        privacy = read_strings(folder / f"{language}.lproj/InfoPlist.strings")
        for key in ("NSMicrophoneUsageDescription", "NSLocalNetworkUsageDescription"):
            assert privacy.get(key), f"Missing permission translation: {language}: {key}"
        print(f"PASS {language}: {len(strings)} interface strings and permission prompts")


def check_source_keys(root):
    sources = sorted(str(p) for p in (root / "Source").rglob("*") if p.suffix in (".m", ".mm", ".h"))
    with tempfile.TemporaryDirectory(prefix="mumble-localization-keys-") as output:
        subprocess.run(["genstrings", "-o", output, *sources], check=True)
        extracted = read_strings(Path(output) / "Localizable.strings")
    english = read_strings(root / "Resources/en.lproj/Localizable.strings")
    assert extracted.keys() == english.keys(), f"Source/resource key mismatch: {sorted(extracted.keys() ^ english.keys())}"
    print(f"PASS source: all {len(extracted)} extracted strings are translated")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", type=Path, help="Validate a built Mumble.app as well")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    check_source_keys(root)
    check(root / "Resources", plistlib.loads((root / "Source/Info.plist").read_bytes()))
    if args.app:
        check(args.app, plistlib.loads((args.app / "Info.plist").read_bytes()))
