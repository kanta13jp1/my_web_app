#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from scripts.supabase_backup_verify import (
    BACKUP_FILES,
    build_assertions_sql,
    build_manifest,
    parse_copy_row_counts,
    verify_manifest,
)


class SupabaseBackupVerifyTest(unittest.TestCase):
    def test_parses_public_copy_blocks_and_ignores_other_schemas(self) -> None:
        contents = r'''COPY "public"."empty" ("id") FROM stdin;
\.
COPY "auth"."users" ("id") FROM stdin;
auth-1
\.
COPY "public"."notes" ("id", "body") FROM stdin;
1\tline one
2\tline two with escaped newline\\ncontinued
\.
'''
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "data.sql"
            path.write_text(contents, encoding="utf-8")
            self.assertEqual(
                parse_copy_row_counts(path, "public"),
                {"empty": 0, "notes": 2},
            )

    def test_rejects_unterminated_copy_block(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "data.sql"
            path.write_text(
                'COPY "public"."notes" ("id") FROM stdin;\n1\n',
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "unterminated COPY block"):
                parse_copy_row_counts(path, "public")

    def test_builds_quoted_row_count_assertions(self) -> None:
        sql = build_assertions_sql({'odd"table': 3}, "public")
        self.assertIn('FROM "public"."odd""table";', sql)
        self.assertIn("actual_count <> 3", sql)
        self.assertIn("restore row-count mismatch: public.odd\"table", sql)

    def test_manifest_verifies_hash_and_size(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name in BACKUP_FILES:
                (root / name).write_text(f"-- {name}\n", encoding="utf-8")
            manifest = build_manifest(
                root,
                "project-ref",
                generated_at="2026-08-26T00:00:00+00:00",
            )
            self.assertEqual(manifest["source_project_ref"], "project-ref")
            self.assertEqual(len(manifest["files"]), 3)
            verify_manifest(root, manifest)

            (root / "data.sql").write_text("tampered\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "mismatch"):
                verify_manifest(root, manifest)

    def test_manifest_is_json_serializable(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name in BACKUP_FILES:
                (root / name).write_text(name, encoding="utf-8")
            payload = build_manifest(root, "ref")
            self.assertIsInstance(json.dumps(payload), str)


if __name__ == "__main__":
    unittest.main()
