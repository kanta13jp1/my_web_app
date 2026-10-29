#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

from cloud_ci_handoff import (
    CLOUD_DEVELOPMENT_WORKFLOW,
    CommandResult,
    HandoffState,
    dispatch_and_locate,
    inspect_remote_handoff,
    dispatch_command,
    parse_args,
    readiness_reasons,
    run_command,
    select_new_exact_run,
)


HEAD = "a" * 40


class RemoteRunner:
    """No subprocess/network; each call is recorded and answered from fixtures."""

    def __init__(self):
        self.calls = []
        self.remote_sha = HEAD
        self.default_branch = "main"
        self.permissions = {"push": True}
        self.workflow_state = "active"
        self.auth_ok = True
        self.ref_exists = True
        self.dispatched = 0
        self.dispatch_code = 0
        self.before = [{"databaseId": 10, "headSha": HEAD}]
        self.after = [
            *self.before,
            {"databaseId": 11, "headSha": "b" * 40},
            {"databaseId": 12, "headSha": HEAD},
        ]

    def __call__(self, args, cwd):
        args = list(args)
        self.calls.append(args)
        if args[:3] == ["gh", "workflow", "run"]:
            self.dispatched += 1
            return CommandResult(self.dispatch_code, "", "synthetic failure" if self.dispatch_code else "")
        if args[:3] == ["gh", "run", "list"]:
            return CommandResult(0, json.dumps(self.after if self.dispatched else self.before), "")
        if args[:4] != ["gh", "api", "--hostname", "github.com"]:
            raise AssertionError(f"Unexpected command, including any local git: {args}")
        endpoint = args[4]
        if endpoint == "user":
            return CommandResult(0, "1", "") if self.auth_ok else CommandResult(1, "", "Bad credentials")
        if endpoint == "repos/example/project":
            payload = {
                "full_name": "example/project", "default_branch": self.default_branch,
                "permissions": self.permissions,
            }
        elif endpoint == "repos/example/project/git/ref/heads/codex%2Fformat":
            if not self.ref_exists:
                return CommandResult(1, "", "Not Found")
            payload = {"ref": "refs/heads/codex/format",
                       "object": {"type": "commit", "sha": self.remote_sha}}
        elif endpoint == f"repos/example/project/actions/workflows/{CLOUD_DEVELOPMENT_WORKFLOW}":
            payload = {"state": self.workflow_state,
                       "path": f".github/workflows/{CLOUD_DEVELOPMENT_WORKFLOW}"}
        else:
            raise AssertionError(f"Unexpected API endpoint: {endpoint}")
        return CommandResult(0, json.dumps(payload), "")


def remote_state(runner, **overrides):
    values = {
        "root": Path.cwd(), "repository": "example/project",
        "branch": "codex/format", "head_sha": HEAD,
        "workflow": CLOUD_DEVELOPMENT_WORKFLOW, "profile": "format",
        "runner": runner,
    }
    values.update(overrides)
    return inspect_remote_handoff(**values)


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

    def test_remote_preflight_uses_no_local_git_or_cleanliness_claim(self):
        runner = RemoteRunner()
        state = remote_state(runner)
        self.assertTrue(state.ready)
        self.assertIsNone(state.clean)
        self.assertEqual(state.source, "remote")
        self.assertEqual(state.repository, "example/project")
        self.assertTrue(all(command[:2] == ["gh", "api"] for command in runner.calls))
        self.assertEqual(runner.dispatched, 0)

    def test_remote_input_validation_stops_before_any_api(self):
        cases = [
            {"branch": "main"}, {"branch": "HEAD"}, {"branch": "../escape"},
            {"branch": "codex/a..b"}, {"branch": "codex/a.lock"},
            {"repository": "https://github.com/example/project"},
            {"repository": "example/.."}, {"head_sha": "short"},
            {"profile": "full"}, {"workflow": "ci.yml"},
        ]
        for case in cases:
            with self.subTest(case=case):
                runner = RemoteRunner()
                self.assertFalse(remote_state(runner, **case).ready)
                self.assertEqual(runner.calls, [])

    def test_remote_auth_missing_branch_and_remote_policy_fail_closed(self):
        for field, value in [("auth_ok", False), ("ref_exists", False)]:
            with self.subTest(field=field):
                runner = RemoteRunner()
                setattr(runner, field, value)
                with self.assertRaises(RuntimeError):
                    remote_state(runner)
                self.assertEqual(runner.dispatched, 0)
        for field, value in [
            ("default_branch", "codex/format"), ("permissions", {"push": False}),
            ("remote_sha", "b" * 40), ("workflow_state", "disabled_manually"),
        ]:
            with self.subTest(field=field):
                runner = RemoteRunner()
                setattr(runner, field, value)
                self.assertFalse(remote_state(runner).ready)
                self.assertEqual(runner.dispatched, 0)

    def test_remote_dispatch_is_repo_scoped_and_finds_only_a_new_exact_run(self):
        runner = RemoteRunner()
        state = remote_state(runner)
        run = dispatch_and_locate(
            state, timeout_seconds=1, poll_seconds=0, runner=runner,
            sleeper=lambda _: None,
        )
        self.assertEqual(run["databaseId"], 12)
        self.assertEqual(runner.dispatched, 1)
        for command in runner.calls:
            if command[:3] in (["gh", "run", "list"], ["gh", "workflow", "run"]):
                self.assertEqual(command[-2:], ["--repo", "github.com/example/project"])
        command = next(c for c in runner.calls if c[:3] == ["gh", "workflow", "run"])
        self.assertIn(f"expected_head_sha={HEAD}", command)
        self.assertIn("profile=format", command)
        self.assertEqual(command[command.index("--ref") + 1], "codex/format")

    def test_remote_branch_movement_before_dispatch_sends_no_request(self):
        runner = RemoteRunner()
        state = remote_state(runner)
        runner.remote_sha = "b" * 40
        with self.assertRaisesRegex(RuntimeError, "changed before dispatch"):
            dispatch_and_locate(state, timeout_seconds=0, poll_seconds=0, runner=runner)
        self.assertEqual(runner.dispatched, 0)

    def test_remote_ambiguous_or_missing_new_run_is_not_retried(self):
        for after, message in [
            ([{"databaseId": 12, "headSha": HEAD},
              {"databaseId": 13, "headSha": HEAD}], "Multiple new runs"),
            ([{"databaseId": 10, "headSha": HEAD},
              {"databaseId": 11, "headSha": "b" * 40}], "request was sent"),
        ]:
            with self.subTest(message=message):
                runner = RemoteRunner()
                runner.after = after
                state = remote_state(runner)
                with self.assertRaisesRegex(RuntimeError, message):
                    dispatch_and_locate(
                        state, timeout_seconds=0, poll_seconds=0, runner=runner,
                    )
                self.assertEqual(runner.dispatched, 1)

    def test_remote_dispatch_error_is_not_automatically_retried(self):
        runner = RemoteRunner()
        runner.dispatch_code = 1
        with self.assertRaisesRegex(RuntimeError, "outcome is unknown"):
            dispatch_and_locate(
                remote_state(runner), timeout_seconds=0, poll_seconds=0, runner=runner,
            )
        self.assertEqual(runner.dispatched, 1)

    def test_remote_cli_requires_all_three_identifiers(self):
        from contextlib import redirect_stderr
        from io import StringIO
        with redirect_stderr(StringIO()), self.assertRaises(SystemExit):
            parse_args(["--remote-repo", "example/project"])
        args = parse_args([
            "--remote-repo", "example/project", "--remote-branch", "codex/format",
            "--expected-head-sha", HEAD, "--profile", "format",
        ])
        self.assertFalse(args.execute)
        self.assertEqual(args.expected_head_sha, HEAD)


if __name__ == "__main__":
    unittest.main()
