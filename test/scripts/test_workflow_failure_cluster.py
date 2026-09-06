import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts import ci_failure_digest  # noqa: E402


class WorkflowFailureClusterTest(unittest.TestCase):

    def test_failed_step_wins_over_unrelated_summary_commands(self) -> None:
        log = "error: invalid_override test/mocks.dart:1\necho deno lint summary\n"
        self.assertEqual(
            ci_failure_digest.classify_workflow_failure("CI", "Analyze code", log),
            "flutter-analyze",
        )
        for step in ("Test CI scope classifier", "Check formatting"):
            with self.subTest(step=step):
                self.assertEqual(
                    ci_failure_digest.classify_workflow_failure("CI", step, log),
                    "generic-ci",
                )

    def test_signature_ignores_runner_commands_and_exit_wrappers(self) -> None:
        log = (
            "job\tstep\t2026-09-06T10:00:00.001Z \x1b[31m"
            "AssertionError: fixture != Fixture Deploy\x1b[0m\n"
            "job\tstep\t2026-09-06T10:00:00.002Z echo deno lint summary\n"
            "job\tstep\t2026-09-06T10:00:00.003Z ##[start-action display=Cache Flutter SDK]\n"
            "job\tstep\t2026-09-06T10:00:00.004Z ##[error]Process completed with exit code 1.\n"
            "FAILED (failures=1)\n"
        )
        self.assertEqual(
            ci_failure_digest.extract_error_signature(log),
            "AssertionError: fixture != Fixture Deploy",
        )

    def test_unknown_noise_only_failure_remains_unknown(self) -> None:
        log = "echo deno lint failed\nDENO_TEST=skipped\n##[group]Run flutter analyze\n"
        self.assertEqual(
            ci_failure_digest.classify_workflow_failure("CI", "", log), "generic-ci",
        )
        self.assertEqual(ci_failure_digest.extract_error_signature(log), "unknown-step")
        self.assertEqual(ci_failure_digest.extract_error_signature("", "my step"), "my step")

    def test_error_signature_prefers_concrete_error_to_failure_summary(self) -> None:
        self.assertEqual(
            ci_failure_digest.extract_error_signature(
                "TypeError: invalid input\nTask failed\n"
            ),
            "TypeError: invalid input",
        )

    def test_cloud_recovery_does_not_require_heavy_local_commands(self) -> None:
        for category in ("flutter-analyze", "flutter-build", "generic-ci"):
            with self.subTest(category=category):
                draft = "\n".join(ci_failure_digest.RECOVERY_DRAFTS[category])
                self.assertNotIn("locally", draft)
                self.assertTrue("cloud" in draft or "GitHub-hosted" in draft)

    def test_github_error_annotation_is_actionable(self) -> None:
        self.assertEqual(
            ci_failure_digest.extract_error_signature(
                "2026-09-06T10:00:00Z ##[error]Required input is missing\n"
                "2026-09-06T10:00:01Z ##[error]Process completed with exit code 1.\n"
            ),
            "error: Required input is missing",
        )

    def test_classifies_required_failure_families(self) -> None:
        cases = [
            (
                "Deploy to Production",
                "Run Supabase migrations",
                "duplicate key value violates unique constraint schema_migrations_pkey",
                "migration-collision",
            ),
            (
                "Deploy to Production",
                "Supabase db push",
                "supabase db push failed with SQLSTATE 42501",
                "supabase-push",
            ),
            (
                "CI",
                "Deno lint Edge Functions",
                "deno lint supabase/functions failed",
                "deno-lint",
            ),
            (
                "CI",
                "Analyze code",
                "flutter analyze found 2 issues",
                "flutter-analyze",
            ),
            (
                "CI",
                "Build Flutter Web",
                "flutter build web --release failed",
                "flutter-build",
            ),
            (
                "Notion Mirror Sync (hourly)",
                "notion.sync",
                "Notion API returned 502",
                "notion-sync",
            ),
        ]

        for workflow_name, step, log_text, expected in cases:
            with self.subTest(expected=expected):
                self.assertEqual(
                    ci_failure_digest.classify_workflow_failure(workflow_name, step, log_text),
                    expected,
                )

    def test_root_cause_key_is_stable_and_signature_sensitive(self) -> None:
        first = ci_failure_digest.workflow_root_cause(
            workflow_name="CI",
            branch="main",
            failed_step="Deno lint",
            log_text="error: Missing semicolon at supabase/functions/a.ts:10:1",
        )
        same = ci_failure_digest.workflow_root_cause(
            workflow_name="CI",
            branch="main",
            failed_step="Deno lint",
            log_text="error: Missing semicolon at supabase/functions/a.ts:10:1",
        )
        different = ci_failure_digest.workflow_root_cause(
            workflow_name="CI",
            branch="main",
            failed_step="Deno lint",
            log_text="error: Cannot resolve module at supabase/functions/b.ts:2:1",
        )

        self.assertEqual(first["root_cause_key"], same["root_cause_key"])
        self.assertNotEqual(first["root_cause_key"], different["root_cause_key"])
        self.assertEqual(first["recovery_scope_key"], different["recovery_scope_key"])
        self.assertTrue(first["root_cause_key"].startswith("wfrc-"))

    def test_recovery_draft_is_category_specific(self) -> None:
        root = ci_failure_digest.workflow_root_cause(
            workflow_name="Deploy to Production",
            branch="main",
            failed_step="Run Supabase migrations",
            log_text="duplicate key value violates unique constraint schema_migrations_pkey",
        )

        self.assertEqual(root["failure_category"], "migration-collision")
        self.assertIn("Category `migration-collision`", root["recovery_draft"])
        self.assertIn("supabase migration list", root["recovery_draft"])
        self.assertIn("duplicate key", root["recovery_draft"])

    def test_marker_parser_reads_issue_metadata(self) -> None:
        markers = ci_failure_digest.parse_issue_markers(
            """
            <!-- workflow_name: CI -->
            <!-- head_branch: main -->
            <!-- root_cause_key: wfrc-123 -->
            """
        )

        self.assertEqual(markers["workflow_name"], "CI")
        self.assertEqual(markers["head_branch"], "main")
        self.assertEqual(markers["root_cause_key"], "wfrc-123")

    def test_metrics_counts_open_and_average_recovery_hours(self) -> None:
        issues = [
            {
                "number": 1,
                "state": "OPEN",
                "createdAt": "2026-05-01T00:00:00Z",
                "closedAt": None,
                "body": "<!-- failure_category: deno-lint -->",
            },
            {
                "number": 2,
                "state": "CLOSED",
                "createdAt": "2026-05-01T00:00:00Z",
                "closedAt": "2026-05-01T06:00:00Z",
                "body": "<!-- failure_category: flutter-build -->",
            },
            {
                "number": 3,
                "state": "CLOSED",
                "createdAt": "2026-05-02T00:00:00Z",
                "closedAt": "2026-05-02T02:00:00Z",
                "body": "<!-- failure_category: deno-lint -->",
            },
        ]

        metrics = ci_failure_digest.workflow_failure_metrics(issues)

        self.assertEqual(metrics["open_count"], 1)
        self.assertEqual(metrics["closed_count"], 2)
        self.assertEqual(metrics["avg_recovery_hours"], 4.0)
        self.assertEqual(metrics["categories"]["deno-lint"], 2)

    def test_metrics_cli_writes_markdown_and_json(self) -> None:
        issues = [
            {
                "number": 1,
                "state": "OPEN",
                "createdAt": "2026-05-01T00:00:00Z",
                "closedAt": None,
                "body": "<!-- failure_category: notion-sync -->",
            }
        ]
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            issues_path = tmp_path / "issues.json"
            markdown_path = tmp_path / "metrics.md"
            json_path = tmp_path / "metrics.json"
            issues_path.write_text(json.dumps(issues), encoding="utf-8")

            exit_code = ci_failure_digest.workflow_failure_metrics_cli(
                type(
                    "Args",
                    (),
                    {
                        "issues_json": str(issues_path),
                        "markdown": str(markdown_path),
                        "json": str(json_path),
                    },
                )()
            )

            self.assertEqual(exit_code, 0)
            self.assertIn("Workflow failure hygiene", markdown_path.read_text(encoding="utf-8"))
            self.assertEqual(
                json.loads(json_path.read_text(encoding="utf-8"))["categories"]["notion-sync"],
                1,
            )

    def test_deterministic_ai_summary_has_stacktrace_sections(self) -> None:
        root = ci_failure_digest.workflow_root_cause(
            workflow_name="CI",
            branch="main",
            failed_step="Deno lint",
            log_text="error: Cannot resolve module at supabase/functions/a.ts:2:1",
        )

        summary = ci_failure_digest.deterministic_failure_summary(
            root,
            "error: Cannot resolve module at supabase/functions/a.ts:2:1",
        )

        self.assertIn("What failed", summary)
        self.assertIn("Where it failed", summary)
        self.assertIn("Likely cause", summary)
        self.assertIn("Next recovery step", summary)

    def test_extract_anthropic_text_reads_text_parts(self) -> None:
        text = ci_failure_digest.extract_anthropic_text(
            {
                "content": [
                    {"type": "text", "text": "first"},
                    {"type": "tool_use", "name": "ignored"},
                    {"type": "text", "text": "second"},
                ]
            }
        )

        self.assertEqual(text, "first\nsecond")

    def test_workflow_ai_summary_cli_writes_fallback_without_key(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            log_path = tmp_path / "failure.log"
            root_path = tmp_path / "root.json"
            markdown_path = tmp_path / "summary.md"
            json_path = tmp_path / "summary.json"
            log_path.write_text(
                "deno lint supabase/functions failed\nerror: no-explicit-any\n",
                encoding="utf-8",
            )
            root = ci_failure_digest.workflow_root_cause(
                workflow_name="CI",
                branch="main",
                failed_step="Deno lint",
                log_text=log_path.read_text(encoding="utf-8"),
            )
            root_path.write_text(json.dumps(root), encoding="utf-8")

            with mock.patch.dict(os.environ, {"ANTHROPIC_API_KEY": ""}):
                exit_code = ci_failure_digest.workflow_ai_summary_cli(
                    type(
                        "Args",
                        (),
                        {
                            "workflow_name": "CI",
                            "branch": "main",
                            "failed_step": "Deno lint",
                            "log": str(log_path),
                            "root_json": str(root_path),
                            "markdown": str(markdown_path),
                            "json": str(json_path),
                            "timeout_seconds": 1,
                        },
                    )()
                )

            self.assertEqual(exit_code, 0)
            self.assertIn("ai_summary_provider: deterministic", markdown_path.read_text(encoding="utf-8"))
            self.assertTrue(json.loads(json_path.read_text(encoding="utf-8"))["fallback_used"])


if __name__ == "__main__":
    unittest.main()
