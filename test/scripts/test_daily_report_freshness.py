#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))

from check_daily_report_freshness import check  # noqa: E402


class DailyReportFreshnessTest(unittest.TestCase):
    def test_generic_daily_report_file_alone_is_not_fresh(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            report = root / "docs" / "daily-reports" / "2026-05-07.md"
            report.parent.mkdir(parents=True)
            report.write_text("# 自分株式会社 日次レポート 2026-05-07\n\n## AI大学更新\n", encoding="utf-8")

            result = check("2026-05-07", root, None)

        self.assertFalse(result["fresh"])
        self.assertTrue(result["signals"]["report_exists"])
        self.assertFalse(result["signals"]["report_marker"])

    def test_generated_marker_makes_report_fresh(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            report = root / "docs" / "daily-reports" / "2026-05-07.md"
            report.parent.mkdir(parents=True)
            report.write_text(
                "# Daily Report\n\n<!-- generated-by: github-actions -->\n",
                encoding="utf-8",
            )

            result = check("2026-05-07", root, None)

        self.assertTrue(result["fresh"])

    def test_matching_metrics_snapshot_can_corrobate_report_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            report = root / "docs" / "daily-reports" / "2026-05-07.md"
            metrics = root / "docs" / "metrics" / "daily-metrics.json"
            report.parent.mkdir(parents=True)
            metrics.parent.mkdir(parents=True)
            report.write_text("# Daily Report\n", encoding="utf-8")
            metrics.write_text(json.dumps({"report_date": "2026-05-07"}), encoding="utf-8")

            result = check("2026-05-07", root, None)

        self.assertTrue(result["fresh"])
        self.assertTrue(result["signals"]["metrics_report_date_matches"])


if __name__ == "__main__":
    unittest.main()
