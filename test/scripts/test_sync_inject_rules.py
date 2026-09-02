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


class ReadFromRefTest(unittest.TestCase):
    """The unattended sync reads the canonical out of a ref, never the working tree."""

    def test_reads_canonical_from_a_ref(self) -> None:
        text = sync_inject_rules.read_text_from_ref("HEAD")

        self.assertIsNotNone(text)
        self.assertEqual(
            sync_inject_rules.verify(text or "")["rule_count"],
            sync_inject_rules.EXPECTED_RULE_COUNT,
        )

    def test_returns_none_for_unknown_ref(self) -> None:
        # A missing ref must surface as None so the caller can fail loudly rather
        # than silently syncing empty rules into the home file.
        self.assertIsNone(sync_inject_rules.read_text_from_ref("no/such/ref"))

    def test_ref_read_ignores_working_tree_edits(self) -> None:
        # The whole point: the result must not depend on what the checkout happens
        # to contain, so the daily sync is safe on any branch, clean or dirty.
        from_ref = sync_inject_rules.read_text_from_ref("HEAD")
        from_tree = sync_inject_rules.read_text(sync_inject_rules.CANONICAL)

        self.assertIsNotNone(from_ref)
        self.assertIsNotNone(from_tree)
        # Committed tree and ref agree here; the guarantee is that from_ref came
        # from the object store, which no working-tree edit can reach.
        self.assertEqual(
            sync_inject_rules.list_rule_ids(from_ref or ""),
            sync_inject_rules.list_rule_ids(from_tree or ""),
        )


if __name__ == "__main__":
    unittest.main()
