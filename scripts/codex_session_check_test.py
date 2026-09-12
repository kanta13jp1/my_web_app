#!/usr/bin/env python3
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from codex_session_check import (
    CommandResult,
    analyze_claude_remote_control,
    collect_remote_control_flags,
    context_injection_snapshot,
    is_remote_control_flag_path,
    notebooklm_snapshot,
    remote_control_environment_audit,
    resource_budget_warnings,
)


class ClaudeRemoteControlDetectionTest(unittest.TestCase):
    def test_detects_all_session_remote_control_flag(self) -> None:
        data = {
            "claudeCode": {
                "remoteControl": {
                    "enableForAllSessions": True,
                },
            },
        }

        flags = collect_remote_control_flags(data)

        self.assertEqual(flags, [(["claudeCode", "remoteControl", "enableForAllSessions"], True)])

    def test_detects_disabled_remote_control_flag(self) -> None:
        data = {
            "remote_control": {
                "enabled_for_all_sessions": False,
            },
        }

        flags = collect_remote_control_flags(data)

        self.assertEqual(flags, [(["remote_control", "enabled_for_all_sessions"], False)])

    def test_ignores_unrelated_remote_setting(self) -> None:
        data = {
            "remote": {
                "host": "example.com",
            },
            "permissions": {
                "enabled": True,
            },
        }

        flags = collect_remote_control_flags(data)

        self.assertEqual(flags, [])

    def test_key_path_normalization_matches_expected_variants(self) -> None:
        self.assertTrue(
            is_remote_control_flag_path(
                ["settings", "remote-control", "enabled for all sessions"]
            )
        )
        self.assertTrue(
            is_remote_control_flag_path(
                ["settings", "remote_control", "always_enabled"]
            )
        )
        self.assertTrue(is_remote_control_flag_path(["remoteControlAtStartup"]))

    def test_environment_audit_redacts_blocker_values(self) -> None:
        audit = remote_control_environment_audit(
            {
                "DO_NOT_TRACK": "1",
                "CLAUDE_CODE_USE_BEDROCK": "true",
                "ANTHROPIC_BASE_URL": "https://secret-gateway.example",
            }
        )

        self.assertEqual(audit["feature_flag_blockers"], ["DO_NOT_TRACK"])
        self.assertEqual(
            audit["provider_blockers"],
            ["ANTHROPIC_BASE_URL", "CLAUDE_CODE_USE_BEDROCK"],
        )
        self.assertTrue(audit["values_redacted"])
        self.assertNotIn("secret-gateway", str(audit))

    def test_analysis_requires_owner_review_even_when_autostart_is_enabled(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "settings.json"
            path.write_text('{"remoteControlAtStartup":true}', encoding="utf-8")
            with patch(
                "codex_session_check.claude_code_version",
                return_value="2.1.248",
            ):
                snapshot = analyze_claude_remote_control(
                    Path(tmp),
                    settings_path=path,
                    environ={},
                )

        self.assertEqual(snapshot["all_sessions_status"], "enabled")
        self.assertEqual(snapshot["flag_path"], "remoteControlAtStartup")
        self.assertEqual(
            snapshot["policy_decision"],
            "owner-security-review-required",
        )
        self.assertIn("Zero Data Retention", snapshot["compliance_note"])

    def test_missing_settings_key_stays_unknown_by_absence(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "settings.json"
            path.write_text('{"permissions":{"defaultMode":"bypassPermissions"}}', encoding="utf-8")
            flags = collect_remote_control_flags({"permissions": {"defaultMode": "bypassPermissions"}})

        self.assertEqual(flags, [])

    def test_notebooklm_unavailable_is_skipped_on_github_actions(self) -> None:
        with (
            patch.dict("os.environ", {"GITHUB_ACTIONS": "true"}),
            patch(
                "codex_session_check.run_command",
                return_value=CommandResult(127, "", "notebooklm not found"),
            ),
        ):
            snapshot = notebooklm_snapshot(Path("."))

        self.assertEqual(snapshot["state"], "skipped_ci_unavailable")
        self.assertFalse(snapshot["harness_notebook_found"])

    def test_context_injection_snapshot_is_available(self) -> None:
        snapshot = context_injection_snapshot(Path(__file__).resolve().parents[1])

        self.assertEqual(snapshot["state"], "ok")
        self.assertIn("ai-tool-adoption", snapshot["matched_route_ids"])
        self.assertEqual(snapshot["notebooklm"]["harness_notebook_id"], "bc58b50b-5fc4-4840-9a62-b397d6d3b65a")


class ResourceBudgetTest(unittest.TestCase):
    def test_warns_when_ram_and_worktree_budget_are_exceeded(self) -> None:
        snapshot = {
            "memory": {"used_pct": 92.2, "free_gb": 1.23},
            "disk_free_gb": 49.0,
            "registered_worktrees": 107,
            "thresholds": {
                "ram_used_warn_pct": 85.0,
                "ram_free_warn_gb": 2.0,
                "disk_free_warn_gb": 26.0,
                "worktree_review_count": 50,
            },
        }

        warnings = resource_budget_warnings(snapshot)

        self.assertTrue(any("RAM usage 92.2%" in warning for warning in warnings))
        self.assertTrue(any("free RAM 1.23 GB" in warning for warning in warnings))
        self.assertTrue(any("worktree count 107" in warning for warning in warnings))
        self.assertFalse(any("free disk" in warning for warning in warnings))

    def test_accepts_a_healthy_resource_budget(self) -> None:
        snapshot = {
            "memory": {"used_pct": 60.0, "free_gb": 6.0},
            "disk_free_gb": 80.0,
            "registered_worktrees": 4,
            "thresholds": {
                "ram_used_warn_pct": 85.0,
                "ram_free_warn_gb": 2.0,
                "disk_free_warn_gb": 26.0,
                "worktree_review_count": 50,
            },
        }

        self.assertEqual(resource_budget_warnings(snapshot), [])


if __name__ == "__main__":
    unittest.main()
