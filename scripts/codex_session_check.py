#!/usr/bin/env python3
"""Print a Codex session-start safety report.

The check is intentionally dependency-free so it can run in Codex desktop,
Codex CLI, Claude Code hooks, or GitHub Actions. It does not try to infer
private Codex app state; it records the repo/worktree facts that make parallel
agent work safe or risky.
"""

from __future__ import annotations

import argparse
import ctypes
import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any


GIB = 1024 ** 3
RESOURCE_RAM_USED_WARN_PCT = 85.0
RESOURCE_RAM_FREE_WARN_GB = 2.0
RESOURCE_DISK_FREE_WARN_GB = 26.0
RESOURCE_WORKTREE_REVIEW_COUNT = 50


@dataclass(frozen=True)
class CommandResult:
    code: int
    stdout: str
    stderr: str


def run_git(args: list[str], cwd: Path) -> CommandResult:
    proc = subprocess.run(
        ["git", *args],
        cwd=str(cwd),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    return CommandResult(proc.returncode, proc.stdout.strip(), proc.stderr.strip())


def run_command(
    args: list[str],
    cwd: Path,
    timeout_seconds: int | None = None,
) -> CommandResult:
    try:
        proc = subprocess.run(
            args,
            cwd=str(cwd),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            timeout=timeout_seconds,
        )
    except FileNotFoundError as exc:
        return CommandResult(127, "", str(exc))
    except PermissionError as exc:
        return CommandResult(126, "", str(exc))
    except OSError as exc:
        return CommandResult(126, "", str(exc))
    except subprocess.TimeoutExpired as exc:
        return CommandResult(
            124,
            (exc.stdout or "").strip() if isinstance(exc.stdout, str) else "",
            f"timed out after {timeout_seconds}s",
        )
    return CommandResult(proc.returncode, proc.stdout.strip(), proc.stderr.strip())


def git_text(args: list[str], cwd: Path, default: str = "") -> str:
    result = run_git(args, cwd)
    if result.code != 0:
        return default
    return result.stdout


def git_root(cwd: Path) -> Path:
    root = git_text(["rev-parse", "--show-toplevel"], cwd)
    if not root:
        raise RuntimeError("not inside a git repository")
    return Path(root)


def upstream_name(root: Path) -> str | None:
    upstream = git_text(["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"], root)
    return upstream or None


def ahead_behind(root: Path, upstream: str | None) -> tuple[int | None, int | None]:
    if not upstream:
        return None, None
    counts = git_text(["rev-list", "--left-right", "--count", f"HEAD...{upstream}"], root)
    if not counts:
        return None, None
    left, right = counts.split()
    return int(left), int(right)


def worktree_entries(root: Path) -> list[dict[str, str]]:
    raw = git_text(["worktree", "list", "--porcelain"], root)
    entries: list[dict[str, str]] = []
    current: dict[str, str] = {}
    for line in raw.splitlines():
        if not line:
            if current:
                entries.append(current)
                current = {}
            continue
        key, _, value = line.partition(" ")
        current[key] = value
    if current:
        entries.append(current)
    return entries


def physical_memory_snapshot() -> dict[str, float | str | None]:
    """Return a dependency-free physical-memory snapshot when supported."""

    total_bytes: int | None = None
    free_bytes: int | None = None
    source = "unavailable"

    if os.name == "nt":
        class MemoryStatusEx(ctypes.Structure):
            _fields_ = [
                ("dwLength", ctypes.c_ulong),
                ("dwMemoryLoad", ctypes.c_ulong),
                ("ullTotalPhys", ctypes.c_ulonglong),
                ("ullAvailPhys", ctypes.c_ulonglong),
                ("ullTotalPageFile", ctypes.c_ulonglong),
                ("ullAvailPageFile", ctypes.c_ulonglong),
                ("ullTotalVirtual", ctypes.c_ulonglong),
                ("ullAvailVirtual", ctypes.c_ulonglong),
                ("ullAvailExtendedVirtual", ctypes.c_ulonglong),
            ]

        status = MemoryStatusEx()
        status.dwLength = ctypes.sizeof(MemoryStatusEx)
        try:
            if ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(status)):
                total_bytes = int(status.ullTotalPhys)
                free_bytes = int(status.ullAvailPhys)
                source = "GlobalMemoryStatusEx"
        except (AttributeError, OSError):
            pass
    elif hasattr(os, "sysconf"):
        try:
            page_size = int(os.sysconf("SC_PAGE_SIZE"))
            total_bytes = int(os.sysconf("SC_PHYS_PAGES")) * page_size
            free_bytes = int(os.sysconf("SC_AVPHYS_PAGES")) * page_size
            source = "sysconf"
        except (OSError, TypeError, ValueError):
            total_bytes = None
            free_bytes = None

    if not total_bytes or free_bytes is None:
        return {
            "source": source,
            "total_gb": None,
            "free_gb": None,
            "used_pct": None,
        }

    free_bytes = max(0, min(free_bytes, total_bytes))
    return {
        "source": source,
        "total_gb": round(total_bytes / GIB, 2),
        "free_gb": round(free_bytes / GIB, 2),
        "used_pct": round((1 - (free_bytes / total_bytes)) * 100, 1),
    }


def resource_budget_snapshot(
    root: Path,
    worktrees: list[dict[str, str]],
) -> dict[str, Any]:
    memory = physical_memory_snapshot()
    disk_root = Path(root.anchor) if root.anchor else root
    try:
        disk = shutil.disk_usage(disk_root)
        disk_total_gb: float | None = round(disk.total / GIB, 2)
        disk_free_gb: float | None = round(disk.free / GIB, 2)
    except OSError:
        disk_total_gb = None
        disk_free_gb = None

    ram_used_pct = memory["used_pct"]
    ram_free_gb = memory["free_gb"]
    parallel_gate = "unknown"
    if isinstance(ram_used_pct, (int, float)) and isinstance(ram_free_gb, (int, float)):
        parallel_gate = (
            "allow"
            if ram_used_pct < RESOURCE_RAM_USED_WARN_PCT
            and ram_free_gb > RESOURCE_RAM_FREE_WARN_GB
            else "hold"
        )

    return {
        "memory": memory,
        "disk_path": str(disk_root),
        "disk_total_gb": disk_total_gb,
        "disk_free_gb": disk_free_gb,
        "registered_worktrees": len(worktrees),
        "parallel_agent_gate": parallel_gate,
        "thresholds": {
            "ram_used_warn_pct": RESOURCE_RAM_USED_WARN_PCT,
            "ram_free_warn_gb": RESOURCE_RAM_FREE_WARN_GB,
            "disk_free_warn_gb": RESOURCE_DISK_FREE_WARN_GB,
            "worktree_review_count": RESOURCE_WORKTREE_REVIEW_COUNT,
        },
    }


def resource_budget_warnings(snapshot: dict[str, Any]) -> list[str]:
    warnings: list[str] = []
    memory = snapshot["memory"]
    used_pct = memory["used_pct"]
    free_gb = memory["free_gb"]
    thresholds = snapshot["thresholds"]

    if used_pct is None or free_gb is None:
        warnings.append("physical memory resource budget is unavailable")
    else:
        if used_pct >= thresholds["ram_used_warn_pct"]:
            warnings.append(
                f"RAM usage {used_pct:.1f}% is at or above "
                f"{thresholds['ram_used_warn_pct']:.1f}%; hold parallel/heavy work"
            )
        if free_gb <= thresholds["ram_free_warn_gb"]:
            warnings.append(
                f"free RAM {free_gb:.2f} GB is at or below "
                f"{thresholds['ram_free_warn_gb']:.2f} GB; hold parallel/heavy work"
            )

    disk_free_gb = snapshot["disk_free_gb"]
    if disk_free_gb is None:
        warnings.append("disk resource budget is unavailable")
    elif disk_free_gb < thresholds["disk_free_warn_gb"]:
        warnings.append(
            f"free disk {disk_free_gb:.2f} GB is below "
            f"{thresholds['disk_free_warn_gb']:.2f} GB"
        )

    worktree_count = snapshot["registered_worktrees"]
    if worktree_count >= thresholds["worktree_review_count"]:
        warnings.append(
            f"registered worktree count {worktree_count} is at or above review threshold "
            f"{thresholds['worktree_review_count']}; audit keep/remove status before cleanup"
        )

    return warnings


def env_snapshot() -> dict[str, str]:
    keys = [
        "CODEX_SANDBOX",
        "CODEX_APPROVAL_POLICY",
        "SANDBOX_MODE",
        "APPROVAL_POLICY",
        "MCP_SANDBOX",
    ]
    return {key: os.environ.get(key, "not-exposed") for key in keys}


def cli_version(command: str, root: Path) -> str:
    result = run_command([command, "--version"], root)
    if result.code != 0 and os.name == "nt":
        result = run_command([f"{command}.cmd", "--version"], root)
    if result.code != 0:
        return "unavailable"
    return result.stdout or result.stderr or "unknown"


def codex_cli_version(root: Path) -> str:
    return cli_version("codex", root)


def claude_code_version(root: Path) -> str:
    return cli_version("claude", root)


def default_claude_settings_path() -> Path:
    override = os.environ.get("CLAUDE_SETTINGS_PATH")
    if override:
        return Path(override)
    return Path.home() / ".claude" / "settings.json"


def normalized_key_path(path: list[str]) -> str:
    return ".".join(path).lower().replace("_", "").replace("-", "").replace(" ", "")


def is_remote_control_flag_path(path: list[str]) -> bool:
    normalized = normalized_key_path(path)
    if "remotecontrol" not in normalized:
        return False
    return any(
        token in normalized
        for token in [
            "enable",
            "enabled",
            "allsessions",
            "autosession",
            "always",
        ]
    )


def collect_remote_control_flags(
    value: Any,
    path: list[str] | None = None,
) -> list[tuple[list[str], bool]]:
    current_path = path or []
    flags: list[tuple[list[str], bool]] = []
    if isinstance(value, dict):
        for key, item in value.items():
            flags.extend(collect_remote_control_flags(item, [*current_path, str(key)]))
    elif isinstance(value, list):
        for index, item in enumerate(value):
            flags.extend(collect_remote_control_flags(item, [*current_path, str(index)]))
    elif isinstance(value, bool) and is_remote_control_flag_path(current_path):
        flags.append((current_path, value))
    return flags


def analyze_claude_remote_control(
    root: Path,
    settings_path: Path | None = None,
) -> dict[str, Any]:
    path = settings_path or default_claude_settings_path()
    version = claude_code_version(root)
    status = "unknown"
    evidence = "No known Remote Control all-sessions setting was found."
    settings_state = "missing"
    flag_path: str | None = None

    if path.exists():
        settings_state = "found"
        try:
            data = json.loads(path.read_text(encoding="utf-8-sig"))
            flags = collect_remote_control_flags(data)
            true_flags = [item for item in flags if item[1]]
            false_flags = [item for item in flags if not item[1]]
            if true_flags:
                status = "enabled"
                flag_path = ".".join(true_flags[0][0])
                evidence = f"Detected true setting at `{flag_path}`."
            elif false_flags:
                status = "disabled"
                flag_path = ".".join(false_flags[0][0])
                evidence = f"Detected false setting at `{flag_path}`."
        except json.JSONDecodeError as exc:
            settings_state = "invalid-json"
            evidence = f"Could not parse Claude settings JSON: {exc}"
        except OSError as exc:
            settings_state = "unreadable"
            evidence = f"Could not read Claude settings: {exc}"

    return {
        "version": version,
        "settings_path": str(path),
        "settings_state": settings_state,
        "all_sessions_status": status,
        "flag_path": flag_path,
        "evidence": evidence,
        "manual_steps": [
            "Open Claude Code locally.",
            "Run `/config`.",
            "Set `Enable Remote Control for all sessions` to `true`.",
            "Start a normal interactive session and verify it appears in `claude.ai/code`.",
        ],
        "admin_note": (
            "Team/Enterprise plans also require an admin to enable the Remote Control "
            "toggle in Claude Code admin settings."
        ),
    }


def notebooklm_snapshot(root: Path) -> dict[str, Any]:
    harness_notebook_id = "bc58b50b-5fc4-4840-9a62-b397d6d3b65a"
    result = run_command(["notebooklm", "list", "--json"], root, timeout_seconds=20)
    combined = "\n".join(part for part in [result.stdout, result.stderr] if part)
    detail = combined.splitlines()[0] if combined else ""
    notebook_ids: list[str] = []
    notebook_count = 0
    harness_notebook_title = ""
    if result.code == 0:
        try:
            payload = json.loads(result.stdout)
            notebooks = payload.get("notebooks", [])
            if isinstance(notebooks, list):
                for notebook in notebooks:
                    if not isinstance(notebook, dict) or not notebook.get("id"):
                        continue
                    notebook_id = str(notebook["id"])
                    notebook_ids.append(notebook_id)
                    if notebook_id == harness_notebook_id:
                        harness_notebook_title = str(notebook.get("title", ""))
                notebook_ids = sorted(set(notebook_ids))
                notebook_count = int(payload.get("count", len(notebook_ids)))
                if notebook_count:
                    if harness_notebook_title:
                        detail = (
                            f"notebooks={notebook_count}; "
                            f"harness_title={harness_notebook_title}"
                        )
                    else:
                        detail = f"notebooks={notebook_count}; harness_notebook_missing"
        except (json.JSONDecodeError, TypeError, ValueError):
            notebook_ids = []
    if not notebook_ids:
        notebook_ids = sorted(
            set(
                re.findall(
                    r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}",
                    combined,
                    flags=re.IGNORECASE,
                )
            )
        )
        notebook_count = len(notebook_ids)

    lowered = combined.lower()
    if result.code == 0:
        state = "ok"
    elif result.code == 127 and os.environ.get("GITHUB_ACTIONS") == "true":
        state = "skipped_ci_unavailable"
        if not detail:
            detail = "NotebookLM CLI is not installed on this GitHub Actions runner."
    elif result.code == 127:
        state = "unavailable"
    elif result.code == 124:
        state = "timeout"
    elif "notebooklm login" in lowered or "authentication expired" in lowered:
        state = "auth_required"
    elif "connection attempts failed" in lowered or "connection refused" in lowered:
        state = "network_error"
    else:
        state = "error"

    return {
        "state": state,
        "exit_code": result.code,
        "harness_notebook_id": harness_notebook_id,
        "harness_notebook_title": harness_notebook_title,
        "harness_notebook_found": harness_notebook_id in notebook_ids,
        "notebook_count": notebook_count,
        "detail": detail[:240],
    }


def managed_mcp_snapshot(root: Path) -> dict[str, Any]:
    config_path = root / "config" / "managed-mcp.json"
    if not config_path.exists():
        return {
            "state": "missing",
            "config": str(config_path),
            "validation_errors": ["config/managed-mcp.json is missing"],
            "session_findings": [],
            "session_warning_count": 0,
            "session_error_count": 0,
        }
    try:
        from check_managed_mcp_policy import (
            default_session_paths,
            load_policy,
            session_findings,
            validate_policy,
        )
    except Exception as exc:
        return {
            "state": "unavailable",
            "config": str(config_path),
            "validation_errors": [f"could not import managed MCP checker: {exc}"],
            "session_findings": [],
            "session_warning_count": 0,
            "session_error_count": 0,
        }
    try:
        policy = load_policy(config_path)
        validation_errors = validate_policy(policy)
        findings = session_findings(
            policy,
            default_session_paths(root, include_home=True),
        )
    except Exception as exc:
        return {
            "state": "error",
            "config": str(config_path),
            "validation_errors": [f"managed MCP check failed: {exc}"],
            "session_findings": [],
            "session_warning_count": 0,
            "session_error_count": 0,
        }
    return {
        "state": "ok" if not validation_errors else "invalid",
        "config": str(config_path),
        "validation_errors": validation_errors,
        "session_findings": [asdict(finding) for finding in findings],
        "session_warning_count": sum(1 for finding in findings if finding.severity == "warning"),
        "session_error_count": sum(1 for finding in findings if finding.severity == "error"),
    }


def context_injection_snapshot(root: Path) -> dict[str, Any]:
    try:
        from context_injection_check import build_session_snapshot
    except Exception as exc:
        return {
            "state": "unavailable",
            "config": "config/context-injection-map.json",
            "issue": 1644,
            "route_count": 0,
            "matched_route_ids": [],
            "validation_errors": [f"could not import context injection checker: {exc}"],
            "notebooklm": {
                "harness_notebook_id": "bc58b50b-5fc4-4840-9a62-b397d6d3b65a",
                "harness_found": False,
                "notebook_count": 0,
                "candidate_issue_drafts": 0,
                "issue_drafts_state": "unknown",
            },
            "proposal_policy": {},
        }
    try:
        snapshot = build_session_snapshot(root)
    except Exception as exc:
        return {
            "state": "error",
            "config": "config/context-injection-map.json",
            "issue": 1644,
            "route_count": 0,
            "matched_route_ids": [],
            "validation_errors": [f"context injection check failed: {exc}"],
            "notebooklm": {
                "harness_notebook_id": "bc58b50b-5fc4-4840-9a62-b397d6d3b65a",
                "harness_found": False,
                "notebook_count": 0,
                "candidate_issue_drafts": 0,
                "issue_drafts_state": "unknown",
            },
            "proposal_policy": {},
        }

    return {
        "state": snapshot["state"],
        "config": snapshot["config"],
        "issue": snapshot["issue"],
        "route_count": snapshot["routeCount"],
        "matched_route_ids": [route["id"] for route in snapshot["matchedRoutes"]],
        "validation_errors": snapshot["validation_errors"],
        "notebooklm": snapshot["notebooklm"],
        "proposal_policy": snapshot["proposalPolicy"],
    }


def first_nonempty_line(path: Path) -> str:
    if not path.exists():
        return ""
    try:
        for line in path.read_text(encoding="utf-8-sig").splitlines():
            stripped = line.strip()
            if stripped:
                return stripped
    except OSError:
        return ""
    return ""


def latest_matching_file(root: Path, pattern: str) -> str:
    try:
        matches = sorted(
            root.glob(pattern),
            key=lambda item: item.stat().st_mtime,
            reverse=True,
        )
    except OSError:
        matches = []
    if not matches:
        return ""
    try:
        return str(matches[0].relative_to(root))
    except ValueError:
        return str(matches[0])


def session_state_snapshot(root: Path) -> dict[str, Any]:
    transcript_dir = root / "memory" / "transcripts"
    session_check_dir = root / "memory" / "session-start-check"
    return {
        "active_issue": first_nonempty_line(root / "memory" / "active-issue.txt"),
        "next_quality_gate": first_nonempty_line(root / "memory" / "next-quality-gate.txt"),
        "transcripts_dir": str(transcript_dir),
        "latest_compact_backup": latest_matching_file(root, "memory/transcripts/compact-*.md"),
        "latest_session_start_log": latest_matching_file(
            root,
            "memory/session-start-check/session-start-*.log",
        ),
        "precompact_hook": ".claude/hooks/pre-compact-backup.ps1",
        "session_start_hook": ".claude/hooks/session-start-state-check.ps1",
        "statusline_hook": ".claude/hooks/statusline.ps1",
        "setup_runbook": "docs/CLAUDE_CODE_SETUP_RUNBOOK.md",
    }


def parse_semver(text: str) -> tuple[int, int, int] | None:
    match = re.search(r"(\d+)\.(\d+)\.(\d+)", text)
    if not match:
        return None
    return int(match.group(1)), int(match.group(2)), int(match.group(3))


def analyze(cwd: Path) -> dict[str, Any]:
    root = git_root(cwd)
    branch = git_text(["branch", "--show-current"], root, default="detached")
    head = git_text(["rev-parse", "--short", "HEAD"], root)
    origin_main = git_text(["rev-parse", "--short", "origin/main"], root, default="unknown")
    upstream = upstream_name(root)
    ahead, behind = ahead_behind(root, upstream)
    dirty = git_text(["status", "--porcelain"], root)
    dirty_lines = [line for line in dirty.splitlines() if line.strip()]
    remote_url = git_text(["remote", "get-url", "origin"], root, default="unknown")
    worktrees = worktree_entries(root)
    resource_budget = resource_budget_snapshot(root, worktrees)
    codex_version = codex_cli_version(root)
    notebooklm = notebooklm_snapshot(root)
    claude_remote_control = analyze_claude_remote_control(root)
    managed_mcp = managed_mcp_snapshot(root)
    context_injection = context_injection_snapshot(root)
    session_state = session_state_snapshot(root)

    warnings: list[str] = []
    warnings.extend(resource_budget_warnings(resource_budget))
    if dirty_lines:
        warnings.append(f"working tree has {len(dirty_lines)} uncommitted path(s)")
    if not upstream:
        warnings.append("branch has no upstream")
    elif ahead is None or behind is None:
        warnings.append(f"upstream `{upstream}` could not be compared")
    else:
        if behind:
            warnings.append(f"branch is behind upstream by {behind} commit(s)")
        if ahead:
            warnings.append(f"branch is ahead of upstream by {ahead} commit(s)")
    if branch in {"main", "master"}:
        warnings.append("current branch is a protected base branch")
    if origin_main == "unknown":
        warnings.append("origin/main is unavailable; run git fetch origin main")
    parsed_codex_version = parse_semver(codex_version)
    if codex_version == "unavailable":
        warnings.append("Codex CLI is unavailable on PATH")
    elif parsed_codex_version and parsed_codex_version < (0, 128, 0):
        warnings.append(
            "Codex CLI is older than 0.128.0; persisted `/goal` workflows are not ready"
        )
    if notebooklm["state"] == "auth_required":
        warnings.append("NotebookLM CLI auth is expired; run `notebooklm login`")
    elif notebooklm["state"] == "unavailable":
        warnings.append("NotebookLM CLI is unavailable on PATH")
    elif notebooklm["state"] == "timeout":
        warnings.append("NotebookLM CLI list timed out")
    elif notebooklm["state"] == "network_error":
        warnings.append("NotebookLM CLI list hit a network/browser connection error")
    elif notebooklm["state"] == "error":
        warnings.append("NotebookLM CLI list failed")
    elif notebooklm["state"] == "skipped_ci_unavailable":
        pass
    elif not notebooklm["harness_notebook_found"]:
        warnings.append(
            "NotebookLM harness notebook bc58b50b-5fc4-4840-9a62-b397d6d3b65a was not found"
        )
    claude_version = claude_remote_control["version"]
    parsed_claude_version = parse_semver(claude_version)
    if claude_version == "unavailable":
        warnings.append("Claude Code CLI is unavailable on PATH; Remote Control cannot be verified")
    elif parsed_claude_version and parsed_claude_version < (2, 1, 79):
        warnings.append("Claude Code is older than 2.1.79; Remote Control slash command support is not ready")
    if claude_remote_control["all_sessions_status"] != "enabled":
        warnings.append(
            "Claude Code Remote Control all-sessions mode is not verified as enabled; run `/config` in Claude Code"
        )
    if managed_mcp["validation_errors"]:
        warnings.append("managed MCP policy validation failed")
    for finding in managed_mcp["session_findings"][:12]:
        warnings.append(f"managed MCP {finding['kind']}: {finding['message']}")
    if len(managed_mcp["session_findings"]) > 12:
        warnings.append(
            f"managed MCP additional findings truncated: {len(managed_mcp['session_findings']) - 12}"
        )
    if context_injection["validation_errors"]:
        warnings.append("dynamic context injection map validation failed")
    if context_injection["state"] not in {"ok"}:
        warnings.append(f"dynamic context injection state is {context_injection['state']}")

    return {
        "root": str(root),
        "branch": branch,
        "head": head,
        "origin_main": origin_main,
        "upstream": upstream,
        "ahead": ahead,
        "behind": behind,
        "dirty_count": len(dirty_lines),
        "dirty_paths": dirty_lines[:20],
        "remote": remote_url,
        "codex_cli_version": codex_version,
        "notebooklm": notebooklm,
        "claude_remote_control": claude_remote_control,
        "managed_mcp": managed_mcp,
        "context_injection": context_injection,
        "session_state": session_state,
        "resource_budget": resource_budget,
        "worktrees": worktrees,
        "environment": env_snapshot(),
        "warnings": warnings,
    }


def render_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# Codex Session Check",
        "",
        f"- Repo: `{report['root']}`",
        f"- Branch: `{report['branch']}`",
        f"- HEAD: `{report['head']}`",
        f"- origin/main: `{report['origin_main']}`",
        f"- Upstream: `{report['upstream'] or 'none'}`",
        f"- Ahead/behind: `{report['ahead'] if report['ahead'] is not None else '?'} / {report['behind'] if report['behind'] is not None else '?'}`",
        f"- Dirty paths: `{report['dirty_count']}`",
        f"- Remote: `{report['remote']}`",
        f"- Codex CLI: `{report['codex_cli_version']}`",
        "",
        "## Resource Budget",
        f"- RAM used: `{report['resource_budget']['memory']['used_pct'] if report['resource_budget']['memory']['used_pct'] is not None else 'unknown'}%`",
        f"- RAM free / total: `{report['resource_budget']['memory']['free_gb'] if report['resource_budget']['memory']['free_gb'] is not None else 'unknown'} / {report['resource_budget']['memory']['total_gb'] if report['resource_budget']['memory']['total_gb'] is not None else 'unknown'} GB`",
        f"- Disk free / total ({report['resource_budget']['disk_path']}): `{report['resource_budget']['disk_free_gb'] if report['resource_budget']['disk_free_gb'] is not None else 'unknown'} / {report['resource_budget']['disk_total_gb'] if report['resource_budget']['disk_total_gb'] is not None else 'unknown'} GB`",
        f"- Registered worktrees: `{report['resource_budget']['registered_worktrees']}`",
        f"- Parallel/heavy-work gate (single sample): `{report['resource_budget']['parallel_agent_gate']}`",
        f"- Thresholds: RAM `< {report['resource_budget']['thresholds']['ram_used_warn_pct']}%` and `> {report['resource_budget']['thresholds']['ram_free_warn_gb']} GB free`; disk `>= {report['resource_budget']['thresholds']['disk_free_warn_gb']} GB free`; worktree review `>= {report['resource_budget']['thresholds']['worktree_review_count']}`",
        "",
        "## Permission / Sandbox Snapshot",
    ]
    for key, value in report["environment"].items():
        lines.append(f"- `{key}`: `{value}`")

    notebooklm = report["notebooklm"]
    lines.extend([
        "",
        "## NotebookLM Snapshot",
        f"- State: `{notebooklm['state']}`",
        f"- Harness notebook: `{notebooklm['harness_notebook_id']}`",
        f"- Harness title: `{notebooklm['harness_notebook_title'] or 'unknown'}`",
        f"- Harness found: `{notebooklm['harness_notebook_found']}`",
        f"- Notebook count: `{notebooklm['notebook_count']}`",
    ])
    if notebooklm["detail"]:
        lines.append(f"- Detail: `{notebooklm['detail']}`")

    remote = report["claude_remote_control"]
    lines.extend(
        [
            "",
            "## Claude Code Remote Control",
            f"- Claude Code CLI: `{remote['version']}`",
            f"- Settings: `{remote['settings_path']}` ({remote['settings_state']})",
            f"- All-session Remote Control: `{remote['all_sessions_status']}`",
            f"- Evidence: {remote['evidence']}",
        ]
    )
    if remote["all_sessions_status"] != "enabled":
        lines.append("- Required manual steps:")
        for step in remote["manual_steps"]:
            lines.append(f"  - {step}")
        lines.append(f"- Team/Enterprise note: {remote['admin_note']}")

    managed_mcp = report["managed_mcp"]
    lines.extend(
        [
            "",
            "## Managed MCP Policy",
            f"- State: `{managed_mcp['state']}`",
            f"- Config: `{managed_mcp['config']}`",
            f"- Validation errors: `{len(managed_mcp['validation_errors'])}`",
            f"- Session warnings/errors: `{managed_mcp['session_warning_count']} / {managed_mcp['session_error_count']}`",
        ]
    )
    for finding in managed_mcp["session_findings"][:8]:
        lines.append(
            f"- `{finding['severity']}` `{finding['kind']}` `{finding['server']}`: {finding['message']}"
        )

    context_injection = report["context_injection"]
    context_notebooklm = context_injection["notebooklm"]
    lines.extend(
        [
            "",
            "## Dynamic Context Injection",
            f"- State: `{context_injection['state']}`",
            f"- Config: `{context_injection['config']}`",
            f"- Issue: `#{context_injection['issue']}`",
            f"- Routes configured: `{context_injection['route_count']}`",
            f"- Session default routes: `{', '.join(context_injection['matched_route_ids']) or 'none'}`",
            f"- Harness notebook: `{context_notebooklm['harness_notebook_id']}`",
            f"- Harness found in intake snapshot: `{context_notebooklm['harness_found']}`",
            f"- Notebook count: `{context_notebooklm['notebook_count']}`",
            f"- Unapplied NotebookLM candidates: `{context_notebooklm['candidate_issue_drafts']}`",
            f"- Issue drafts state: `{context_notebooklm['issue_drafts_state']}`",
            "- Proposal rule: distill NotebookLM output and connect it to a GitHub Issue, PR body, or existing Issue comment.",
        ]
    )
    for failure in context_injection["validation_errors"][:8]:
        lines.append(f"- Validation failure: {failure}")

    session_state = report["session_state"]
    lines.extend(
        [
            "",
            "## Session State Recovery",
            f"- Active issue marker: `{session_state['active_issue'] or 'none'}`",
            f"- Next quality gate: `{session_state['next_quality_gate'] or 'none'}`",
            f"- Latest compact backup: `{session_state['latest_compact_backup'] or 'none'}`",
            f"- Latest SessionStart log: `{session_state['latest_session_start_log'] or 'none'}`",
            f"- PreCompact hook: `{session_state['precompact_hook']}`",
            f"- SessionStart hook: `{session_state['session_start_hook']}`",
            f"- StatusLine hook: `{session_state['statusline_hook']}`",
            f"- Setup runbook: `{session_state['setup_runbook']}`",
        ]
    )

    lines.extend(["", "## Warnings"])
    if report["warnings"]:
        for warning in report["warnings"]:
            lines.append(f"- {warning}")
    else:
        lines.append("- No blocking session-start warnings.")

    lines.extend(["", "## Worktrees"])
    for entry in report["worktrees"][:12]:
        path = entry.get("worktree", "unknown")
        branch = entry.get("branch", "detached")
        head = entry.get("HEAD", "unknown")[:12]
        lines.append(f"- `{path}` — `{branch}` @ `{head}`")

    return "\n".join(lines) + "\n"


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="Print JSON instead of Markdown.")
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit non-zero when the session has warnings.",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    args = parse_args(argv)
    report = analyze(Path.cwd())
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(render_markdown(report))
    return 1 if args.strict and report["warnings"] else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
