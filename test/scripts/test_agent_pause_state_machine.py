#!/usr/bin/env python3
"""Offline unit tests for scripts/agent_pause_state_machine.py (#2616)."""

from __future__ import annotations

import json
from pathlib import Path
import socket
import sys
import tempfile
import unittest
from unittest.mock import MagicMock, patch

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import agent_pause_state_machine as apsm  # noqa: E402


class AgentPauseStateMachineTest(unittest.TestCase):
    def test_90_percent_warning_emits_immediate_slack_and_deduped_issue(self) -> None:
        initial = apsm.AgentCheckpointState(
            run_key="run-alpha-90",
            agent_name="research-agent",
            usage_ratio_pct=55.0,
        )
        decision = apsm.evaluate_checkpoint_transition(
            initial,
            usage_ratio_pct=91.2,
            pending_step="step_rank_sources",
            cursor_payload={"offset": 40},
            completed_items=["doc-1", "doc-2"],
            now_iso="2026-11-24T08:00:00Z",
        )
        self.assertEqual(decision.next_state.pause_status, "warning_90")
        self.assertTrue(decision.should_emit_warning_90)
        self.assertFalse(decision.should_emit_silent_pause_alert)
        self.assertIsNotNone(decision.slack_payload)
        self.assertIn("90% EARLY WARNING", decision.slack_payload["text"])
        self.assertIsNotNone(decision.github_issue_payload)
        self.assertIn("[agent-warning-90:run-alpha-90]", decision.github_issue_payload["title"])

        duplicate = apsm.evaluate_checkpoint_transition(
            decision.next_state,
            usage_ratio_pct=94.0,
            existing_open_issues=[
                {"title": "[agent-warning-90:run-alpha-90] existing", "body": ""}
            ],
            now_iso="2026-11-24T08:05:00Z",
        )
        self.assertFalse(duplicate.should_emit_warning_90)
        self.assertIsNone(duplicate.slack_payload)
        self.assertIsNone(duplicate.github_issue_payload)

    def test_credit_depletion_saves_lossless_snapshot_and_flags_silent_pause(self) -> None:
        active = apsm.AgentCheckpointState(
            run_key="run-beta-100",
            agent_name="writer-agent",
            checkpoint_seq=2,
            pause_status="warning_90",
            usage_ratio_pct=93.0,
            warning_90_sent=True,
            state_snapshot=apsm.build_lossless_snapshot(
                run_key="run-beta-100",
                agent_name="writer-agent",
                checkpoint_seq=2,
                pending_step="draft_section_3",
                cursor_payload={"paragraph": 18, "draft_id": "d-42"},
                completed_items=["intro", "sec1", "sec2"],
                captured_at="2026-11-24T08:01:00Z",
            ),
        )
        paused_decision = apsm.evaluate_checkpoint_transition(
            active,
            usage_ratio_pct=100.0,
            credit_depleted=True,
            now_iso="2026-11-24T08:02:00Z",
        )
        st = paused_decision.next_state
        self.assertEqual(st.pause_status, "paused_lossless")
        self.assertEqual(st.checkpoint_seq, 3)
        self.assertTrue(st.silent_pause_alerted)
        self.assertTrue(paused_decision.should_emit_silent_pause_alert)
        self.assertTrue(apsm.verify_lossless_snapshot(st.state_snapshot))
        self.assertEqual(st.state_snapshot["pending_step"], "draft_section_3")
        self.assertEqual(st.state_snapshot["cursor_payload"]["paragraph"], 18)
        self.assertIsNotNone(paused_decision.github_issue_payload)
        self.assertIn("[agent-silent-pause:run-beta-100]", paused_decision.github_issue_payload["title"])

    def test_lossless_resume_restores_context_and_rejects_non_admin_or_tamper(self) -> None:
        snap = apsm.build_lossless_snapshot(
            run_key="run-gamma-resume",
            agent_name="billing-audit-agent",
            checkpoint_seq=4,
            pending_step="reconcile_invoices",
            cursor_payload={"batch_cursor": "inv-099"},
            completed_items=["inv-001"],
            captured_at="2026-11-24T08:03:00Z",
        )
        paused = apsm.AgentCheckpointState(
            run_key="run-gamma-resume",
            agent_name="billing-audit-agent",
            checkpoint_seq=4,
            pause_status="paused_lossless",
            usage_ratio_pct=100.0,
            warning_90_sent=True,
            silent_pause_alerted=True,
            state_snapshot=snap,
        )

        with self.assertRaises(PermissionError):
            apsm.resume_from_checkpoint(
                paused,
                actor_user_id="user-1",
                actor_is_admin=False,
                new_usage_ratio_pct=12.0,
            )

        with self.assertRaises(ValueError):
            apsm.resume_from_checkpoint(
                paused,
                actor_user_id="admin-1",
                actor_is_admin=True,
                new_usage_ratio_pct=100.0,
            )

        tampered = apsm.AgentCheckpointState(
            run_key=paused.run_key,
            agent_name=paused.agent_name,
            checkpoint_seq=paused.checkpoint_seq,
            pause_status="paused_lossless",
            usage_ratio_pct=100.0,
            state_snapshot={**snap, "pending_step": "tampered_step"},
        )
        with self.assertRaises(ValueError):
            apsm.resume_from_checkpoint(
                tampered,
                actor_user_id="admin-1",
                actor_is_admin=True,
                new_usage_ratio_pct=20.0,
            )

        resumed, restored = apsm.resume_from_checkpoint(
            paused,
            actor_user_id="admin-1",
            actor_is_admin=True,
            new_usage_ratio_pct=20.0,
            now_iso="2026-11-24T08:10:00Z",
        )
        self.assertEqual(resumed.pause_status, "resumed")
        self.assertEqual(resumed.checkpoint_seq, 5)
        self.assertEqual(resumed.resumed_by, "admin-1")
        self.assertEqual(restored["pending_step"], "reconcile_invoices")
        self.assertEqual(restored["cursor_payload"]["batch_cursor"], "inv-099")
        self.assertEqual(restored["completed_items"], ["inv-001"])

    def test_terminal_failed_state_blocks_transitions(self) -> None:
        failed_state = apsm.AgentCheckpointState(
            run_key="run-failed",
            agent_name="sync-agent",
            pause_status="failed",
        )
        with self.assertRaises(ValueError):
            apsm.evaluate_checkpoint_transition(failed_state, usage_ratio_pct=10.0)

    def test_pinned_https_connection_rejects_ssrf_and_handles_errors_safely(self) -> None:
        cleaned = apsm._sanitize_url_for_log(
            "https://hooks.slack.com/services/T1/B2/abc?sig=secret_value#frag"
        )
        self.assertEqual(cleaned, "https://hooks.slack.com/services/T1/B2/abc")

        with self.assertRaises(ValueError):
            apsm.validate_and_resolve_https_url("http://hooks.slack.com/services/T1/B2")
        with patch(
            "socket.getaddrinfo",
            return_value=[(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("169.254.169.254", 443))],
        ):
            with self.assertRaises(ValueError):
                apsm.validate_and_resolve_https_url("https://metadata.example.com/latest")

        fake_conn = MagicMock()
        redirect_resp = MagicMock(status=302)
        redirect_resp.read.return_value = b"Found"
        fake_conn.getresponse.return_value = redirect_resp
        with (
            patch(
                "socket.getaddrinfo",
                return_value=[(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("93.184.216.34", 443))],
            ),
            patch.object(apsm, "_PinnedHTTPSConnection", return_value=fake_conn) as pinned_cls,
        ):
            with self.assertRaises(RuntimeError) as redirect_ctx:
                apsm._http_json(
                    "https://api.github.com/repos/a/b/issues?access=xyz",
                    method="POST",
                    headers={"Content-Type": "application/json"},
                    payload={"title": "x"},
                )
        self.assertIn("Redirect blocked (HTTP 302)", str(redirect_ctx.exception))
        self.assertNotIn("access=xyz", str(redirect_ctx.exception))
        self.assertEqual(pinned_cls.call_args.kwargs["pinned_ip"], "93.184.216.34")
        self.assertEqual(pinned_cls.call_args.kwargs["tls_hostname"], "api.github.com")

        err_resp = MagicMock(status=503)
        err_resp.read.return_value = b"upstream overloaded"
        fake_conn.getresponse.return_value = err_resp
        with (
            patch(
                "socket.getaddrinfo",
                return_value=[(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("93.184.216.34", 443))],
            ),
            patch.object(apsm, "_PinnedHTTPSConnection", return_value=fake_conn),
        ):
            with self.assertRaises(RuntimeError) as ctx:
                apsm._http_json(
                    "https://api.github.com/repos/a/b/issues?access=xyz",
                    method="POST",
                    headers={"Content-Type": "application/json"},
                    payload={"title": "x"},
                )
        self.assertIn("HTTP 503", str(ctx.exception))
        self.assertNotIn("access=xyz", str(ctx.exception))

    def test_cli_dry_run_and_self_test(self) -> None:
        self.assertEqual(apsm.main(["--self-test"]), 0)
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            json_out = tmp / "report.json"
            md_out = tmp / "report.md"
            gh_out = tmp / "gh_output.txt"
            rc = apsm.main(
                [
                    "--run-key",
                    "cli-run-95",
                    "--agent-name",
                    "cli-agent",
                    "--usage-pct",
                    "95.0",
                    "--dry-run",
                    "--json-out",
                    str(json_out),
                    "--markdown-out",
                    str(md_out),
                    "--github-output",
                    str(gh_out),
                ]
            )
            self.assertEqual(rc, 0)
            parsed = json.loads(json_out.read_text(encoding="utf-8"))
            self.assertEqual(parsed["next_state"]["pause_status"], "warning_90")
            self.assertIn("warning_90_emitted=true", gh_out.read_text(encoding="utf-8"))
            self.assertIn("cli-run-95", md_out.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
