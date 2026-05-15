#!/usr/bin/env python3
"""Session compression guard for repo-managed Claude Code hooks.

This script implements the safe, dependency-free parts of the v23 structural
session compression contract for Issue #1564:

- Layer JJ: SessionStart hard-gate decision and optional cleanup fire.
- Layer KK: PreToolUse compression budget snapshot and capped mid-session fire.
- Layer LL: SessionEnd/wrap-up compression pass.
- Layer MM: UserPromptSubmit idle-gap cleanup fire.
- Layer NN: SessionStart/UserPromptSubmit KPI banner.
- Layer DDD: Always-fire per-session disk quota contract.

It writes state under the user's home directory by default so committed repo
files stay clean. Tests can override every measured value and output path.
"""

from __future__ import annotations

import argparse
import csv
import ctypes
import json
import os
import shutil
import subprocess
import sys
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


SESSION_START_PHASE = "session_start_forced_fire"
USERPROMPT_PHASE = "idle_gap_pre"
PRETOOLUSE_PHASE = "pretooluse_budget_snapshot"
WRAP_UP_PHASE = "wrap_up_post"
STATE_VERSION = 1


@dataclass
class CleanupResult:
    status: str
    returncode: int | None = None
    actual_reclaim_mb: float = 0.0
    stdout_tail: str = ""
    stderr_tail: str = ""


@dataclass
class QuotaResult:
    min_reclaim_mb: float = 0.0
    actual_reclaim_mb: float = 0.0
    passed: bool = True
    reason: str = "disabled"


@dataclass
class GuardResult:
    mode: str
    phase: str
    decision: str
    should_fire: bool
    reason: str
    c_free_gb_before: float
    c_free_gb_after: float | None
    ram_pct_before: float | None
    ram_pct_after: float | None
    last_fire_age_min: float | None
    fatigue: str
    banner: str
    cleanup: CleanupResult
    quota: QuotaResult
    log_path: str
    state_path: str


def parse_iso(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone.utc)
    except ValueError:
        return None


def iso_now(value: str | None) -> datetime:
    parsed = parse_iso(value)
    return parsed or datetime.now(timezone.utc)


def minutes_between(now: datetime, then: datetime | None) -> float | None:
    if then is None:
        return None
    return max(0.0, (now - then).total_seconds() / 60.0)


def default_drive_root() -> Path:
    if os.name == "nt":
        return Path(os.environ.get("SystemDrive", "C:") + "\\")
    return Path("/")


def drive_free_gb(path: Path) -> float:
    usage = shutil.disk_usage(path)
    return round(usage.free / (1024**3), 2)


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


def memory_used_pct() -> float | None:
    if os.name != "nt":
        return None
    status = MEMORYSTATUSEX()
    status.dwLength = ctypes.sizeof(MEMORYSTATUSEX)
    if not ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(status)):  # type: ignore[attr-defined]
        return None
    return round(float(status.dwMemoryLoad), 1)


def tail_text(text: str, limit: int = 700) -> str:
    if len(text) <= limit:
        return text
    return text[-limit:]


def load_state(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"version": STATE_VERSION, "fires": []}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {"version": STATE_VERSION, "fires": []}
    if not isinstance(data, dict):
        return {"version": STATE_VERSION, "fires": []}
    if not isinstance(data.get("fires"), list):
        data["fires"] = []
    data["version"] = STATE_VERSION
    return data


def write_state(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    tmp.replace(path)


def fatigue_status(state: dict[str, Any]) -> str:
    fires = [entry for entry in state.get("fires", []) if isinstance(entry, dict)]
    recent = [float(entry.get("reclaim_mb") or 0.0) for entry in fires[-3:]]
    if len(recent) < 3:
        return "OK"
    average = sum(recent) / len(recent)
    return "FATIGUE" if average < 100.0 else "OK"


def format_optional(value: float | None, suffix: str = "") -> str:
    if value is None:
        return "unknown"
    if suffix:
        return f"{value:.1f}{suffix}"
    return f"{value:.1f}"


def build_banner(
    *,
    c_free_gb: float,
    ram_pct: float | None,
    last_fire_age_min: float | None,
    fatigue: str,
) -> str:
    return (
        f"[KPI] C:{c_free_gb:.2f}GB "
        f"RAM:{format_optional(ram_pct, '%')} "
        f"last_fire:{format_optional(last_fire_age_min, 'min')} "
        f"fatigue:{fatigue}"
    )


def run_dev_cache_cleanup(args: argparse.Namespace) -> CleanupResult:
    if args.sample_cleanup_reclaim_mb is not None:
        return CleanupResult(
            status="sampled",
            returncode=0,
            actual_reclaim_mb=round(max(0.0, args.sample_cleanup_reclaim_mb), 1),
        )

    script = args.root / "scripts" / "dev_cache_cleanup.py"
    if not script.exists():
        return CleanupResult(status="missing_dev_cache_cleanup", stderr_tail=str(script))

    command = [
        sys.executable,
        str(script),
        "--root",
        str(args.root),
        "--apply",
        "--json",
        "--max-runtime-sec",
        str(args.max_runtime_sec),
        "--command-timeout",
        str(max(10, args.max_runtime_sec)),
    ]
    if args.tier18:
        command.append("--tier18")
    if args.tier19:
        command.append("--tier19")

    try:
        proc = subprocess.run(
            command,
            cwd=str(args.root),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            timeout=max(15, args.max_runtime_sec + 15),
        )
    except subprocess.TimeoutExpired as exc:
        stdout = exc.stdout if isinstance(exc.stdout, str) else ""
        return CleanupResult(
            status="timeout",
            returncode=124,
            stdout_tail=tail_text(stdout),
            stderr_tail=f"timed out after {max(15, args.max_runtime_sec + 15)}s",
        )

    actual = 0.0
    if proc.stdout.strip():
        try:
            payload = json.loads(proc.stdout)
            actual = float(payload.get("actual_reclaim_mb") or 0.0)
        except (json.JSONDecodeError, TypeError, ValueError):
            actual = 0.0
    return CleanupResult(
        status="success" if proc.returncode == 0 else "failed",
        returncode=proc.returncode,
        actual_reclaim_mb=round(actual, 1),
        stdout_tail=tail_text(proc.stdout),
        stderr_tail=tail_text(proc.stderr),
    )


def append_session_delta(path: Path, result: GuardResult) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    exists = path.exists()
    with path.open("a", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "timestamp",
                "mode",
                "phase",
                "decision",
                "c_free_gb_before",
                "c_free_gb_after",
                "ram_pct_before",
                "ram_pct_after",
                "reclaim_mb",
                "last_fire_age_min",
                "fatigue",
                "cleanup_status",
                "quota_min_reclaim_mb",
                "quota_pass",
                "quota_reason",
            ],
        )
        if not exists:
            writer.writeheader()
        writer.writerow(
            {
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "mode": result.mode,
                "phase": result.phase,
                "decision": result.decision,
                "c_free_gb_before": result.c_free_gb_before,
                "c_free_gb_after": result.c_free_gb_after,
                "ram_pct_before": result.ram_pct_before,
                "ram_pct_after": result.ram_pct_after,
                "reclaim_mb": result.cleanup.actual_reclaim_mb,
                "last_fire_age_min": result.last_fire_age_min,
                "fatigue": result.fatigue,
                "cleanup_status": result.cleanup.status,
                "quota_min_reclaim_mb": result.quota.min_reclaim_mb,
                "quota_pass": result.quota.passed,
                "quota_reason": result.quota.reason,
            }
        )


def build_quota_result(args: argparse.Namespace, cleanup: CleanupResult) -> QuotaResult:
    min_reclaim = round(max(0.0, args.min_reclaim_mb), 1)
    actual = round(max(0.0, cleanup.actual_reclaim_mb), 1)
    if min_reclaim <= 0:
        return QuotaResult(actual_reclaim_mb=actual)
    if cleanup.status == "skipped":
        return QuotaResult(
            min_reclaim_mb=min_reclaim,
            actual_reclaim_mb=actual,
            passed=False,
            reason="cleanup did not run",
        )
    if actual >= min_reclaim:
        return QuotaResult(
            min_reclaim_mb=min_reclaim,
            actual_reclaim_mb=actual,
            passed=True,
            reason=f"reclaim {actual:.1f} MB >= {min_reclaim:.1f} MB",
        )
    return QuotaResult(
        min_reclaim_mb=min_reclaim,
        actual_reclaim_mb=actual,
        passed=False,
        reason=f"reclaim {actual:.1f} MB < {min_reclaim:.1f} MB",
    )


def decide_session_start(
    *,
    c_free_gb: float,
    last_fire_age_min: float | None,
    min_free_gb: float,
    max_age_hours: float,
) -> tuple[bool, str]:
    reasons: list[str] = []
    if c_free_gb < min_free_gb:
        reasons.append(f"c_free_gb {c_free_gb:.2f} < {min_free_gb:.2f}")
    if last_fire_age_min is None:
        reasons.append("last_fire_at missing")
    elif last_fire_age_min > max_age_hours * 60.0:
        reasons.append(f"last_fire_age {last_fire_age_min:.1f}min > {max_age_hours * 60.0:.1f}min")
    if reasons:
        return True, "; ".join(reasons)
    return False, "within session-start compression budget"


def decide_userprompt(
    *,
    now: datetime,
    state: dict[str, Any],
    max_age_minutes: float,
    cooldown_minutes: float,
) -> tuple[bool, str]:
    last_fire = parse_iso(state.get("last_fire_at"))
    last_prompt_fire = parse_iso(state.get("last_userprompt_fire_at"))
    last_fire_age = minutes_between(now, last_fire)
    cooldown_age = minutes_between(now, last_prompt_fire)
    if last_fire_age is not None and last_fire_age <= max_age_minutes:
        return False, f"last_fire_age {last_fire_age:.1f}min <= {max_age_minutes:.1f}min"
    if cooldown_age is not None and cooldown_age < cooldown_minutes:
        return False, f"userprompt cooldown {cooldown_age:.1f}min < {cooldown_minutes:.1f}min"
    return True, "idle gap exceeded"


def decide_pretooluse(
    *,
    state: dict[str, Any],
    c_free_gb: float,
    interval: int,
    aggressive_free_gb: float,
    max_mid_fires: int,
) -> tuple[bool, bool, str]:
    tool_count = int(state.get("tool_use_count_session") or 0) + 1
    mid_fires = int(state.get("mid_fire_count_session") or 0)
    state["tool_use_count_session"] = tool_count

    if tool_count % interval != 0:
        return False, False, f"tool_use_count {tool_count} not on {interval}-tool boundary"
    if c_free_gb >= aggressive_free_gb:
        return True, False, f"budget snapshot at tool_use_count {tool_count}; c_free_gb {c_free_gb:.2f} >= {aggressive_free_gb:.2f}"
    if mid_fires >= max_mid_fires:
        return True, False, f"mid-fire cap reached {mid_fires}/{max_mid_fires}"
    return True, True, f"c_free_gb {c_free_gb:.2f} < {aggressive_free_gb:.2f} at tool_use_count {tool_count}"


def run_guard(args: argparse.Namespace) -> GuardResult:
    now = iso_now(args.sample_now)
    state = load_state(args.state_path)
    last_fire = parse_iso(state.get("last_fire_at"))
    last_fire_age_min = minutes_between(now, last_fire)

    c_free_before = args.sample_free_gb
    if c_free_before is None:
        c_free_before = drive_free_gb(args.drive)
    ram_before = args.sample_ram_pct if args.sample_ram_pct is not None else memory_used_pct()
    fatigue = fatigue_status(state)
    banner = build_banner(
        c_free_gb=c_free_before,
        ram_pct=ram_before,
        last_fire_age_min=last_fire_age_min,
        fatigue=fatigue,
    )

    cleanup_required = False
    state_dirty = False

    if args.mode == "session-start":
        phase = SESSION_START_PHASE
        if args.always_fire:
            should_fire = True
            reason = "always-fire disk quota contract"
        else:
            should_fire, reason = decide_session_start(
                c_free_gb=c_free_before,
                last_fire_age_min=last_fire_age_min,
                min_free_gb=args.min_free_gb,
                max_age_hours=args.max_age_hours,
            )
        state["session_started_at"] = now.isoformat()
        state["tool_use_count_session"] = 0
        state["mid_fire_count_session"] = 0
        state_dirty = True
        cleanup_required = should_fire
    elif args.mode == "userprompt":
        phase = USERPROMPT_PHASE
        should_fire, reason = decide_userprompt(
            now=now,
            state=state,
            max_age_minutes=args.max_age_minutes,
            cooldown_minutes=args.cooldown_minutes,
        )
        cleanup_required = should_fire
    elif args.mode == "pretooluse":
        phase = PRETOOLUSE_PHASE
        should_fire, cleanup_required, reason = decide_pretooluse(
            state=state,
            c_free_gb=c_free_before,
            interval=args.tool_budget_interval,
            aggressive_free_gb=args.aggressive_free_gb,
            max_mid_fires=args.max_mid_fires,
        )
        state_dirty = True
    else:
        phase = WRAP_UP_PHASE
        should_fire = True
        cleanup_required = True
        reason = "wrap-up compression required"

    cleanup = CleanupResult(status="skipped")
    c_free_after: float | None = None
    ram_after: float | None = None
    if args.apply and should_fire and cleanup_required:
        cleanup = run_dev_cache_cleanup(args)
        if args.sample_free_gb_after is not None:
            c_free_after = args.sample_free_gb_after
        else:
            c_free_after = drive_free_gb(args.drive)
        ram_after = args.sample_ram_pct_after if args.sample_ram_pct_after is not None else memory_used_pct()
        measured_reclaim = max(0.0, round((c_free_after - c_free_before) * 1024.0, 1))
        if measured_reclaim > cleanup.actual_reclaim_mb:
            cleanup.actual_reclaim_mb = measured_reclaim

        fire_entry = {
            "at": now.isoformat(),
            "mode": args.mode,
            "phase": phase,
            "reclaim_mb": cleanup.actual_reclaim_mb,
            "c_free_gb_before": c_free_before,
            "c_free_gb_after": c_free_after,
            "cleanup_status": cleanup.status,
        }
        fires = [entry for entry in state.get("fires", []) if isinstance(entry, dict)]
        fires.append(fire_entry)
        state["fires"] = fires[-20:]
        state["last_fire_at"] = now.isoformat()
        if args.mode == "userprompt":
            state["last_userprompt_fire_at"] = now.isoformat()
        if args.mode == "pretooluse":
            state["mid_fire_count_session"] = int(state.get("mid_fire_count_session") or 0) + 1
        state_dirty = True

    if args.apply and should_fire and not cleanup_required:
        cleanup = CleanupResult(status="snapshot_only")

    quota = build_quota_result(args, cleanup)

    if args.apply and state_dirty:
        write_state(args.state_path, state)

    if should_fire and args.apply and cleanup_required:
        decision = "fire"
    elif should_fire and args.apply:
        decision = "snapshot"
    elif should_fire:
        decision = "due"
    else:
        decision = "skip"
    result = GuardResult(
        mode=args.mode,
        phase=phase,
        decision=decision,
        should_fire=should_fire,
        reason=reason,
        c_free_gb_before=c_free_before,
        c_free_gb_after=c_free_after,
        ram_pct_before=ram_before,
        ram_pct_after=ram_after,
        last_fire_age_min=last_fire_age_min,
        fatigue=fatigue,
        banner=banner,
        cleanup=cleanup,
        quota=quota,
        log_path=str(args.log_path),
        state_path=str(args.state_path),
    )

    if should_fire and (args.apply or args.log_dry_run):
        append_session_delta(args.log_path, result)
    return result


def parse_args(argv: list[str]) -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parents[1]
    home_state = Path.home() / ".claude" / "state" / "session-compression-guard.json"
    home_log = Path.home() / ".claude" / "logs" / "session-delta.csv"

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--mode",
        choices=("session-start", "userprompt", "pretooluse", "wrap-up"),
        default="session-start",
    )
    parser.add_argument("--root", type=Path, default=repo_root)
    parser.add_argument("--drive", type=Path, default=default_drive_root())
    parser.add_argument("--state-path", type=Path, default=home_state)
    parser.add_argument("--log-path", type=Path, default=home_log)
    parser.add_argument("--min-free-gb", type=float, default=26.0)
    parser.add_argument("--target-free-gb", type=float, default=28.0)
    parser.add_argument("--min-reclaim-mb", type=float, default=0.0)
    parser.add_argument("--max-age-hours", type=float, default=4.0)
    parser.add_argument("--max-age-minutes", type=float, default=30.0)
    parser.add_argument("--cooldown-minutes", type=float, default=60.0)
    parser.add_argument("--tool-budget-interval", type=int, default=10)
    parser.add_argument("--aggressive-free-gb", type=float, default=22.0)
    parser.add_argument("--max-mid-fires", type=int, default=5)
    parser.add_argument("--max-runtime-sec", type=int, default=120)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--always-fire", action="store_true")
    parser.add_argument("--tier18", action="store_true")
    parser.add_argument("--tier19", action="store_true")
    parser.add_argument("--enforce", action="store_true")
    parser.add_argument("--banner", action="store_true")
    parser.add_argument("--quiet", action="store_true")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--log-dry-run", action="store_true")
    parser.add_argument("--sample-free-gb", type=float)
    parser.add_argument("--sample-free-gb-after", type=float)
    parser.add_argument("--sample-cleanup-reclaim-mb", type=float)
    parser.add_argument("--sample-ram-pct", type=float)
    parser.add_argument("--sample-ram-pct-after", type=float)
    parser.add_argument("--sample-now")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    result = run_guard(args)

    if args.json:
        print(json.dumps(asdict(result), ensure_ascii=False, indent=2))
    elif not args.quiet or result.should_fire:
        if args.banner:
            print(result.banner)
        print(f"{result.mode}: {result.decision} ({result.reason})")
        if result.cleanup.status != "skipped":
            print(f"cleanup: {result.cleanup.status}; reclaim_mb={result.cleanup.actual_reclaim_mb:.1f}")

    if args.enforce:
        if result.cleanup.status in {"failed", "timeout", "missing_dev_cache_cleanup"}:
            return 1
        effective_free = result.c_free_gb_after if result.c_free_gb_after is not None else result.c_free_gb_before
        if effective_free < args.target_free_gb:
            return 2
        if not result.quota.passed:
            return 3
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
