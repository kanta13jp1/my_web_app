from __future__ import annotations

import sys
import types
import unittest
from pathlib import Path
from unittest import mock


sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from scripts import generate_blog_draft, validate_blog_draft  # noqa: E402


class GenerateBlogDraftTest(unittest.TestCase):
    def test_call_gemini_uses_gemini_4_hydrogen_and_low_thinking(self) -> None:
        captured: dict[str, object] = {}

        def fake_post(url: str, *, headers=None, json=None, timeout=None):
            captured["url"] = url
            captured["json"] = json
            resp = types.SimpleNamespace(
                status_code=200,
                raise_for_status=lambda: None,
                json=lambda: {
                    "candidates": [
                        {"content": {"parts": [{"text": '{"ok": true}'}]}}
                    ]
                },
            )
            return resp

        with mock.patch.object(generate_blog_draft.requests, "post", side_effect=fake_post):
            text = generate_blog_draft.call_gemini("dummy-key", "hello prompt")

        self.assertEqual(text, '{"ok": true}')
        self.assertIn("gemini-4-hydrogen:generateContent", str(captured["url"]))
        gen_cfg = captured["json"]["generationConfig"]  # type: ignore[index]
        self.assertEqual(gen_cfg["thinkingConfig"]["thinkingLevel"], "LOW")
        self.assertNotIn("temperature", gen_cfg)
        self.assertNotIn("maxOutputTokens", gen_cfg)

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
