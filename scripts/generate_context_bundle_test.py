import unittest
from generate_context_bundle import INPUTS, build_bundle, render_coverage, ci_job_evidence

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

    def test_generated_coverage_preserves_manual_and_updates_once(self):
        manual = "Manual mapping\\nPending: real browser verification\\n".replace("\\\\n", "\\n")
        first = render_coverage(manual, SHA, None)
        evidence = dict(id=42, conclusion="success", test_steps={"flutter_test": "skipped"})
        second = render_coverage(first, SHA, evidence)
        self.assertTrue(second.startswith(manual))
        self.assertEqual(second.count("## Generated CI evidence"), 1)
        self.assertIn("| flutter_test | skipped |", second)
        self.assertIn("| deno_test | not reported |", second)
        self.assertNotIn("Unverified:", second)
        self.assertEqual(render_coverage(second, SHA, evidence), second)

    def test_invalid_coverage_markers_fail(self):
        for text in ("<!-- generated-ci-evidence:begin -->",
                     "<!-- generated-ci-evidence:end --><!-- generated-ci-evidence:begin -->"):
            with self.assertRaises(ValueError):
                render_coverage(text, SHA, None)

    def test_unknown_test_outcome_is_rejected(self):
        with self.assertRaises(ValueError):
            build_bundle(self.contents, [], SHA, dict(
                id=42, head_sha=SHA, status="completed", conclusion="success",
                test_steps={"flutter_test": "pretend-success"}))

    def test_ci_snapshot_uses_checked_revision_and_real_step_outcomes(self):
        evidence = ci_job_evidence(SHA, "123", "success", {
            "flutter_test": {"outcome": "skipped"},
            "deno_test": {"outcome": "success", "outputs": {"untrusted": "ignored"}},
        })
        _, bundle, metadata = build_bundle(self.contents, [], SHA, evidence)
        self.assertEqual(metadata["test_run"]["head_sha"], SHA)
        self.assertEqual(metadata["test_run"]["evidence_scope"], "ci_job_snapshot")
        self.assertEqual(metadata["test_run"]["test_steps"],
                         {"flutter_test": "skipped", "deno_test": "success"})
        self.assertIn("not final workflow completion", bundle)
        self.assertNotIn("untrusted", bundle)

    def test_ci_snapshot_rejects_invalid_run_or_status(self):
        for run_id, status in [("0", "success"), ("main", "success"), ("1", "queued")]:
            with self.assertRaises(ValueError):
                ci_job_evidence(SHA, run_id, status, {})

    def test_inputs_are_not_mutated(self):
        before = dict(self.contents)
        build_bundle(self.contents, ["replacement"], SHA)
        self.assertEqual(self.contents, before)


if __name__ == "__main__":
    unittest.main()
