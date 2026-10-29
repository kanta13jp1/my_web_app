
import sys
import unittest
from dataclasses import replace
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import cloud_ci_handoff as handoff


def valid_evidence():
    return handoff.Release5925Evidence(
        branch=handoff._RELEASE_5925_BRANCH,
        head_sha=handoff._RELEASE_5925_HEAD,
        tree_sha=handoff._RELEASE_5925_TREE,
        parent_sha=handoff._RELEASE_5925_BASE,
        workflow_blob=handoff._RELEASE_5925_WORKFLOW,
        changed_blobs=dict(handoff._RELEASE_5925_CHANGED_BLOBS),
        pr_merged=True,
        pr_merge_sha=handoff._RELEASE_5925_MERGE,
        live_sha=handoff._RELEASE_5925_BASE,
        hold_value="false",
        branch_protected=False,
        effective_rules=(),
        active_or_queued_runs=(),
        fifo_lease_verified=True,
        approved_release=True,
        scope="web_only",
        profile="full",
    )


class Release5925GuardTest(unittest.TestCase):
    def test_nominal_evidence_still_cannot_dispatch(self):
        reasons = handoff.release_5925_blockers(valid_evidence())
        self.assertEqual(len(reasons), 3)
        self.assertIn("approved release dispatch is unimplemented", reasons)
        with self.assertRaisesRegex(RuntimeError, "no request sent"):
            handoff.dispatch_release_5925()


    def test_returned_run_id_or_unknown_never_guessed(self):
        self.assertEqual(handoff.parse_release_5925_run_id(200, {"workflow_run_id": 42}), 42)
        for status, payload in ((204, {}), (200, {}), (200, {"workflow_run_id": True}), (500, None)):
            with self.subTest(status=status, payload=payload):
                with self.assertRaisesRegex(RuntimeError, "do not retry"):
                    handoff.parse_release_5925_run_id(status, payload)

    def test_pending_journal_is_exclusive_and_has_no_token(self):
        import json
        import tempfile

        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "pending.json"
            handoff.create_release_5925_pending_journal(path, "a" * 32)
            saved = json.loads(path.read_text(encoding="utf-8"))
            self.assertEqual(saved["status"], "pending_or_unknown")
            self.assertEqual(saved["operation_id"], "a" * 32)
            self.assertNotIn("token", saved)
            with self.assertRaises(FileExistsError):
                handoff.create_release_5925_pending_journal(path, "b" * 32)
            self.assertEqual(json.loads(path.read_text(encoding="utf-8")), saved)

    def test_reject_invalid_operation_before_creating_journal(self):
        import tempfile

        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "pending.json"
            with self.assertRaises(ValueError):
                handoff.create_release_5925_pending_journal(path, "not-a-valid-id")
            self.assertFalse(path.exists())

    def test_unknown_or_protected_branches_fail_closed(self):
        for protected, rules in ((None, ()), (True, ()), (False, None), (False, ("x",))):
            with self.subTest(protected=protected, rules=rules):
                evidence = replace(valid_evidence(), branch_protected=protected, effective_rules=rules)
                self.assertGreater(len(handoff.release_5925_blockers(evidence)), 3)

    def test_remote_head_tree_parent_workflow_and_paths_are_fixed(self):
        for key, value in (
            ("branch", "main"), ("head_sha", "0" * 40), ("tree_sha", "0" * 40),
            ("parent_sha", "0" * 40), ("workflow_blob", "0" * 40),
            ("changed_blobs", {}), ("changed_blobs", {**handoff._RELEASE_5925_CHANGED_BLOBS, "extra": "x"}),
        ):
            with self.subTest(key=key):
                self.assertGreater(len(handoff.release_5925_blockers(replace(valid_evidence(), **{key: value}))), 3)

    def test_hold_pr_and_live_base_fail_closed(self):
        for key, value in (
            ("hold_value", ""), ("hold_value", "true"), ("hold_value", "False"),
            ("pr_merged", False), ("pr_merge_sha", "0" * 40), ("live_sha", "0" * 40),
        ):
            with self.subTest(key=key):
                self.assertGreater(len(handoff.release_5925_blockers(replace(valid_evidence(), **{key: value}))), 3)

    def test_unknown_or_busy_queue_and_missing_lease_fail_closed(self):
        for key, value in (
            ("active_or_queued_runs", None), ("active_or_queued_runs", ("run",)),
            ("fifo_lease_verified", False),
        ):
            with self.subTest(key=key):
                self.assertGreater(len(handoff.release_5925_blockers(replace(valid_evidence(), **{key: value}))), 3)

    def test_unapproved_or_wrong_scope_fails_closed(self):
        for key, value in (("approved_release", False), ("scope", "all"), ("profile", "web-build")):
            with self.subTest(key=key):
                self.assertGreater(len(handoff.release_5925_blockers(replace(valid_evidence(), **{key: value}))), 3)


if __name__ == "__main__":
    unittest.main()
