import tempfile
import unittest
from pathlib import Path

from scripts import notebooklm_intake_gate as gate


class NotebookLmIntakeGateTest(unittest.TestCase):
    def test_normalizes_optional_metadata(self):
        payload = {
            "count": 1,
            "notebooks": [
                {
                    "index": 1,
                    "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
                    "title": "Example Notebook",
                    "updated_at": "2026-05-03T00:00:00",
                    "sources": [{"title": "A"}, {"title": "B"}],
                }
            ],
        }

        notebooks = gate.normalize_notebooks(payload)

        self.assertEqual(len(notebooks), 1)
        self.assertEqual(notebooks[0]["source_count"], 2)
        self.assertEqual(notebooks[0]["updated_at"], "2026-05-03T00:00:00")
        self.assertEqual(notebooks[0]["title_key"], "example notebook")

    def test_routes_harness_and_known_notebooks(self):
        harness = {
            "id": gate.HARNESS_NOTEBOOK_ID,
            "title": gate.HARNESS_NOTEBOOK_TITLE,
        }
        competitive = {
            "id": "17cd45cd-5166-4b3f-aefb-107e2c1e3589",
            "title": "Competitive Intelligence Report: 2026 AI Infrastructure",
        }

        harness_decision = gate.classify_notebook(harness, "", {})
        competitive_decision = gate.classify_notebook(competitive, "", {})

        self.assertEqual(harness_decision["disposition"], "priority_reference")
        self.assertEqual(harness_decision["issue"], 1606)
        self.assertEqual(competitive_decision["disposition"], "routed")
        self.assertEqual(competitive_decision["issue"], 1660)

    def test_existing_issue_reference_skips_duplicate(self):
        notebook_id = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
        notebook = {"id": notebook_id, "title": "WorkOS AuthKit MCP"}

        decision = gate.classify_notebook(notebook, "", {notebook_id: ["issue #1194"]})

        self.assertEqual(decision["disposition"], "applied")
        self.assertEqual(decision["action"], "skip")
        self.assertIn("issue #1194", decision["references"])

    def test_analyze_from_input_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "docs" / "ai-tool-watch").mkdir(parents=True)
            (root / "docs" / "ai-tool-watch" / "latest-report.md").write_text(
                f"`{gate.HARNESS_NOTEBOOK_ID}`\n",
                encoding="utf-8",
            )
            input_path = root / "notebooks.json"
            input_path.write_text(
                """
                {
                  "count": 2,
                  "notebooks": [
                    {
                      "index": 1,
                      "id": "bc58b50b-5fc4-4840-9a62-b397d6d3b65a",
                      "title": "Codex vs Claude Code: The Ultimate AI Development Synergy"
                    },
                    {
                      "index": 2,
                      "id": "9b8885ef-86a6-45c4-8e3d-2dc6fd601fd0",
                      "title": "Automating SaaS Operations with Claude Code Schedule"
                    }
                  ]
                }
                """,
                encoding="utf-8",
            )
            args = gate.parse_args(["--root", str(root), "--input", str(input_path), "--no-gh"])

            report = gate.analyze(args)

        self.assertEqual(report["notebook_count"], 2)
        self.assertTrue(report["harness"]["found"])
        self.assertEqual(report["counts"]["priority_reference"], 1)
        self.assertEqual(report["counts"]["routed"], 1)


if __name__ == "__main__":
    unittest.main()
