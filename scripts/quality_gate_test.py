#!/usr/bin/env python3
from __future__ import annotations

import contextlib
import io
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

from quality_gate import (
    GateCommand,
    ResourceLock,
    ResourceLockTimeout,
    TIMEOUT_EXIT_CODE,
    execute_gate,
    fast_commands,
    flutter_vm_test_concurrency,
    full_commands,
    resource_lock_path,
    run_gate,
    terminate_owned_process_tree,
)


def process_is_running(pid: int) -> bool:
    if os.name == "nt":
        import ctypes

        handle = ctypes.windll.kernel32.OpenProcess(0x1000, False, pid)
        if not handle:
            return False
        ctypes.windll.kernel32.CloseHandle(handle)
        return True
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False


class QualityGateTest(unittest.TestCase):
    def test_flutter_analyzer_has_timeout_and_cross_worktree_lock(self) -> None:
        command = next(item for item in fast_commands() if item.name == "flutter analyze")

        self.assertEqual(command.timeout_seconds, 300)
        self.assertEqual(command.resource_lock, "flutter-analyzer")

    def test_resource_lock_fails_with_bounded_zero_wait(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "analyzer.lock"
            with ResourceLock(path, 0):
                with self.assertRaises(ResourceLockTimeout):
                    with ResourceLock(path, 0):
                        self.fail("second lock must not be acquired")

    def test_analyzer_lock_path_is_shared_by_worktrees(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            common = Path(temp) / "common-git"
            with patch.dict(os.environ, {"QUALITY_GATE_LOCK_ROOT": str(common)}):
                first = resource_lock_path(Path(temp) / "worktree-a", "flutter-analyzer")
                second = resource_lock_path(Path(temp) / "worktree-b", "flutter-analyzer")

        self.assertEqual(first, second)

    def test_hanging_command_kills_owned_descendant_only(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            child_pid_path = root / "child.pid"
            code = (
                "import pathlib, subprocess, sys, time; "
                "child=subprocess.Popen([sys.executable, '-c', "
                "'import time; time.sleep(60)']); "
                f"pathlib.Path({str(child_pid_path)!r}).write_text(str(child.pid)); "
                "time.sleep(60)"
            )
            unrelated = subprocess.Popen(
                [sys.executable, "-c", "import time; time.sleep(60)"]
            )
            child_pid = 0
            try:
                result = execute_gate(
                    GateCommand(
                        "fake hang",
                        [sys.executable, "-c", code],
                        timeout_seconds=0.5,
                    ),
                    root,
                )
                self.assertEqual(result.returncode, TIMEOUT_EXIT_CODE)
                self.assertEqual(result.status, "timeout")
                self.assertLess(result.elapsed_seconds, 10)
                self.assertTrue(result.cleanup["attempted"])
                self.assertTrue(result.cleanup["succeeded"])
                self.assertIsNone(unrelated.poll())

                child_pid = int(child_pid_path.read_text(encoding="utf-8"))
                deadline = time.monotonic() + 3
                while process_is_running(child_pid) and time.monotonic() < deadline:
                    time.sleep(0.05)
                self.assertFalse(process_is_running(child_pid))
            finally:
                unrelated.terminate()
                try:
                    unrelated.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    unrelated.kill()
                if child_pid and process_is_running(child_pid):
                    if os.name == "nt":
                        subprocess.run(
                            ["taskkill", "/PID", str(child_pid), "/T", "/F"],
                            capture_output=True,
                            check=False,
                        )
                    else:
                        os.kill(child_pid, signal.SIGKILL)

    def test_cleanup_routes_to_windows_taskkill(self) -> None:
        proc = unittest.mock.Mock(pid=1234)
        proc.poll.return_value = 1
        with patch("quality_gate.subprocess.run") as run:
            run.return_value.returncode = 0
            result = terminate_owned_process_tree(proc, platform_name="nt")

        run.assert_called_once_with(
            ["taskkill", "/PID", "1234", "/T", "/F"],
            capture_output=True,
            timeout=15,
            check=False,
        )
        self.assertEqual(result["method"], "taskkill")

    def test_cleanup_routes_to_posix_process_group(self) -> None:
        proc = unittest.mock.Mock(pid=4321)
        proc.poll.return_value = 1
        with patch("quality_gate.os.killpg", create=True) as killpg:
            result = terminate_owned_process_tree(proc, platform_name="posix")

        killpg.assert_called_once_with(4321, signal.SIGTERM)
        self.assertEqual(result["method"], "process_group")

    def test_run_gate_emits_structured_recovery_output(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            stdout = io.StringIO()
            stderr = io.StringIO()
            with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                code = run_gate(
                    GateCommand("pass", [sys.executable, "-c", "pass"]),
                    Path(temp),
                    recovery_command="python scripts/quality_gate.py --fast",
                )

        self.assertEqual(code, 0)
        self.assertIn('"event": "quality_gate_command"', stdout.getvalue())
        self.assertIn('"recovery_command":', stdout.getvalue())

    def test_pre_push_does_not_repeat_the_full_ci_gate(self) -> None:
        root = Path(__file__).resolve().parents[1]
        lefthook = (root / "lefthook.yml").read_text(encoding="utf-8")

        self.assertNotIn("pre-push:", lefthook)
        self.assertNotIn("quality_gate.py --full", lefthook)

    def test_vm_tests_keep_coverage_with_bounded_concurrency(self) -> None:
        root = Path(__file__).resolve().parents[1]
        command = next(
            item for item in full_commands(root) if item.name == "flutter vm tests"
        )

        self.assertEqual(
            command.args,
            [
                "flutter",
                "test",
                "--coverage",
                f"--concurrency={flutter_vm_test_concurrency()}",
            ],
        )
        self.assertEqual(flutter_vm_test_concurrency("nt"), 1)
        self.assertEqual(flutter_vm_test_concurrency("posix"), 2)

        workflow = (root / ".github" / "workflows" / "ci.yml").read_text(
            encoding="utf-8"
        )
        self.assertIn(
            "run: flutter test --coverage --concurrency=2",
            workflow,
        )


if __name__ == "__main__":
    unittest.main()
