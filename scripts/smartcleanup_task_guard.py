#!/usr/bin/env python3
"""Detect and optionally repair a stuck SmartCleanup_MonthlyDeep task.

Issue #1564 v27 Layer GGG calls out a local Windows Task Scheduler failure mode:
`LastTaskResult = 267011` with a 1999-era `LastRunTime`, which means the monthly
deep cleanup task never actually ran. This checker is safe by default: it only
reports the task state unless `--fix` is passed.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


TASK_NEVER_RAN_CODE = 267011


@dataclass
class SmartCleanupTaskResult:
    task_name: str
    installed: bool
    status: str
    stuck: bool
    reasons: list[str]
    last_run_time: str
    last_task_result: int | None
    next_run_time: str
    state: str
    principal_user_id: str
    run_level: str
    logon_type: str
    fix_attempted: bool
    fix_result: str


def parse_dt(value: str | None) -> datetime | None:
    if not value:
        return None
    cleaned = str(value).strip()
    if not cleaned:
        return None
    for candidate in (cleaned, cleaned.replace("Z", "+00:00")):
        try:
            parsed = datetime.fromisoformat(candidate)
            if parsed.tzinfo is None:
                parsed = parsed.replace(tzinfo=timezone.utc)
            return parsed.astimezone(timezone.utc)
        except ValueError:
            continue
    return None


def normalize_int(value: Any) -> int | None:
    if value is None or value == "":
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def load_sample(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def collect_task_info(task_name: str) -> dict[str, Any]:
    if os.name != "nt":
        return {
            "installed": False,
            "state": "unsupported",
            "last_run_time": "",
            "last_task_result": None,
            "next_run_time": "",
            "error": "Windows Task Scheduler is only available on Windows",
        }

    ps = rf"""
$ErrorActionPreference = 'Stop'
$task = Get-ScheduledTask -TaskName '{task_name}' -ErrorAction SilentlyContinue
if (-not $task) {{
  [pscustomobject]@{{
    installed = $false
    state = 'missing'
    last_run_time = ''
    last_task_result = $null
    next_run_time = ''
  }} | ConvertTo-Json -Compress
  exit 0
}}
$info = Get-ScheduledTaskInfo -TaskName '{task_name}'
[pscustomobject]@{{
  installed = $true
  state = [string]$task.State
  principal_user_id = [string]$task.Principal.UserId
  run_level = [string]$task.Principal.RunLevel
  logon_type = [string]$task.Principal.LogonType
  last_run_time = if ($info.LastRunTime) {{ $info.LastRunTime.ToString('o') }} else {{ '' }}
  last_task_result = $info.LastTaskResult
  next_run_time = if ($info.NextRunTime) {{ $info.NextRunTime.ToString('o') }} else {{ '' }}
}} | ConvertTo-Json -Compress
"""
    proc = subprocess.run(
        ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        timeout=20,
    )
    if proc.returncode != 0:
        return {
            "installed": False,
            "state": "error",
            "last_run_time": "",
            "last_task_result": None,
            "next_run_time": "",
            "error": proc.stderr.strip() or proc.stdout.strip(),
        }
    return json.loads(proc.stdout or "{}")


def analyze_task(task_name: str, payload: dict[str, Any], max_age_days: float) -> SmartCleanupTaskResult:
    installed = bool(payload.get("installed"))
    state = str(payload.get("state") or "")
    principal_user_id = str(payload.get("principal_user_id") or "")
    run_level = str(payload.get("run_level") or "")
    logon_type = str(payload.get("logon_type") or "")
    last_run_time = str(payload.get("last_run_time") or "")
    next_run_time = str(payload.get("next_run_time") or "")
    last_task_result = normalize_int(payload.get("last_task_result"))
    reasons: list[str] = []

    parsed_last_run = parse_dt(last_run_time)
    never_ran = parsed_last_run is None or parsed_last_run.year <= 1999 or last_task_result == TASK_NEVER_RAN_CODE

    if not installed:
        reasons.append("task missing")
    elif never_ran and principal_user_id and "\\" not in principal_user_id and not principal_user_id.startswith("S-"):
        reasons.append("principal_user_id missing DOMAIN prefix")

    if installed and parsed_last_run is None:
        reasons.append("last_run_time missing")
    elif parsed_last_run is not None and parsed_last_run.year <= 1999:
        reasons.append("last_run_time sentinel year <= 1999")

    if last_task_result == TASK_NEVER_RAN_CODE:
        reasons.append("last_task_result 267011 indicates task has not run")
    elif last_task_result not in (None, 0, 267009):
        reasons.append(f"last_task_result {last_task_result} is non-zero")

    if parsed_last_run is not None and parsed_last_run.year > 1999:
        age_days = (datetime.now(timezone.utc) - parsed_last_run).total_seconds() / 86400.0
        if age_days > max_age_days:
            reasons.append(f"last_run_age {age_days:.1f}d > {max_age_days:.1f}d")

    stuck = bool(reasons)
    status = "stuck" if stuck else "ok"
    if not installed:
        status = "missing"
    return SmartCleanupTaskResult(
        task_name=task_name,
        installed=installed,
        status=status,
        stuck=stuck,
        reasons=reasons,
        last_run_time=last_run_time,
        last_task_result=last_task_result,
        next_run_time=next_run_time,
        state=state,
        principal_user_id=principal_user_id,
        run_level=run_level,
        logon_type=logon_type,
        fix_attempted=False,
        fix_result="not-requested",
    )


def start_task(task_name: str) -> str:
    if os.name != "nt":
        return "unsupported-non-windows"
    proc = subprocess.run(
        ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", f"Start-ScheduledTask -TaskName '{task_name}'"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        timeout=20,
    )
    if proc.returncode == 0:
        return "started"
    return "failed: " + (proc.stderr.strip() or proc.stdout.strip())


def repair_principal(task_name: str) -> str:
    if os.name != "nt":
        return "principal-repair-unsupported-non-windows"
    ps = rf"""
$ErrorActionPreference = 'Stop'
$task = Get-ScheduledTask -TaskName '{task_name}' -ErrorAction Stop
$userId = "$env:USERDOMAIN\$env:USERNAME"
$principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Limited
Set-ScheduledTask -TaskName '{task_name}' -Principal $principal -ErrorAction Stop | Out-Null
$updated = Get-ScheduledTask -TaskName '{task_name}' -ErrorAction Stop
$observed = [string]$updated.Principal.UserId
$expectedShort = "$env:USERNAME"
if ($observed -eq $userId) {{
  Write-Output "principal-updated:$userId"
}} elseif ($observed -eq $expectedShort) {{
  Write-Output "principal-repair-accepted-observed-short:$observed requested:$userId"
}} else {{
  throw "principal verification failed: $observed != $userId"
}}
"""
    proc = subprocess.run(
        ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        timeout=20,
    )
    if proc.returncode == 0:
        return (proc.stdout.strip() or "principal-updated")
    return "principal-repair-failed: " + (proc.stderr.strip() or proc.stdout.strip())


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--task-name", default="SmartCleanup_MonthlyDeep")
    parser.add_argument("--max-age-days", type=float, default=35.0)
    parser.add_argument("--sample-json", type=Path)
    parser.add_argument("--fix", action="store_true")
    parser.add_argument("--enforce", action="store_true")
    parser.add_argument("--json", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    payload = load_sample(args.sample_json) if args.sample_json else collect_task_info(args.task_name)
    result = analyze_task(args.task_name, payload, args.max_age_days)

    if args.fix and result.installed and result.stuck:
        result.fix_attempted = True
        fixes: list[str] = []
        if "principal_user_id missing DOMAIN prefix" in result.reasons:
            fixes.append(repair_principal(args.task_name))
        fixes.append(start_task(args.task_name))
        result.fix_result = "; ".join(fixes)

    if args.json:
        print(json.dumps(asdict(result), ensure_ascii=False, indent=2))
    else:
        reason = "; ".join(result.reasons) if result.reasons else "healthy"
        print(f"{result.task_name}: {result.status} ({reason})")
        if result.fix_attempted:
            print(f"fix: {result.fix_result}")

    if args.enforce and result.stuck:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
