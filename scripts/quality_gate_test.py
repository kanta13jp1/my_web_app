#!/usr/bin/env python3
from __future__ import annotations

import ctypes
import json
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
    CommandResult,
    GateCommand,
    analyzer_lock_path,
    classify_analyzer_result,
    dart_analyze_fallback_command,
    flutter_vm_test_concurrency,
    full_commands,
    main,
    run_gate,
    run_analyzer_gate,
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
        with patch("quality_gate.run_analyzer_gate", return_value=0) as run:
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
        self.assertTrue(command.capture_output)
        self.assertGreater(command.timeout_seconds, 0)

    def test_analyze_only_cli_uses_same_analyzer_wrapper(self) -> None:
        with patch("quality_gate.run_analyzer_gate", return_value=0) as run:
            self.assertEqual(main(["--analyze-only"]), 0)

        command = run.call_args.args[0]
        self.assertEqual(command.args, ["flutter", "analyze"])
        self.assertTrue(command.serialize_analyzer)

    def test_analyzer_failure_classification_separates_code_and_infrastructure(self) -> None:
        code_result = CommandResult(1, 1.0, False, "not_needed", "error - lib/a.dart:1")
        crash_result = CommandResult(
            -1073740791,
            2.0,
            False,
            "not_needed",
            "../../runtime/vm/zone.cc: 96: error: Out of memory.",
        )
        timeout_result = CommandResult(TIMEOUT_EXIT_CODE, 3.0, True, "taskkill_exit_0")

        self.assertEqual(classify_analyzer_result(code_result), "code_findings")
        self.assertEqual(classify_analyzer_result(crash_result), "infrastructure_crash")
        self.assertEqual(classify_analyzer_result(timeout_result), "infrastructure_timeout")

    def test_infrastructure_crash_runs_dart_fallback_and_writes_evidence(self) -> None:
        primary = CommandResult(
            -1073740791,
            2.5,
            False,
            "not_needed",
            "Analysis server exited. Out of memory.\n",
        )
        fallback = CommandResult(0, 1.25, False, "not_needed", "No issues found!\n")
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            artifact_dir = Path(".ci-logs/analyzer")
            with (
                patch(
                    "quality_gate.execute_gate",
                    side_effect=[(primary, "acquired"), (fallback, "acquired")],
                ) as execute,
                patch("quality_gate.tool_version", side_effect=["Flutter test", "Dart test"]),
            ):
                code = run_analyzer_gate(
                    GateCommand(
                        "flutter analyze",
                        ["flutter", "analyze"],
                        "flutter",
                        serialize_analyzer=True,
                        capture_output=True,
                    ),
                    root,
                    artifact_dir,
                )

            self.assertEqual(code, 0)
            self.assertEqual(execute.call_count, 2)
            self.assertEqual(execute.call_args_list[1].args[0], dart_analyze_fallback_command())
            evidence = json.loads(
                (root / artifact_dir / "result.json").read_text(encoding="utf-8")
            )
            self.assertEqual(evidence["status"], "degraded_pass")
            self.assertEqual(evidence["primary"]["classification"], "infrastructure_crash")
            self.assertEqual(evidence["fallback"]["classification"], "success")
            self.assertTrue((root / artifact_dir / "comment.md").is_file())
            self.assertIn(
                "No issues found!",
                (root / artifact_dir / "dart-analyze-fallback.log").read_text(
                    encoding="utf-8"
                ),
            )

    def test_code_findings_do_not_run_fallback(self) -> None:
        primary = CommandResult(1, 0.5, False, "not_needed", "error - lib/a.dart:1\n")
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            with (
                patch("quality_gate.execute_gate", return_value=(primary, "acquired")) as execute,
                patch("quality_gate.tool_version", side_effect=["Flutter test", "Dart test"]),
            ):
                code = run_analyzer_gate(
                    GateCommand(
                        "flutter analyze",
                        ["flutter", "analyze"],
                        "flutter",
                        serialize_analyzer=True,
                        capture_output=True,
                    ),
                    root,
                    Path("evidence"),
                )

            self.assertEqual(code, 1)
            execute.assert_called_once()
            evidence = json.loads((root / "evidence/result.json").read_text(encoding="utf-8"))
            self.assertEqual(evidence["status"], "code_findings")
            self.assertIsNone(evidence["fallback"])


if __name__ == "__main__":
    unittest.main()
