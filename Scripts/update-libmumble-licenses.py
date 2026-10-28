#!/usr/bin/env python3
"""Refresh the third-party notices embedded in the application's Legal screen."""
from pathlib import Path
import html

root = Path(__file__).resolve().parents[1]
page = root / "Resources/Legal.html"
text = page.read_text()
begin = "<!-- libmumble licenses begin -->"
end = "<!-- libmumble licenses end -->"
notices = []
for name in ("libmumble", "ipxx", "quickpool", "openssl", "opus", "speexdsp", "protobuf", "abseil", "utf8-range"):
    notice = (root / f"Dependencies/Generated/licenses/{name}.txt").read_text()
    notices.append(f"<h3>{html.escape(name)}</h3><pre>{html.escape(notice)}</pre><hr/>\n")
content = begin + "\n" + "".join(notices) + end
assert begin in text and end in text, "Missing license section markers"
text = text[:text.index(begin)] + content + text[text.index(end) + len(end):]
page.write_text(text)
