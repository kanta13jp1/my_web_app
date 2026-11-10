"""Verify the dedicated browser fixture's Flutter-generated local fonts."""
import hashlib
import json
import sys
from pathlib import Path

FONT_ASSETS = {
    "NotoSans": (
        "web/assets/fonts/NotoSans-Regular.ttf",
        "b85c38ecea8a7cfb39c24e395a4007474fa5a4fc864f6ee33309eb4948d232d5",
    ),
    "NotoSansJP": (
        "web/assets/fonts/NotoSansJP-Regular.ttf",
        "6e60ad1ccbb6ce0726bbb3dfd89092692bc1e83af073dd602a323da1e9b25760",
    ),
    "NotoColorEmoji": (
        "web/assets/fonts/NotoColorEmoji.ttf",
        "2073905bc592c76d3fb738769a48505c444cf18c8cef71a232a10dfee06a6412",
    ),
    "Roboto": (
        "fonts/fallback/Roboto-Regular.ttf",
        "79e851404657dac2106b3d22ad256d47824a9a5765458edb72c9102a45816d95",
    ),
}
ICON_ASSETS = {
    "MaterialIcons": "fonts/MaterialIcons-Regular.otf",
    "packages/cupertino_icons/CupertinoIcons": "packages/cupertino_icons/assets/CupertinoIcons.ttf",
}
LICENSE_ASSET = "web/assets/fonts/NotoSans-OFL.txt"
LICENSE_SHA256 = "138b7f6e5d8ab96671ef7604f936d3d077beed67911acfb1b0adb71359dc44bc"


def local_file(path):
    if path.resolve(strict=True) != path or not path.is_file():
        raise ValueError("Missing or unsafe fixture file")
    return path


def verify_font_bytes(assets, relative, expected):
    data = local_file(assets / relative).read_bytes()
    if hashlib.sha256(data).hexdigest() != expected:
        raise ValueError(f"Fixture font/license bytes differ: {relative}")


def verify_fixture_fonts(build):
    assets = build / "assets"
    manifest = json.loads(local_file(assets / "FontManifest.json").read_bytes())
    if not isinstance(manifest, list) or not all(
        isinstance(item, dict) and isinstance(item.get("family"), str) for item in manifest
    ):
        raise ValueError("Unexpected fixture font manifest")
    expected_families = set(FONT_ASSETS) | set(ICON_ASSETS)
    if any(item["family"] not in expected_families for item in manifest):
        raise ValueError("Unexpected font family outside the fixed fixture allowlist")
    for family, relative in ICON_ASSETS.items():
        icons = [item for item in manifest if item["family"] == family]
        if icons != [{"family": family, "fonts": [{"asset": relative}]}]:
            raise ValueError(f"Unexpected {family} registration")
        local_file(assets / relative)
    for family, (relative, expected) in FONT_ASSETS.items():
        entries = [entry for entry in manifest if entry["family"] == family]
        if len(entries) != 1:
            raise ValueError(f"Expected one {family} registration, found {len(entries)}")
        if entries[0] != {"family": family, "fonts": [{"asset": relative}]}:
            raise ValueError(f"Unexpected {family} asset registration")
        verify_font_bytes(assets, relative, expected)
    verify_font_bytes(assets, LICENSE_ASSET, LICENSE_SHA256)


if __name__ == "__main__":
    source = Path.cwd().resolve(strict=True)
    build = source / "build" / "web"
    requested = Path(sys.argv[1]).absolute()
    if requested != build or requested.resolve(strict=True) != build:
        raise ValueError("Expected this fixture build/web")
    index = local_file(build / "index.html")
    fixture_index = local_file(source / "test/fixtures/asset_panel_index.html")
    if index.read_bytes() != fixture_index.read_bytes():
        raise ValueError("Expected the dedicated asset panel browser fixture index")
    verify_fixture_fonts(build)
