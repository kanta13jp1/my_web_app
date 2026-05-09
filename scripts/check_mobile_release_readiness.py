#!/usr/bin/env python3
"""Validate native mobile release metadata before store builds."""

from __future__ import annotations

import plistlib
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ANDROID_NS = "{http://schemas.android.com/apk/res/android}"
MOJIBAKE_MARKERS = ("繧", "縺", "譁", "荳", "蜈", "逕", "�", "", "\ufffd")


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def fail_if(condition: bool, message: str, failures: list[str]) -> None:
    if condition:
        failures.append(message)


def extract_quoted_assignment(content: str, key: str) -> str | None:
    match = re.search(rf"\b{re.escape(key)}\s*=\s*\"([^\"]+)\"", content)
    return match.group(1) if match else None


def check_android(failures: list[str]) -> None:
    build_gradle = read_text(ROOT / "android/app/build.gradle")
    namespace = extract_quoted_assignment(build_gradle, "namespace")
    application_id = extract_quoted_assignment(build_gradle, "applicationId")

    fail_if(not namespace, "Android namespace is missing.", failures)
    fail_if(not application_id, "Android applicationId is missing.", failures)
    fail_if(
        bool(application_id and application_id.startswith("com.example")),
        "Android applicationId still uses the com.example placeholder.",
        failures,
    )
    fail_if(
        bool(namespace and namespace.startswith("com.example")),
        "Android namespace still uses the com.example placeholder.",
        failures,
    )
    fail_if(
        "sourceCompatibility = JavaVersion.VERSION_17" not in build_gradle
        or "targetCompatibility = JavaVersion.VERSION_17" not in build_gradle,
        "Android Java compatibility must target Java 17 to match release Kotlin tasks.",
        failures,
    )

    manifest = ET.parse(ROOT / "android/app/src/main/AndroidManifest.xml")
    application = manifest.getroot().find("application")
    label = application.get(f"{ANDROID_NS}label") if application is not None else None
    fail_if(not label, "Android application label is missing.", failures)
    fail_if(
        label in {"my_web_app", "My Web App"},
        "Android application label still uses the Flutter placeholder.",
        failures,
    )

    if application_id:
        activity_path = (
            ROOT
            / "android/app/src/main/kotlin"
            / Path(*application_id.split("."))
            / "MainActivity.kt"
        )
        fail_if(
            not activity_path.exists(),
            f"Android MainActivity package path is missing: {activity_path.relative_to(ROOT)}",
            failures,
        )


def check_ios(failures: list[str]) -> None:
    with (ROOT / "ios/Runner/Info.plist").open("rb") as plist_file:
        plist = plistlib.load(plist_file)

    display_name = plist.get("CFBundleDisplayName")
    bundle_name = plist.get("CFBundleName")
    fail_if(not display_name, "iOS CFBundleDisplayName is missing.", failures)
    fail_if(
        display_name in {"My Web App", "my_web_app"},
        "iOS CFBundleDisplayName still uses the Flutter placeholder.",
        failures,
    )
    fail_if(not bundle_name, "iOS CFBundleName is missing.", failures)
    fail_if(
        bundle_name == "my_web_app",
        "iOS CFBundleName still uses the Flutter placeholder.",
        failures,
    )

    for key in (
        "NSCameraUsageDescription",
        "NSPhotoLibraryUsageDescription",
        "NSMicrophoneUsageDescription",
    ):
        value = plist.get(key, "")
        fail_if(
            len(value.strip()) < 12,
            f"iOS {key} is missing a user-facing purpose string.",
            failures,
        )
        fail_if(
            any(marker in value for marker in MOJIBAKE_MARKERS),
            f"iOS {key} appears to contain mojibake.",
            failures,
        )

    pbxproj = read_text(ROOT / "ios/Runner.xcodeproj/project.pbxproj")
    bundle_ids = set(re.findall(r"PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);", pbxproj))
    fail_if(not bundle_ids, "iOS PRODUCT_BUNDLE_IDENTIFIER is missing.", failures)
    fail_if(
        any(bundle_id.startswith("com.example") for bundle_id in bundle_ids),
        "iOS PRODUCT_BUNDLE_IDENTIFIER still uses the com.example placeholder.",
        failures,
    )


def main() -> int:
    failures: list[str] = []
    check_android(failures)
    check_ios(failures)

    if failures:
        print("Mobile release readiness check failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("Mobile release readiness check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
