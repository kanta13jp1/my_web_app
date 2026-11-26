#!/usr/bin/env python3
"""Unit tests for scripts/home_folder_policy_check.py (#2799)."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

_SCRIPTS_DIR = Path(__file__).resolve().parent
if str(_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_DIR))

from home_folder_policy_check import (  # noqa: E402
    sample_home_folder_policy,
    validate_home_folder_policy,
)


class HomeFolderPolicyCheckTests(unittest.TestCase):
    def test_sample_policy_passes(self) -> None:
        res = validate_home_folder_policy(sample_home_folder_policy())
        self.assertTrue(res.ok, msg=f"Errors: {res.errors}")
        self.assertEqual(len(res.validated_sync_paths), 2)

    def test_unencrypted_or_traversal_path_fails(self) -> None:
        bad = sample_home_folder_policy()
        bad["encryptionEnabled"] = False
        bad["syncPaths"] = ["../etc/passwd"]
        res = validate_home_folder_policy(bad)
        self.assertFalse(res.ok)
        self.assertIn("encryptionEnabled must be true", res.errors)

    def test_strict_mode_blocks_clipboard_exfiltration(self) -> None:
        bad = sample_home_folder_policy()
        bad["fileTransferPolicy"]["allowClipboardToLocal"] = True
        res = validate_home_folder_policy(bad)
        self.assertFalse(res.ok)
        self.assertIn(
            "allowClipboardToLocal must be false in strictSecurityMode",
            res.errors,
        )


if __name__ == "__main__":
    unittest.main()
