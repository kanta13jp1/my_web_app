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

    def test_plan_declares_no_production_credentials(self) -> None:
        plan = module.build_plan(
            ROOT / "test" / "fixtures" / "testcontainers" / "sql",
            ROOT / "test" / "fixtures" / "testcontainers" / "edge-db-smoke.ts",
            ROOT / "supabase" / "functions" / "health-check" / "index.ts",
        )
        self.assertFalse(plan["production_credentials_required"])
        self.assertIn("summary.json", " ".join(plan["artifacts"]))


if __name__ == "__main__":
    unittest.main()
