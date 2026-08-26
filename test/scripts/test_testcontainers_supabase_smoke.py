#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "testcontainers_supabase_smoke.py"
spec = importlib.util.spec_from_file_location("testcontainers_supabase_smoke", SCRIPT)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = module
spec.loader.exec_module(module)


class TestTestcontainersSupabaseSmoke(unittest.TestCase):
    def test_redact_url_masks_password(self) -> None:
        redacted = module.redact_url("postgresql://user:secret@localhost:5432/db")
        self.assertEqual(redacted, "postgresql://user:***@localhost:5432/db")
        self.assertNotIn("secret", redacted)

    def test_normalize_connection_url_strips_sqlalchemy_driver(self) -> None:
        normalized = module.normalize_connection_url(
            "postgresql+psycopg2://test:test@localhost:5432/test"
        )
        self.assertEqual(normalized, "postgresql://test:test@localhost:5432/test")

    def test_sql_files_are_sorted(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "002_seed.sql").write_text("select 2;", encoding="utf-8")
            (root / "001_schema.sql").write_text("select 1;", encoding="utf-8")
            self.assertEqual(
                [path.name for path in module.sql_files(root)],
                ["001_schema.sql", "002_seed.sql"],
            )

    def test_sql_statements_skip_empty_chunks(self) -> None:
        self.assertEqual(
            module.sql_statements("select 1;\n\nselect 2;;"),
            ["select 1", "select 2"],
        )

    def test_sql_statements_preserve_quoted_semicolons(self) -> None:
        sql = """
        create function public.touch_row()
        returns trigger language plpgsql as $body$
        begin
          new.updated_at = now();
          return new;
        end;
        $body$;
        select 'a;b';
        """
        statements = module.sql_statements(sql)
        self.assertEqual(len(statements), 2)
        self.assertIn("new.updated_at = now();", statements[0])
        self.assertEqual(statements[1], "select 'a;b'")

    def test_plan_declares_no_production_credentials(self) -> None:
        plan = module.build_plan(
            ROOT / "test" / "fixtures" / "testcontainers" / "sql",
            ROOT / "test" / "fixtures" / "testcontainers" / "edge-db-smoke.ts",
            ROOT / "supabase" / "functions" / "health-check" / "index.ts",
        )
        self.assertFalse(plan["production_credentials_required"])
        self.assertIn("summary.json", " ".join(plan["artifacts"]))

    def test_plan_includes_fail_closed_rls_migration(self) -> None:
        plan = module.build_plan(
            ROOT / "test" / "fixtures" / "testcontainers" / "sql",
            ROOT / "test" / "fixtures" / "testcontainers" / "edge-db-smoke.ts",
            ROOT / "supabase" / "functions" / "health-check" / "index.ts",
        )
        self.assertEqual(
            plan["tenant_rls_migration"],
            "supabase/migrations/20260815124052_fail_closed_rls_issue_2773.sql",
        )
        self.assertIn(
            "missing tenant claims see zero rows",
            " ".join(plan["tenant_rls_checks"]),
        )

    def test_plan_includes_asset_chat_rls_migration(self) -> None:
        plan = module.build_plan(
            ROOT / "test" / "fixtures" / "testcontainers" / "sql",
            ROOT / "test" / "fixtures" / "testcontainers" / "edge-db-smoke.ts",
            ROOT / "supabase" / "functions" / "health-check" / "index.ts",
        )
        self.assertEqual(
            plan["asset_chat_migration"],
            "supabase/migrations/20260817151738_create_asset_chat_tables.sql",
        )
        self.assertIn(
            "message ownership follows the parent thread",
            plan["asset_chat_checks"],
        )

    def test_plan_includes_tax_records_rls_migration(self) -> None:
        plan = module.build_plan(
            ROOT / "test" / "fixtures" / "testcontainers" / "sql",
            ROOT / "test" / "fixtures" / "testcontainers" / "edge-db-smoke.ts",
            ROOT / "supabase" / "functions" / "health-check" / "index.ts",
        )
        self.assertEqual(
            plan["tax_records_migration"],
            "supabase/migrations/20260820023000_create_tax_records.sql",
        )
        self.assertIn(
            "authenticated users cannot forge another owner",
            plan["tax_records_checks"],
        )

    def test_plan_includes_ai_university_migration_runtime_proof(self) -> None:
        plan = module.build_plan(
            ROOT / "test" / "fixtures" / "testcontainers" / "sql",
            ROOT / "test" / "fixtures" / "testcontainers" / "edge-db-smoke.ts",
            ROOT / "supabase" / "functions" / "health-check" / "index.ts",
        )
        self.assertEqual(
            plan["ai_university_migration"],
            "supabase/migrations/20260824135127_add_ai_university_evidence_and_content_analytics.sql",
        )
        self.assertIn(
            "migration applies twice without losing legacy rows",
            plan["ai_university_checks"],
        )

    def test_plan_includes_app_analytics_write_boundary(self) -> None:
        plan = module.build_plan(
            ROOT / "test" / "fixtures" / "testcontainers" / "sql",
            ROOT / "test" / "fixtures" / "testcontainers" / "edge-db-smoke.ts",
            ROOT / "supabase" / "functions" / "health-check" / "index.ts",
        )
        self.assertEqual(
            plan["app_analytics_migration"],
            "supabase/migrations/20260827003000_harden_app_analytics_writes.sql",
        )
        self.assertIn(
            "raw browser INSERT, UPDATE, and DELETE are denied",
            plan["app_analytics_checks"],
        )

    def test_tenant_role_count_rejects_untrusted_identifiers(self) -> None:
        with self.assertRaisesRegex(ValueError, "unexpected role"):
            module.issue_2773_role_count(
                None,
                "postgres",
                None,
                "ab_assignments",
            )
        with self.assertRaisesRegex(ValueError, "unexpected table"):
            module.issue_2773_role_count(None, "authenticated", None, "pg_authid")

    def test_asset_chat_role_count_rejects_untrusted_identifiers(self) -> None:
        with self.assertRaisesRegex(ValueError, "unexpected role"):
            module.asset_chat_role_count(
                None,
                "postgres",
                None,
                "asset_chat_threads",
            )
        with self.assertRaisesRegex(ValueError, "unexpected table"):
            module.asset_chat_role_count(
                None,
                "authenticated",
                None,
                "pg_authid",
            )

    def test_tax_records_role_count_rejects_untrusted_identifiers(self) -> None:
        with self.assertRaisesRegex(ValueError, "unexpected role"):
            module.tax_records_role_count(
                None,
                "postgres",
                None,
                "tax_records",
            )
        with self.assertRaisesRegex(ValueError, "unexpected table"):
            module.tax_records_role_count(
                None,
                "authenticated",
                None,
                "pg_authid",
            )


if __name__ == "__main__":
    unittest.main()
