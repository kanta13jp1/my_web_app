#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "audit_hub_migration_completeness.py"
spec = importlib.util.spec_from_file_location("audit_hub_migration_completeness", SCRIPT)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = module
spec.loader.exec_module(module)


class AuditHubMigrationCompletenessTest(unittest.TestCase):
    def test_load_dead_list_from_workflow(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workflow = Path(tmp) / "deploy-prod.yml"
            workflow.write_text(
                """
jobs:
  deploy:
    steps:
      - run: |
          DEAD_LIST=(
            share-quote
            generate-quote-image
          )
""",
                encoding="utf-8",
            )

            self.assertEqual(
                module.load_dead_list(str(workflow)),
                ["share-quote", "generate-quote-image"],
            )

    def test_scan_stale_refs_detects_invoke_and_url(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "lib").mkdir()
            (root / "lib" / "page.dart").write_text(
                """
await client.functions.invoke(
  'share-quote',
  body: {},
);
""",
                encoding="utf-8",
            )
            (root / "script.py").write_text(
                "url = 'https://example.supabase.co/functions/v1/generate-quote-image'\n",
                encoding="utf-8",
            )

            stale = module.scan_stale_refs(
                ["share-quote", "generate-quote-image"],
                [str(root / "lib"), str(root)],
            )

            self.assertIn("share-quote", stale)
            self.assertIn("generate-quote-image", stale)

    def test_hub_guidance_includes_specific_hub_action(self) -> None:
        guidance = module.hub_guidance("share-quote")
        self.assertIn("growth-hub", guidance)
        self.assertIn("share-quote", guidance)

    def test_hub_guidance_falls_back_for_unknown_mapping(self) -> None:
        guidance = module.hub_guidance("legacy-custom-tool")
        self.assertIn("deploy-prod.yml", guidance)
        self.assertIn("legacy-custom-tool", guidance)


if __name__ == "__main__":
    unittest.main()
