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

    def test_canonical_duplicate_matches_same_notebook_issue(self):
        notebook_id = "9871b0b1-0748-4d7d-99bc-bd6aea2231f6"
        requirement = reqs.Requirement(
            notebook_id=notebook_id,
            notebook_short_id="9871b0b1",
            notebook_title="Claude Code and Obsidian: Building Your AI Second Brain",
            notebook_created_at=None,
            notebook_is_owner=True,
            slot=3,
            title="AI調査結果のQuery to Wiki直接保存機能の導入",
            rationale="AIツールで得た比較表や構成案を使い捨てにせずナレッジベースに永続化する。",
            acceptance_criteria=[
                "AI出力をワンクリックで永続記憶として保存できる",
                "保存データがSupabase検索対象に含まれる",
                "元Issueとタイムスタンプをメタデータとして付与する",
            ],
            implementation_notes="Flutter WebにMarkdownプレビューと保存処理を追加する。",
        )
        issue = {
            "number": 975,
            "title": "[追加要望] Query to Wiki: AI回答を永続ナレッジ化する保存ワークフロー",
            "url": "https://github.com/owner/repo/issues/975",
            "state": "OPEN",
            "body": (
                f"Source: https://notebooklm.google.com/notebook/{notebook_id}\n"
                "AI回答・診断結果・WBS手順・比較表などをMarkdownノートとして永続保存する。"
                "保存時にタイトル、要約、タグ、関連Issue、関連ノート候補を生成する。"
            ),
        }

        duplicate = reqs.find_canonical_duplicate(requirement, [issue])

        self.assertIsNotNone(duplicate)
        self.assertEqual(duplicate["number"], 975)

    def test_canonical_duplicate_requires_same_notebook_reference(self):
        requirement = reqs.Requirement(
            notebook_id="9871b0b1-0748-4d7d-99bc-bd6aea2231f6",
            notebook_short_id="9871b0b1",
            notebook_title="Notebook",
            notebook_created_at=None,
            notebook_is_owner=True,
            slot=2,
            title="Knowledge Vault Lint",
            rationale="Detect orphan notes and broken links.",
        )
        issue = {
            "number": 976,
            "title": "Knowledge Vault Lint",
            "url": "https://github.com/owner/repo/issues/976",
            "state": "CLOSED",
            "body": "Same words, but it references a different notebook id aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.",
        }

        self.assertIsNone(reqs.find_canonical_duplicate(requirement, [issue]))

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

    def test_report_surfaces_canonical_duplicate_skip(self):
        requirement = reqs.Requirement(
            notebook_id="aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
            notebook_short_id="aaaaaaaa",
            notebook_title="Example Notebook",
            notebook_created_at=None,
            notebook_is_owner=True,
            slot=1,
            title="Existing canonical requirement",
            rationale="Reason",
            status="skipped_canonical_duplicate",
            issue_url="https://github.com/owner/repo/issues/974",
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

        self.assertIn("Canonical duplicate Issues skipped: `1`", report)
        self.assertIn("Skipped Canonical Duplicates", report)


if __name__ == "__main__":
    unittest.main()
