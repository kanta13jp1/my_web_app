#!/usr/bin/env python3
"""Regression tests for dynamic Supabase migration repair."""

from __future__ import annotations

import tempfile
import unittest
from argparse import Namespace
from pathlib import Path
from unittest.mock import patch

import ci_failure_digest


ROOT = Path(__file__).resolve().parents[1]


def args_for(root: Path) -> Namespace:
    migrations = root / "migrations"
    migrations.mkdir()
    (migrations / "20260828010101_example.sql").write_text("select 1;\n", encoding="utf-8")
    (migrations / "20260828020202_other.sql").write_text("select 2;\n", encoding="utf-8")
    (migrations / "20260828030303_latest.sql").write_text("select 3;\n", encoding="utf-8")
    return Namespace(
        log_dir=str(root / "logs"),
        migrations_dir=str(migrations),
        recent_limit=10,
        summary=None,
        include_all=True,
        max_digest_lines=20,
    )


class SupabaseMigrationRepairTest(unittest.TestCase):
    def test_duplicate_history_repairs_only_the_reported_version(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            calls: list[list[str]] = []
            push_count = 0

            def invoke(command: list[str], log_path: Path) -> int:
                nonlocal push_count
                calls.append(command)
                if command[:3] == ["supabase", "db", "push"]:
                    push_count += 1
                    if push_count == 1:
                        with log_path.open("a", encoding="utf-8") as log:
                            log.write(
                                "duplicate key value violates unique constraint "
                                'schema_migrations_pkey\n'
                                "Key (version)=(20260828010101) already exists.\n"
                            )
                        return 1
                return 0

            with patch.object(ci_failure_digest, "run_command", side_effect=invoke):
                result = ci_failure_digest.supabase_db_push(args_for(Path(temp)))

        self.assertEqual(result, 0)
        self.assertEqual(
            calls,
            [
                ["supabase", "migration", "list"],
                ["supabase", "db", "push", "--include-all"],
                [
                    "supabase",
                    "migration",
                    "repair",
                    "--status",
                    "applied",
                    "20260828010101",
                ],
                ["supabase", "db", "push", "--include-all"],
            ],
        )

    def test_remote_only_history_repairs_the_reported_version_as_reverted(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            calls: list[list[str]] = []
            push_count = 0

            def invoke(command: list[str], log_path: Path) -> int:
                nonlocal push_count
                calls.append(command)
                if command[:3] == ["supabase", "db", "push"]:
                    push_count += 1
                    if push_count == 1:
                        with log_path.open("a", encoding="utf-8") as log:
                            log.write(
                                "Remote migration versions not found in local "
                                "migrations directory.\n"
                                "20260828040404 | remote only\n"
                            )
                        return 1
                return 0

            with patch.object(ci_failure_digest, "run_command", side_effect=invoke):
                result = ci_failure_digest.supabase_db_push(args_for(Path(temp)))

        self.assertEqual(result, 0)
        self.assertEqual(
            calls,
            [
                ["supabase", "migration", "list"],
                ["supabase", "db", "push", "--include-all"],
                [
                    "supabase",
                    "migration",
                    "repair",
                    "--status",
                    "reverted",
                    "20260828040404",
                ],
                ["supabase", "db", "push", "--include-all"],
            ],
        )

    def test_unknown_failure_does_not_mutate_history_or_retry(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            calls: list[list[str]] = []

            def invoke(command: list[str], log_path: Path) -> int:
                calls.append(command)
                if command[:3] == ["supabase", "db", "push"]:
                    with log_path.open("a", encoding="utf-8") as log:
                        log.write("dial tcp: connection timed out\n")
                    return 1
                return 0

            with patch.object(ci_failure_digest, "run_command", side_effect=invoke):
                result = ci_failure_digest.supabase_db_push(args_for(Path(temp)))

        self.assertEqual(result, 1)
        self.assertEqual(
            calls,
            [
                ["supabase", "migration", "list"],
                ["supabase", "db", "push", "--include-all"],
            ],
        )

    def test_explicit_repair_recommendation_ignores_unrelated_versions(self) -> None:
        status, versions = ci_failure_digest.classify_migration_failure(
            "Applying migration 20260828030303_latest.sql...\n"
            "supabase migration repair 20260828010101 --status reverted\n"
        )

        self.assertEqual(status, "reverted")
        self.assertEqual(versions, ["20260828010101"])

    def test_regular_sql_duplicate_does_not_repair_migration_history(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            calls: list[list[str]] = []

            def invoke(command: list[str], log_path: Path) -> int:
                calls.append(command)
                if command[:3] == ["supabase", "db", "push"]:
                    with log_path.open("a", encoding="utf-8") as log:
                        log.write(
                            'duplicate key violates unique constraint "users_email_key"\n'
                            "Key (email)=(owner@example.com) already exists.\n"
                        )
                    return 1
                return 0

            with patch.object(ci_failure_digest, "run_command", side_effect=invoke):
                result = ci_failure_digest.supabase_db_push(args_for(Path(temp)))

        self.assertEqual(result, 1)
        self.assertEqual(
            calls,
            [
                ["supabase", "migration", "list"],
                ["supabase", "db", "push", "--include-all"],
            ],
        )

    def test_regular_version_duplicate_does_not_repair_migration_history(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            calls: list[list[str]] = []

            def invoke(command: list[str], log_path: Path) -> int:
                calls.append(command)
                if command[:3] == ["supabase", "db", "push"]:
                    with log_path.open("a", encoding="utf-8") as log:
                        log.write(
                            'duplicate key violates "release_versions_pkey"\n'
                            "Key (version)=(20260828010101) already exists.\n"
                        )
                    return 1
                return 0

            with patch.object(ci_failure_digest, "run_command", side_effect=invoke):
                result = ci_failure_digest.supabase_db_push(args_for(Path(temp)))

        self.assertEqual(result, 1)
        self.assertEqual(len(calls), 2)

    def test_reverted_repair_rejects_a_version_that_exists_locally(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            calls: list[list[str]] = []

            def invoke(command: list[str], log_path: Path) -> int:
                calls.append(command)
                if command[:3] == ["supabase", "db", "push"]:
                    with log_path.open("a", encoding="utf-8") as log:
                        log.write(
                            "Remote migration versions not found in local migrations "
                            "directory.\n20260828020202 | reported inconsistently\n"
                        )
                    return 1
                return 0

            with patch.object(ci_failure_digest, "run_command", side_effect=invoke):
                result = ci_failure_digest.supabase_db_push(args_for(Path(temp)))

        self.assertEqual(result, 1)
        self.assertEqual(len(calls), 2)

    def test_applied_repair_rejects_a_version_missing_locally(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            calls: list[list[str]] = []

            def invoke(command: list[str], log_path: Path) -> int:
                calls.append(command)
                if command[:3] == ["supabase", "db", "push"]:
                    with log_path.open("a", encoding="utf-8") as log:
                        log.write(
                            'duplicate key violates "schema_migrations_pkey"\n'
                            "Key (version)=(20260828040404) already exists.\n"
                        )
                    return 1
                return 0

            with patch.object(ci_failure_digest, "run_command", side_effect=invoke):
                result = ci_failure_digest.supabase_db_push(args_for(Path(temp)))

        self.assertEqual(result, 1)
        self.assertEqual(len(calls), 2)

    def test_remote_table_stops_before_later_version_lines(self) -> None:
        status, versions = ci_failure_digest.classify_migration_failure(
            "Remote migration versions not found in local migrations directory.\n"
            "20260828040404 | remote only\n"
            "\n"
            "unrelated diagnostic\n"
            "20260828050505 | must not be repaired\n"
        )

        self.assertEqual(status, "reverted")
        self.assertEqual(versions, ["20260828040404"])

    def test_reused_log_directory_ignores_an_old_repair_recommendation(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            log_dir = root / "logs"
            log_dir.mkdir()
            (log_dir / "supabase-db-push.log").write_text(
                "supabase migration repair 20260828010101 --status applied\n",
                encoding="utf-8",
            )
            calls: list[list[str]] = []

            def invoke(command: list[str], log_path: Path) -> int:
                calls.append(command)
                if command[:3] == ["supabase", "db", "push"]:
                    with log_path.open("a", encoding="utf-8") as log:
                        log.write("dial tcp: connection timed out\n")
                    return 1
                return 0

            with patch.object(ci_failure_digest, "run_command", side_effect=invoke):
                result = ci_failure_digest.supabase_db_push(args_for(root))

        self.assertEqual(result, 1)
        self.assertEqual(
            calls,
            [
                ["supabase", "migration", "list"],
                ["supabase", "db", "push", "--include-all"],
            ],
        )

    def test_failed_repair_stops_before_second_push(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            calls: list[list[str]] = []

            def invoke(command: list[str], log_path: Path) -> int:
                calls.append(command)
                if command[:3] == ["supabase", "db", "push"]:
                    with log_path.open("a", encoding="utf-8") as log:
                        log.write(
                            'duplicate key violates "schema_migrations_pkey"\n'
                            "Key (version)=(20260828010101) already exists.\n"
                        )
                    return 1
                if command[:3] == ["supabase", "migration", "repair"]:
                    return 2
                return 0

            with patch.object(ci_failure_digest, "run_command", side_effect=invoke):
                result = ci_failure_digest.supabase_db_push(args_for(Path(temp)))

        self.assertEqual(result, 2)
        self.assertEqual(
            calls,
            [
                ["supabase", "migration", "list"],
                ["supabase", "db", "push", "--include-all"],
                [
                    "supabase",
                    "migration",
                    "repair",
                    "--status",
                    "applied",
                    "20260828010101",
                ],
            ],
        )

    def test_deploy_workflow_has_no_speculative_repair_list(self) -> None:
        workflow = (ROOT / ".github/workflows/deploy-prod.yml").read_text(
            encoding="utf-8"
        )

        self.assertNotIn("supabase migration repair --status", workflow)
        self.assertIn(
            "python scripts/ci_failure_digest.py supabase-db-push",
            workflow,
        )


if __name__ == "__main__":
    unittest.main()
