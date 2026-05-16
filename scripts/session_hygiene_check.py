#!/usr/bin/env python3
"""Measure and optionally compress session memory/disk hygiene state.

Issue #2506 needs a single, repo-managed entrypoint that can be called from a
GitHub Actions cron or a local Claude/Codex SessionStart hook. The default mode
is safe: it records a CSV/JSON report and only runs cleanup when both --apply is
passed and an auto threshold is crossed.
"""

from __future__ import annotations

import argparse
import csv
import ctypes
import json
import os
import platform
import shutil
import socket
import subprocess
import sys
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


@dataclass
class CommandResult:
    status: str
    returncode: int | None = None
    stdout_tail: str = ""
    stderr_tail: str = ""


@dataclass
class HygieneResult:
    generated_at: str
    mode: str
    hostname: str
    os_name: str
    root: str
    c_free_gb: float
    ram_pct: float | None
    severity: str
    reasons: list[str]
    should_auto_apply: bool
    applied: bool
    smartcleanup: CommandResult
    git_gc: CommandResult
    cache_cleanup: CommandResult
    actual_reclaim_mb: float
    log_path: str
    run_url: str


class MEMORYSTATUSEX(ctypes.Structure):
    _fields_ = [
        ("dwLength", ctypes.c_ulong),
        ("dwMemoryLoad", ctypes.c_ulong),
        ("ullTotalPhys", ctypes.c_ulonglong),
        ("ullAvailPhys", ctypes.c_ulonglong),
        ("ullTotalPageFile", ctypes.c_ulonglong),
        ("ullAvailPageFile", ctypes.c_ulonglong),
        ("ullTotalVirtual", ctypes.c_ulonglong),
        ("ullAvailVirtual", ctypes.c_ulonglong),
        ("sullAvailExtendedVirtual", ctypes.c_ulonglong),
    ]


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def tail_text(value: str, limit: int = 700) -> str:
    if len(value) <= limit:
        return value
    return value[-limit:]


def command_result(status: str, returncode: int | None = None, stdout: str = "", stderr: str = "") -> CommandResult:
    return CommandResult(
        status=status,
        returncode=returncode,
        stdout_tail=tail_text(stdout.strip()),
        stderr_tail=tail_text(stderr.strip()),
    )


def run_command(args: list[str], cwd: Path | None = None, timeout: int = 120) -> CommandResult:
    try:
        proc = subprocess.run(
            args,
            cwd=str(cwd) if cwd else None,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            timeout=timeout,
        )
    except FileNotFoundError as exc:
        return command_result("missing", 127, stderr=str(exc))
    except PermissionError as exc:
        return command_result("permission-denied", 126, stderr=str(exc))
    except OSError as exc:
        return command_result("error", 126, stderr=str(exc))
    except subprocess.TimeoutExpired as exc:
        stdout = exc.stdout if isinstance(exc.stdout, str) else ""
        stderr = exc.stderr if isinstance(exc.stderr, str) else ""
        return command_result("timeout", 124, stdout=stdout, stderr=stderr or f"timed out after {timeout}s")
    status = "success" if proc.returncode == 0 else "failed"
    return command_result(status, proc.returncode, proc.stdout, proc.stderr)


def default_drive_root() -> Path:
    if os.name == "nt":
        return Path(os.environ.get("SystemDrive", "C:") + "\\")
    return Path("/")


def drive_free_gb(path: Path) -> float:
    return round(shutil.disk_usage(path).free / (1024**3), 2)


def memory_used_pct() -> float | None:
    if os.name != "nt":
        return None
    status = MEMORYSTATUSEX()
    status.dwLength = ctypes.sizeof(MEMORYSTATUSEX)
    if not ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(status)):  # type: ignore[attr-defined]
        return None
    return round(float(status.dwMemoryLoad), 1)


def classify(
    *,
    c_free_gb: float,
    ram_pct: float | None,
    disk_warn_gb: float,
    disk_auto_gb: float,
    ram_warn_pct: float,
    ram_auto_pct: float,
) -> tuple[str, list[str]]:
    reasons: list[str] = []
    auto = False
    warn = False
    if c_free_gb < disk_auto_gb:
        auto = True
        reasons.append(f"C free {c_free_gb:.2f}GB < auto {disk_auto_gb:.2f}GB")
    elif c_free_gb < disk_warn_gb:
        warn = True
        reasons.append(f"C free {c_free_gb:.2f}GB < warn {disk_warn_gb:.2f}GB")

    if ram_pct is not None:
        if ram_pct >= ram_auto_pct:
            auto = True
            reasons.append(f"RAM {ram_pct:.1f}% >= auto {ram_auto_pct:.1f}%")
        elif ram_pct >= ram_warn_pct:
            warn = True
            reasons.append(f"RAM {ram_pct:.1f}% >= warn {ram_warn_pct:.1f}%")

    if auto:
        return "auto", reasons
    if warn:
        return "warn", reasons
    return "ok", ["within thresholds"]


def run_smartcleanup(task_name: str, timeout: int) -> CommandResult:
    if os.name != "nt":
        return command_result("skipped", stdout="Windows Task Scheduler unavailable")
    ps = rf"""
$ErrorActionPreference = 'Stop'
$task = Get-ScheduledTask -TaskName '{task_name}' -ErrorAction SilentlyContinue
if (-not $task) {{
  Write-Output 'task-missing'
  exit 0
}}
Start-ScheduledTask -TaskName '{task_name}'
Write-Output 'task-started'
"""
    result = run_command(
        ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps],
        timeout=timeout,
    )
    if result.status == "success" and "task-missing" in result.stdout_tail:
        result.status = "missing"
    return result


def run_git_gc(root: Path, timeout: int) -> CommandResult:
    return run_command(["git", "gc", "--auto"], cwd=root, timeout=timeout)


def run_dev_cache_cleanup(root: Path, report_path: Path, timeout: int) -> tuple[CommandResult, float]:
    script = root / "scripts" / "dev_cache_cleanup.py"
    if not script.exists():
        return command_result("missing", stderr=str(script)), 0.0
    args = [
        sys.executable,
        str(script),
        "--root",
        str(root),
        "--tier18",
        "--tier19",
        "--apply",
        "--json-out",
        str(report_path),
        "--max-runtime-sec",
        str(timeout),
        "--command-timeout",
        str(max(10, timeout)),
    ]
    result = run_command(args, cwd=root, timeout=timeout + 15)
    actual = 0.0
    if report_path.exists():
        try:
            summary = json.loads(report_path.read_text(encoding="utf-8"))
            actual = float(summary.get("actual_reclaim_mb") or 0.0)
        except (OSError, ValueError, TypeError, json.JSONDecodeError):
            actual = 0.0
    return result, round(max(0.0, actual), 1)


def append_log(path: Path, result: HygieneResult) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    exists = path.exists()
    fields = [
        "generated_at",
        "mode",
        "hostname",
        "os_name",
        "c_free_gb",
        "ram_pct",
        "severity",
        "should_auto_apply",
        "applied",
        "smartcleanup_status",
        "git_gc_status",
        "cache_cleanup_status",
        "actual_reclaim_mb",
        "run_url",
        "reasons",
    ]
    with path.open("a", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        if not exists:
            writer.writeheader()
        writer.writerow(
            {
                "generated_at": result.generated_at,
                "mode": result.mode,
                "hostname": result.hostname,
                "os_name": result.os_name,
                "c_free_gb": result.c_free_gb,
                "ram_pct": "" if result.ram_pct is None else result.ram_pct,
                "severity": result.severity,
                "should_auto_apply": result.should_auto_apply,
                "applied": result.applied,
                "smartcleanup_status": result.smartcleanup.status,
                "git_gc_status": result.git_gc.status,
                "cache_cleanup_status": result.cache_cleanup.status,
                "actual_reclaim_mb": result.actual_reclaim_mb,
                "run_url": result.run_url,
                "reasons": "; ".join(result.reasons),
            }
        )


def github_run_url() -> str:
    server = os.environ.get("GITHUB_SERVER_URL")
    repo = os.environ.get("GITHUB_REPOSITORY")
    run_id = os.environ.get("GITHUB_RUN_ID")
    if server and repo and run_id:
        return f"{server}/{repo}/actions/runs/{run_id}"
    return ""


def run_hygiene(args: argparse.Namespace) -> HygieneResult:
    c_free_gb = args.sample_free_gb if args.sample_free_gb is not None else drive_free_gb(args.drive)
    ram_pct = args.sample_ram_pct if args.sample_ram_pct is not None else memory_used_pct()
    severity, reasons = classify(
        c_free_gb=c_free_gb,
        ram_pct=ram_pct,
        disk_warn_gb=args.disk_warn_gb,
        disk_auto_gb=args.disk_auto_gb,
        ram_warn_pct=args.ram_warn_pct,
        ram_auto_pct=args.ram_auto_pct,
    )
    should_auto_apply = severity == "auto" or args.force
    applied = bool(args.apply and should_auto_apply)
    smartcleanup = command_result("skipped")
    git_gc = command_result("skipped")
    cache_cleanup = command_result("skipped")
    actual_reclaim_mb = 0.0

    if applied:
        smartcleanup = run_smartcleanup(args.smartcleanup_task, args.command_timeout)
        git_gc = run_git_gc(args.root, args.command_timeout)
        cache_report = args.json_out.with_name(args.json_out.stem + ".dev-cache.json") if args.json_out else args.log_path.with_suffix(".dev-cache.json")
        cache_cleanup, actual_reclaim_mb = run_dev_cache_cleanup(args.root, cache_report, args.max_runtime_sec)

    result = HygieneResult(
        generated_at=now_iso(),
        mode=args.mode,
        hostname=socket.gethostname(),
        os_name=platform.platform(),
        root=str(args.root),
        c_free_gb=round(c_free_gb, 2),
        ram_pct=ram_pct,
        severity=severity,
        reasons=reasons,
        should_auto_apply=should_auto_apply,
        applied=applied,
        smartcleanup=smartcleanup,
        git_gc=git_gc,
        cache_cleanup=cache_cleanup,
        actual_reclaim_mb=actual_reclaim_mb,
        log_path=str(args.log_path),
        run_url=github_run_url(),
    )
    append_log(args.log_path, result)
    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(json.dumps(asdict(result), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return result


def parse_args(argv: list[str]) -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=repo_root)
    parser.add_argument("--drive", type=Path, default=default_drive_root())
    parser.add_argument("--mode", default="session-start")
    parser.add_argument("--log-path", type=Path, default=repo_root / "memory" / "session_hygiene_log.csv")
    parser.add_argument("--json-out", type=Path)
    parser.add_argument("--disk-warn-gb", type=float, default=25.0)
    parser.add_argument("--disk-auto-gb", type=float, default=15.0)
    parser.add_argument("--ram-warn-pct", type=float, default=85.0)
    parser.add_argument("--ram-auto-pct", type=float, default=90.0)
    parser.add_argument("--smartcleanup-task", default="SmartCleanup_DailySafe")
    parser.add_argument("--max-runtime-sec", type=int, default=120)
    parser.add_argument("--command-timeout", type=int, default=60)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--sample-free-gb", type=float)
    parser.add_argument("--sample-ram-pct", type=float)
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    result = run_hygiene(args)
    if args.json:
        print(json.dumps(asdict(result), ensure_ascii=False, indent=2))
    else:
        print(f"{result.mode}: {result.severity} ({'; '.join(result.reasons)})")
        if result.applied:
            print(f"cleanup: {result.cache_cleanup.status}; reclaim_mb={result.actual_reclaim_mb:.1f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
