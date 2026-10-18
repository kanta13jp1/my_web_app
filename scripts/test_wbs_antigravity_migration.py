"""Static migration contract checks; these do not execute PostgreSQL.

Run: python scripts/test_wbs_antigravity_migration.py
SQL integration counterpart: scripts/sql/test_wbs_antigravity_migration.sql
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATIONS = ROOT / 'supabase/migrations'
BASELINE = MIGRATIONS / '20260610210400_wbs_drag_unassigned_owner.sql'
TARGET = MIGRATIONS / '20261001194000_wbs_sdlc_7phase_comprehensive_coverage.sql'


def owner_check(sql):
    return re.search(
        r'ADD CONSTRAINT wbs_tasks_owner_instance_check\s+CHECK\s*\((.*?)\)\s*;',
        sql, re.S).group(1)


def owners(check):
    return set(re.findall(r"'([^']*)'", check)) - {''}


class WbsAntigravityMigrationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sql = TARGET.read_text(encoding='utf-8')
        cls.old = owner_check(BASELINE.read_text(encoding='utf-8'))
        cls.new = owner_check(cls.sql)

    def test_only_antigravity_is_added(self):
        self.assertEqual(owners(self.new), owners(self.old) | {'antigravity'})
        self.assertEqual(self.new.replace("'antigravity', ", ''), self.old)

    def test_null_and_empty_remain_explicitly_allowed(self):
        self.assertIn('owner_instance IS NULL', self.new)
        self.assertIn("owner_instance = ''", self.new)

    def test_constraint_replacement_precedes_first_seed(self):
        first = self.sql.index('INSERT INTO public.wbs_tasks')
        drop = self.sql.index('ALTER TABLE public.wbs_tasks DROP CONSTRAINT IF EXISTS')
        add = self.sql.index('ALTER TABLE public.wbs_tasks ADD CONSTRAINT')
        self.assertLess(drop, add)
        self.assertLess(add, first)
        self.assertNotIn('NOT VALID', self.sql[:first])

    def test_all_ten_seed_rows_fit_allowlists_and_deduplicate(self):
        rows = re.findall(
            r"SELECT\s+'((?:''|[^'])*)',\s+'([^']+)',\s+'([^']+)',"
            r"\s+(\d+),\s+'([^']+)',\s+'([^']+)',\s+'([^']+)',"
            r"\s+'((?:''|[^'])*)',\s+now\(\),\s+now\(\)"
            r"\s+WHERE NOT EXISTS\s*\(\s*SELECT 1 FROM public.wbs_tasks"
            r"\s+WHERE title = '((?:''|[^'])*)'\s*\);", self.sql, re.S)
        self.assertEqual(len(rows), 10)
        self.assertEqual(self.sql.count('INSERT INTO public.wbs_tasks'), 10)
        self.assertEqual(len({row[0] for row in rows}), 10)
        phases = {'planning', 'design', 'impl', 'test', 'release', 'ops', 'maintenance'}
        self.assertEqual({row[6] for row in rows}, phases)
        for title, _, status, progress, priority, owner, phase, description, guard in rows:
            with self.subTest(title=title):
                self.assertEqual(title, guard)
                self.assertIn(owner, owners(self.new))
                self.assertIn(status, {'pending', 'in_progress'})
                self.assertTrue(0 <= int(progress) <= 100)
                self.assertIn(priority, {'medium', 'high', 'critical'})
                self.assertIn(phase, phases)
                self.assertTrue(description.strip())


if __name__ == '__main__':
    unittest.main()
