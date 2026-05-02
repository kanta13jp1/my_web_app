#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
from unittest import TestCase, main
from unittest.mock import patch

import codex_session_check
from codex_session_check import CommandResult, NOTEBOOKLM_HARNESS_ID


class NotebookLmCliStatusTest(TestCase):
    def status_for(self, result: CommandResult) -> dict[str, object]:
        def fake_run_command(
            args: list[str],
            cwd: Path,
            timeout: int | None = None,
        ) -> CommandResult:
            self.assertEqual(args, ["notebooklm", "list"])
            self.assertEqual(cwd, Path("."))
            self.assertEqual(timeout, codex_session_check.NOTEBOOKLM_LIST_TIMEOUT_SECONDS)
            return result

        with patch.object(codex_session_check, "run_command", side_effect=fake_run_command):
            return codex_session_check.notebooklm_cli_status(Path("."))

    def test_ok_when_harness_notebook_is_visible(self) -> None:
        status = self.status_for(
            CommandResult(0, f"Codex vs Claude Code {NOTEBOOKLM_HARNESS_ID}", "")
        )

        self.assertEqual(status["status"], "ok")
        self.assertTrue(status["harness_visible"])
        self.assertEqual(status["message"], "")

    def test_warns_when_harness_notebook_is_missing(self) -> None:
        status = self.status_for(CommandResult(0, "other-notebook", ""))

        self.assertEqual(status["status"], "ok")
        self.assertFalse(status["harness_visible"])

    def test_reports_auth_expiry_without_signin_url(self) -> None:
        status = self.status_for(
            CommandResult(
                1,
                "",
                "Error: Authentication expired or invalid.\nRun 'notebooklm login' to re-authenticate.",
            )
        )

        self.assertEqual(status["status"], "auth_expired")
        self.assertIsNone(status["harness_visible"])
        self.assertIn("notebooklm login", str(status["message"]))

    def test_reports_missing_cli(self) -> None:
        status = self.status_for(CommandResult(127, "", "not found"))

        self.assertEqual(status["status"], "unavailable")
        self.assertIsNone(status["harness_visible"])


if __name__ == "__main__":
    main()
