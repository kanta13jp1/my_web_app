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


def workflow_step_ids(workflow):
    # Style-scoped block scanner, not a general YAML parser: jobs at column 0,
    # job keys at 2 spaces, steps at 4, list items at 6, step fields at 8.
    # Track every level so a job env/output key cannot impersonate a step ID.
    # Flow mappings, aliases, and escaped scalars need a real YAML parser.
    # PyYAML is installed by a different workflow, not this early CI step.
    id_pattern = re.compile(
        r"^(?: {8}| {6}- )id:[ \t]+(?P<quote>['\"]?)"
        r"(?P<id>[A-Za-z_][A-Za-z0-9_-]*)(?P=quote)(?:[ \t]+#.*)?[ \t]*$"
    )
    ids = []
    in_jobs = in_job = in_steps = in_step = False
    for line in workflow.splitlines():
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        indent = len(line) - len(line.lstrip(' '))
        if indent == 0:
            in_jobs = bool(re.fullmatch(r"jobs:[ \t]*(?:#.*)?", line))
            in_job = in_steps = in_step = False
            continue
        if not in_jobs:
            continue
        if indent == 2:
            in_job = bool(re.fullmatch(
                r"  [A-Za-z_][A-Za-z0-9_-]*:[ \t]*(?:#.*)?", line,
            ))
            in_steps = in_step = False
            continue
        if not in_job:
            continue
        if indent == 4:
            in_steps = bool(re.fullmatch(r"    steps:[ \t]*(?:#.*)?", line))
            in_step = False
            continue
        if not in_steps:
            continue
        if indent <= 6:
            in_step = line.startswith('      - ')
        if in_step:
            match = id_pattern.fullmatch(line)
            if match:
                ids.append(match.group('id'))
    return ids


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

    def test_business_e2e_success_does_not_imply_lock_test_success(self):
        summary = render_summary({
            "changes": {"outputs": {"web": "false", "business_execution": "true"}},
            "flutter_web_test": {"outcome": "skipped"},
            "business_execution_locks": {"outcome": "failure"},
            "business_execution_e2e": {"outcome": "success"},
        })
        self.assertIn("| Web import smoke tests | false | — skipped |", summary)
        self.assertIn("| Business execution browser locks | true | ❌ failure |", summary)
        self.assertIn("| Business execution browser E2E | true | ✅ success |", summary)

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

    def test_analyzer_download_requires_actual_upload_not_job_success(self):
        workflow = (Path(__file__).resolve().parents[1] /
                    ".github/workflows/ci.yml").read_text(encoding="utf-8")
        producer = workflow.split("  lint-and-test:\n", 1)[1].split("    steps:", 1)[0]
        self.assertIn("analyzer_evidence_uploaded: ${{ steps.upload_analyzer_evidence.outcome == 'success' }}", producer)
        upload = workflow.split("      - name: Upload analyzer evidence\n", 1)[1].split("      - name:", 1)[0]
        self.assertIn("id: upload_analyzer_evidence", upload)
        self.assertIn("if: always()", upload)
        self.assertIn("if-no-files-found: error", upload)
        download = workflow.split("      - name: Download analyzer evidence\n", 1)[1].split("      - name:", 1)[0]
        self.assertIn("if: needs.lint-and-test.outputs.analyzer_evidence_uploaded == 'true'", download)
        self.assertNotIn("needs.lint-and-test.result", download)
        self.assertIn("continue-on-error: true", download)

    def test_step_id_discovery_includes_digits_and_hyphens(self):
        values = [
            'flutter_web_test', 'business_execution_e2e',
            'Browser-E2E-2', '_internal_2', '2invalid', 'invalid.dot',
        ]
        workflow = '\n'.join([
            'jobs:', '  check:', '    steps:',
            *[f'      - id: {value}' for value in values],
        ])
        self.assertEqual(workflow_step_ids(workflow), values[:4])

    def test_step_id_style_supports_quotes_comments_and_first_key(self):
        workflow = "\n".join([
            'jobs:', '  check:', '    steps:',
            '      - name: single quoted',
            "        id: 'business_execution_e2e'",
            '      - name: double quoted',
            '        id: "business_execution_e2e" # browser gate',
            '      - name: plain',
            "        id: business_execution_e2e # browser gate",
            "      - id: 'business_execution_e2e' # first step key",
            '      - id: "Browser-E2E-2"',
            "      - id: plain_first_key",
            "          id: shell_body_is_not_a_step",
            "      - id: 'mismatched_quote\"",
            "    id: job_level_is_not_a_step",
        ])
        self.assertEqual(workflow_step_ids(workflow), [
            'business_execution_e2e', 'business_execution_e2e',
            'business_execution_e2e', 'business_execution_e2e',
            'Browser-E2E-2', 'plain_first_key',
        ])

    def test_non_step_ids_before_after_and_between_jobs_are_ignored(self):
        workflow = '\n'.join([
            'env:', '        id: global_env',
            'jobs:', '  first:',
            '    env:', '        id: before_steps',
            '    steps:', '      - id: first_real_step',
            '        env:', '          id: nested_step_env',
            '    outputs:', '        id: after_steps',
            '  second:', '    env:', '        id: next_job_env',
            '    steps: # another job', '      - id: second_real_step',
        ])
        self.assertEqual(workflow_step_ids(workflow), [
            'first_real_step', 'second_real_step',
        ])

    def test_env_id_cannot_replace_a_missing_real_e2e_step(self):
        workflow = (Path(__file__).resolve().parents[1] /
                    '.github/workflows/ci.yml').read_text(encoding='utf-8')
        real_id = '        id: business_execution_e2e\n'
        self.assertEqual(workflow.count(real_id), 1)
        without_step_id = workflow.replace(real_id, '', 1)
        forged = without_step_id.replace(
            '    steps:\n',
            '    env:\n        id: business_execution_e2e\n    steps:\n',
            1,
        )
        self.assertEqual(workflow_step_ids(workflow).count('business_execution_e2e'), 1)
        self.assertNotIn('business_execution_e2e', workflow_step_ids(forged))

    def test_actual_workflow_wires_every_reported_step_and_regression_suite(self):
        workflow = (Path(__file__).resolve().parents[1] /
                    ".github/workflows/ci.yml").read_text(encoding="utf-8")
        ids = workflow_step_ids(workflow)
        for _, _, step in CHECKS:
            self.assertEqual(ids.count(step), 2 if step == 'flutter_dependencies' else 1, step)
        summary = workflow.split("      - name: Job Summary\n", 1)[1].split(
            "\n  actionlint:", 1)[0]
        self.assertIn("if: always()", summary)
        self.assertIn("CI_STEPS_JSON: ${{ toJSON(steps) }}", summary)
        self.assertIn("run: python scripts/ci_job_summary.py", summary)
        self.assertIn("python scripts/ci_job_summary_test.py", workflow)


if __name__ == "__main__":
    unittest.main()
