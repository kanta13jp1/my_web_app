import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("migration_guard", Path(__file__).with_name("check_migration_time_relative_check.py"))
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)

class QualifiedMigrationGuardTest(unittest.TestCase):
    def test_public_update_keeps_table_name(self):
        match = guard.UPDATE_RE.search("UPDATE public.asset_payroll_balance_selections SET reason = 'x';")
        self.assertEqual(guard.canonical_name(match.group(1)), "asset_payroll_balance_selections")

    def test_quoted_and_private_names(self):
        self.assertEqual(guard.canonical_name(guard.UPDATE_RE.search('UPDATE "public"."wbs_tasks" SET x = 1').group(1)), "wbs_tasks")
        self.assertEqual(guard.canonical_name("private.wbs_tasks"), "private.wbs_tasks")

    def test_schema_qualified_time_trigger_still_detected(self):
        original = guard.MIGRATIONS_DIR
        with tempfile.TemporaryDirectory() as directory:
            guard.MIGRATIONS_DIR = Path(directory)
            try:
                (Path(directory) / "synthetic.sql").write_text("""
CREATE FUNCTION public.enforce_due() RETURNS trigger LANGUAGE plpgsql AS $fn$
BEGIN IF NEW.due_date < CURRENT_DATE THEN RAISE EXCEPTION 'expired'; END IF; RETURN NEW; END;
$fn$;
CREATE TRIGGER due_guard BEFORE UPDATE ON public.wbs_tasks FOR EACH ROW EXECUTE FUNCTION public.enforce_due();
""", encoding="utf8")
                _, sensitive, _ = guard.get_time_enforcement_tables()
                self.assertEqual(sensitive, {"wbs_tasks"})
                safe = guard.canonical_name(guard.UPDATE_RE.search("UPDATE public.asset_payroll_balance_selections SET reason = 'x'").group(1))
                risky = guard.canonical_name(guard.UPDATE_RE.search("UPDATE public.wbs_tasks SET title = 'x'").group(1))
                self.assertNotIn(safe, sensitive)
                self.assertIn(risky, sensitive)
            finally:
                guard.MIGRATIONS_DIR = original

if __name__ == "__main__":
    unittest.main()
