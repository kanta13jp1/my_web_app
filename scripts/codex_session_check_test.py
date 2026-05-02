#!/usr/bin/env python3
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from codex_session_check import (
    collect_remote_control_flags,
    is_remote_control_flag_path,
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


if __name__ == "__main__":
    unittest.main()
