#!/usr/bin/env python3
"""Unit tests for Windows Winget toolchain setup (#2805)."""

from __future__ import annotations

import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PS1_PATH = REPO_ROOT / "scripts" / "setup_windows_toolchain.ps1"
DOC_PATH = REPO_ROOT / "docs" / "WINDOWS_WINGET_TOOLCHAIN_SETUP.md"


class WindowsToolchainSetupTests(unittest.TestCase):
    def test_ps1_encoding_utf8_no_bom_and_lf(self) -> None:
        raw = PS1_PATH.read_bytes()
        self.assertFalse(
            raw.startswith(b"\xef\xbb\xbf"),
            "Repo git diff --check requires no BOM",
        )
        self.assertNotIn(b"\r", raw, "Repo git diff --check requires LF")

    def test_ps1_contains_verified_packages_flags_and_checks(self) -> None:
        text = PS1_PATH.read_text(encoding="utf-8-sig")
        for token in (
            "param(",
            "[switch]$DryRun",
            "Git.Git",
            "GitHub.cli",
            "DenoLand.Deno",
            "OpenJS.NodeJS.LTS",
            "--accept-package-agreements",
            "--accept-source-agreements",
            "git --version",
            "gh --version",
            "deno --version",
            "flutter --version",
            "supabase --version",
        ):
            self.assertIn(token, text)
        self.assertNotIn(" && ", text, "PS 5.1 does not support &&")

    def test_doc_covers_proxy_enotfound_and_versions(self) -> None:
        doc = DOC_PATH.read_text(encoding="utf-8")
        self.assertIn("ENOTFOUND", doc)
        self.assertIn("HTTP_PROXY", doc)
        self.assertIn("flutter --version", doc)
        self.assertIn("supabase --version", doc)


if __name__ == "__main__":
    unittest.main()
