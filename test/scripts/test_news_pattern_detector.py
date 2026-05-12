import json
import tempfile
import unittest
from pathlib import Path

from scripts import fake_news_filter
from scripts import news_pattern_detector


class FakeNewsFilterTest(unittest.TestCase):
    def test_official_source_passes_with_high_confidence(self) -> None:
        entry = fake_news_filter.normalize_entry(
            {
                "title": "Claude Code changelog",
                "url": "https://code.claude.com/docs/en/changelog",
                "status": 200,
                "latest_signal": "2.1.136 release notes add workflow changes",
            },
            "unit",
        )

        result = fake_news_filter.assess_entry(entry, min_confidence=0.60)

        self.assertEqual(result.verdict, "pass")
        self.assertGreaterEqual(result.confidence, 0.80)
        self.assertNotIn("social_only_source", result.risk_flags)

    def test_social_only_claim_routes_to_review(self) -> None:
        entry = fake_news_filter.normalize_entry(
            {
                "title": "Insane secret trading leak",
                "url": "https://x.com/example/status/1",
                "summary": "single-source rumor claims guaranteed 100x return",
            },
            "unit",
        )

        result = fake_news_filter.assess_entry(entry, min_confidence=0.60)

        self.assertIn(result.verdict, {"review", "drop"})
        self.assertIn("social_only_source", result.risk_flags)
        self.assertIn("unverified_language", result.risk_flags)


class NewsPatternDetectorTest(unittest.TestCase):
    def test_ai_tool_watch_json_clusters_repeated_agent_signals(self) -> None:
        data = {
            "sources": [
                {
                    "name": "Claude Code changelog",
                    "owner": "Claude Code",
                    "url": "https://code.claude.com/docs/en/changelog",
                    "status": 200,
                    "latest_signal": "Agent workflow release with CI gate support",
                    "snippets": ["agent workflow CI gate release"],
                },
                {
                    "name": "Codex changelog",
                    "owner": "Codex",
                    "url": "https://developers.openai.com/codex/changelog",
                    "status": 200,
                    "latest_signal": "Agent workflow automation release",
                    "snippets": ["agent workflow automation release"],
                },
            ]
        }
        entries = fake_news_filter.entries_from_json(data, "ai-tool-watch")
        filtered = fake_news_filter.filter_entries(entries, min_confidence=0.55)

        patterns, issue_candidates = news_pattern_detector.detect_patterns(
            filtered,
            min_confidence=0.55,
            issue_threshold=2,
        )

        self.assertTrue(patterns)
        self.assertEqual(patterns[0]["topic"], "agentic-workflows")
        self.assertTrue(issue_candidates)

    def test_cli_writes_json_and_markdown(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "signals.json"
            output = root / "patterns.json"
            markdown = root / "patterns.md"
            source.write_text(
                json.dumps(
                    {
                        "sources": [
                            {
                                "name": "Cursor changelog",
                                "url": "https://cursor.com/changelog",
                                "status": 200,
                                "latest_signal": "Agent workflow release",
                            },
                            {
                                "name": "Devin release notes",
                                "url": "https://docs.devin.ai/release-notes",
                                "status": 200,
                                "latest_signal": "Agent workflow release",
                            },
                        ]
                    }
                ),
                encoding="utf-8",
            )

            exit_code = news_pattern_detector.main(
                [
                    "--source",
                    str(source),
                    "--output",
                    str(output),
                    "--markdown",
                    str(markdown),
                    "--issue-threshold",
                    "2",
                ]
            )

            self.assertEqual(exit_code, 0)
            self.assertTrue(output.exists())
            self.assertIn("News Pattern Detector", markdown.read_text(encoding="utf-8"))
            self.assertTrue(json.loads(output.read_text(encoding="utf-8"))["patterns"])


if __name__ == "__main__":
    unittest.main()
