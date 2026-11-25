#!/usr/bin/env python3
"""Safely detect and recover hung Dart Analysis Server processes (#2748).

Addresses VS Code / LSP disconnect loops such as:
  Pending response rejected since connection got disposed (Code: -32097)

Default mode is read-only (`--dry-run`), listing candidate Dart Analysis
Server processes without terminating anything. Pass `--apply` to terminate
hung analyzer processes cleanly while preserving unrelated `flutter run`,
`dart test`, `dart format`, and CLI `dart analyze` processes.
"""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
import json
import os
import re
import signal
import subprocess
import sys
import time
from typing import Callable


CONFIRMATION_PHRASE = "RECOVER_DART_ANALYZER"

DART_EXECUTABLES = frozenset({
    "dart",
    "dart.exe",
    "dartaotruntime",
    "dartaotruntime.exe",
})

ANALYZER_MARKERS = (
    "analysis_server.dart.snapshot",
    "analysis_server.aot",
    "language-server",
    "--client-id=",
    "--lsp",
)

EXCLUDED_CMD_MARKERS = (
    "recover_dart_analyzer.py",
    "flutter_tools.snapshot",
    "flutter run",
    "flutter test",
    "flutter build",
    "dart test",
    "dart format",
    "dart pub",
    "dart compile",
    "dart analyze",
)

RE_WINDOWS_NOT_FOUND = re.compile(
    r"(?:not\s+found|no\s+running\s+instance|見つかりませんでした)",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class CommandResult:
    code: int
    stdout: str
    stderr: str


@dataclass(frozen=True)
class ProcessInfo:
    pid: int
    ppid: int
    name: str
    command_line: str


@dataclass(frozen=True)
class AnalyzerCandidate:
    pid: int
    ppid: int
    name: str
    command_line: str
    matched_markers: list[str]


@dataclass(frozen=True)
class TerminationOutcome:
    pid: int
    status: str
    method: str
    detail: str


Runner = Callable[[list[str], int], CommandResult]
KillFn = Callable[[int, int], None]
AliveFn = Callable[[int], bool]
SleepFn = Callable[[float], None]


def default_runner(command: list[str], timeout: int = 15) -> CommandResult:
    try:
        proc = subprocess.run(
            command,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
        )
    except FileNotFoundError as exc:
        return CommandResult(127, "", str(exc))
    except subprocess.TimeoutExpired as exc:
        stdout = exc.stdout if isinstance(exc.stdout, str) else ""
        stderr = exc.stderr if isinstance(exc.stderr, str) else ""
        return CommandResult(
            124, stdout.strip(), stderr.strip() or "command timed out"
        )
    except OSError as exc:
        return CommandResult(126, "", str(exc))
    return CommandResult(
        proc.returncode, proc.stdout.strip(), proc.stderr.strip()
    )


def default_is_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    except OSError:
        return False
    return True


def _normalize_exe_name(raw_name: str) -> str:
    base = os.path.basename(raw_name.strip().replace("\\", "/")).lower()
    return base


def match_analyzer_markers(
    process: ProcessInfo,
    self_pid: int | None = None,
) -> list[str]:
    """Return matched analyzer markers if `process` is a Dart Analysis Server."""
    if process.pid <= 0 or (self_pid is not None and process.pid == self_pid):
        return []

    exe = _normalize_exe_name(process.name)
    if exe not in DART_EXECUTABLES:
        return []

    cmd = process.command_line.strip()
    if not cmd:
        return []
    cmd_lower = cmd.lower()

    for excluded in EXCLUDED_CMD_MARKERS:
        if excluded in cmd_lower:
            return []

    matched = [marker for marker in ANALYZER_MARKERS if marker in cmd_lower]
    has_strong_marker = any(
        m in matched
        for m in (
            "analysis_server.dart.snapshot",
            "analysis_server.aot",
            "language-server",
            "--client-id=",
        )
    )
    if has_strong_marker:
        return matched
    if "--lsp" in matched and ("snapshot" in cmd_lower or "dart" in cmd_lower):
        return matched
    return []


def parse_windows_cim_processes(raw_json: str) -> list[ProcessInfo]:
    text = raw_json.strip()
    if not text:
        return []
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        return []

    rows = parsed if isinstance(parsed, list) else [parsed]
    processes: list[ProcessInfo] = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        try:
            pid = int(row.get("ProcessId") or 0)
        except (TypeError, ValueError):
            continue
        try:
            ppid = int(row.get("ParentProcessId") or 0)
        except (TypeError, ValueError):
            ppid = 0
        name = str(row.get("Name") or "")
        cmd = str(row.get("CommandLine") or "")
        if pid > 0:
            processes.append(ProcessInfo(pid=pid, ppid=ppid, name=name, command_line=cmd))
    return processes


def parse_posix_ps_processes(raw_stdout: str) -> list[ProcessInfo]:
    processes: list[ProcessInfo] = []
    for line in raw_stdout.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        parts = stripped.split(None, 3)
        if len(parts) < 4:
            continue
        try:
            pid = int(parts[0])
            ppid = int(parts[1])
        except ValueError:
            continue
        processes.append(
            ProcessInfo(pid=pid, ppid=ppid, name=parts[2], command_line=parts[3])
        )
    return processes


def discover_processes(
    platform_name: str | None = None,
    runner: Runner = default_runner,
) -> tuple[list[ProcessInfo], str | None]:
    target_os = platform_name or sys.platform
    if target_os.startswith("win"):
        ps_cmd = (
            "Get-CimInstance Win32_Process | "
            "Where-Object { $_.Name -like 'dart*' } | "
            "Select-Object ProcessId,ParentProcessId,Name,CommandLine | "
            "ConvertTo-Json -Compress"
        )
        res = runner(
            ["powershell", "-NoProfile", "-Command", ps_cmd],
            15,
        )
        if res.code != 0 and not res.stdout:
            return [], res.stderr or f"powershell failed with exit {res.code}"
        return parse_windows_cim_processes(res.stdout), None

    res = runner(["ps", "-eo", "pid=,ppid=,comm=,args="], 15)
    if res.code != 0 and not res.stdout:
        return [], res.stderr or f"ps failed with exit {res.code}"
    return parse_posix_ps_processes(res.stdout), None


def find_analyzer_candidates(
    processes: list[ProcessInfo],
    self_pid: int | None = None,
) -> list[AnalyzerCandidate]:
    candidates: list[AnalyzerCandidate] = []
    current_pid = os.getpid() if self_pid is None else self_pid
    for proc in processes:
        markers = match_analyzer_markers(proc, self_pid=current_pid)
        if markers:
            candidates.append(
                AnalyzerCandidate(
                    pid=proc.pid,
                    ppid=proc.ppid,
                    name=proc.name,
                    command_line=proc.command_line,
                    matched_markers=markers,
                )
            )
    return sorted(candidates, key=lambda c: c.pid)


def terminate_candidate(
    candidate: AnalyzerCandidate,
    platform_name: str | None = None,
    runner: Runner = default_runner,
    kill_fn: KillFn = os.kill,
    is_alive_fn: AliveFn = default_is_alive,
    sleep_fn: SleepFn = time.sleep,
    grace_seconds: float = 1.0,
) -> TerminationOutcome:
    target_os = platform_name or sys.platform
    if target_os.startswith("win"):
        res = runner(
            ["taskkill", "/PID", str(candidate.pid), "/T", "/F"],
            15,
        )
        combined = f"{res.stdout} {res.stderr}".strip()
        if res.code == 0:
            return TerminationOutcome(
                pid=candidate.pid,
                status="terminated",
                method="taskkill",
                detail=combined or "process tree terminated",
            )
        if res.code == 128 or RE_WINDOWS_NOT_FOUND.search(combined):
            return TerminationOutcome(
                pid=candidate.pid,
                status="already_exited",
                method="taskkill",
                detail=combined or "process already exited",
            )
        return TerminationOutcome(
            pid=candidate.pid,
            status="failed",
            method="taskkill",
            detail=combined or f"taskkill exit {res.code}",
        )

    sigterm = getattr(signal, "SIGTERM", 15)
    sigkill = getattr(signal, "SIGKILL", 9)
    try:
        kill_fn(candidate.pid, sigterm)
    except ProcessLookupError:
        return TerminationOutcome(
            pid=candidate.pid,
            status="already_exited",
            method="sigterm",
            detail="process already exited before SIGTERM",
        )
    except OSError as exc:
        return TerminationOutcome(
            pid=candidate.pid,
            status="failed",
            method="sigterm",
            detail=str(exc),
        )

    steps = max(1, int(grace_seconds / 0.1)) if grace_seconds > 0 else 0
    for _ in range(steps):
        if not is_alive_fn(candidate.pid):
            return TerminationOutcome(
                pid=candidate.pid,
                status="terminated",
                method="sigterm",
                detail="terminated cleanly on SIGTERM",
            )
        sleep_fn(0.1)

    if not is_alive_fn(candidate.pid):
        return TerminationOutcome(
            pid=candidate.pid,
            status="terminated",
            method="sigterm",
            detail="terminated cleanly on SIGTERM",
        )

    try:
        kill_fn(candidate.pid, sigkill)
    except ProcessLookupError:
        return TerminationOutcome(
            pid=candidate.pid,
            status="already_exited",
            method="sigkill",
            detail="exited prior to SIGKILL",
        )
    except OSError as exc:
        return TerminationOutcome(
            pid=candidate.pid,
            status="failed",
            method="sigkill",
            detail=str(exc),
        )

    return TerminationOutcome(
        pid=candidate.pid,
        status="terminated",
        method="sigkill",
        detail="escalated to SIGKILL after grace period",
    )


def build_recovery_report(
    candidates: list[AnalyzerCandidate],
    apply: bool,
    outcomes: list[TerminationOutcome],
    discovery_error: str | None = None,
) -> dict[str, object]:
    return {
        "mode": "apply" if apply else "dry_run",
        "detected_count": len(candidates),
        "candidates": [asdict(c) for c in candidates],
        "outcomes": [asdict(o) for o in outcomes],
        "discovery_error": discovery_error,
        "next_steps": [
            "Open VS Code Command Palette (Ctrl+Shift+P / Cmd+Shift+P).",
            "Run 'Dart: Restart Analysis Server' so the IDE respawns a clean LSP session (Code -32097 recovery).",
            "If disconnects persist, run 'flutter pub get' after restarting VS Code.",
        ],
    }


def run_self_test() -> int:
    sample_win = json.dumps([
        {
            "ProcessId": 4100,
            "ParentProcessId": 1000,
            "Name": "dart.exe",
            "CommandLine": (
                "C:\\flutter\\bin\\cache\\dart-sdk\\bin\\dart.exe "
                "analysis_server.dart.snapshot --client-id=VS-Code --lsp"
            ),
        },
        {
            "ProcessId": 4200,
            "ParentProcessId": 1000,
            "Name": "dart.exe",
            "CommandLine": "dart test test/features/app_test.dart",
        },
    ])
    procs = parse_windows_cim_processes(sample_win)
    cands = find_analyzer_candidates(procs, self_pid=9999)
    assert len(cands) == 1 and cands[0].pid == 4100, "self-test detection mismatch"

    def fake_taskkill(cmd: list[str], _timeout: int) -> CommandResult:
        return CommandResult(0, f"SUCCESS: {cmd}", "")

    out = terminate_candidate(cands[0], platform_name="win32", runner=fake_taskkill)
    assert out.status == "terminated"
    report = build_recovery_report(cands, apply=True, outcomes=[out])
    assert report["detected_count"] == 1
    print("SELF_TEST_PASS detected=1 terminated=1")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Terminate detected Dart Analysis Server processes (default is dry-run).",
    )
    parser.add_argument(
        "--confirm",
        default=None,
        help=f"Optional confirmation guard phrase ({CONFIRMATION_PHRASE}) for IDE tasks.",
    )
    parser.add_argument(
        "--grace-seconds",
        type=float,
        default=1.0,
        help="POSIX SIGTERM grace window before escalating to SIGKILL.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit JSON report.",
    )
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="Run built-in deterministic verification without touching real processes.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.self_test:
        return run_self_test()

    if args.apply and args.confirm is not None and args.confirm != CONFIRMATION_PHRASE:
        payload = {
            "error": (
                f"Confirmation phrase mismatch. Type '{CONFIRMATION_PHRASE}' "
                "to terminate hung Dart Analysis Server processes."
            ),
            "mode": "aborted",
        }
        if args.json:
            print(json.dumps(payload, ensure_ascii=False, indent=2))
        else:
            print(payload["error"], file=sys.stderr)
        return 2

    processes, discovery_error = discover_processes()
    candidates = find_analyzer_candidates(processes)
    outcomes: list[TerminationOutcome] = []

    if args.apply and candidates:
        for cand in candidates:
            outcomes.append(
                terminate_candidate(cand, grace_seconds=args.grace_seconds)
            )

    report = build_recovery_report(
        candidates=candidates,
        apply=bool(args.apply),
        outcomes=outcomes,
        discovery_error=discovery_error,
    )

    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(
            f"[recover_dart_analyzer] mode={report['mode']} "
            f"detected={report['detected_count']}"
        )
        if discovery_error:
            print(f"Discovery warning: {discovery_error}")
        for cand in candidates:
            print(
                f" - PID={cand.pid} (PPID={cand.ppid}) "
                f"markers={','.join(cand.matched_markers)} :: {cand.command_line}"
            )
        for out in outcomes:
            print(
                f" -> PID={out.pid}: {out.status} via {out.method} ({out.detail})"
            )
        if not candidates and not discovery_error:
            print("No hung Dart Analysis Server processes found.")
        print("Next steps:")
        for step in report["next_steps"]:  # type: ignore[attr-defined]
            print(f"  * {step}")

    if discovery_error:
        return 1
    if any(out.status == "failed" for out in outcomes):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
