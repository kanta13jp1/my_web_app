#!/usr/bin/env python3
from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from wbs_role_harness import build_plan, main, parse_due_date, plan_sort_key


class WbsRoleHarnessTest(unittest.TestCase):
    def test_automation_wbs_issue_routes_to_codex1_only(self) -> None:
        plan = build_plan(
            {
                "number": 1636,
                "title": "Connect Codex role harness to WBS automation",
                "body": "Define WBS automation templates.",
                "labels": [{"name": "automation"}, {"name": "wbs"}],
                "comments": [
                    {
                        "createdAt": "2026-05-02T19:33:06Z",
                        "body": "Historical note mentioned Codex #2, but current flow is two-instance.",
                        "url": "https://example.test/comment",
                    }
                ],
            }
        )

        self.assertEqual(plan["kind"], "automation_wbs")
        self.assertEqual(plan["next_owner"], "Codex #1")
        self.assertEqual(plan["split"], "single_scoped_pr")
        rendered_roles = json.dumps(plan["roles"])
        self.assertIn("Codex #1", rendered_roles)
        self.assertNotIn("Codex #2", rendered_roles)
        self.assertIn("record C drive free space", " ".join(plan["resource_hygiene"]))

    def test_security_or_migration_routes_to_claude_first(self) -> None:
        plan = build_plan(
            {
                "number": 1724,
                "title": "Supabase migration with service_role policy",
                "labels": [{"name": "wbs"}],
            }
        )

        self.assertEqual(plan["kind"], "data_or_security")
        self.assertEqual(plan["next_owner"], "Claude Code #1")
        self.assertEqual(plan["split"], "multi_pr_or_claude_first")
        self.assertTrue(any("design approval" in item for item in plan["write_set"]))

    def test_blocked_issue_routes_to_user_or_automation(self) -> None:
        plan = build_plan(
            {
                "number": 1984,
                "title": "Axis B is blocked by #1724",
                "labels": [{"name": "wbs"}],
            }
        )

        self.assertEqual(plan["kind"], "blocked_or_manual")
        self.assertEqual(plan["next_owner"], "User/Automation")

    def test_due_date_can_be_parsed_and_used_for_sorting(self) -> None:
        early = build_plan({"number": 2, "title": "Task due 2026/05/18"})
        later = build_plan({"number": 1, "title": "Task due 2026-05-19"})

        self.assertEqual(parse_due_date({"title": "finish due 2026/05/18"}), "2026-05-18")
        self.assertLess(plan_sort_key(early), plan_sort_key(later))

    def test_cli_offline_fixture_writes_reports(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            fixture = root / "issues.json"
            output_md = root / "report.md"
            output_json = root / "report.json"
            fixture.write_text(
                json.dumps(
                    [
                        {
                            "number": 10,
                            "title": "WBS automation due 2026-05-19",
                            "labels": [{"name": "automation"}, {"name": "wbs"}],
                        }
                    ]
                ),
                encoding="utf-8",
            )

            exit_code = main(
                [
                    "--repo",
                    "kanta13jp1/my_web_app",
                    "--issues-json",
                    str(fixture),
                    "--output-md",
                    str(output_md),
                    "--output-json",
                    str(output_json),
                ]
            )

            self.assertEqual(exit_code, 0)
            self.assertIn("WBS Role Harness Report", output_md.read_text(encoding="utf-8"))
            report = json.loads(output_json.read_text(encoding="utf-8"))
            self.assertEqual(report["plans"][0]["issue"], 10)


if __name__ == "__main__":
    unittest.main()
