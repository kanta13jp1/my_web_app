#!/usr/bin/env python3
"""Regression tests for Knowledge Graph embedding and Supabase writes."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch


sys.path.insert(0, str(Path(__file__).resolve().parent))

from kg_index_common import SourceRecord, finish, upsert_supabase  # noqa: E402
from sync_memory_index import embedding_text_for  # noqa: E402


class _Response:
    status = 201

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        return False


class KgIndexCommonTest(unittest.TestCase):
    def test_embedding_text_uses_kg_source_fields(self) -> None:
        text = embedding_text_for(
            {
                "title": "Notebook update",
                "source_id": "notebook:slot:3",
                "excerpt": "Short summary",
                "content": "Full content",
            }
        )
        self.assertIn("notebook:slot:3", text)
        self.assertIn("Short summary", text)

    def test_finish_embeds_before_writing_jsonl(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "rows.jsonl"
            audit = Path(directory) / "audit.jsonl"
            args = SimpleNamespace(
                output=str(output),
                audit_log=str(audit),
                apply=False,
                with_embeddings=True,
                gemini_api_key="test-key",
                supabase_url="",
                service_role_key="",
            )

            def fake_embed(rows, api_key):
                self.assertEqual(api_key, "test-key")
                rows[0]["embedding"] = [1.0, 0.0]

            with patch("kg_index_common.embed_rows", side_effect=fake_embed):
                stats = finish(
                    [
                        SourceRecord(
                            source_type="doc",
                            source_id="docs/example.md",
                            title="Example",
                            content="Safe content",
                        )
                    ],
                    args,
                )

            row = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(row["embedding"], [1.0, 0.0])
            self.assertEqual(stats["embedding_status"], "generated")

    def test_finish_requires_key_when_embeddings_are_requested(self) -> None:
        args = SimpleNamespace(
            output="unused.jsonl",
            audit_log="unused-audit.jsonl",
            apply=False,
            with_embeddings=True,
            gemini_api_key="",
            supabase_url="",
            service_role_key="",
        )
        with self.assertRaisesRegex(SystemExit, "requires GEMINI_API_KEY"):
            finish([], args)

    def test_supabase_upsert_is_batched(self) -> None:
        payloads = [{"source_id": str(index)} for index in range(51)]
        requests = []

        def fake_urlopen(request, timeout):
            requests.append((request, timeout))
            return _Response()

        with patch("kg_index_common.urllib.request.urlopen", side_effect=fake_urlopen):
            applied = upsert_supabase(
                payloads,
                supabase_url="https://example.supabase.co",
                service_role_key="secret",
            )

        self.assertEqual(applied, 51)
        self.assertEqual([len(json.loads(item[0].data)) for item in requests], [25, 25, 1])
        self.assertTrue(all(item[1] == 60 for item in requests))


if __name__ == "__main__":
    unittest.main()
