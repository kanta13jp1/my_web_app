#!/usr/bin/env python3
"""Unit tests for scripts/image_pipeline_manifest_check.py (#2798)."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

_SCRIPTS_DIR = Path(__file__).resolve().parent
if str(_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_DIR))

from image_pipeline_manifest_check import (  # noqa: E402
    sample_dry_run_manifest,
    validate_image_pipeline_manifest,
)


class ImagePipelineManifestCheckTests(unittest.TestCase):
    def test_valid_manifest_passes_and_builds_notification(self) -> None:
        res = validate_image_pipeline_manifest(sample_dry_run_manifest())
        self.assertTrue(res.ok, msg=f"Errors: {res.errors}")
        self.assertEqual(len(res.rollout_plan), 2)
        self.assertIsNotNone(res.admin_notification)
        assert res.admin_notification is not None
        self.assertEqual(
            res.admin_notification["event"],
            "image_pipeline_dry_run",
        )

    def test_invalid_sha256_and_uri_fail(self) -> None:
        bad = sample_dry_run_manifest()
        bad["sha256"] = "not-a-hex-digest"
        bad["installerUri"] = "ftp://insecure.example.com/app.msi"
        res = validate_image_pipeline_manifest(bad)
        self.assertFalse(res.ok)
        self.assertEqual(len(res.errors), 2)

    def test_empty_target_fleets_fails(self) -> None:
        bad = sample_dry_run_manifest()
        bad["targetFleets"] = []
        res = validate_image_pipeline_manifest(bad)
        self.assertFalse(res.ok)
        self.assertIn("targetFleets must be a non-empty list", res.errors)


if __name__ == "__main__":
    unittest.main()
