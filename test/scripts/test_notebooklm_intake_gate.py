import argparse
import tempfile
import unittest
from pathlib import Path

from scripts import notebooklm_intake_gate as gate


class NotebookLmIntakeGateTest(unittest.TestCase):
    def test_parse_json_maybe_prefixed(self):
        payload = gate.parse_json_maybe_prefixed("log line\n{\"notebooks\": []}")

        self.assertEqual(payload, {"notebooks": []})

    def test_normalize_notebook_keeps_optional_fields(self):
        item = gate.normalize_notebook(
            {
                "index": 7,
                "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
                "title": "Example Notebook",
                "is_owner": True,
                "created_at": "2026-05-03T00:00:00",
                "updated_at": "2026-05-03T01:00:00",
                "source_count": 2,
            },
            1,
        )

        self.assertEqual(item["short_id"], "aaaaaaaa")
        self.assertEqual(item["title_key"], "example-notebook")
        self.assertEqual(item["source_count"], 2)
        self.assertEqual(item["source_count_state"], "from_list")

    def test_static_routes_harness_and_competitive_notebooks(self):
        harness = gate.static_route(
            {
                "id": gate.HARNESS_NOTEBOOK_ID,
                "title": gate.HARNESS_TITLE,
            }
        )
        competitive = gate.static_route(
            {
                "id": "17cd45cd-5166-4b3f-aefb-107e2c1e3589",
                "title": "Competitive Intelligence Report",
            }
        )

        self.assertEqual(harness["disposition"], "priority_reference")
        self.assertEqual(harness["issue"], "1606")
        self.assertEqual(competitive["disposition"], "route_existing_issue")
        self.assertEqual(competitive["issue"], "1660")

    def test_build_routing_uses_previous_skip_reason(self):
        notebook = gate.normalize_notebook(
            {
                "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
                "title": "Unmatched Notebook",
            },
            1,
        )
        routed = gate.build_routing(
            [notebook],
            {},
            [],
            {
                "notebooks": {
                    notebook["id"]: {
                        "disposition": "skipped",
                        "skip_reason": "non_project_topic",
                    }
                }
            },
        )

        self.assertEqual(routed[0]["disposition"], "skipped")
        self.assertEqual(routed[0]["skip_reason"], "non_project_topic")

    def test_main_writes_snapshot_from_input_json(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            input_json = root / "notebooks.json"
            input_json.write_text(
                """
                {
                  "notebooks": [
                    {
                      "id": "bc58b50b-5fc4-4840-9a62-b397d6d3b65a",
                      "title": "Codex vs Claude Code: The Ultimate AI Development Synergy"
                    }
                  ]
                }
                """,
                encoding="utf-8",
            )
            args = argparse.Namespace(
                input_json=str(input_json),
                refresh=False,
                state=str(root / "state.json"),
                snapshot=str(root / "snapshot.json"),
                report=str(root / "report.md"),
                issue_drafts=str(root / "drafts.md"),
                repo="kanta13jp1/my_web_app",
                gh_dedup=False,
                gh_issues_json=None,
                metadata="none",
                metadata_limit=12,
                timeout=10,
                print_only=False,
            )

            notebooks = gate.read_notebook_list(args, root)
            routed = gate.build_routing(notebooks, {}, [], {"notebooks": {}})
            snapshot = {
                "checked_at": gate.now_iso(),
                "harness_notebook_id": gate.HARNESS_NOTEBOOK_ID,
                "harness_found": True,
                "notebook_count": len(routed),
                "notebooks": routed,
            }
            gate.save_json(Path(args.snapshot), snapshot)

            written = gate.load_json(Path(args.snapshot), {})

        self.assertEqual(written["notebook_count"], 1)
        self.assertTrue(written["harness_found"])


if __name__ == "__main__":
    unittest.main()
