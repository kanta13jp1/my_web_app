#!/usr/bin/env python3

import tempfile
import unittest
from pathlib import Path

from render_web_supabase_config import normalize_public_url, render_web_shell


class RenderWebSupabaseConfigTest(unittest.TestCase):
    def test_renders_all_placeholders_without_printing_a_key(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            target = Path(temp_dir) / "index.html"
            target.write_text(
                '<link href="__SUPABASE_URL__"><script>"__SUPABASE_URL__"</script>',
                encoding="utf-8",
            )

            count = render_web_shell(target, "https://example.supabase.co/")

            self.assertEqual(count, 2)
            self.assertEqual(
                target.read_text(encoding="utf-8").count(
                    "https://example.supabase.co"
                ),
                2,
            )

    def test_rejects_credentials_and_non_https_remote_urls(self) -> None:
        for value in (
            "http://example.supabase.co",
            "https://user:password@example.supabase.co",
            "https://example.supabase.co/path",
        ):
            with self.subTest(value=value):
                with self.assertRaises(ValueError):
                    normalize_public_url(value)

    def test_allows_local_supabase(self) -> None:
        self.assertEqual(
            normalize_public_url("http://127.0.0.1:54321/"),
            "http://127.0.0.1:54321",
        )


if __name__ == "__main__":
    unittest.main()
