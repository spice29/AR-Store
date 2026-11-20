#!/usr/bin/env python3
"""Generate an iOS OTA installation manifest for an already signed Ad Hoc IPA.

This does not sign IPA files or register devices. Both IPA and manifest must be
served via trusted HTTPS; the IPA URL must remain reachable by iOS during install.
"""
import argparse
import html
import pathlib
import plistlib
import re
from urllib.parse import urlparse, quote

def https_url(value: str) -> str:
    parsed = urlparse(value)
    if parsed.scheme != "https" or not parsed.netloc or parsed.username or parsed.password or parsed.fragment:
        raise argparse.ArgumentTypeError("URL must be absolute HTTPS without credentials or fragments")
    return value

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--ipa-url", required=True, type=https_url)
    p.add_argument("--manifest-url", required=True, type=https_url)
    p.add_argument("--bundle-id", required=True)
    p.add_argument("--version", required=True)
    p.add_argument("--title", required=True)
    p.add_argument("--output", default="dist")
    a = p.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", a.bundle_id):
        p.error("Invalid bundle identifier")
    if not a.version.strip() or not a.title.strip():
        p.error("Version and title are required")
    output = pathlib.Path(a.output)
    output.mkdir(parents=True, exist_ok=True)
    manifest = {
        "items": [{
            "assets": [{"kind": "software-package", "url": a.ipa_url}],
            "metadata": {
                "bundle-identifier": a.bundle_id,
                "bundle-version": a.version,
                "kind": "software",
                "title": a.title,
            },
        }]
    }
    (output / "manifest.plist").write_bytes(plistlib.dumps(manifest, fmt=plistlib.FMT_XML))
    install_url = "itms-services://?action=download-manifest&url=" + quote(a.manifest_url, safe="")
    page = (
        "<!doctype html><html lang='ar' dir='rtl'><head>"
        "<meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>"
        "<title>ABUREMAS | تثبيت التطبيق</title>"
        "<style>body{background:#0a1221;color:#f5f5f5;font:18px -apple-system,system-ui;"
        "padding:32px;max-width:540px;margin:10vh auto;text-align:center}"
        "a{display:block;background:#e8ba59;color:#10141c;border-radius:14px;"
        "padding:16px;margin:28px 0;font-weight:700;text-decoration:none}"
        "small{color:#b7c0cf}</style></head><body>"
        "<h1>ABUREMAS</h1><h2>" + html.escape(a.title) + "</h2>"
        "<a href='" + html.escape(install_url, quote=True) + "'>تثبيت التطبيق</a>"
        "<small>يعمل فقط على أجهزة مسجلة في ملف Ad Hoc المستخدم لتوقيع التطبيق. "
        "افتح الصفحة من Safari على الجهاز المصرح له.</small></body></html>"
    )
    (output / "index.html").write_text(page, encoding="utf-8")
    print("Generated:", output / "manifest.plist", output / "index.html")
    print("Install URL:", install_url)

if __name__ == "__main__":
    main()
