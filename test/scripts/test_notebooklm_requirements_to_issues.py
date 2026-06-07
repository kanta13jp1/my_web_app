import json
import unittest
from pathlib import Path
from unittest import mock

from scripts import notebooklm_requirements_to_issues as reqs


class NotebookLmRequirementsToIssuesTest(unittest.TestCase):
    def test_normalize_requirement_builds_wbs_ready_issue_title_and_labels(self):
        notebook = {
            "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
            "short_id": "aaaaaaaa",
            "title": "Example Notebook",
            "created_at": "2026-05-18T00:00:00Z",
            "is_owner": True,
        }

        requirement = reqs.normalize_requirement(
            notebook,
            2,
            {
                "title": "資産管理のAI差分レビュー",
                "rationale": "NotebookLM source",
                "acceptance_criteria": ["差分が表示される", "WBSに同期される"],
                "priority": "P1",
            },
        )

        self.assertEqual(requirement.priority, "P1")
        self.assertEqual(
            requirement.marker,
            "notebooklm-requirement:aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee:2",
        )
        self.assertTrue(requirement.issue_title.startswith("[追加要望][P1][NotebookLM]"))
        self.assertIn(
            "priority:high",
            reqs.labels_for_requirement(reqs.DEFAULT_LABELS, requirement),
        )

    def test_issue_creation_requires_dedup_when_enabled(self):
        with mock.patch.object(
            reqs,
            "run_command",
            return_value=reqs.CommandResult(1, "", "api unavailable"),
        ):
            self.assertEqual(
                reqs.existing_requirement_issues("owner/repo", Path("."), 10),
                {},
            )
            with self.assertRaises(reqs.DedupFetchError):
                reqs.existing_requirement_issues(
                    "owner/repo",
                    Path("."),
                    10,
                    required=True,
                )

    def test_existing_marker_dedup_parser(self):
        issues = [
            {
                "number": 123,
                "title": "Existing",
                "url": "https://github.com/owner/repo/issues/123",
                "state": "OPEN",
                "body": "<!-- notebooklm-requirement:aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee:1 -->",
            }
        ]
        with mock.patch.object(
            reqs,
            "run_command",
            return_value=reqs.CommandResult(0, json.dumps(issues), ""),
        ):
            existing = reqs.existing_requirement_issues("owner/repo", Path("."), 10)

        self.assertIn(
            "notebooklm-requirement:aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee:1",
            existing,
        )

    def test_parse_answer_array_accepts_control_characters_in_strings(self):
        answer = """[
          {
            "title": "line
break",
            "acceptance_criteria": ["ok"],
            "priority": "P2"
          }
        ]"""

        rows = reqs.parse_answer_array(answer)

        self.assertEqual(rows[0]["title"], "line\nbreak")

    def test_report_surfaces_creation_cap(self):
        requirement = reqs.Requirement(
            notebook_id="aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
            notebook_short_id="aaaaaaaa",
            notebook_title="Example Notebook",
            notebook_created_at=None,
            notebook_is_owner=True,
            slot=1,
            title="Capped requirement",
            rationale="Reason",
            status="create_cap_reached",
        )

        report = reqs.render_report(
            "2026-05-18T00:00:00Z",
            [],
            [requirement],
            [],
            "owner/repo",
            True,
            9,
        )

        self.assertIn("Issue creation cap: `9`", report)
        self.assertIn("Held by Creation Cap", report)


if __name__ == "__main__":
    unittest.main()
