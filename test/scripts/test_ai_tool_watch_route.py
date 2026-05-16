import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from scripts import ai_tool_watch_route


def sample_report() -> dict:
    return {
        "checked_at": "2026-05-12T00:00:00Z",
        "changed_sources": [
            {
                "slug": "claude-code-changelog",
                "name": "Claude Code changelog",
                "url": "https://code.claude.com/docs/en/changelog",
                "latest_signal": "2.1.139 / May 11, 2026",
                "keyword_groups": {
                    "hooks": ["SessionStart"],
                    "schedule": ["workflow"],
                },
            }
        ],
        "high_priority_groups": ["hooks", "schedule"],
        "active_groups": ["hooks", "schedule", "integration"],
        "impact_routes": {
            "hooks": {
                "issues": ["#1422"],
                "action": "Review hook policy.",
            },
            "schedule": {
                "issues": ["#1559"],
                "action": "Route to GitHub Actions.",
            },
        },
    }


class AiToolWatchRouteTest(unittest.TestCase):
    def test_should_route_only_changed_high_priority_reports(self) -> None:
        report = sample_report()
        self.assertTrue(ai_tool_watch_route.should_route(report))

        report["changed_sources"] = []
        self.assertFalse(ai_tool_watch_route.should_route(report))
        self.assertTrue(ai_tool_watch_route.should_route(report, force=True))

    def test_issue_body_uses_two_instance_policy(self) -> None:
        body = ai_tool_watch_route.render_issue_body(
            sample_report(),
            "docs/cross-instance-prs/drafts/ai-tool-watch/handoff.md",
            "docs/cross-instance-prs/drafts/ai-tool-watch/pr.md",
        )

        self.assertIn("Codex #1 owns scoped implementation", body)
        self.assertIn("Legacy Codex #2/#3 lanes are dormant", body)
        self.assertIn("GitHub Issues WBS Sync", body)
        self.assertIn("Claude Code changelog", body)

    def test_write_drafts_creates_handoff_and_pr_skeleton(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            draft_dir = Path(tmp) / "drafts"
            handoff, pr_skeleton = ai_tool_watch_route.write_drafts(
                sample_report(),
                draft_dir,
                dry_run=False,
            )

            handoff_path = Path(handoff)
            pr_path = Path(pr_skeleton)
            if not handoff_path.is_absolute():
                handoff_path = ai_tool_watch_route.REPO_ROOT / handoff_path
            if not pr_path.is_absolute():
                pr_path = ai_tool_watch_route.REPO_ROOT / pr_path

            self.assertTrue(handoff_path.exists())
            self.assertTrue(pr_path.exists())
            self.assertIn("Delegation Packet", handoff_path.read_text(encoding="utf-8"))
            self.assertIn("Proposed PR Title", pr_path.read_text(encoding="utf-8"))

    def test_cli_dry_run_does_not_require_gh(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            report_path = root / "latest-report.json"
            report_path.write_text(json.dumps(sample_report()), encoding="utf-8")

            exit_code = ai_tool_watch_route.main(
                [
                    "--report-json",
                    str(report_path),
                    "--repo",
                    "kanta13jp1/my_web_app",
                    "--draft-dir",
                    str(root / "drafts"),
                    "--dry-run",
                ]
            )

            self.assertEqual(exit_code, 0)
            self.assertFalse((root / "drafts").exists())


if __name__ == "__main__":
    unittest.main()
