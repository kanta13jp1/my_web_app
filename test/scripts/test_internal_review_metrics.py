import contextlib
import io
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

import internal_review_metrics as irm  # noqa: E402


class InternalReviewMetricsTest(unittest.TestCase):
    def test_evaluate_pass_and_density_math(self) -> None:
        breakdown = irm.FindingBreakdown(spec=1, design=1, security=0, uiux=1, test=1)
        report = irm.evaluate_internal_review(
            scope_size=0.5,
            review_minutes=30,
            breakdown=breakdown,
            minimum_review_density=30.0,
            minimum_finding_density=2.0,
        )
        self.assertEqual(report.breakdown.total, 4)
        self.assertEqual(report.review_density, 60.0)
        self.assertEqual(report.finding_density, 8.0)
        self.assertTrue(report.meets_review_density)
        self.assertTrue(report.meets_finding_density)
        self.assertEqual(report.status, "pass")

    def test_evaluate_warn_when_below_threshold(self) -> None:
        report = irm.evaluate_internal_review(
            scope_size=2.0,
            review_minutes=20,
            breakdown=irm.FindingBreakdown(spec=1),
            minimum_review_density=30.0,
            minimum_finding_density=1.0,
        )
        self.assertEqual(report.review_density, 10.0)
        self.assertEqual(report.finding_density, 0.5)
        self.assertFalse(report.meets_review_density)
        self.assertFalse(report.meets_finding_density)
        self.assertEqual(report.status, "warn")

    def test_rejects_invalid_inputs(self) -> None:
        with self.assertRaises(ValueError):
            irm.evaluate_internal_review(scope_size=0, review_minutes=10)
        with self.assertRaises(ValueError):
            irm.evaluate_internal_review(scope_size=1.0, review_minutes=-5)
        with self.assertRaises(ValueError):
            irm.FindingBreakdown(security=-1)

    def test_parse_inline_and_table_markdown(self) -> None:
        pr_md = """
| 対象規模 (`scope_size`) | `0.5 KLOC` | レビュー密度算出母数 |
| レビュー所要時間 (`review_minutes`) | `45 分` | 正味レビュー時間 |
| 指摘件数内訳 | `spec:1 / design:2 / security:1 / uiux:0 / test:1` | 分類別カウント |
"""
        parsed = irm.parse_markdown_record(pr_md)
        self.assertEqual(parsed["scope_size"], 0.5)
        self.assertEqual(parsed["review_minutes"], 45)
        breakdown = parsed["breakdown"]
        self.assertIsInstance(breakdown, irm.FindingBreakdown)
        assert isinstance(breakdown, irm.FindingBreakdown)
        self.assertEqual(breakdown.total, 5)
        self.assertEqual(breakdown.security, 1)

        issue_md = """
- 対象規模 (`scope_size`): 1.25
- レビュー所要時間 (`review_minutes`): 60

| 仕様 (`spec`) | 2 | missing edge |
| 設計 (`design`) | 1 | extract helper |
| セキュリティ (`security`) | 0 | ok |
| UI/UX (`uiux`) | 1 | contrast |
| テスト (`test`) | 2 | boundary cases |
"""
        parsed_issue = irm.parse_markdown_record(issue_md)
        b2 = parsed_issue["breakdown"]
        assert isinstance(b2, irm.FindingBreakdown)
        self.assertEqual(b2.spec, 2)
        self.assertEqual(b2.total, 6)

    def test_cli_json_and_strict_exit_code(self) -> None:
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = irm.main(
                [
                    "--scope-size",
                    "0.5",
                    "--review-minutes",
                    "30",
                    "--spec",
                    "1",
                    "--uiux",
                    "1",
                    "--json",
                    "--strict",
                ]
            )
        self.assertEqual(rc, 0)
        payload = json.loads(buf.getvalue())
        self.assertEqual(payload["status"], "pass")
        self.assertEqual(payload["findings"]["total"], 2)

        buf2 = io.StringIO()
        with contextlib.redirect_stdout(buf2):
            rc2 = irm.main(
                [
                    "--scope-size",
                    "5.0",
                    "--review-minutes",
                    "10",
                    "--strict",
                ]
            )
        self.assertEqual(rc2, 2)

    def test_templates_contain_required_review_sections(self) -> None:
        pr_tpl = (ROOT / ".github" / "PULL_REQUEST_TEMPLATE.md").read_text(encoding="utf-8")
        self.assertIn("内部レビュー観点（仕様・セキュリティ・UIUX）と品質メトリクス", pr_tpl)
        self.assertIn("仕様整合", pr_tpl)
        self.assertIn("セキュリティ", pr_tpl)
        self.assertIn("UI/UX", pr_tpl)
        self.assertIn("レビュー密度", pr_tpl)

        issue_tpl = (ROOT / ".github" / "ISSUE_TEMPLATE" / "internal_review.md").read_text(
            encoding="utf-8"
        )
        self.assertIn("Internal Review Record", issue_tpl)
        self.assertIn("仕様 (`spec`)", issue_tpl)
        self.assertIn("セキュリティ (`security`)", issue_tpl)
        self.assertIn("UI/UX (`uiux`)", issue_tpl)


if __name__ == "__main__":
    unittest.main()
