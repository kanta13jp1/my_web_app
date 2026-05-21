import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from scripts import notebooklm_requirements_failure_notice as notice


class NotebookLmRequirementsFailureNoticeTest(unittest.TestCase):
    def test_notice_explains_missing_secret_without_leaking_secret(self):
        body = notice.render_notice(
            workflow="NotebookLM Requirements to Issues",
            run_url="https://github.com/owner/repo/actions/runs/123",
            run_id="123",
            event="schedule",
            head_sha="abcdef1234567890",
            secret_present=False,
            updated_at="2026-05-21T00:00:00Z",
        )

        self.assertIn(notice.NOTICE_MARKER, body)
        self.assertIn("missing_or_empty", body)
        self.assertIn("gh secret set NOTEBOOKLM_STORAGE_STATE_JSON", body)
        self.assertIn("abcdef123456", body)
        self.assertNotIn("storage_state.json payload", body)

    def test_notice_explains_expired_auth_when_secret_exists(self):
        body = notice.render_notice(
            workflow="NotebookLM Requirements to Issues",
            run_url="",
            run_id="123",
            event="workflow_dispatch",
            head_sha="1234567890abcdef",
            secret_present=True,
            updated_at="2026-05-21T00:00:00Z",
        )

        self.assertIn("present", body)
        self.assertIn("likely expired", body)
        self.assertIn("`123`", body)

    def test_find_notice_comment_returns_existing_marker_comment(self):
        comments = [
            {"id": 1, "body": "regular comment"},
            {"id": 2, "body": f"{notice.NOTICE_MARKER}\nmanaged"},
        ]

        self.assertEqual(notice.find_notice_comment(comments), 2)

    def test_fetch_issue_comments_uses_get_not_comment_create(self):
        with mock.patch.object(notice, "run_gh", return_value="[]") as run_gh:
            self.assertEqual(notice.fetch_issue_comments("owner/repo", 2967), [])

        self.assertIn("--method", run_gh.call_args.args[0])
        self.assertIn("GET", run_gh.call_args.args[0])


if __name__ == "__main__":
    unittest.main()
