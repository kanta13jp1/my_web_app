#!/usr/bin/env python3
"""Unit tests for deploy concurrency and sync monitor (#2678)."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

import deploy_concurrency_monitor as monitor  # noqa: E402


SHA_MAIN = "1111111111111111111111111111111111111111"
SHA_PREV = "2222222222222222222222222222222222222222"


class DeployConcurrencyMonitorTest(unittest.TestCase):
    def test_repository_workflow_concurrency_contracts_pass(self) -> None:
        audit = monitor.inspect_workflow_concurrency(ROOT)
        self.assertTrue(audit["contracts_ok"], audit["violations"])
        self.assertGreaterEqual(audit["checked_workflows"], 5)
        prod = next(w for w in audit["workflows"] if w["path"].endswith("deploy-prod.yml"))
        self.assertEqual(prod["group"], "deploy-production")
        self.assertEqual(prod["cancel_in_progress"], "false")

    def test_contract_audit_detects_unsafe_cancel_in_progress(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_root = Path(tmpdir)
            wf_dir = tmp_root / ".github" / "workflows"
            wf_dir.mkdir(parents=True)
            for rel in monitor.REQUIRED_SERIAL_DEPLOY_WORKFLOWS:
                text = (ROOT / rel).read_text(encoding="utf-8-sig")
                if rel.endswith("deploy-prod.yml"):
                    text = text.replace("cancel-in-progress: false", "cancel-in-progress: true", 1)
                (tmp_root / rel).write_text(text, encoding="utf-8")
            audit = monitor.inspect_workflow_concurrency(tmp_root)
            self.assertFalse(audit["contracts_ok"])
            self.assertTrue(
                any("cancel-in-progress must be `false`" in msg for msg in audit["violations"]),
            )

    def test_evaluate_healthy_vs_queued_serial_execution(self) -> None:
        contracts = monitor.inspect_workflow_concurrency(ROOT)
        healthy = monitor.evaluate_deploy_state(
            [
                {
                    "id": 9002,
                    "head_sha": SHA_MAIN,
                    "status": "completed",
                    "conclusion": "success",
                    "created_at": "2026-11-25T02:00:00Z",
                    "run_attempt": 1,
                },
                {
                    "id": 9001,
                    "head_sha": SHA_PREV,
                    "status": "completed",
                    "conclusion": "cancelled",
                    "created_at": "2026-11-25T01:50:00Z",
                    "run_attempt": 1,
                },
            ],
            main_sha=SHA_MAIN,
            contract_audit=contracts,
        )
        self.assertEqual(healthy["status"], "healthy")
        self.assertTrue(healthy["synced"])
        self.assertEqual(healthy["cancelled_runs_count"], 1)

        queued = monitor.evaluate_deploy_state(
            [
                {
                    "databaseId": 9003,
                    "headSha": SHA_MAIN,
                    "status": "queued",
                    "conclusion": None,
                    "createdAt": "2026-11-25T03:00:00Z",
                },
                {
                    "databaseId": 9002,
                    "headSha": SHA_PREV,
                    "status": "in_progress",
                    "conclusion": None,
                    "createdAt": "2026-11-25T02:55:00Z",
                },
            ],
            main_sha=SHA_MAIN,
            contract_audit=contracts,
        )
        self.assertEqual(queued["status"], "queued_behind_active")
        self.assertEqual(queued["recommended_action"], "wait_serial_queue")
        self.assertFalse(queued["synced"])

    def test_evaluate_cancelled_failed_and_unsynced_states(self) -> None:
        contracts = monitor.inspect_workflow_concurrency(ROOT)

        cancelled = monitor.evaluate_deploy_state(
            [
                {
                    "databaseId": 9101,
                    "headSha": SHA_MAIN,
                    "status": "completed",
                    "conclusion": "cancelled",
                    "createdAt": "2026-11-25T04:00:00Z",
                },
            ],
            main_sha=SHA_MAIN,
            contract_audit=contracts,
        )
        self.assertEqual(cancelled["status"], "concurrency_cancelled")
        self.assertEqual(cancelled["recommended_action"], "dispatch_main_deploy")
        self.assertFalse(cancelled["synced"])

        retryable = monitor.evaluate_deploy_state(
            [
                {
                    "databaseId": 9102,
                    "headSha": SHA_MAIN,
                    "status": "completed",
                    "conclusion": "failure",
                    "attempt": 1,
                    "createdAt": "2026-11-25T04:05:00Z",
                },
            ],
            main_sha=SHA_MAIN,
            contract_audit=contracts,
            max_attempts=2,
        )
        self.assertEqual(retryable["status"], "needs_rerun")
        self.assertEqual(retryable["retry_run_id"], 9102)
        self.assertEqual(retryable["recommended_action"], "rerun_failed_jobs")

        exhausted = monitor.evaluate_deploy_state(
            [
                {
                    "databaseId": 9103,
                    "headSha": SHA_MAIN,
                    "status": "completed",
                    "conclusion": "failure",
                    "attempt": 2,
                    "createdAt": "2026-11-25T04:10:00Z",
                },
            ],
            main_sha=SHA_MAIN,
            contract_audit=contracts,
            max_attempts=2,
        )
        self.assertEqual(exhausted["status"], "needs_manual_escalation")
        self.assertEqual(exhausted["recommended_action"], "inspect_deploy_failure")

        unsynced = monitor.evaluate_deploy_state(
            [
                {
                    "databaseId": 9104,
                    "headSha": SHA_PREV,
                    "status": "completed",
                    "conclusion": "success",
                    "createdAt": "2026-11-25T04:15:00Z",
                },
            ],
            main_sha=SHA_MAIN,
            contract_audit=contracts,
        )
        self.assertEqual(unsynced["status"], "main_head_unsynced")
        self.assertEqual(unsynced["recommended_action"], "dispatch_main_deploy")

    def test_cli_outputs_fail_closed_and_dry_run_safety(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            runs_file = tmp / "runs.json"
            runs_file.write_text(
                json.dumps(
                    [
                        {
                            "databaseId": 9201,
                            "headSha": SHA_MAIN,
                            "status": "completed",
                            "conclusion": "cancelled",
                            "createdAt": "2026-11-25T05:00:00Z",
                        },
                    ],
                ),
                encoding="utf-8",
            )
            json_out = tmp / "report.json"
            md_out = tmp / "report.md"
            gh_out = tmp / "gh_output.txt"

            with patch.object(monitor, "_execute_recovery") as mock_recover:
                rc = monitor.main(
                    [
                        "--repo-root",
                        str(ROOT),
                        "--runs-json",
                        str(runs_file),
                        "--main-sha",
                        SHA_MAIN,
                        "--dry-run",
                        "--require-synced",
                        "--json-out",
                        str(json_out),
                        "--markdown-out",
                        str(md_out),
                        "--github-output",
                        str(gh_out),
                    ],
                )
            self.assertEqual(rc, 1)
            mock_recover.assert_not_called()

            parsed = json.loads(json_out.read_text(encoding="utf-8"))
            self.assertEqual(parsed["status"], "concurrency_cancelled")
            self.assertIn("concurrency_cancelled", md_out.read_text(encoding="utf-8"))
            gh_text = gh_out.read_text(encoding="utf-8")
            self.assertIn("status=concurrency_cancelled", gh_text)
            self.assertIn("synced=false", gh_text)
            self.assertIn("recommended_action=dispatch_main_deploy", gh_text)

    def test_rejects_invalid_inputs_and_runs_self_test(self) -> None:
        with self.assertRaises(ValueError):
            monitor._validate_inputs("invalid-repo", "deploy-prod.yml", "main")
        with self.assertRaises(ValueError):
            monitor._validate_inputs("owner/repo", "../bad.yml", "main")
        with self.assertRaises(ValueError):
            monitor.normalize_run(
                {
                    "databaseId": 1,
                    "headSha": "short",
                    "status": "completed",
                    "conclusion": "success",
                },
            )
        self.assertEqual(monitor.main(["--repo-root", str(ROOT), "--dry-run"]), 0)
        with patch.object(
            monitor,
            "_fetch_live_runs",
            return_value=[
                {
                    "databaseId": 9301,
                    "headSha": SHA_MAIN,
                    "status": "completed",
                    "conclusion": "success",
                    "createdAt": "2026-11-25T06:00:00Z",
                },
            ],
        ), patch.object(monitor, "_fetch_live_main_sha", return_value=SHA_MAIN):
            self.assertEqual(
                monitor.main(["--repo-root", str(ROOT), "--fetch-gh", "--dry-run", "--require-synced"]),
                0,
            )
        self.assertEqual(monitor.main(["--repo-root", str(ROOT), "--self-test"]), 0)


if __name__ == "__main__":
    unittest.main()
