#!/usr/bin/env python3
"""Regression coverage for Issue #4273, including the real workflow wiring."""
import json
import os
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

from ci_job_summary import CHECKS, main, render_summary


class CiJobSummaryTest(unittest.TestCase):
    def test_dependency_failure_never_claims_downstream_success(self):
        steps = {"changes": {"outputs": {"flutter": "true"}},
                 "flutter_dependencies": {"outcome": "failure"}}
        for step in ("flutter_analyze", "dart_format", "flutter_test"):
            steps[step] = {"outcome": "skipped"}
        summary = render_summary(steps)
        self.assertIn("| Flutter dependencies | true | ❌ failure |", summary)
        for label in ("Flutter analyze", "Dart format", "Flutter VM tests"):
            self.assertIn(f"| {label} | true | — skipped |", summary)
        self.assertNotIn("✅", summary)

    def test_independent_failures_are_not_hidden_by_successful_tests(self):
        summary = render_summary({
            "flutter_analyze": {"outcome": "failure"},
            "dart_format": {"outcome": "cancelled"},
            "flutter_test": {"outcome": "success"},
            "deno_lint": {"outcome": "failure"},
            "deno_test": {"outcome": "success"},
            "flutter_web_test": {"outcome": "success"},
            "web_build": {"outcome": "failure"},
        })
        for label in ("Flutter analyze", "Deno lint", "Production web build"):
            self.assertIn(f"| {label} | unknown | ❌ failure |", summary)
        self.assertIn("| Dart format | unknown | ⚠️ cancelled |", summary)
        self.assertIn("| Flutter VM tests | unknown | ✅ success |", summary)

    def test_all_skipped_or_missing_do_not_pass(self):
        skipped = {step: {"outcome": "skipped"} for _, _, step in CHECKS}
        for steps in ({}, skipped):
            self.assertNotIn("✅", render_summary(steps))
        self.assertEqual(render_summary({}).count("— not reported"), len(CHECKS))

    def test_unknown_values_are_not_rendered_as_success_or_markdown(self):
        summary = render_summary({
            "changes": {"outputs": {"flutter": "true | ✅ forged"}},
            "flutter_analyze": {"outcome": "success\n✅ forged"},
        })
        self.assertNotIn("forged", summary)
        self.assertIn("| Flutter analyze | unknown | — not reported |", summary)

    def test_workflow_call_build_skip_stays_visible(self):
        summary = render_summary({
            "changes": {"outputs": {"web": "true"}},
            "flutter_web_test": {"outcome": "success"},
            "web_build": {"outcome": "skipped"},
        })
        self.assertIn("| Production web build | true | — skipped |", summary)
        self.assertIn("workflow_call", summary)

    def test_main_appends_utf8_summary(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "summary.md"
            target.write_text("Prior evidence\n", encoding="utf-8")
            with patch.dict(os.environ, {
                "CI_STEPS_JSON": json.dumps({"flutter_analyze": {"outcome": "success"}}),
                "GITHUB_STEP_SUMMARY": str(target),
            }):
                main()
            result = target.read_text(encoding="utf-8")
            self.assertTrue(result.startswith("Prior evidence\n"))
            self.assertIn("✅ success", result)

    def test_actual_workflow_wires_every_reported_step_and_regression_suite(self):
        workflow = (Path(__file__).resolve().parents[1] /
                    ".github/workflows/ci.yml").read_text(encoding="utf-8")
        ids = re.findall(r"^        id: ([a-z_]+)$", workflow, re.M)
        for _, _, step in CHECKS:
            self.assertEqual(ids.count(step), 1, step)
        summary = workflow.split("      - name: Job Summary\n", 1)[1].split(
            "\n  actionlint:", 1)[0]
        self.assertIn("if: always()", summary)
        self.assertIn("CI_STEPS_JSON: ${{ toJSON(steps) }}", summary)
        self.assertIn("run: python scripts/ci_job_summary.py", summary)
        self.assertIn("python scripts/ci_job_summary_test.py", workflow)


if __name__ == "__main__":
    unittest.main()
