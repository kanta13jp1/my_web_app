#!/usr/bin/env python3
from __future__ import annotations

import ctypes
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from types import SimpleNamespace
from unittest.mock import patch

from quality_gate import (
    AnalyzerLock,
    AnalyzerLockTimeout,
    LOCK_TIMEOUT_EXIT_CODE,
    TIMEOUT_EXIT_CODE,
    GateCommand,
    analyzer_lock_path,
    flutter_vm_test_concurrency,
    full_commands,
    main,
    run_gate,
    run_process,
    shared_git_dir,
    terminate_owned_process_tree,
)


def pid_is_running(pid: int) -> bool:
    if os.name == "nt":
        process_query_limited_information = 0x1000
        handle = ctypes.windll.kernel32.OpenProcess(
            process_query_limited_information,
            False,
            pid,
        )
        if not handle:
            return False
        ctypes.windll.kernel32.CloseHandle(handle)
        return True
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    return True


class QualityGateTest(unittest.TestCase):
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

    def test_analyzer_lock_is_shared_across_worktrees(self) -> None:
        root = Path(__file__).resolve().parents[1]
        common_dir = shared_git_dir(root)

        self.assertEqual(analyzer_lock_path(root).parent.parent, common_dir)

    def test_analyzer_lock_wait_is_bounded(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            lock_path = Path(temp_dir) / "analyzer.lock"
            started = time.monotonic()
            with AnalyzerLock(lock_path, 1.0):
                with self.assertRaises(AnalyzerLockTimeout):
                    with AnalyzerLock(lock_path, 0.1):
                        pass
            self.assertLess(time.monotonic() - started, 1.0)

    def test_hanging_command_times_out_and_cleans_owned_descendants(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            child_pid_path = root / "child.pid"
            unrelated = subprocess.Popen(
                [sys.executable, "-c", "import time; time.sleep(60)"],
                creationflags=(
                    subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0
                ),
                start_new_session=os.name != "nt",
            )
            try:
                script = (
                    "import pathlib,subprocess,sys,time;"
                    "child=subprocess.Popen([sys.executable,'-c','import time; time.sleep(60)']);"
                    "pathlib.Path(sys.argv[1]).write_text(str(child.pid),encoding='utf-8');"
                    "time.sleep(60)"
                )
                result = run_process(
                    [sys.executable, "-c", script, str(child_pid_path)],
                    root,
                    1.0,
                )

                self.assertEqual(result.returncode, TIMEOUT_EXIT_CODE)
                self.assertTrue(result.timed_out)
                self.assertTrue(child_pid_path.is_file())
                child_pid = int(child_pid_path.read_text(encoding="utf-8"))
                self.assertFalse(pid_is_running(child_pid))
                self.assertIsNone(unrelated.poll())
            finally:
                unrelated.kill()
                unrelated.wait(timeout=5)

    def test_windows_cleanup_routes_through_taskkill_tree(self) -> None:
        proc = SimpleNamespace(pid=1234, poll=lambda: None, wait=lambda timeout: 0)
        completed = SimpleNamespace(returncode=0)
        with patch("quality_gate.subprocess.run", return_value=completed) as run:
            result = terminate_owned_process_tree(proc, platform_name="nt")

        self.assertEqual(result, "taskkill_exit_0")
        run.assert_called_once_with(
            ["taskkill", "/PID", "1234", "/T", "/F"],
            capture_output=True,
            check=False,
        )

    def test_posix_cleanup_routes_through_owned_process_group(self) -> None:
        proc = SimpleNamespace(pid=1234, poll=lambda: None, wait=lambda timeout: 0)
        with patch("quality_gate.os.killpg", create=True) as killpg:
            result = terminate_owned_process_tree(proc, platform_name="posix")

        self.assertEqual(result, "process_group_terminated")
        killpg.assert_called_once_with(1234, 15)

    def test_run_gate_reports_timeout_as_failure(self) -> None:
        root = Path(__file__).resolve().parents[1]
        command = GateCommand(
            "fake hang",
            [sys.executable, "-c", "import time; time.sleep(60)"],
            timeout_seconds=0.1,
        )

        self.assertEqual(run_gate(command, root), TIMEOUT_EXIT_CODE)

    def test_lock_timeout_exit_code_is_distinct_from_command_timeout(self) -> None:
        self.assertNotEqual(LOCK_TIMEOUT_EXIT_CODE, TIMEOUT_EXIT_CODE)

    def test_analyze_files_cli_builds_bounded_serialized_command(self) -> None:
        with patch("quality_gate.run_gate", return_value=0) as run:
            self.assertEqual(
                main(["--analyze-files", "lib/example.dart", "test/example_test.dart"]),
                0,
            )

        command = run.call_args.args[0]
        self.assertEqual(
            command.args,
            [
                "flutter",
                "analyze",
                "--no-pub",
                "lib/example.dart",
                "test/example_test.dart",
            ],
        )
        self.assertTrue(command.serialize_analyzer)
        self.assertGreater(command.timeout_seconds, 0)


if __name__ == "__main__":
    unittest.main()
