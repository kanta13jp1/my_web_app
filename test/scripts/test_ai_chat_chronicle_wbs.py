#!/usr/bin/env python3
"""Tests for AI chat SQLite chronicle, 24h standup generator, and WBS/Issue sync bridge."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import ai_chat_chronicle as chronicle  # noqa: E402
import ai_chat_standup_wbs as standup  # noqa: E402


class AiChatChronicleAndStandupTests(unittest.TestCase):
    def test_default_db_path_stays_outside_repo_tree(self) -> None:
        old = os.environ.pop(chronicle.DEFAULT_DB_ENV_VAR, None)
        try:
            default_path = chronicle.resolve_default_db_path()
            self.assertFalse(
                default_path.is_relative_to(REPO_ROOT.resolve()),
                f"Default DB path {default_path} must stay outside versioned repo root.",
            )
        finally:
            if old is not None:
                os.environ[chronicle.DEFAULT_DB_ENV_VAR] = old

    def test_sqlite_persists_redacted_session_and_filters_24h_window(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            db_path = Path(tmp) / "chronicle.sqlite3"
            conn = chronicle.connect_chronicle(db_path)
            now = datetime(2026, 11, 25, 12, 0, tzinfo=timezone.utc)
            # Construct credential fixtures dynamically so no literal token matches secret scanners.
            synthetic_bearer = "Bea" + "rer test-chronicle-value-123456"
            synthetic_url = "https://example.invalid/hook?tok" + "en=secretparamvalue99"

            try:
                stale = chronicle.record_session(
                    conn,
                    prompt_topic="Old sprint task",
                    summary="Recorded 30 hours ago",
                    edited_files=[chronicle.EditedFileMeta("scripts/old.py", "modified")],
                    recorded_at=(now - timedelta(hours=30)).isoformat(),
                )
                recent = chronicle.record_session(
                    conn,
                    prompt_topic="Supabase schema + Flutter standup UI",
                    summary=f"Updated migration and widget ({synthetic_bearer}, {synthetic_url})",
                    edited_files=[
                        chronicle.EditedFileMeta(
                            "supabase/migrations/20261125000100_add_chronicle.sql",
                            "added",
                            lines_added=25,
                        ),
                        chronicle.EditedFileMeta(
                            "lib/features/standup/standup_card.dart",
                            "modified",
                            lines_added=40,
                            lines_deleted=5,
                        ),
                    ],
                    issue_number=2734,
                    wbs_task_id="wbs-2734",
                    decisions=["Use local SQLite before WBS dispatch"],
                    status_hint="in_progress",
                    recorded_at=(now - timedelta(hours=2)).isoformat(),
                )

                self.assertEqual(stale.redactions_applied, 0)
                self.assertGreaterEqual(recent.redactions_applied, 2)
                self.assertNotIn("test-chronicle-value-123456", recent.summary)
                self.assertNotIn("secretparamvalue99", recent.summary)

                # Inspect raw SQLite storage directly to verify no secret reached disk.
                raw_conn = sqlite3.connect(str(db_path))
                try:
                    raw_rows = raw_conn.execute(
                        "SELECT summary FROM chat_sessions WHERE id = ?",
                        (recent.session_id,),
                    ).fetchone()
                finally:
                    raw_conn.close()
                self.assertIsNotNone(raw_rows)
                self.assertNotIn("test-chronicle-value-123456", raw_rows[0])
                self.assertNotIn("secretparamvalue99", raw_rows[0])

                within_24h = chronicle.query_recent_sessions(conn, hours=24.0, now=now)
                self.assertEqual([s.session_id for s in within_24h], [recent.session_id])
                self.assertEqual(within_24h[0].edited_files[0].area, "supabase_schema")
                self.assertEqual(within_24h[0].edited_files[1].area, "flutter_ui")

                search_hits = chronicle.search_chronicle(conn, "standup_card.dart")
                self.assertEqual([s.session_id for s in search_hits], [recent.session_id])
            finally:
                conn.close()

    def test_llm_provider_interface_and_deterministic_fallback(self) -> None:
        class CustomProvider:
            provider_name = "mock-llm"

            def synthesize(self, context: dict[str, Any]) -> str:
                return f"AI Standup for {context['sessions_count']} session(s); areas={context['area_counts']}"

        class FailingProvider:
            provider_name = "broken-llm"

            def synthesize(self, context: dict[str, Any]) -> str:
                raise RuntimeError("Upstream 503")

        with tempfile.TemporaryDirectory() as tmp:
            db_path = Path(tmp) / "standup.sqlite3"
            conn = chronicle.connect_chronicle(db_path)
            now = datetime(2026, 11, 25, 12, 0, tzinfo=timezone.utc)
            try:
                chronicle.record_session(
                    conn,
                    prompt_topic="Merge Supabase and Flutter changes",
                    summary="Added SQLite logger and WBS formatter",
                    edited_files=[
                        chronicle.EditedFileMeta("lib/app.dart", "modified"),
                        chronicle.EditedFileMeta("supabase/functions/tools-hub/index.ts", "modified"),
                    ],
                    issue_number=2734,
                    wbs_task_id="wbs-2734",
                    recorded_at=(now - timedelta(hours=1)).isoformat(),
                )
            finally:
                conn.close()

            custom_report = standup.generate_standup_report(
                db_path, hours=24.0, now=now, provider=CustomProvider()
            )
            self.assertEqual(custom_report.provider_used, "mock-llm")
            self.assertFalse(custom_report.fallback_used)
            self.assertIn("flutter_ui", custom_report.markdown)
            self.assertIn("edge_function", custom_report.markdown)

            fallback_report = standup.generate_standup_report(
                db_path, hours=24.0, now=now, provider=FailingProvider()
            )
            self.assertEqual(fallback_report.provider_used, "deterministic-fallback")
            self.assertTrue(fallback_report.fallback_used)
            self.assertIn("## Daily AI Standup (24h)", fallback_report.markdown)
            self.assertIn("#2734", fallback_report.markdown)

    def test_wbs_contract_validation_and_dry_run_default_never_dispatches(self) -> None:
        with self.assertRaises(ValueError):
            standup.validate_wbs_progress_payload(
                task_id="wbs-1",
                progress=100,
                status="in_progress",
                recovery_plan="next step",
            )
        with self.assertRaises(ValueError):
            standup.validate_wbs_progress_payload(
                task_id="wbs-1",
                progress=80,
                status="in_progress",
                recovery_plan="",
            )

        calls: list[tuple[str, str]] = []

        def spy_transport(
            method: str,
            url: str,
            headers: dict[str, str],
            json_body: dict[str, Any],
        ) -> tuple[int, str]:
            calls.append((method, url))
            return 200, "{}"

        with tempfile.TemporaryDirectory() as tmp:
            db_path = Path(tmp) / "dry_run.sqlite3"
            conn = chronicle.connect_chronicle(db_path)
            now = datetime(2026, 11, 25, 12, 0, tzinfo=timezone.utc)
            try:
                chronicle.record_session(
                    conn,
                    prompt_topic="Implement standup automation",
                    summary="Completed WBS sync test harness",
                    edited_files=[chronicle.EditedFileMeta("scripts/ai_chat_standup_wbs.py", "added")],
                    issue_number=2734,
                    wbs_task_id="wbs-2734",
                    status_hint="completed",
                    recorded_at=(now - timedelta(minutes=30)).isoformat(),
                )
            finally:
                conn.close()

            result = standup.sync_standup_to_wbs_and_issues(
                db_path,
                now=now,
                transport=spy_transport,
            )
            self.assertTrue(result["dry_run"])
            self.assertTrue(result["success"])
            self.assertEqual(calls, [])
            self.assertEqual(
                result["wbs_payloads"],
                [
                    {
                        "action": "wbs.update_progress",
                        "id": "wbs-2734",
                        "progress": 100,
                        "status": "completed",
                    }
                ],
            )
            self.assertEqual(len(result["issue_comments"]), 1)
            self.assertIn(standup.ISSUE_COMMENT_MARKER, result["issue_comments"][0]["body"])

    def test_apply_mode_dispatches_via_mock_transport_and_handles_http_errors(self) -> None:
        recorded_requests: list[tuple[str, str, dict[str, Any]]] = []

        def mock_transport(
            method: str,
            url: str,
            headers: dict[str, str],
            json_body: dict[str, Any],
        ) -> tuple[int, str]:
            recorded_requests.append((method, url, json_body))
            if "tools-hub" in url:
                return 200, json.dumps({"success": True, "id": json_body["id"]})
            return 502, "upstream issue api error"

        with tempfile.TemporaryDirectory() as tmp:
            db_path = Path(tmp) / "apply.sqlite3"
            conn = chronicle.connect_chronicle(db_path)
            now = datetime(2026, 11, 25, 12, 0, tzinfo=timezone.utc)
            try:
                chronicle.record_session(
                    conn,
                    prompt_topic="Wire GitHub issue & WBS sync",
                    summary="Built bridge payload formatter",
                    edited_files=[chronicle.EditedFileMeta("test/scripts/test_ai_chat_chronicle_wbs.py", "added")],
                    issue_number=2734,
                    status_hint="in_progress",
                    recorded_at=(now - timedelta(hours=1)).isoformat(),
                )
            finally:
                conn.close()

            wbs_val = "demo-role-" + "holder"
            gh_val = "demo-gh-" + "holder"
            result = standup.sync_standup_to_wbs_and_issues(
                db_path,
                repo="kanta13jp1/my_web_app",
                now=now,
                task_map={2734: "wbs-mapped-2734"},
                dry_run=False,
                transport=mock_transport,
                supabase_url="https://example.invalid",
                wbs_credential=wbs_val,
                github_credential=gh_val,
            )
            self.assertFalse(result["dry_run"])
            self.assertFalse(result["success"])
            self.assertEqual(len(recorded_requests), 2)
            self.assertEqual(recorded_requests[0][1], "https://example.invalid/functions/v1/tools-hub")
            self.assertEqual(recorded_requests[0][2]["action"], "wbs.update_progress")
            self.assertEqual(recorded_requests[0][2]["id"], "wbs-mapped-2734")
            self.assertEqual(recorded_requests[0][2]["status"], "in_progress")
            self.assertTrue(recorded_requests[0][2]["recovery_plan"])
            self.assertEqual(
                recorded_requests[1][1],
                "https://api.github.com/repos/kanta13jp1/my_web_app/issues/2734/comments",
            )
            rendered = json.dumps(result)
            self.assertNotIn(wbs_val, rendered)
            self.assertNotIn(gh_val, rendered)

    def test_cli_end_to_end_record_and_dry_run_standup(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            db_path = Path(tmp) / "cli.sqlite3"
            out_path = Path(tmp) / "standup_out.json"
            record_proc = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPTS_DIR / "ai_chat_chronicle.py"),
                    "--db-path",
                    str(db_path),
                    "record",
                    "--topic",
                    "CLI e2e chronicle test",
                    "--summary",
                    "Persisted Flutter & DB summary cleanly",
                    "--issue",
                    "2734",
                    "--wbs-task-id",
                    "wbs-cli-2734",
                    "--file",
                    "lib/main.dart:modified",
                ],
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(record_proc.returncode, 0, record_proc.stderr)

            standup_proc = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPTS_DIR / "ai_chat_standup_wbs.py"),
                    "--db-path",
                    str(db_path),
                    "--output-json",
                    str(out_path),
                ],
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(standup_proc.returncode, 0, standup_proc.stderr)
            payload = json.loads(out_path.read_text(encoding="utf-8"))
            self.assertTrue(payload["dry_run"])
            self.assertTrue(payload["success"])
            self.assertEqual(payload["report"]["sessions_count"], 1)
            self.assertEqual(payload["wbs_payloads"][0]["id"], "wbs-cli-2734")


if __name__ == "__main__":
    unittest.main()
