#!/usr/bin/env python3
from __future__ import annotations

import sys
import unittest
from pathlib import Path

from cloud_ci_handoff import (
    CLOUD_DEVELOPMENT_WORKFLOW,
    HandoffState,
    dispatch_command,
    parse_args,
    readiness_reasons,
    run_command,
    select_new_exact_run,
)


HEAD = "a" * 40


class CloudCiHandoffTest(unittest.TestCase):
    def test_runner_decodes_utf8_cli_output_on_windows(self) -> None:
        result = run_command(
            [
                sys.executable,
                "-c",
                "import sys; sys.stdout.buffer.write('クラウド✓'.encode('utf-8'))",
            ],
            Path.cwd(),
        )

        self.assertEqual(result.code, 0)
        self.assertEqual(result.stdout, "クラウド✓")

    def test_exact_pushed_feature_branch_is_ready(self) -> None:
        self.assertEqual(
            readiness_reasons(
                branch="codex/cloud-first",
                head_sha=HEAD,
                remote_sha=HEAD,
                clean=True,
                gh_available=True,
            ),
            (),
        )

    def test_dirty_or_unpushed_state_is_blocked(self) -> None:
        reasons = readiness_reasons(
            branch="codex/cloud-first",
            head_sha=HEAD,
            remote_sha="b" * 40,
            clean=False,
            gh_available=True,
        )

        self.assertTrue(any("dirty" in reason for reason in reasons))
        self.assertTrue(any("does not match" in reason for reason in reasons))

    def test_dispatch_carries_the_exact_expected_sha(self) -> None:
        state = HandoffState(
            root="C:/repo",
            branch="codex/cloud-first",
            head_sha=HEAD,
            remote_sha=HEAD,
            clean=True,
            workflow=CLOUD_DEVELOPMENT_WORKFLOW,
            ready=True,
            reasons=(),
            profile="test",
        )

        self.assertEqual(
            dispatch_command(state),
            [
                "gh",
                "workflow",
                "run",
                CLOUD_DEVELOPMENT_WORKFLOW,
                "--ref",
                "codex/cloud-first",
                "-f",
                f"expected_head_sha={HEAD}",
                "-f",
                "profile=test",
            ],
        )

    def test_default_handoff_uses_cloud_development_full_profile(self) -> None:
        args = parse_args([])

        self.assertEqual(args.workflow, CLOUD_DEVELOPMENT_WORKFLOW)
        self.assertEqual(args.profile, "full")

    def test_workspace_profile_is_available_without_flutter(self) -> None:
        args = parse_args(["--profile", "workspace"])

        self.assertEqual(args.profile, "workspace")

    def test_legacy_ci_handoff_does_not_send_profile(self) -> None:
        state = HandoffState(
            root="C:/repo",
            branch="codex/cloud-first",
            head_sha=HEAD,
            remote_sha=HEAD,
            clean=True,
            workflow="ci.yml",
            ready=True,
            reasons=(),
        )

        self.assertNotIn("profile=full", dispatch_command(state))

    def test_run_lookup_ignores_old_or_different_sha_runs(self) -> None:
        runs = [
            {"databaseId": 10, "headSha": HEAD},
            {"databaseId": 11, "headSha": "b" * 40},
            {"databaseId": 12, "headSha": HEAD, "url": "https://example.test/run/12"},
        ]

        selected = select_new_exact_run(
            runs,
            head_sha=HEAD,
            previous_ids={10},
        )

        self.assertIsNotNone(selected)
        self.assertEqual(selected["databaseId"], 12)

    def test_workflow_pins_manual_gate_to_event_and_expected_sha(self) -> None:
        workflow = (
            Path(__file__).resolve().parents[1]
            / ".github"
            / "workflows"
            / CLOUD_DEVELOPMENT_WORKFLOW
        ).read_text(encoding="utf-8")

        self.assertIn("expected_head_sha:", workflow)
        self.assertIn("actual_head_sha=\"$(git rev-parse HEAD)\"", workflow)


if __name__ == "__main__":
    unittest.main()
