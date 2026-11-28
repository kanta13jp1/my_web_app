#!/usr/bin/env python3
"""Unit tests for scripts/architectural_safety_checkpoints.py (#2712)."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from scripts import architectural_safety_checkpoints as asc


class ArchitecturalSafetyCheckpointsTests(unittest.TestCase):
    def test_low_risk_mcp_call_runs_directly_without_pause(self) -> None:
        decision = asc.evaluate_mcp_tool_safety(
            tool_name="notes.list",
            requested_scopes=["read"],
            actor_role="viewer",
        )
        self.assertEqual(decision.decision, "allow_direct")
        self.assertTrue(decision.execution_allowed)
        self.assertFalse(decision.pause_required)
        self.assertIsNone(decision.checkpoint)

    def test_missing_scope_blocks_fail_closed(self) -> None:
        decision = asc.evaluate_mcp_tool_safety(
            tool_name="db.delete_rows",
            requested_scopes=["delete"],
            actor_role="viewer",
        )
        self.assertEqual(decision.decision, "blocked_policy")
        self.assertFalse(decision.execution_allowed)
        self.assertIn("delete", decision.missing_scopes)

    def test_system_impact_mcp_call_pauses_before_execution_and_resumes_only_on_admin_ui(self) -> None:
        paused = asc.evaluate_mcp_tool_safety(
            tool_name="deploy.edge_function",
            requested_scopes=["update"],
            actor_role="admin",
            run_key="batch-deploy-01",
            agent_name="release-agent",
            tool_payload={"function": "ai-hub"},
            captured_at="2026-11-25T09:00:00Z",
        )
        self.assertEqual(paused.decision, "paused_for_approval")
        self.assertFalse(paused.execution_allowed)
        self.assertTrue(paused.pause_required)
        self.assertIsNotNone(paused.checkpoint)
        assert paused.checkpoint is not None
        self.assertEqual(paused.checkpoint["pause_status"], "paused_lossless")

        # Non-verified UI caller must fail closed
        non_admin = asc.verify_safety_checkpoint_approval(
            paused.checkpoint,
            channel="admin_ui",
            admin_verified=False,
            approved_by="user-1",
        )
        self.assertFalse(non_admin.execution_allowed)
        self.assertEqual(non_admin.decision, "blocked_unauthorized")

        # Admin UI approval unblocks exact matching operation
        approved = asc.verify_safety_checkpoint_approval(
            paused.checkpoint,
            channel="admin_ui",
            admin_verified=True,
            approved_by="admin-user-1",
            now_iso="2026-11-25T09:05:00Z",
        )
        self.assertTrue(approved.execution_allowed)
        self.assertEqual(approved.decision, "approved_resumed")
        assert approved.checkpoint is not None

        resumed = asc.evaluate_mcp_tool_safety(
            tool_name="deploy.edge_function",
            requested_scopes=["update"],
            actor_role="admin",
            run_key="batch-deploy-01",
            agent_name="release-agent",
            tool_payload={"function": "ai-hub"},
            checkpoint=approved.checkpoint,
        )
        self.assertTrue(resumed.execution_allowed)
        self.assertEqual(resumed.decision, "approved_resumed")

        # Changing tool payload invalidates prior approval and triggers fresh pause
        changed_payload = asc.evaluate_mcp_tool_safety(
            tool_name="deploy.edge_function",
            requested_scopes=["update"],
            actor_role="admin",
            run_key="batch-deploy-01",
            agent_name="release-agent",
            tool_payload={"function": "billing-hub"},
            checkpoint=approved.checkpoint,
        )
        self.assertFalse(changed_payload.execution_allowed)
        self.assertEqual(changed_payload.decision, "paused_for_approval")

    def test_github_issue_approval_requires_authorized_maintainer_and_not_rejected(self) -> None:
        paused = asc.evaluate_mcp_tool_safety(
            tool_name="db.truncate_cache",
            requested_scopes=["delete"],
            actor_role="admin",
            run_key="cache-purge-77",
            github_repo="kanta13jp1/my_web_app",
            github_issue_number=2712,
            captured_at="2026-11-25T10:00:00Z",
        )
        assert paused.checkpoint is not None
        chk_id = str(paused.checkpoint["id"])

        # External contributor approval comment is ignored
        untrusted = asc.verify_safety_checkpoint_approval(
            paused.checkpoint,
            channel="github_issue",
            comments=[
                {
                    "id": 10,
                    "user": {"login": "external-user"},
                    "author_association": "NONE",
                    "body": f"/approve-checkpoint {chk_id}",
                }
            ],
        )
        self.assertFalse(untrusted.execution_allowed)
        self.assertEqual(untrusted.decision, "blocked_unauthorized")

        # Maintainer approval followed by later maintainer rejection stays blocked
        revoked = asc.verify_safety_checkpoint_approval(
            paused.checkpoint,
            channel="github_issue",
            comments=[
                {
                    "id": 11,
                    "user": {"login": "kanta13jp1"},
                    "author_association": "OWNER",
                    "body": f"/approve-checkpoint {chk_id}",
                },
                {
                    "id": 12,
                    "user": {"login": "kanta13jp1"},
                    "author_association": "OWNER",
                    "body": f"/reject-checkpoint {chk_id}",
                },
            ],
        )
        self.assertFalse(revoked.execution_allowed)

        # Clean maintainer approval authorizes resumption
        valid = asc.verify_safety_checkpoint_approval(
            paused.checkpoint,
            channel="github_issue",
            comments=[
                {
                    "id": 13,
                    "user": {"login": "kanta13jp1"},
                    "author_association": "OWNER",
                    "body": f"Approved. [safety-checkpoint-approved:{chk_id}]",
                }
            ],
        )
        self.assertTrue(valid.execution_allowed)
        self.assertEqual(valid.decision, "approved_resumed")
        assert valid.checkpoint is not None
        safety = valid.checkpoint["state_snapshot"]["safety_checkpoint"]
        self.assertEqual(safety["approval_channel"], "github_issue")
        self.assertEqual(safety["github_comment_id"], 13)

    def test_tampered_snapshot_fails_closed(self) -> None:
        paused = asc.evaluate_mcp_tool_safety(
            tool_name="billing.refund",
            requested_scopes=["purchase"],
            actor_role="admin",
            run_key="refund-09",
        )
        assert paused.checkpoint is not None
        tampered = json.loads(json.dumps(paused.checkpoint))
        tampered["state_snapshot"]["pending_step"] = "hijacked_step"
        res = asc.verify_safety_checkpoint_approval(
            tampered,
            channel="admin_ui",
            admin_verified=True,
            approved_by="admin-1",
        )
        self.assertFalse(res.execution_allowed)
        self.assertEqual(res.decision, "blocked_tampered_snapshot")

    def test_cli_exit_codes_and_self_test(self) -> None:
        summary = asc.run_self_test()
        self.assertEqual(summary["self_test"], "ok")
        self.assertEqual(asc.main(["--self-test"]), 0)

        with tempfile.TemporaryDirectory() as tmp:
            chk_path = Path(tmp) / "pause.json"
            comments_path = Path(tmp) / "comments.json"
            pause_rc = asc.main(
                [
                    "--tool-name",
                    "infra.apply_policy",
                    "--scopes",
                    "update",
                    "--actor-role",
                    "admin",
                    "--run-key",
                    "cli-policy-1",
                    "--json-out",
                    str(chk_path),
                ]
            )
            self.assertEqual(pause_rc, 3)
            decision_obj = json.loads(chk_path.read_text(encoding="utf-8"))
            chk_file = Path(tmp) / "checkpoint.json"
            chk_file.write_text(
                json.dumps(decision_obj["checkpoint"]),
                encoding="utf-8",
            )
            comments_path.write_text(
                json.dumps(
                    [
                        {
                            "id": 77,
                            "user": {"login": "kanta13jp1"},
                            "author_association": "OWNER",
                            "body": "/approve-checkpoint cli-policy-1",
                        }
                    ]
                ),
                encoding="utf-8",
            )
            resume_rc = asc.main(
                [
                    "--verify-channel",
                    "github_issue",
                    "--checkpoint-json",
                    str(chk_file),
                    "--comments-json",
                    str(comments_path),
                ]
            )
            self.assertEqual(resume_rc, 0)


if __name__ == "__main__":
    unittest.main()
