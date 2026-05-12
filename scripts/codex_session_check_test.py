#!/usr/bin/env python3
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from codex_session_check import (
    CommandResult,
    collect_remote_control_flags,
    context_injection_snapshot,
    is_remote_control_flag_path,
    notebooklm_snapshot,
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


if __name__ == "__main__":
    unittest.main()
