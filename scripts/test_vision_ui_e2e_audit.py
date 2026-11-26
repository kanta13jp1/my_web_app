#!/usr/bin/env python3
"""Unit tests for scripts/vision_ui_e2e_audit.py (#2790)."""

from __future__ import annotations

import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))

import vision_ui_e2e_audit as audit  # noqa: E402


class VisionUiE2eAuditTest(unittest.TestCase):
    def test_high_res_capture_preserves_resolution_and_tokens(self) -> None:
        cap = audit.ScreenshotCaptureMetadata(
            route="/",
            width_px=1440,
            height_px=2560,
            full_page=True,
            downscaled=False,
            image_path="playwright-report/home-full.png",
        )
        self.assertEqual(cap.long_edge_px, 2560)
        self.assertFalse(cap.exceeds_high_res_limit)
        # ceil(1440/28)=52, ceil(2560/28)=92 -> 52 * 92 = 4784
        self.assertEqual(cap.estimated_vision_tokens, 4784)

    def test_flags_downscaling_and_over_limit_long_edge(self) -> None:
        report = audit.evaluate_audit_run(
            run_id="run-viol",
            captures=[
                audit.ScreenshotCaptureMetadata(
                    route="/settings",
                    width_px=1280,
                    height_px=3000,
                    full_page=True,
                    downscaled=True,
                    image_path="playwright-report/settings.png",
                ),
            ],
            findings=[],
            budget_config=audit.TaskBudgetConfig(max_total_tokens=20000),
        )
        self.assertEqual(report.downscale_violations, 1)
        self.assertEqual(report.over_limit_captures, 1)
        self.assertFalse(report.budget_exceeded)

    def test_task_budget_ceiling_detects_overrun(self) -> None:
        report = audit.evaluate_audit_run(
            run_id="run-budget",
            captures=[
                audit.ScreenshotCaptureMetadata(
                    route="/dashboard",
                    width_px=1440,
                    height_px=2560,
                    full_page=True,
                    downscaled=False,
                    image_path="playwright-report/dash.png",
                ),
            ],
            findings=[],
            budget_config=audit.TaskBudgetConfig(max_total_tokens=4000),
            prompt_overhead_per_capture=500,
        )
        self.assertTrue(report.budget_exceeded)
        self.assertEqual(report.total_estimated_tokens, 5284)

    def test_dry_run_cli_generates_json_and_issue_markdown(self) -> None:
        payload = {
            "run_id": "ci-2790",
            "captures": [
                {
                    "route": "/pricing",
                    "width_px": 1280,
                    "height_px": 1800,
                    "full_page": True,
                    "downscaled": False,
                    "image_path": "playwright-report/pricing.png",
                }
            ],
            "findings": [
                {
                    "route": "/pricing",
                    "severity": "high",
                    "category": "layout_overflow",
                    "summary": "CTA button clips horizontally at 375px",
                    "details": "Right edge clipped by 14px in mobile viewport.",
                    "screenshot_path": "playwright-report/pricing.png",
                }
            ],
        }
        with tempfile.TemporaryDirectory() as tmp:
            tmp_dir = Path(tmp)
            in_path = tmp_dir / "input.json"
            out_json = tmp_dir / "report.json"
            out_md = tmp_dir / "issue.md"
            in_path.write_text(json.dumps(payload), encoding="utf-8")

            rc = audit.main(
                [
                    "--input",
                    str(in_path),
                    "--budget-tokens",
                    "64000",
                    "--out-json",
                    str(out_json),
                    "--out-md",
                    str(out_md),
                ]
            )
            self.assertEqual(rc, 0)
            parsed = json.loads(out_json.read_text(encoding="utf-8"))
            self.assertEqual(parsed["findings_total"], 1)
            self.assertFalse(parsed["budget_exceeded"])
            md = out_md.read_text(encoding="utf-8")
            self.assertIn("[HIGH] `/pricing` (layout_overflow)", md)
            self.assertIn("CTA button clips horizontally at 375px", md)


if __name__ == "__main__":
    unittest.main()
