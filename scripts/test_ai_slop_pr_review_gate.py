#!/usr/bin/env python3
"""Unit tests for scripts/ai_slop_pr_review_gate.py (#2789)."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

_SCRIPTS_DIR = Path(__file__).resolve().parent
if str(_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_DIR))

from ai_slop_pr_review_gate import WARNING_LABEL, evaluate_pr_files  # noqa: E402


class AiSlopPrReviewGateTests(unittest.TestCase):
    def test_clean_files_approve_without_warning_label(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            ts_file = Path(tmp) / "clean.ts"
            ts_file.write_text(
                'export const greeting = "hello";\n',
                encoding="utf-8",
            )
            report = evaluate_pr_files([ts_file], has_llm_key=False)

        self.assertEqual(report.decision, "approve")
        self.assertFalse(report.apply_warning_label)
        self.assertFalse(report.should_block_merge)
        self.assertEqual(report.optional_llm_status, "skipped_missing_key")
        self.assertIn("PASS", report.markdown)

    def test_security_risk_triggers_block_and_warning_label(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            ts_file = Path(tmp) / "unsafe.ts"
            ts_file.write_text(
                'export function run(x: string) { return eval(x); }\n',
                encoding="utf-8",
            )
            report = evaluate_pr_files([ts_file], has_llm_key=False)

        self.assertEqual(report.decision, "block")
        self.assertTrue(report.apply_warning_label)
        self.assertTrue(report.should_block_merge)
        self.assertEqual(report.warning_label, WARNING_LABEL)
        self.assertEqual(len(report.security_findings), 1)
        self.assertEqual(report.security_findings[0].code, "dynamic-code-exec")
        self.assertIn("Security Risk Findings", report.markdown)

    def test_multiple_antipatterns_trigger_block(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            ts_file = Path(tmp) / "slop.ts"
            ts_file.write_text(
                "export function f(x: any) {\n"
                "  // TODO: implement\n"
                '  throw new ' + 'Unimplemented' + 'Error();\n'
                "}\n",
                encoding="utf-8",
            )
            report = evaluate_pr_files([ts_file], has_llm_key=False)

        self.assertEqual(report.decision, "block")
        self.assertTrue(report.apply_warning_label)
        self.assertTrue(report.should_block_merge)
        self.assertGreaterEqual(len(report.antipattern_findings), 2)
        self.assertIn("AI-Slop Anti-pattern Findings", report.markdown)

    def test_single_antipattern_warns_without_blocking(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            ts_file = Path(tmp) / "warn_only.ts"
            ts_file.write_text(
                "export const val: any = 1;\n",
                encoding="utf-8",
            )
            report = evaluate_pr_files([ts_file], has_llm_key=False)

        self.assertEqual(report.decision, "warn")
        self.assertTrue(report.apply_warning_label)
        self.assertFalse(report.should_block_merge)
        self.assertEqual(len(report.antipattern_findings), 1)


if __name__ == "__main__":
    unittest.main()
