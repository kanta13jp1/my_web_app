#!/usr/bin/env python3
"""Unit tests for scripts/auto_refactor_compat_lint.py (#2791)."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

_SCRIPTS_DIR = Path(__file__).resolve().parent
if str(_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_DIR))

from auto_refactor_compat_lint import (  # noqa: E402
    DUAL_WRITE_DOC_REF,
    evaluate_refactor_and_compat,
    lint_sql_migration,
    parse_dart_analyze_output,
    parse_dart_fix_output,
)


class AutoRefactorCompatLintTests(unittest.TestCase):
    def test_parses_dart_fix_and_analyze_logs(self) -> None:
        fix_log = (
            "lib/services/example.dart: 2 fixes (prefer_const_constructors)\n"
        )
        analyze_log = (
            "info - Prefer const with constant constructors - "
            "lib/main.dart:42:10 - prefer_const_constructors\n"
        )

        fixes = parse_dart_fix_output(fix_log)
        diags = parse_dart_analyze_output(analyze_log)

        self.assertEqual(len(fixes), 1)
        self.assertEqual(fixes[0].file_path, "lib/services/example.dart")
        self.assertTrue(fixes[0].fixable)

        self.assertEqual(len(diags), 1)
        self.assertEqual(diags[0].file_path, "lib/main.dart")
        self.assertEqual(diags[0].line, 42)
        self.assertEqual(diags[0].rule_code, "prefer_const_constructors")

    def test_detects_breaking_sql_patterns_and_links_dual_write(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            sql_file = Path(tmp) / "20261126_breaking.sql"
            sql_file.write_text(
                "DROP TABLE old_logs;\n"
                "ALTER TABLE users DROP COLUMN legacy_flag;\n"
                "ALTER TABLE users ALTER COLUMN age TYPE TEXT;\n"
                "ALTER TABLE users RENAME COLUMN nick TO handle;\n"
                "TRUNCATE TABLE temp_events;\n"
                "ALTER TABLE users ADD COLUMN role TEXT NOT NULL;\n",
                encoding="utf-8",
            )
            report = evaluate_refactor_and_compat(sql_paths=[sql_file])

        codes = [v.code for v in report.sql_violations]
        self.assertTrue(report.has_breaking_sql)
        self.assertIn("sql-drop-table", codes)
        self.assertIn("sql-drop-column", codes)
        self.assertIn("sql-alter-column-type", codes)
        self.assertIn("sql-rename-column", codes)
        self.assertIn("sql-truncate", codes)
        self.assertIn("sql-not-null-no-default", codes)
        self.assertIn(DUAL_WRITE_DOC_REF, report.markdown)

    def test_allows_additive_safe_migrations_and_ignores_comments(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            sql_file = Path(tmp) / "20261126_safe.sql"
            sql_file.write_text(
                "-- DROP TABLE commented_out;\n"
                "ALTER TABLE users ADD COLUMN bio TEXT;\n"
                "ALTER TABLE users ADD COLUMN tier TEXT NOT NULL DEFAULT 'free';\n",
                encoding="utf-8",
            )
            violations = lint_sql_migration(sql_file)

        self.assertEqual(violations, [])


if __name__ == "__main__":
    unittest.main()
