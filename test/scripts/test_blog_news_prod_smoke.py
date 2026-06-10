from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts import blog_news_prod_smoke as smoke  # noqa: E402


class FakeResponse:
    def __init__(self, status: int, body: str, content_type: str = "application/json"):
        self.status = status
        self._body = body.encode("utf-8")
        self.headers = {"content-type": content_type}

    def read(self) -> bytes:
        return self._body

    def __enter__(self) -> "FakeResponse":
        return self

    def __exit__(self, *_args: object) -> None:
        return None


class BlogNewsProdSmokeTest(unittest.TestCase):
    def test_load_anon_key_from_main_dart(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "lib").mkdir()
            (root / "lib" / "main.dart").write_text(
                "await Supabase.initialize(\n  anonKey:\n      'anon-token',\n);\n",
                encoding="utf-8",
            )

            self.assertEqual(smoke.load_anon_key(root), "anon-token")

    def test_load_anon_key_from_main_dart_publishable_key(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "lib").mkdir()
            (root / "lib" / "main.dart").write_text(
                "await Supabase.initialize(\n  publishableKey:\n      'publishable-token',\n);\n",
                encoding="utf-8",
            )

            self.assertEqual(smoke.load_anon_key(root), "publishable-token")

    def test_public_routes_require_flutter_marker(self) -> None:
        def fake_urlopen(_req: object, timeout: int = 0) -> FakeResponse:
            self.assertGreater(timeout, 0)
            return FakeResponse(200, "<html><script src=\"flutter_bootstrap.js\"></script>", "text/html")

        with patch.object(smoke.urllib.request, "urlopen", fake_urlopen):
            checks = smoke.check_public_routes("https://example.test/", timeout=3)

        self.assertEqual([item.status for item in checks], ["pass", "pass", "pass"])

    def test_rss_fetch_accepts_success_with_empty_items_as_warning(self) -> None:
        def fake_urlopen(_req: object, timeout: int = 0) -> FakeResponse:
            body = {
                "success": True,
                "source_count": 2,
                "items": [],
                "signals": [],
                "errors": [{"source": "A", "url": "https://a.test/rss", "error": "down"}],
            }
            return FakeResponse(200, json.dumps(body))

        with patch.object(smoke.urllib.request, "urlopen", fake_urlopen):
            result = smoke.check_rss_fetch(
                "https://supabase.test",
                "anon-token",
                timeout=3,
                feeds=smoke.DEFAULT_RSS_FEEDS,
            )

        self.assertEqual(result.status, "warn")
        self.assertEqual(result.details["item_count"], 0)
        self.assertEqual(result.details["error_count"], 1)

    def test_blog_queue_read_skips_without_service_role_key(self) -> None:
        checks, post_id = smoke.query_blog_queue_state("https://supabase.test", "", timeout=3)

        self.assertEqual(post_id, "")
        self.assertEqual(checks[0].status, "warn")


if __name__ == "__main__":
    unittest.main()
