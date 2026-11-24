#!/usr/bin/env python3
"""Unit tests for the product and market research pipeline (#2677)."""

from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

import product_market_research_pipeline as pipeline  # noqa: E402


class ProductMarketResearchPipelineTest(unittest.TestCase):
    def test_trigger_context_accepts_env_and_issue_json(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            issue_file = Path(tmpdir) / "issue.json"
            issue_file.write_text(
                json.dumps(
                    {
                        "number": 2677,
                        "title": "AI research pipeline test",
                        "body": "Collect primary market and compliance sources.",
                    },
                ),
                encoding="utf-8",
            )
            ctx = pipeline.parse_trigger_context(
                issue_json_path=issue_file,
                budget_minutes=20,
            )
            self.assertEqual(ctx["issue_number"], 2677)
            self.assertEqual(ctx["topic"], "AI research pipeline test")
            self.assertEqual(ctx["budget_minutes"], 20)
            self.assertEqual(len(ctx["angles"]), 4)

        with patch.dict(
            os.environ,
            {
                "RESEARCH_TOPIC": "",
                "RESEARCH_ISSUE_NUMBER": "42",
                "RESEARCH_ISSUE_TITLE": "Env issue title",
            },
            clear=False,
        ):
            env_ctx = pipeline.parse_trigger_context(budget_minutes=10)
            self.assertEqual(env_ctx["issue_number"], 42)
            self.assertEqual(env_ctx["topic"], "Env issue title")

    def test_budget_bounds_and_issue_validation(self) -> None:
        for bad_budget in (0, 4, 46, 120):
            with self.assertRaises(ValueError):
                pipeline.parse_trigger_context(topic="x", budget_minutes=bad_budget)
        with self.assertRaises(ValueError):
            pipeline.parse_trigger_context(topic="x", issue_number="abc", budget_minutes=15)

    def test_rejects_uncited_and_unknown_citations_fail_closed(self) -> None:
        bundle = pipeline.default_research_bundle("AI Agent Hub")
        with self.assertRaises(ValueError):
            pipeline.validate_sources_and_findings(
                bundle["sources"],
                [
                    {
                        "angle": "market_demand",
                        "summary": "Missing citations",
                        "requirement": "Should fail",
                        "citation_ids": [],
                    },
                ],
                [],
            )

        with self.assertRaises(ValueError):
            pipeline.validate_sources_and_findings(
                bundle["sources"],
                [
                    {
                        "angle": "market_demand",
                        "summary": "Unknown citation",
                        "requirement": "Should fail",
                        "citation_ids": ["S999"],
                    },
                ],
                [],
            )

        with self.assertRaises(ValueError):
            pipeline.validate_sources_and_findings(
                bundle["sources"],
                bundle["findings"],
                [
                    {
                        "risk_id": "R99",
                        "title": "Risk without source",
                        "severity": "high",
                        "mitigation": "Require citation",
                        "citation_ids": [],
                    },
                ],
            )

    def test_ssrf_blocks_unsafe_urls(self) -> None:
        for url in (
            "http://example.com/report",
            "https://localhost/internal",
            "https://127.0.0.1/internal",
            "https://169.254.169.254/latest/meta-data",
            "https://10.20.30.40/admin",
            "https://100.64.1.1/cgnat",
            "https://[::ffff:127.0.0.1]/mapped",
        ):
            with self.assertRaises(ValueError):
                pipeline.validate_public_https_url(url)

    def test_end_to_end_synthesis_state_tracking_and_cli_outputs(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            sources_file = tmp / "bundle.json"
            sources_file.write_text(
                json.dumps(pipeline.default_research_bundle("Cross-channel PRD automation"), ensure_ascii=False),
                encoding="utf-8",
            )
            state_out = tmp / "state.json"
            json_out = tmp / "report.json"
            md_out = tmp / "report.md"
            notify_out = tmp / "notify.json"
            gh_out = tmp / "gh_output.txt"

            rc = pipeline.main(
                [
                    "--topic",
                    "Cross-channel PRD automation",
                    "--issue-number",
                    "2677",
                    "--budget-minutes",
                    "30",
                    "--sources-json",
                    str(sources_file),
                    "--notify-mode",
                    "issue-comment-dry-run",
                    "--dry-run",
                    "--state-file",
                    str(state_out),
                    "--json-out",
                    str(json_out),
                    "--markdown-out",
                    str(md_out),
                    "--notify-json-out",
                    str(notify_out),
                    "--github-output",
                    str(gh_out),
                ],
            )
            self.assertEqual(rc, 0)

            report = json.loads(json_out.read_text(encoding="utf-8"))
            self.assertEqual(report["status"], "completed")
            self.assertEqual(report["source_count"], 4)
            self.assertEqual(report["finding_count"], 4)
            self.assertEqual(report["risk_count"], 2)
            self.assertEqual(report["missing_angles"], [])

            state = json.loads(state_out.read_text(encoding="utf-8"))
            self.assertEqual(
                [item["stage"] for item in state["history"]],
                list(pipeline.JOB_STATES),
            )

            md = md_out.read_text(encoding="utf-8")
            self.assertIn("プロダクト要件定義 (PRD)", md)
            self.assertIn("リスク管理 (Risk Management)", md)
            self.assertIn("[S1]", md)

            notify = json.loads(notify_out.read_text(encoding="utf-8"))
            self.assertEqual(notify["mode"], "issue-comment-dry-run")
            self.assertFalse(notify["dispatched"])
            self.assertTrue(notify["dry_run"])

            gh_text = gh_out.read_text(encoding="utf-8")
            self.assertIn("status=completed", gh_text)
            self.assertIn("prd_ready=true", gh_text)

    def test_self_test_cli_passes(self) -> None:
        self.assertEqual(pipeline.main(["--self-test"]), 0)


if __name__ == "__main__":
    unittest.main()
