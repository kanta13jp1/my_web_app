import unittest
from generate_context_bundle import INPUTS, build_bundle

SHA = "a" * 40


class ContextBundleTest(unittest.TestCase):
    def setUp(self):
        self.contents = {name: f"Original {name}\n" for name in INPUTS}

    def test_exact_inputs_and_deterministic_tree(self):
        tree, bundle, metadata = build_bundle(self.contents, ["z", "a", "a"], SHA)
        self.assertEqual(tree, "a\nz\n")
        self.assertEqual(set(metadata["inputs"]), set(INPUTS))
        for name in INPUTS:
            self.assertIn("## " + name, bundle)
        self.assertIn(self.contents["TEST_COVERAGE.md"], bundle)
        self.assertIsNone(metadata["test_run"])
        self.assertIn("unverified", bundle)

    def test_missing_input_fails(self):
        del self.contents["USER_MANUAL.md"]
        with self.assertRaises(ValueError):
            build_bundle(self.contents, [], SHA)

    def test_invalid_revision_fails(self):
        with self.assertRaises(ValueError):
            build_bundle(self.contents, [], "main")

    def test_other_revision_cannot_supply_test_success(self):
        evidence = dict(id=1, head_sha="b" * 40, status="completed", conclusion="success")
        with self.assertRaises(ValueError):
            build_bundle(self.contents, [], SHA, evidence)

    def test_running_or_unknown_result_cannot_claim_completion(self):
        for status, conclusion in [("in_progress", "success"), ("completed", "unknown")]:
            with self.assertRaises(ValueError):
                build_bundle(self.contents, [], SHA, dict(
                    id=1, head_sha=SHA, status=status, conclusion=conclusion))

    def test_failure_is_preserved_not_promoted_to_success(self):
        evidence = dict(id=1, head_sha=SHA, status="completed", conclusion="failure")
        _, _, metadata = build_bundle(self.contents, [], SHA, evidence)
        self.assertEqual(metadata["test_run"]["conclusion"], "failure")

    def test_inputs_are_not_mutated(self):
        before = dict(self.contents)
        build_bundle(self.contents, ["replacement"], SHA)
        self.assertEqual(self.contents, before)


if __name__ == "__main__":
    unittest.main()
