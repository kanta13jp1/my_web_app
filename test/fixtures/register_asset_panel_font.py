import hashlib
import json
import sys
from pathlib import Path

FONT_ASSET = "web/assets/fonts/NotoSans-Regular.ttf"
FONT_SHA256 = "b85c38ecea8a7cfb39c24e395a4007474fa5a4fc864f6ee33309eb4948d232d5"
LICENSE_ASSET = "web/assets/fonts/NotoSans-OFL.txt"
LICENSE_SHA256 = "138b7f6e5d8ab96671ef7604f936d3d077beed67911acfb1b0adb71359dc44bc"


def register_fixture_font(root):
    manifest_path = root / "assets" / "FontManifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if not isinstance(manifest, list) or not all(
        isinstance(family, dict) for family in manifest
    ):
        raise ValueError("Unexpected fixture font manifest")
    families = [family.get("family") for family in manifest]
    if "Roboto" in families or families.count("NotoSans") != 1:
        raise ValueError("Expected one NotoSans family and no Roboto family")
    noto = next(family for family in manifest if family.get("family") == "NotoSans")
    if noto.get("fonts") != [{"asset": FONT_ASSET}]:
        raise ValueError("Unexpected NotoSans asset registration")
    for asset, expected in (
        (FONT_ASSET, FONT_SHA256),
        (LICENSE_ASSET, LICENSE_SHA256),
    ):
        path = root / "assets" / asset
        if not path.is_file() or path.is_symlink():
            raise ValueError("Missing or unsafe fixture font/license asset")
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise ValueError("Fixture font/license provenance mismatch")
    # Alias existing bytes only. Do not copy, rewrite, or rename the font.
    result = [*manifest, {"family": "Roboto", "fonts": [{"asset": FONT_ASSET}]}]
    manifest_path.write_text(json.dumps(result) + "\n", encoding="utf-8")


if __name__ == "__main__":
    fixture_root = Path(sys.argv[1])
    expected_root = Path.cwd().resolve() / "build" / "web"
    if fixture_root.resolve() != expected_root:
        raise ValueError("Only the asset panel browser fixture build may be changed")
    index = fixture_root / "index.html"
    fixture_index = Path("test/fixtures/asset_panel_index.html")
    if index.is_symlink() or index.read_bytes() != fixture_index.read_bytes():
        raise ValueError("Expected the dedicated asset panel browser fixture index")
    manifest = fixture_root / "assets" / "FontManifest.json"
    if manifest.is_symlink() or manifest.resolve() != expected_root / "assets" / "FontManifest.json":
        raise ValueError("Unsafe fixture manifest path")
    register_fixture_font(fixture_root)
