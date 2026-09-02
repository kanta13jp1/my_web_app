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
    build_pgmq_bootstrap_sql,
    build_pgmq_finalize_sql,
    infer_pgmq_queue_names,
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

    def test_builds_pgmq_bootstrap_and_sequence_finalize(self) -> None:
        counts = {
            "a_company_agent_runtime": 2,
            "meta": 1,
            "q_company_agent_runtime": 3,
        }
        queues = infer_pgmq_queue_names(counts)
        self.assertEqual(queues, ["company_agent_runtime"])

        bootstrap = build_pgmq_bootstrap_sql(queues, restore_meta=True)
        self.assertIn("PERFORM pgmq.create('company_agent_runtime');", bootstrap)
        self.assertIn('DELETE FROM "pgmq"."meta"', bootstrap)

        finalize = build_pgmq_finalize_sql(queues, counts)
        self.assertIn("pg_get_serial_sequence", finalize)
        self.assertIn("source_is_partitioned OR source_is_unlogged", finalize)
        self.assertIn('FROM "pgmq"."q_company_agent_runtime"', finalize)
        self.assertEqual(finalize.count("DO $backup_restore_check$"), 3)

    def test_rejects_incomplete_pgmq_queue_pair(self) -> None:
        with self.assertRaisesRegex(ValueError, "missing archive table"):
            infer_pgmq_queue_names({"q_jobs": 1, "meta": 1})

    def test_pgmq_sql_quotes_queue_names(self) -> None:
        queue_name = "odd'queue"
        bootstrap = build_pgmq_bootstrap_sql([queue_name], restore_meta=True)
        self.assertIn("pgmq.create('odd''queue')", bootstrap)
        self.assertIn('"q_odd\'\'queue"', bootstrap)

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

    def test_storage_compatibility_connects_as_local_storage_owner(self) -> None:
        workflow = (
            ROOT / ".github" / "workflows" / "supabase-backup-restore.yml"
        ).read_text(encoding="utf-8")
        local_password = 'export PGPASSWORD="$POSTGRES_PASSWORD"'
        loopback = "--host 127.0.0.1"
        owner_login = "--username supabase_storage_admin"
        compatibility = "--file /tmp/storage-compat.sql"
        postgres_login = "--username postgres"
        roles_restore = "--file /tmp/roles.sql"

        password_index = workflow.index(local_password)
        loopback_index = workflow.index(loopback, password_index)
        owner_index = workflow.index(owner_login)
        compatibility_index = workflow.index(compatibility)
        postgres_index = workflow.index(postgres_login, compatibility_index)
        self.assertLess(password_index, loopback_index)
        self.assertLess(loopback_index, owner_index)
        self.assertLess(owner_index, compatibility_index)
        self.assertLess(compatibility_index, postgres_index)
        self.assertLess(postgres_index, workflow.index(roles_restore))
        self.assertNotIn("SET ROLE supabase_storage_admin", workflow)

    def test_artifact_upload_uses_the_backup_root(self) -> None:
        workflow = (
            ROOT / ".github" / "workflows" / "supabase-backup-restore.yml"
        ).read_text(encoding="utf-8")

        self.assertIn("${{ env.BACKUP_ROOT }}/bundle/*.7z", workflow)
        self.assertIn(
            "${{ env.BACKUP_ROOT }}/bundle/restore-evidence.json",
            workflow,
        )
        self.assertNotIn("${{ runner.temp }}/supabase-backup", workflow)


if __name__ == "__main__":
    unittest.main()
