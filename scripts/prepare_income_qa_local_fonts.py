"""Serve the SDK's real Roboto locally in validation build output only."""
import hashlib
import json
from pathlib import Path
import shutil

flutter_executable = shutil.which("flutter")
assert flutter_executable, "SDK Flutter executable not on PATH"
sdk_root = Path(flutter_executable).resolve().parent.parent
sdk_fonts = sdk_root / "bin/cache/artifacts/material_fonts"
font = sdk_fonts / "roboto-regular.ttf"
license_file = sdk_fonts / "roboto_license.txt"
assert font.is_file() and license_file.is_file(), "SDK Material Roboto missing"
asset_root = Path("build/web/assets")
manifest_file = asset_root / "FontManifest.json"
before = manifest_file.read_bytes()
manifest = json.loads(before)
assert not any(row["family"] == "Roboto" for row in manifest), "Review preexisting Roboto first"
local_fonts = asset_root / "ci-fonts"
local_fonts.mkdir(exist_ok=True)
shutil.copyfile(font, local_fonts / font.name)
shutil.copyfile(license_file, local_fonts / license_file.name)
manifest.append({"family": "Roboto", "fonts": [{"asset": "ci-fonts/roboto-regular.ttf"}]})
manifest_file.write_text(json.dumps(manifest), encoding="utf-8")
evidence = {
    "scope": "validation-only generated build output; product sources unchanged",
    "family": "Roboto",
    "sdk_asset": "bin/cache/artifacts/material_fonts/roboto-regular.ttf",
    "local_asset": "assets/ci-fonts/roboto-regular.ttf",
    "font_sha256": hashlib.sha256(font.read_bytes()).hexdigest(),
    "license_sha256": hashlib.sha256(license_file.read_bytes()).hexdigest(),
    "manifest_before_sha256": hashlib.sha256(before).hexdigest(),
    "manifest_after_sha256": hashlib.sha256(manifest_file.read_bytes()).hexdigest(),
}
Path(".ci-logs/income-responsive-qa/local-fonts.json").write_text(
    json.dumps(evidence, indent=2), encoding="utf-8"
)
print("SDK Roboto registered in validation FontManifest; network fallback unnecessary")
