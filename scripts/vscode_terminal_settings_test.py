#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
SETTINGS_PATH = ROOT / ".vscode" / "settings.json"
GUIDE_PATH = ROOT / "docs" / "VSCODE_TERMINAL_TROUBLESHOOTING.md"
IT_POLICY_PATH = ROOT / "docs" / "IT_SECURITY_POLICY_V1.md"


class VsCodeTerminalSettingsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.settings = json.loads(SETTINGS_PATH.read_text(encoding="utf-8"))
        cls.guide = GUIDE_PATH.read_text(encoding="utf-8")
        cls.it_policy = IT_POLICY_PATH.read_text(encoding="utf-8")

    def test_split_terminals_always_start_at_workspace_root(self) -> None:
        self.assertEqual(
            self.settings["terminal.integrated.cwd"], "${workspaceFolder}"
        )
        self.assertEqual(
            self.settings["terminal.integrated.splitCwd"], "workspaceRoot"
        )

    def test_application_scoped_inherit_env_is_not_misconfigured(self) -> None:
        self.assertNotIn("terminal.integrated.inheritEnv", self.settings)
        self.assertIn("application-scoped user setting", self.guide)
        self.assertIn("default of", self.guide)
        self.assertIn("`true`", self.guide)
        self.assertIn("no effect on\nWindows", self.guide)

    def test_workspace_environment_contract_is_preserved(self) -> None:
        for platform in ("windows", "osx", "linux"):
            env = self.settings[f"terminal.integrated.env.{platform}"]
            self.assertEqual(env["PYTHONUTF8"], "1")
            self.assertEqual(env["PYTHONIOENCODING"], "utf-8")

    def test_parallel_flutter_supabase_layout_is_documented(self) -> None:
        for marker in (
            "Recommended Flutter + Supabase layout",
            "supabase start",
            "supabase functions serve",
            "flutter run -d chrome",
            "Get-Command flutter",
            "Get-Command supabase",
        ):
            self.assertIn(marker, self.guide)

    def test_endpoint_exception_workflow_is_narrow_and_auditable(self) -> None:
        for marker in (
            "Endpoint Security and Least-Privilege Policy",
            "standard user",
            "Protection history",
            "Get-AuthenticodeSignature",
            "Get-FileHash -Algorithm SHA256",
            "winpty.dll",
            "winpty-agent.exe",
            "conpty.node",
            "conpty_console_list.node",
            "time-bound exception",
            "pilot device",
            "expiry time",
            "rollback owner",
            "Never allow",
            "process exclusion",
        ):
            self.assertIn(marker, self.guide)

        self.assertNotIn("Add-MpPreference", self.guide)
        self.assertNotIn("Set-MpPreference -DisableRealtimeMonitoring", self.guide)

    def test_it_policy_requires_standard_user_and_default_deny_exclusions(self) -> None:
        for marker in (
            "| 3-6 |",
            "| 3-7 |",
            "標準ユーザーで実行",
            "default deny",
            "endpoint-security owner",
            "期限切れ除外を撤回",
            "VSCODE_TERMINAL_TROUBLESHOOTING.md",
        ):
            self.assertIn(marker, self.it_policy)


if __name__ == "__main__":
    from vscode_formatter_settings_test import FormatterSettingsTest

    unittest.main()
