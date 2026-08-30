#!/usr/bin/env python3
from __future__ import annotations

import unittest
from unittest import mock

import container_cleanup_guard as cleanup


class FakeRunner:
    def __init__(self) -> None:
        self.commands: list[list[str]] = []

    def __call__(self, command: list[str], timeout: int) -> cleanup.CommandResult:
        del timeout
        self.commands.append(command)
        if command[:2] == ["docker", "info"]:
            return cleanup.CommandResult(0, '"28.0.0"', "")
        if command[:3] == ["docker", "system", "df"]:
            return cleanup.CommandResult(0, "TYPE TOTAL ACTIVE SIZE RECLAIMABLE", "")
        if command[:3] == ["docker", "volume", "ls"]:
            return cleanup.CommandResult(
                0,
                '\n'.join(
                    [
                        '{"Driver":"local","Labels":"com.supabase.cli.project=my_web_app","Name":"supabase_db_my_web_app"}',
                        '{"Driver":"local","Labels":"","Name":"throwaway-cache"}',
                    ]
                ),
                "",
            )
        if command[:3] == ["docker", "system", "prune"]:
            return cleanup.CommandResult(0, "Total reclaimed space: 1GB", "")
        return cleanup.CommandResult(0, "", "")


class ContainerCleanupGuardTest(unittest.TestCase):
    def execute(self, argv: list[str]) -> tuple[int, dict[str, object], FakeRunner]:
        runner = FakeRunner()
        with mock.patch.object(cleanup.shutil, "which", return_value="docker.exe"):
            code, report = cleanup.execute(argv, runner)
        return code, report, runner

    def test_dry_run_never_prunes(self) -> None:
        code, report, runner = self.execute([])

        self.assertEqual(code, 0)
        self.assertEqual(report["mode"], "dry-run")
        self.assertFalse(
            any(
                command[:3] == ["docker", "system", "prune"]
                for command in runner.commands
            )
        )

    def test_supabase_volume_is_protected_and_no_volume_is_deleted(self) -> None:
        _, report, _ = self.execute([])

        self.assertEqual(report["protected_volumes"], ["supabase_db_my_web_app"])
        self.assertFalse(report["volumes_deleted"])
        self.assertFalse(report["supabase_no_backup_used"])

    def test_apply_requires_exact_confirmation(self) -> None:
        code, report, runner = self.execute(["--apply", "--confirm", "yes"])

        self.assertEqual(code, 2)
        self.assertEqual(report["status"], "refused")
        self.assertFalse(
            any(
                command[:3] == ["docker", "system", "prune"]
                for command in runner.commands
            )
        )

    def test_apply_prunes_old_resources_without_volumes(self) -> None:
        code, report, runner = self.execute(
            [
                "--apply",
                "--confirm",
                cleanup.CONFIRMATION_PHRASE,
                "--older-than-hours",
                "336",
            ]
        )

        self.assertEqual(code, 0)
        self.assertEqual(report["status"], "success")
        prune = next(
            command
            for command in runner.commands
            if command[:3] == ["docker", "system", "prune"]
        )
        self.assertEqual(prune[-1], "until=336h")
        self.assertNotIn("--volumes", prune)
        self.assertNotIn("volume", prune)
        self.assertNotIn("--no-backup", prune)

    def test_refuses_age_below_one_day(self) -> None:
        code, report, runner = self.execute(["--older-than-hours", "23"])

        self.assertEqual(code, 2)
        self.assertEqual(report["status"], "refused")
        self.assertEqual(runner.commands, [])


if __name__ == "__main__":
    unittest.main()
