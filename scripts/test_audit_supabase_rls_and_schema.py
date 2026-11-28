#!/usr/bin/env python3
"""Unit tests for scripts/audit_supabase_rls_and_schema.py (#4131)."""

from __future__ import annotations

from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))

import audit_supabase_rls_and_schema as auditor  # noqa: E402


class AuditSupabaseRlsAndSchemaTest(unittest.TestCase):
    def test_detects_rls_and_policy_across_migrations(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            mig_dir = Path(tmp)
            (mig_dir / "001_init.sql").write_text(
                "CREATE TABLE IF NOT EXISTS public.items (id uuid PRIMARY KEY);\n"
                "CREATE TABLE orphan_logs (id bigint);\n",
                encoding="utf-8",
            )
            (mig_dir / "002_rls.sql").write_text(
                "ALTER TABLE public.items ENABLE ROW LEVEL SECURITY;\n"
                'CREATE POLICY "items_select" ON public.items '
                "FOR SELECT USING (true);\n",
                encoding="utf-8",
            )

            summary = auditor.audit_migrations_dir(mig_dir)
            self.assertEqual(summary.total_migrations, 2)
            self.assertEqual(summary.total_tables, 2)
            self.assertEqual(summary.tables_with_rls, 1)
            self.assertEqual(summary.tables_with_policy, 1)
            self.assertEqual(summary.tables_missing_rls, ["orphan_logs"])
            self.assertEqual(summary.tables_missing_policy, ["orphan_logs"])

    def test_fail_on_gap_returns_nonzero_when_missing_rls(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            mig_dir = Path(tmp)
            (mig_dir / "001_table.sql").write_text(
                "CREATE TABLE raw_events (id int);\n",
                encoding="utf-8",
            )
            rc = auditor.main(
                ["--migrations-dir", str(mig_dir), "--fail-on-gap"],
            )
            self.assertEqual(rc, 1)

    def test_audits_repo_migrations_successfully(self) -> None:
        repo_root = Path(__file__).resolve().parent.parent
        mig_dir = repo_root / "supabase" / "migrations"
        summary = auditor.audit_migrations_dir(mig_dir)
        self.assertGreater(summary.total_migrations, 0)
        self.assertGreater(summary.total_tables, 0)
        md = auditor.render_markdown(summary)
        self.assertIn("Supabase RLS & Schema Governance Inventory", md)


if __name__ == "__main__":
    unittest.main()
