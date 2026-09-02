#!/usr/bin/env python3
"""Tests for mobile distribution readiness gate."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/check_mobile_distribution_readiness.py"
SPEC = importlib.util.spec_from_file_location("mobile_distribution_readiness", SCRIPT)
assert SPEC and SPEC.loader
mobile_distribution_readiness = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(mobile_distribution_readiness)


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


class MobileDistributionReadinessTest(unittest.TestCase):
    def make_root(self) -> tempfile.TemporaryDirectory[str]:
        temp = tempfile.TemporaryDirectory()
        root = Path(temp.name)
        write(
            root / ".github/workflows/mobile-release-build.yml",
            "\n".join(
                (
                    "workflow_dispatch:",
                    "android-aab:",
                    "ios-no-codesign:",
                    "publish-release:",
                    "run: flutter build appbundle --release",
                    "run: flutter build ios --simulator --debug",
                    "uses: actions/upload-artifact@0123456789012345678901234567890123456789 # v7",
                )
            ),
        )
        write(
            root / ".github/workflows/mobile-distribution-readiness.yml",
            "\n".join(
                (
                    "name: Mobile Distribution Readiness",
                    "run: python scripts/check_mobile_distribution_readiness.py --require-secrets",
                    "uses: actions/upload-artifact@0123456789012345678901234567890123456789 # v7",
                )
            ),
        )
        write(
            root / "android/key.properties.example",
            "\n".join(
                (
                    "storePassword=replace",
                    "keyPassword=replace",
                    "keyAlias=upload",
                    "storeFile=app/upload-keystore.jks",
                )
            ),
        )
        write(root / "ios/Runner/PrivacyInfo.xcprivacy", "<plist/>")
        write(
            root / "docs/MOBILE_SIMULTANEOUS_RELEASE.md",
            "mobile-distribution-readiness.yml ANDROID_KEYSTORE_BASE64 "
            "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON APP_STORE_CONNECT_API_KEY_P8 "
            "IOS_SIGNING_CERTIFICATE_BASE64 Internal testing TestFlight",
        )
        write(
            root / "docs/ANDROID_APP_RELEASE_STEP_BY_STEP.md",
            "Internal testing ANDROID_KEYSTORE_BASE64 GOOGLE_PLAY_SERVICE_ACCOUNT_JSON",
        )
        write(
            root / "docs/IOS_APP_RELEASE_STEP_BY_STEP.md",
            "TestFlight APP_STORE_CONNECT_API_KEY_P8 IOS_SIGNING_CERTIFICATE_BASE64",
        )
        return temp

    def test_missing_secrets_warn_without_strict_mode(self) -> None:
        with self.make_root() as temp:
            report = mobile_distribution_readiness.evaluate(
                root=Path(temp),
                platform="all",
                require_secrets=False,
                env={},
            )

        self.assertEqual(report["status"], "warn")
        self.assertTrue(report["missing_secrets"])

    def test_missing_secrets_fail_with_strict_mode(self) -> None:
        with self.make_root() as temp:
            report = mobile_distribution_readiness.evaluate(
                root=Path(temp),
                platform="android",
                require_secrets=True,
                env={},
            )

        self.assertEqual(report["status"], "fail")
        self.assertIn("ANDROID_KEYSTORE_BASE64", report["missing_secrets"])
        self.assertNotIn("APPLE_TEAM_ID", report["missing_secrets"])

    def test_secret_flags_pass_strict_mode(self) -> None:
        env = {f"HAS_{name}": "true" for name in mobile_distribution_readiness.selected_secrets("all")}
        with self.make_root() as temp:
            report = mobile_distribution_readiness.evaluate(
                root=Path(temp),
                platform="all",
                require_secrets=True,
                env=env,
            )

        self.assertEqual(report["status"], "pass")
        self.assertEqual(report["missing_secrets"], [])

    def test_committed_android_key_properties_fails(self) -> None:
        with self.make_root() as temp:
            root = Path(temp)
            write(root / "android/key.properties", "storePassword=secret")
            report = mobile_distribution_readiness.evaluate(
                root=root,
                platform="android",
                require_secrets=False,
                env={},
            )

        failed = {check["name"] for check in report["checks"] if check["status"] == "fail"}
        self.assertIn("android key.properties not committed", failed)


if __name__ == "__main__":
    unittest.main()
