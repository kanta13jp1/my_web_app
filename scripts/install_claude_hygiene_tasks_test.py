#!/usr/bin/env python3
"""Static tests for install_claude_hygiene_tasks.ps1.

The installer mutates Windows Task Scheduler state, so CI keeps these tests
static and dependency-free. Local operators can still run -Status/-Verify
manually on Windows before using -Install.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "install_claude_hygiene_tasks.ps1"


class InstallClaudeHygieneTasksTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.text = SCRIPT.read_text(encoding="utf-8")

    def test_declares_exact_five_task_names(self) -> None:
        names = re.findall(r'BaseName\s*=\s*"([^"]+)"', self.text)
        self.assertEqual(
            names,
            [
                "claude_session_start",
                "claude_session_mid",
                "claude_session_end",
                "claude_disk_compress",
                "claude_ram_gc",
            ],
        )

    def test_uses_expected_trigger_shapes(self) -> None:
        expected_snippets = [
            "New-ScheduledTaskTrigger -AtLogOn",
            "RepetitionInterval (New-TimeSpan -Minutes 30)",
            "RunOnlyIfIdle",
            "IdleDuration",
            "New-TimeSpan -Minutes 60",
            "New-ScheduledTaskTrigger -Weekly",
            "RepetitionInterval (New-TimeSpan -Minutes 15)",
        ]
        for snippet in expected_snippets:
            with self.subTest(snippet=snippet):
                self.assertIn(snippet, self.text)

    def test_registers_as_domain_user_and_verifies_after_write(self) -> None:
        self.assertIn('$env:USERDOMAIN\\$env:USERNAME', self.text)
        self.assertIn("New-ScheduledTaskPrincipal -UserId $userId", self.text)
        self.assertIn("Register-ScheduledTask", self.text)
        self.assertIn("-ErrorAction Stop", self.text)
        self.assertIn("Register-ScheduledTask returned but task was not found", self.text)

    def test_default_mode_is_status_not_install(self) -> None:
        self.assertRegex(self.text, r"if \(\$actions\.Count -eq 0\)\s*\{\s*\$Status = \$true")
        no_action_region = self.text.split("if ($Install) {", 1)[0]
        self.assertNotIn("Register-ScheduledTask `", no_action_region)

    def test_actions_call_existing_hygiene_primitives(self) -> None:
        self.assertIn("scripts\\session_hygiene_check.py", self.text)
        self.assertIn("scripts\\memory_trim_phase2.ps1", self.text)
        self.assertIn("--apply", self.text)
        self.assertIn("--force", self.text)
        self.assertIn("EncodedCommand", self.text)


if __name__ == "__main__":
    unittest.main(verbosity=2)
