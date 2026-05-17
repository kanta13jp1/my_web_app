import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from scripts import sync_inject_rules


class SyncInjectRulesTest(unittest.TestCase):
    def test_canonical_rule_count_matches_expected_constant(self) -> None:
        text = sync_inject_rules.read_text(sync_inject_rules.CANONICAL)
        self.assertIsNotNone(text)

        result = sync_inject_rules.verify(text or "")

        self.assertEqual(result["rule_count"], sync_inject_rules.EXPECTED_RULE_COUNT)
        self.assertEqual(result["expected_rule_count"], sync_inject_rules.EXPECTED_RULE_COUNT)
        self.assertEqual(result["missing_critical_rules"], [])
        self.assertTrue(result["kpi_pass"], result["issues"])

    def test_rules_index_mentions_every_canonical_rule(self) -> None:
        canonical = sync_inject_rules.read_text(sync_inject_rules.CANONICAL) or ""
        docs = (sync_inject_rules.REPO_ROOT / "docs" / "RULES_INDEX.md").read_text(
            encoding="utf-8",
        )

        missing = [
            rule_id
            for rule_id in sync_inject_rules.list_rule_ids(canonical)
            if rule_id not in docs
        ]

        self.assertEqual(missing, [])


if __name__ == "__main__":
    unittest.main()
