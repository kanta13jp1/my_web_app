#!/usr/bin/env python3
from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))

from report_daily_report_staleness import (  # noqa: E402
    DEFAULT_TITLE,
    decide_action,
    find_matching_issue,
    load_open_issues,
    render_body,
)


class DailyReportStalenessIssueTest(unittest.TestCase):
    def test_fresh_report_is_noop(self) -> None:
        plan = decide_action({"fresh": True}, [])

        self.assertEqual(plan["action"], "none")

    def test_stale_report_comments_on_existing_canonical_issue(self) -> None:
        existing = {"number": 1699, "title": DEFAULT_TITLE, "url": "https://example.test/issues/1699"}
        plan = decide_action({"fresh": False}, [existing])

        self.assertEqual(plan["action"], "comment")
        self.assertEqual(plan["issue_number"], 1699)

    def test_stale_report_creates_issue_when_no_canonical_issue_exists(self) -> None:
        plan = decide_action({"fresh": False}, [{"number": 1, "title": "other"}])

        self.assertEqual(plan["action"], "create")

    def test_matching_issue_requires_exact_title(self) -> None:
        self.assertIsNone(find_matching_issue([{"title": DEFAULT_TITLE + " duplicate"}], DEFAULT_TITLE))

    def test_body_includes_checked_paths_and_workflow(self) -> None:
        body = render_body(
            {
                "date": "2026-05-07",
                "fresh": False,
                "ref": "origin/main",
                "reason": "missing daily-report report file or corroborating freshness signal",
                "signals": {"report_exists": False, "report_marker": False},
                "paths": {"report": "docs/daily-reports/2026-05-07.md"},
            },
            "https://example.test/actions/runs/1",
            "comment",
        )

        self.assertIn("2026-05-07", body)
        self.assertIn("docs/daily-reports/2026-05-07.md", body)
        self.assertIn("https://example.test/actions/runs/1", body)

    def test_load_open_issues_accepts_json_list_fixture(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir) / "issues.json"
            path.write_text(f'[{{"number":1699,"title":"{DEFAULT_TITLE}"}}]', encoding="utf-8")

            issues = load_open_issues("owner/repo", DEFAULT_TITLE, path)

        self.assertEqual(issues[0]["number"], 1699)

    def test_load_open_issues_accepts_powershell_utf16_fixture(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir) / "issues.json"
            path.write_text(
                f'[{{"number":1699,"title":"{DEFAULT_TITLE}"}}]',
                encoding="utf-16",
            )

            issues = load_open_issues("owner/repo", DEFAULT_TITLE, path)

        self.assertEqual(issues[0]["number"], 1699)


if __name__ == "__main__":
    unittest.main()
