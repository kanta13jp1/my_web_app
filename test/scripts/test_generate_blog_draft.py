from __future__ import annotations

import sys
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from scripts import generate_blog_draft, validate_blog_draft  # noqa: E402


class GenerateBlogDraftTest(unittest.TestCase):
    def test_multiline_gitlog_keeps_fallback_headings_at_column_zero(self) -> None:
        gitlog = "abc1234 First change\ndef5678 Second change"

        ja, en = generate_blog_draft.fallback_template("2026-08-30", gitlog)

        self.assertTrue(ja.startswith("---\n"))
        self.assertTrue(en.startswith("---\n"))
        self.assertEqual(
            validate_blog_draft.h2_headings(ja),
            ["## 今日の進捗", "## 所感"],
        )
        self.assertEqual(
            validate_blog_draft.h2_headings(en),
            ["## Progress", "## Reflection"],
        )
        self.assertIn(f"\n{gitlog}\n", ja)
        self.assertIn(f"\n{gitlog}\n", en)


if __name__ == "__main__":
    unittest.main()
