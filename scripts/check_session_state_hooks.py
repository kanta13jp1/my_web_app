#!/usr/bin/env python3
"""Validate repo-managed session state hooks for Issue #1564.

The checker is dependency-free and intentionally parses files instead of
executing hooks. That keeps CI deterministic while still proving the PreCompact,
SessionStart, StatusLine, setup runbook, and transcript secret-scan contract.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


REQUIRED_FILES = [
    ".claude/hooks/pre-compact-backup.ps1",
    ".claude/hooks/post-tool-use-ai-antipatterns.ps1",
    ".claude/hooks/pretooluse-compression-budget.ps1",
    ".claude/hooks/session-end-auto-compress.ps1",
    ".claude/hooks/session-start-hard-gate.ps1",
    ".claude/hooks/session-start-state-check.ps1",
    ".claude/hooks/smartcleanup-monthlydeep-guard.ps1",
    ".claude/hooks/statusline.ps1",
    ".claude/hooks/userprompt-idle-gap-fire.ps1",
    ".claude/hooks/userprompt-kpi-banner.ps1",
    ".claude/settings.json",
    "docs/CLAUDE_CODE_SETUP_RUNBOOK.md",
    "memory/session-start-check/.gitignore",
    "memory/session-start-check/.gitkeep",
    "memory/transcripts/.gitignore",
    "memory/transcripts/.gitkeep",
    "scripts/session_compression_guard.py",
    "scripts/check_ai_code_antipatterns.py",
    "scripts/smartcleanup_task_guard.py",
]

SECRET_PATTERNS = [
    re.compile(r"gh[opsu]_[A-Za-z0-9_]{20,}"),
    re.compile(r"Bearer\s+[A-Za-z0-9._-]{20,}", re.IGNORECASE),
    re.compile(r"sk-[A-Za-z0-9_-]{20,}"),
    re.compile(r"sb_[A-Za-z0-9_]{20,}"),
    re.compile(
        r"(?i)\b[A-Z0-9_]*(PASSWORD|SECRET|TOKEN|KEY)[A-Z0-9_]*\s*=\s*(?!\[REDACTED\])[^\s,;]+"
    ),
]


def read_text(root: Path, relative: str) -> str:
    return (root / relative).read_text(encoding="utf-8-sig")


def require_contains(errors: list[str], text: str, needle: str, label: str) -> None:
    if needle not in text:
        errors.append(f"{label} missing `{needle}`")


def validate_settings(root: Path, errors: list[str]) -> None:
    settings_path = root / ".claude/settings.json"
    try:
        settings = json.loads(settings_path.read_text(encoding="utf-8-sig"))
    except json.JSONDecodeError as exc:
        errors.append(f".claude/settings.json is invalid JSON: {exc}")
        return

    status_line = settings.get("statusLine", {})
    command = str(status_line.get("command", ""))
    if "statusline.ps1" not in command:
        errors.append("settings.statusLine.command must reference statusline.ps1")

    session_hooks = settings.get("hooks", {}).get("SessionStart", [])
    commands = [
        str(hook.get("command", ""))
        for group in session_hooks
        for hook in group.get("hooks", [])
        if isinstance(group, dict)
    ]
    if not any("session-start-sync-rules.ps1" in command for command in commands):
        errors.append("SessionStart must keep session-start-sync-rules.ps1")
    if not any("session-start-hard-gate.ps1" in command for command in commands):
        errors.append("SessionStart must run session-start-hard-gate.ps1")
    if not any("smartcleanup-monthlydeep-guard.ps1" in command for command in commands):
        errors.append("SessionStart must run smartcleanup-monthlydeep-guard.ps1")
    if not any("session-start-state-check.ps1" in command for command in commands):
        errors.append("SessionStart must run session-start-state-check.ps1")

    userprompt_hooks = settings.get("hooks", {}).get("UserPromptSubmit", [])
    userprompt_commands = [
        str(hook.get("command", ""))
        for group in userprompt_hooks
        for hook in group.get("hooks", [])
        if isinstance(group, dict)
    ]
    if not any("userprompt-kpi-banner.ps1" in command for command in userprompt_commands):
        errors.append("UserPromptSubmit must run userprompt-kpi-banner.ps1")
    if not any("userprompt-idle-gap-fire.ps1" in command for command in userprompt_commands):
        errors.append("UserPromptSubmit must run userprompt-idle-gap-fire.ps1")

    pretooluse_hooks = settings.get("hooks", {}).get("PreToolUse", [])
    pretooluse_commands = [
        str(hook.get("command", ""))
        for group in pretooluse_hooks
        for hook in group.get("hooks", [])
        if isinstance(group, dict)
    ]
    if not any("pretooluse-compression-budget.ps1" in command for command in pretooluse_commands):
        errors.append("PreToolUse must run pretooluse-compression-budget.ps1")

    posttooluse_hooks = settings.get("hooks", {}).get("PostToolUse", [])
    posttooluse_commands = [
        str(hook.get("command", ""))
        for group in posttooluse_hooks
        for hook in group.get("hooks", [])
        if isinstance(group, dict)
    ]
    if not any(
        "post-tool-use-ai-antipatterns.ps1" in command
        for command in posttooluse_commands
    ):
        errors.append("PostToolUse must run post-tool-use-ai-antipatterns.ps1")

    stop_hooks = settings.get("hooks", {}).get("Stop", [])
    stop_commands = [
        str(hook.get("command", ""))
        for group in stop_hooks
        for hook in group.get("hooks", [])
        if isinstance(group, dict)
    ]
    if not any("session-end-auto-compress.ps1" in command for command in stop_commands):
        errors.append("Stop must run session-end-auto-compress.ps1")

    precompact_hooks = settings.get("hooks", {}).get("PreCompact", [])
    precompact_commands = [
        str(hook.get("command", ""))
        for group in precompact_hooks
        for hook in group.get("hooks", [])
        if isinstance(group, dict)
    ]
    if not any("pre-compact-backup.ps1" in command for command in precompact_commands):
        errors.append("PreCompact must run pre-compact-backup.ps1")


def validate_precompact(root: Path, errors: list[str]) -> None:
    text = read_text(root, ".claude/hooks/pre-compact-backup.ps1")
    label = "pre-compact-backup.ps1"
    for needle in [
        "function Redact-SessionText",
        "gh[opsu]_",
        "Bearer\\s+",
        "sk-",
        "sb_",
        "two_instance_policy",
        "next_quality_gates",
        "uncommitted_files",
        "unpushed_commits",
        "memory\\transcripts",
    ]:
        require_contains(errors, text, needle, label)


def validate_session_start(root: Path, errors: list[str]) -> None:
    text = read_text(root, ".claude/hooks/session-start-state-check.ps1")
    label = "session-start-state-check.ps1"
    for needle in [
        "Win Claude + Win Codex only",
        "codex2",
        "codex3",
        "rev-list",
        "status",
        "dirty_paths",
        "unpushed_commits",
        "memory\\next-quality-gate.txt",
        "codex_session_check.py",
        "memory\\session-start-check",
    ]:
        require_contains(errors, text, needle, label)


def validate_session_compression(root: Path, errors: list[str]) -> None:
    guard_text = read_text(root, "scripts/session_compression_guard.py")
    guard_label = "session_compression_guard.py"
    for needle in [
        "session_start_forced_fire",
        "pretooluse_budget_snapshot",
        "wrap_up_post",
        "session-delta.csv",
        "dev_cache_cleanup.py",
        "[KPI]",
        "SESSION_START_PHASE",
        "PRETOOLUSE_PHASE",
        "WRAP_UP_PHASE",
        "QuotaResult",
        "always-fire disk quota contract",
        "min_reclaim_mb",
    ]:
        require_contains(errors, guard_text, needle, guard_label)

    pretooluse_text = read_text(root, ".claude/hooks/pretooluse-compression-budget.ps1")
    pretooluse_label = "pretooluse-compression-budget.ps1"
    for needle in [
        "--mode\", \"pretooluse",
        "--tool-budget-interval\", \"10",
        "--aggressive-free-gb\", \"22",
        "--max-mid-fires\", \"5",
        "session_compression_guard.py",
    ]:
        require_contains(errors, pretooluse_text, needle, pretooluse_label)

    hard_gate_text = read_text(root, ".claude/hooks/session-start-hard-gate.ps1")
    hard_gate_label = "session-start-hard-gate.ps1"
    for needle in [
        "SESSION_COMPRESSION_FAIL_CLOSED",
        "SESSION_COMPRESSION_DRY_RUN",
        "--mode\", \"session-start",
        "--apply",
        "--always-fire",
        "--min-reclaim-mb\", \"512",
        "session_compression_guard.py",
    ]:
        require_contains(errors, hard_gate_text, needle, hard_gate_label)

    banner_text = read_text(root, ".claude/hooks/userprompt-kpi-banner.ps1")
    banner_label = "userprompt-kpi-banner.ps1"
    for needle in [
        "SESSION_COMPRESSION_USERPROMPT_APPLY",
        "--mode\", \"userprompt",
        "--max-age-minutes\", \"30",
        "session_compression_guard.py",
    ]:
        require_contains(errors, banner_text, needle, banner_label)

    idle_gap_text = read_text(root, ".claude/hooks/userprompt-idle-gap-fire.ps1")
    idle_gap_label = "userprompt-idle-gap-fire.ps1"
    for needle in [
        "--mode\", \"userprompt",
        "--apply",
        "--cooldown-minutes\", \"60",
        "session_compression_guard.py",
    ]:
        require_contains(errors, idle_gap_text, needle, idle_gap_label)

    wrap_up_text = read_text(root, ".claude/hooks/session-end-auto-compress.ps1")
    wrap_up_label = "session-end-auto-compress.ps1"
    for needle in [
        "SESSION_COMPRESSION_WRAPUP_ENFORCE",
        "--mode\", \"wrap-up",
        "--target-free-gb\", \"28",
        "--min-reclaim-mb\", \"512",
        "session_compression_guard.py",
    ]:
        require_contains(errors, wrap_up_text, needle, wrap_up_label)

    smartcleanup_text = read_text(root, ".claude/hooks/smartcleanup-monthlydeep-guard.ps1")
    smartcleanup_label = "smartcleanup-monthlydeep-guard.ps1"
    for needle in [
        "SmartCleanup_MonthlyDeep",
        "SMARTCLEANUP_MONTHLYDEEP_FIX",
        "SMARTCLEANUP_MONTHLYDEEP_ENFORCE",
        "smartcleanup_task_guard.py",
    ]:
        require_contains(errors, smartcleanup_text, needle, smartcleanup_label)

    smartcleanup_guard = read_text(root, "scripts/smartcleanup_task_guard.py")
    smartcleanup_guard_label = "smartcleanup_task_guard.py"
    for needle in [
        "TASK_NEVER_RAN_CODE = 267011",
        "last_run_time sentinel year <= 1999",
        "principal_user_id missing DOMAIN prefix",
        "Set-ScheduledTask",
        "Start-ScheduledTask",
        "SmartCleanup_MonthlyDeep",
    ]:
        require_contains(errors, smartcleanup_guard, needle, smartcleanup_guard_label)


def validate_statusline(root: Path, errors: list[str]) -> None:
    text = read_text(root, ".claude/hooks/statusline.ps1")
    label = "statusline.ps1"
    for needle in [
        "CLAUDE_INSTANCE",
        "memory\\active-issue.txt",
        "memory\\next-quality-gate.txt",
        "branch",
        "dirtyCount",
        "Write-Output",
    ]:
        require_contains(errors, text, needle, label)


def validate_runbook(root: Path, errors: list[str]) -> None:
    text = read_text(root, "docs/CLAUDE_CODE_SETUP_RUNBOOK.md")
    label = "CLAUDE_CODE_SETUP_RUNBOOK.md"
    for needle in [
        "Claude Code #1 and Codex #1",
        "`--init`",
        "`--maintenance`",
        "PreCompact Recovery",
        "SessionStart Recovery",
        "Session Compression Guard",
        "StatusLine",
        "Secret Handling",
        "python scripts/check_session_state_hooks.py",
    ]:
        require_contains(errors, text, needle, label)


def scan_transcripts(root: Path, errors: list[str]) -> None:
    transcript_dir = root / "memory/transcripts"
    if not transcript_dir.exists():
        errors.append("memory/transcripts directory is missing")
        return

    for path in transcript_dir.rglob("*"):
        if not path.is_file() or path.name == ".gitkeep":
            continue
        text = path.read_text(encoding="utf-8-sig", errors="replace")
        for pattern in SECRET_PATTERNS:
            match = pattern.search(text)
            if match:
                errors.append(f"{path.relative_to(root)} contains possible secret: {match.group(0)[:32]}")
                break


def validate(root: Path, scan: bool) -> list[str]:
    errors: list[str] = []
    for relative in REQUIRED_FILES:
        if not (root / relative).exists():
            errors.append(f"required file missing: {relative}")

    if errors:
        return errors

    validate_settings(root, errors)
    validate_precompact(root, errors)
    validate_session_start(root, errors)
    validate_session_compression(root, errors)
    validate_statusline(root, errors)
    validate_runbook(root, errors)
    if scan:
        scan_transcripts(root, errors)
    return errors


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--scan-transcripts",
        action="store_true",
        help="Scan memory/transcripts for known secret patterns.",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    root = Path(__file__).resolve().parents[1]
    errors = validate(root, scan=args.scan_transcripts)
    if errors:
        print("Session state hook validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Session state hook validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
