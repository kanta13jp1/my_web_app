#!/usr/bin/env python3
"""Mocked unit tests for scripts/recover_dart_analyzer.py & .vscode/tasks.json (#2748)."""

from __future__ import annotations

import json
import os
from pathlib import Path
import signal
import sys
import unittest

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "scripts"))

import recover_dart_analyzer as mod  # noqa: E402


class RecoverDartAnalyzerTests(unittest.TestCase):
    def test_matches_only_dart_analysis_server_processes(self) -> None:
        processes = [
            mod.ProcessInfo(
                pid=101,
                ppid=10,
                name="dart.exe",
                command_line=(
                    "C:\\flutter\\bin\\cache\\dart-sdk\\bin\\dart.exe "
                    "C:\\flutter\\bin\\cache\\dart-sdk\\bin\\snapshots\\"
                    "analysis_server.dart.snapshot --client-id=VS-Code --lsp"
                ),
            ),
            mod.ProcessInfo(
                pid=102,
                ppid=10,
                name="dart",
                command_line="/opt/flutter/bin/cache/dart-sdk/bin/dart language-server --lsp",
            ),
            mod.ProcessInfo(
                pid=103,
                ppid=10,
                name="dart.exe",
                command_line="dart.exe test test/features/app_test.dart",
            ),
            mod.ProcessInfo(
                pid=104,
                ppid=10,
                name="dart.exe",
                command_line="dart.exe flutter_tools.snapshot run -d chrome",
            ),
            mod.ProcessInfo(
                pid=105,
                ppid=10,
                name="dart.exe",
                command_line="dart.exe format --output=none --set-exit-if-changed lib",
            ),
            mod.ProcessInfo(
                pid=106,
                ppid=10,
                name="python.exe",
                command_line="python.exe scripts/recover_dart_analyzer.py --apply",
            ),
            mod.ProcessInfo(
                pid=os.getpid(),
                ppid=10,
                name="dart.exe",
                command_line="analysis_server.dart.snapshot",
            ),
        ]

        candidates = mod.find_analyzer_candidates(processes)
        self.assertEqual([c.pid for c in candidates], [101, 102])

    def test_parses_windows_cim_single_and_list_json(self) -> None:
        single_json = json.dumps({
            "ProcessId": 5001,
            "ParentProcessId": 222,
            "Name": "dart.exe",
            "CommandLine": "dart.exe analysis_server.dart.snapshot --lsp",
        })
        single = mod.parse_windows_cim_processes(single_json)
        self.assertEqual(len(single), 1)
        self.assertEqual(single[0].pid, 5001)

        list_json = json.dumps([
            {
                "ProcessId": 5002,
                "ParentProcessId": 222,
                "Name": "dart.exe",
                "CommandLine": "dart.exe --client-id=antigravity --lsp",
            },
            {
                "ProcessId": 5003,
                "ParentProcessId": 222,
                "Name": "dart.exe",
                "CommandLine": "dart.exe analyze",
            },
        ])
        parsed_list = mod.parse_windows_cim_processes(list_json)
        candidates = mod.find_analyzer_candidates(parsed_list, self_pid=9999)
        self.assertEqual([c.pid for c in candidates], [5002])

    def test_parses_posix_ps_output(self) -> None:
        ps_out = (
            " 2201   110 dart     /sdk/bin/dart analysis_server.dart.snapshot --lsp\n"
            " 2202   110 dart     /sdk/bin/dart pub get\n"
        )
        procs = mod.parse_posix_ps_processes(ps_out)
        cands = mod.find_analyzer_candidates(procs, self_pid=9999)
        self.assertEqual([c.pid for c in cands], [2201])

    def test_windows_termination_and_already_exited_nonfatal(self) -> None:
        cand = mod.AnalyzerCandidate(
            pid=777,
            ppid=10,
            name="dart.exe",
            command_line="dart.exe analysis_server.dart.snapshot --lsp",
            matched_markers=["analysis_server.dart.snapshot"],
        )
        calls: list[list[str]] = []

        def ok_runner(cmd: list[str], _timeout: int) -> mod.CommandResult:
            calls.append(cmd)
            return mod.CommandResult(0, "SUCCESS: terminated", "")

        out_ok = mod.terminate_candidate(cand, platform_name="win32", runner=ok_runner)
        self.assertEqual(out_ok.status, "terminated")
        self.assertEqual(calls[0], ["taskkill", "/PID", "777", "/T", "/F"])

        def missing_runner(_cmd: list[str], _timeout: int) -> mod.CommandResult:
            return mod.CommandResult(128, "", 'ERROR: The process "777" not found.')

        out_gone = mod.terminate_candidate(
            cand, platform_name="win32", runner=missing_runner
        )
        self.assertEqual(out_gone.status, "already_exited")

    def test_posix_sigterm_escalation_to_sigkill(self) -> None:
        cand = mod.AnalyzerCandidate(
            pid=888,
            ppid=1,
            name="dart",
            command_line="dart analysis_server.dart.snapshot --lsp",
            matched_markers=["analysis_server.dart.snapshot"],
        )
        signals_sent: list[tuple[int, int]] = []
        sigterm = getattr(signal, "SIGTERM", 15)
        sigkill = getattr(signal, "SIGKILL", 9)

        def fake_kill(pid: int, sig: int) -> None:
            signals_sent.append((pid, sig))

        out = mod.terminate_candidate(
            cand,
            platform_name="linux",
            kill_fn=fake_kill,
            is_alive_fn=lambda _pid: True,
            sleep_fn=lambda _sec: None,
            grace_seconds=0.2,
        )
        self.assertEqual(out.status, "terminated")
        self.assertEqual(out.method, "sigkill")
        self.assertEqual(signals_sent, [(888, sigterm), (888, sigkill)])

    def test_confirm_mismatch_aborts_before_discovery(self) -> None:
        rc = mod.main(["--apply", "--confirm", "WRONG_PHRASE", "--json"])
        self.assertEqual(rc, 2)

    def test_self_test_and_vscode_tasks_integration(self) -> None:
        self.assertEqual(mod.run_self_test(), 0)

        tasks_path = REPO_ROOT / ".vscode" / "tasks.json"
        data = json.loads(tasks_path.read_text(encoding="utf-8"))
        labels = [t["label"] for t in data["tasks"]]
        self.assertIn("Containers: audit cleanup safety", labels)
        self.assertIn("Containers: safe prune (volumes excluded)", labels)
        self.assertIn("Dart Analyzer: diagnose (dry-run)", labels)
        self.assertIn("Dart Analyzer: recover frozen server (apply)", labels)

        input_ids = [i["id"] for i in data["inputs"]]
        self.assertIn("containerCleanupConfirmation", input_ids)
        self.assertIn("dartAnalyzerRecoveryConfirmation", input_ids)


if __name__ == "__main__":
    unittest.main()
