#!/usr/bin/env python3
"""Validate mobile distribution readiness without exposing secrets.

This complements check_mobile_release_readiness.py. The older check verifies
native metadata; this check verifies that distribution automation, store
handoff docs, signing placeholders, and secret presence gates are wired.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Mapping


ROOT = Path(__file__).resolve().parents[1]

ANDROID_SECRETS = (
    "ANDROID_KEYSTORE_BASE64",
    "ANDROID_KEYSTORE_PASSWORD",
    "ANDROID_KEY_ALIAS",
    "ANDROID_KEY_PASSWORD",
    "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON",
)

IOS_SECRETS = (
    "APPLE_TEAM_ID",
    "APP_STORE_CONNECT_KEY_ID",
    "APP_STORE_CONNECT_ISSUER_ID",
    "APP_STORE_CONNECT_API_KEY_P8",
    "IOS_SIGNING_CERTIFICATE_BASE64",
    "IOS_SIGNING_CERTIFICATE_PASSWORD",
    "IOS_PROVISIONING_PROFILE_BASE64",
)

ANDROID_KEY_PROPERTIES_MARKERS = (
    "storePassword=",
    "keyPassword=",
    "keyAlias=",
    "storeFile=",
)

MOBILE_RELEASE_WORKFLOW_MARKERS = (
    "workflow_dispatch:",
    "android-aab:",
    "ios-no-codesign:",
    "publish-release:",
    "flutter build appbundle --release",
    "flutter build ios --simulator --debug",
    r"re:uses:\s*actions/upload-artifact@[0-9a-f]{40}\s+#\s*v7\b",
)

DISTRIBUTION_WORKFLOW_MARKERS = (
    "Mobile Distribution Readiness",
    "check_mobile_distribution_readiness.py",
    "--require-secrets",
    r"re:uses:\s*actions/upload-artifact@[0-9a-f]{40}\s+#\s*v7\b",
)

DOC_MARKERS: dict[str, tuple[str, ...]] = {
    "docs/MOBILE_SIMULTANEOUS_RELEASE.md": (
        "mobile-distribution-readiness.yml",
        "ANDROID_KEYSTORE_BASE64",
        "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON",
        "APP_STORE_CONNECT_API_KEY_P8",
        "IOS_SIGNING_CERTIFICATE_BASE64",
        "Internal testing",
        "TestFlight",
    ),
    "docs/ANDROID_APP_RELEASE_STEP_BY_STEP.md": (
        "Internal testing",
        "ANDROID_KEYSTORE_BASE64",
        "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON",
    ),
    "docs/IOS_APP_RELEASE_STEP_BY_STEP.md": (
        "TestFlight",
        "APP_STORE_CONNECT_API_KEY_P8",
        "IOS_SIGNING_CERTIFICATE_BASE64",
    ),
}


def read_text(root: Path, relative: str) -> str:
    return (root / relative).read_text(encoding="utf-8")


def add_check(
    checks: list[dict[str, str]],
    name: str,
    ok: bool,
    detail: str,
    *,
    warn: bool = False,
) -> None:
    status = "pass" if ok else ("warn" if warn else "fail")
    checks.append({"name": name, "status": status, "detail": detail})


def selected_secrets(platform: str) -> tuple[str, ...]:
    if platform == "android":
        return ANDROID_SECRETS
    if platform == "ios":
        return IOS_SECRETS
    return ANDROID_SECRETS + IOS_SECRETS


def secret_present(name: str, env: Mapping[str, str]) -> bool:
    flag_names = (f"HAS_{name}", f"MOBILE_SECRET_{name}")
    truthy = {"1", "true", "yes", "present", "set"}
    falsy = {"", "0", "false", "no", "missing", "unset"}

    for flag_name in flag_names:
        if flag_name in env:
            value = env[flag_name].strip().lower()
            if value in truthy:
                return True
            if value in falsy:
                return False

    return bool(env.get(name, "").strip())


def check_file_contains(
    root: Path,
    relative: str,
    markers: tuple[str, ...],
    checks: list[dict[str, str]],
    name: str,
) -> None:
    path = root / relative
    if not path.exists():
        add_check(checks, name, False, f"{relative} is missing.")
        return

    content = read_text(root, relative)
    missing = [
        marker
        for marker in markers
        if not (
            re.search(marker.removeprefix("re:"), content)
            if marker.startswith("re:")
            else marker in content
        )
    ]
    add_check(
        checks,
        name,
        not missing,
        "all markers present" if not missing else f"missing markers: {', '.join(missing)}",
    )


def evaluate(
    *,
    root: Path,
    platform: str,
    require_secrets: bool,
    env: Mapping[str, str],
) -> dict[str, object]:
    checks: list[dict[str, str]] = []
    secrets: list[dict[str, object]] = []

    check_file_contains(
        root,
        ".github/workflows/mobile-release-build.yml",
        MOBILE_RELEASE_WORKFLOW_MARKERS,
        checks,
        "mobile release build workflow",
    )
    check_file_contains(
        root,
        ".github/workflows/mobile-distribution-readiness.yml",
        DISTRIBUTION_WORKFLOW_MARKERS,
        checks,
        "mobile distribution readiness workflow",
    )

    key_example = root / "android/key.properties.example"
    if key_example.exists():
        content = key_example.read_text(encoding="utf-8")
        missing = [marker for marker in ANDROID_KEY_PROPERTIES_MARKERS if marker not in content]
        add_check(
            checks,
            "android key.properties example",
            not missing,
            "release signing template is complete"
            if not missing
            else f"missing markers: {', '.join(missing)}",
        )
    else:
        add_check(checks, "android key.properties example", False, "android/key.properties.example is missing.")

    add_check(
        checks,
        "android key.properties not committed",
        not (root / "android/key.properties").exists(),
        "android/key.properties is absent from the repository worktree",
    )
    add_check(
        checks,
        "android upload keystore not committed",
        not (root / "android/app/upload-keystore.jks").exists(),
        "android/app/upload-keystore.jks is absent from the repository worktree",
    )
    add_check(
        checks,
        "ios privacy manifest exists",
        (root / "ios/Runner/PrivacyInfo.xcprivacy").exists(),
        "ios/Runner/PrivacyInfo.xcprivacy exists",
    )

    for relative, markers in DOC_MARKERS.items():
        check_file_contains(root, relative, markers, checks, f"doc markers: {relative}")

    selected = selected_secrets(platform)
    missing_secrets: list[str] = []
    for secret in selected:
        present = secret_present(secret, env)
        secrets.append({"name": secret, "present": present})
        if not present:
            missing_secrets.append(secret)

    if missing_secrets:
        add_check(
            checks,
            "distribution secrets",
            False,
            f"missing: {', '.join(missing_secrets)}",
            warn=not require_secrets,
        )
    else:
        add_check(
            checks,
            "distribution secrets",
            True,
            "all distribution secret flags are present"
            if platform == "all"
            else f"all {platform} distribution secret flags are present",
        )

    has_failures = any(check["status"] == "fail" for check in checks)
    has_warnings = any(check["status"] == "warn" for check in checks)

    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "status": "fail" if has_failures else ("warn" if has_warnings else "pass"),
        "platform": platform,
        "require_secrets": require_secrets,
        "checks": checks,
        "secrets": secrets,
        "missing_secrets": missing_secrets,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--platform", choices=("all", "android", "ios"), default="all")
    parser.add_argument("--require-secrets", action="store_true")
    parser.add_argument("--report", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    report = evaluate(
        root=args.root.resolve(),
        platform=args.platform,
        require_secrets=args.require_secrets,
        env=os.environ,
    )

    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 1 if report["status"] == "fail" else 0


if __name__ == "__main__":
    sys.exit(main())
