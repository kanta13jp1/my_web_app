from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from scripts import ai_tool_changelog_summarize as summarize


class AiToolChangelogSummarizeTest(unittest.TestCase):
    def test_parse_web_snapshot_extracts_title_date_and_body(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "cursor.html"
            path.write_text(
                """
                <html>
                  <head><title>What's New in Cursor</title></head>
                  <body>
                    <h1>Design Mode Improvements</h1>
                    <p>Jun 5, 2026. Canvas Design Mode adds agent UI editing.</p>
                  </body>
                </html>
                """,
                encoding="utf-8",
            )

            items = summarize.parse_web_snapshot(
                path,
                "Cursor changelog",
                "https://cursor.com/changelog",
            )

        self.assertEqual(len(items), 1)
        self.assertEqual(items[0]["name"], "What's New in Cursor")
        self.assertEqual(items[0]["date"], "Jun 5, 2026")
        self.assertIn("Canvas Design Mode", items[0]["body"])

    def test_render_markdown_keeps_h_priority_lines_for_issue_creation(self) -> None:
        markdown = summarize.render_markdown(
            "2026-06",
            claude_items=[],
            codex_items=[],
            cursor_items=[
                {
                    "name": "Cursor Design Mode Improvements",
                    "date": "Jun 5, 2026",
                    "url": "https://cursor.com/changelog",
                    "body": "Canvas Design Mode and auto-review for agents.",
                }
            ],
            replit_items=[
                {
                    "name": "Replit Agent 4",
                    "date": "Mar 13, 2026",
                    "url": "https://replit.com/blog/introducing-agent-4-built-for-creativity",
                    "body": "Agent 4 adds parallel agents and design canvas.",
                }
            ],
            ai_summary=None,
        )

        self.assertIn("## Cursor Changelog", markdown)
        self.assertIn("## Replit Agent / Updates", markdown)
        self.assertIn("- [H] **Cursor Design Mode Improvements**", markdown)
        self.assertIn("- [H] **Replit Agent 4**", markdown)
        self.assertIn("## Fleet Adoption Candidates", markdown)


if __name__ == "__main__":
    unittest.main()
