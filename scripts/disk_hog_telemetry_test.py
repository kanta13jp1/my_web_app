#!/usr/bin/env python3
"""Unit tests for disk_hog_telemetry.py."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import disk_hog_telemetry as telemetry


class DiskHogTelemetryTest(unittest.TestCase):
    def test_collects_five_metrics_without_pruning(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            target = home / ".cache" / "codex-runtimes"
            target.mkdir(parents=True)
            (target / "runtime.bin").write_bytes(b"x" * 2 * 1024 * 1024)

            metrics = telemetry.collect_metrics(home)

        self.assertEqual(set(metrics), set(telemetry.MAJOR_DIRS))
        self.assertGreater(metrics["cache_codex_runtimes_MB"], 0)

    def test_threshold_warning_uses_uncovered_dirs_only(self) -> None:
        metrics = {key: 0.0 for key in telemetry.MAJOR_DIRS}
        metrics["cache_codex_runtimes_MB"] = 1500.0
        metrics["plugins_marketplaces_MB"] = 600.0
        metrics["npm_cache_MB"] = 5000.0

        warnings = telemetry.warning_messages(metrics, threshold_mb=2000.0)

        self.assertEqual(len(warnings), 1)
        self.assertIn("2100.0 MB", warnings[0])


if __name__ == "__main__":
    unittest.main()
