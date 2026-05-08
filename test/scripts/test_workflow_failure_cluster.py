import json
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts import ci_failure_digest  # noqa: E402


class WorkflowFailureClusterTest(unittest.TestCase):
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


if __name__ == "__main__":
    unittest.main()
