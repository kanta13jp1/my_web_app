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

    def test_plan_includes_agentless_course_runtime_proof(self) -> None:
        plan = module.build_plan(
            ROOT / "test" / "fixtures" / "testcontainers" / "sql",
            ROOT / "test" / "fixtures" / "testcontainers" / "edge-db-smoke.ts",
            ROOT / "supabase" / "functions" / "health-check" / "index.ts",
        )
        self.assertEqual(
            plan["agentless_course_migration"],
            "supabase/migrations/20260830120000_remediate_agentless_course.sql",
        )
        checks = " ".join(plan["agentless_course_checks"])
        self.assertIn("exact Agentless course row", checks)
        self.assertIn("creates no learner outcome rows", checks)
        self.assertIn("fail closed", checks)
        self.assertIn("service-role-only aggregate view", checks)
        self.assertIn("applies twice", checks)

    def test_agentless_completion_insert_matches_fixed_manifest_shape(self) -> None:
        self.assertEqual(module.AGENTLESS_COMPLETION_INSERT_SQL.count("%s"), 22)
        self.assertIn("'lab_completed'", module.AGENTLESS_COMPLETION_INSERT_SQL)

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
        self.assertIn(
            "deno check --config supabase/functions/deno.json "
            "supabase/functions/growth-hub/index.ts",
            plan["actual_edge_checks"],
        )

    def test_plan_includes_voice_dubbing_quota_state_machine(self) -> None:
        plan = module.build_plan(
            ROOT / "test" / "fixtures" / "testcontainers" / "sql",
            ROOT / "test" / "fixtures" / "testcontainers" / "edge-db-smoke.ts",
            ROOT / "supabase" / "functions" / "health-check" / "index.ts",
        )
        self.assertEqual(
            plan["voice_dubbing_sql"],
            [
                "supabase/tests/voice_dubbing_bootstrap.sql",
                "supabase/migrations/20260505203000_create_billing_tables.sql",
                "supabase/migrations/20260814160000_add_voice_dubbing_usage.sql",
                "supabase/tests/voice_dubbing_quota_contract.sql",
            ],
        )
        checks = " ".join(plan["voice_dubbing_checks"])
        self.assertIn("applies twice", checks)
        self.assertIn("without rebilling", checks)
        self.assertIn("TTL reconciliation", checks)
        self.assertIn("over-limit claims", checks.lower())

    def test_plan_includes_issue_1233_resource_optimizer_contract(self) -> None:
        plan = module.build_plan(
            ROOT / "test" / "fixtures" / "testcontainers" / "sql",
            ROOT / "test" / "fixtures" / "testcontainers" / "edge-db-smoke.ts",
            ROOT / "supabase" / "functions" / "health-check" / "index.ts",
        )
        self.assertEqual(
            plan["issue_1233_resource_optimizer_sql"],
            [
                "supabase/tests/issue1233_resource_optimizer_bootstrap.sql",
                "supabase/migrations/20260412025000_create_hub_data_table.sql",
                "supabase/migrations/20260327000012_create_daily_habits.sql",
                "supabase/migrations/20260721235500_add_habit_resource_optimization.sql",
                "supabase/migrations/20260827040000_resource_optimizer_ai_quota.sql",
                "supabase/tests/issue1233_resource_optimizer_contract.sql",
            ],
        )
        checks = " ".join(plan["issue_1233_resource_optimizer_checks"])
        self.assertIn("apply twice", checks)
        self.assertIn("two authenticated users", checks)
        self.assertIn("PUBLIC and anon", checks)
        self.assertIn("default", checks)
        self.assertIn("below seven", checks)
        self.assertIn("without variance", checks)
        self.assertIn("seven varied self-reported", checks)
        self.assertIn("parallel", checks)
        self.assertIn("daily limit", checks)
        bootstrap = (
            ROOT / "supabase" / "tests" / "issue1233_resource_optimizer_bootstrap.sql"
        ).read_text(encoding="utf-8")
        self.assertNotIn("alter default privileges", bootstrap.lower())

    def test_plan_includes_issue_4956_wbs_admin_review_contract(self) -> None:
        plan = module.build_plan(
            ROOT / "test" / "fixtures" / "testcontainers" / "sql",
            ROOT / "test" / "fixtures" / "testcontainers" / "edge-db-smoke.ts",
            ROOT / "supabase" / "functions" / "health-check" / "index.ts",
        )
        self.assertEqual(
            plan["issue_4956_wbs_admin_review_sql"],
            [
                "supabase/tests/issue4956_wbs_admin_review_bootstrap.sql",
                "supabase/migrations/20260828153722_repair_wbs_admin_review_contract.sql",
                "supabase/tests/issue4956_wbs_admin_review_contract.sql",
            ],
        )
        checks = " ".join(plan["issue_4956_wbs_admin_review_checks"])
        self.assertIn("legacy profile id collides", checks)
        self.assertIn("in_progress/100/requested", checks)
        self.assertIn("trigger ordering", checks)
        self.assertIn("fail closed", checks)
        self.assertIn("manual_override", checks)
        self.assertIn("applies twice", checks)

    def test_plan_includes_issue_4927_recurring_tombstone_contract(self) -> None:
        plan = module.build_plan(
            ROOT / "test" / "fixtures" / "testcontainers" / "sql",
            ROOT / "test" / "fixtures" / "testcontainers" / "edge-db-smoke.ts",
            ROOT / "supabase" / "functions" / "health-check" / "index.ts",
        )
        self.assertEqual(
            plan["issue_4927_recurring_tombstone_sql"],
            [
                "supabase/migrations/20260612230000_asset_pref_mirror.sql",
                "supabase/migrations/20260828164000_atomic_recurring_fixed_cost_tombstones.sql",
                "supabase/tests/issue4927_recurring_tombstone_contract.sql",
            ],
        )
        checks = " ".join(plan["issue_4927_recurring_tombstone_checks"])
        self.assertIn("NULL IDs", checks)
        self.assertIn("mixed-type malformed", checks)
        self.assertIn("spoofed-GUC", checks)
        self.assertIn("unrelated-key CRUD", checks)
        self.assertIn("guard state", checks)
        self.assertIn("concurrent add/remove", checks)
        self.assertIn("applies twice", checks)

    def test_plan_includes_issue_2844_account_deletion_contract(self) -> None:
        plan = module.build_plan(
            ROOT / "test" / "fixtures" / "testcontainers" / "sql",
            ROOT / "test" / "fixtures" / "testcontainers" / "edge-db-smoke.ts",
            ROOT / "supabase" / "functions" / "health-check" / "index.ts",
        )
        self.assertEqual(
            plan["issue_2844_account_deletion_sql"],
            [
                "supabase/tests/issue2844_account_deletion_bootstrap.sql",
                "supabase/migrations/20260829095836_account_retention_and_deletion.sql",
                "supabase/migrations/20260830054326_account_deletion_rollout_preflight.sql",
                "supabase/tests/issue2844_account_deletion_contract.sql",
                "supabase/tests/issue2844_account_deletion_rollout_contract.sql",
            ],
        )
        checks = " ".join(plan["issue_2844_account_deletion_checks"])
        self.assertIn("service-role only", checks)
        self.assertIn("atomically", checks)
        self.assertIn("CASCADE", checks)
        self.assertIn("fail closed", checks)
        self.assertIn("Storage owner metadata", checks)
        self.assertIn("bounded retry", checks)
        self.assertIn("removes user_id", checks)
        self.assertIn("non-mutating", checks)
        self.assertIn("control tenant", checks)
        self.assertIn("residual is zero", checks)

    def test_plan_includes_note_comments_authorization_boundary(self) -> None:
        plan = module.build_plan(
            ROOT / "test" / "fixtures" / "testcontainers" / "sql",
            ROOT / "test" / "fixtures" / "testcontainers" / "edge-db-smoke.ts",
            ROOT / "supabase" / "functions" / "health-check" / "index.ts",
        )
        self.assertEqual(
            plan["note_comments_migration"],
            "supabase/migrations/20260827032000_harden_note_comments_authorization.sql",
        )
        checks = " ".join(plan["note_comments_checks"])
        self.assertIn("body user_id forgery", checks)
        self.assertIn("direct self-join", checks)
        self.assertIn("applies twice", checks)
        self.assertEqual(
            plan["generated_memo_repair_migration"],
            "supabase/migrations/"
            "20260830021402_restore_generated_public_memo_publishing.sql",
        )
        repair_checks = " ".join(plan["generated_memo_repair_checks"])
        self.assertIn("owner-backed notes", repair_checks)
        self.assertIn("foreign key is validated", repair_checks)
        self.assertIn("forged legacy publications", repair_checks)
        self.assertIn("applies twice", repair_checks)
        self.assertEqual(
            plan["public_memo_returning_rls_migration"],
            "supabase/migrations/"
            "20260830063839_fix_public_memo_returning_rls.sql",
        )
        returning_checks = " ".join(plan["public_memo_returning_rls_checks"])
        self.assertIn("insert with RETURNING", returning_checks)
        self.assertIn("conflict update with RETURNING", returning_checks)
        self.assertIn("does not self-read", returning_checks)
        self.assertIn("applies twice", returning_checks)

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

    def test_note_comments_runner_rejects_untrusted_role(self) -> None:
        with self.assertRaisesRegex(ValueError, "unexpected role"):
            module.note_comments_run_as(
                None,
                role="postgres",
                user_id=None,
                statement="select 1",
            )

    def test_team_join_uses_authenticated_rpc_boundary(self) -> None:
        source = (ROOT / "lib" / "pages" / "team_workspace_page.dart").read_text(
            encoding="utf-8"
        )
        join_method = source.split("Future<void> _joinByInviteCode() async {", 1)[1]
        join_method = join_method.split("Future<void> _deleteTeam", 1)[0]
        self.assertIn("'join_team_with_invite_code'", join_method)
        self.assertIn("'p_invite_code': code.trim()", join_method)
        self.assertNotIn(".from('team_memberships').insert", join_method)
        self.assertNotIn("'user_id'", join_method)
        self.assertIn("招待コード (8文字または32文字)", source)
        self.assertIn("LengthLimitingTextInputFormatter(32)", source)

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
