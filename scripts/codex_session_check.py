#!/usr/bin/env python3
"""Print a Codex session-start safety report.

The check is intentionally dependency-free so it can run in Codex desktop,
Codex CLI, Claude Code hooks, or GitHub Actions. It does not try to infer
private Codex app state; it records the repo/worktree facts that make parallel
agent work safe or risky.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


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


def run_command(args: list[str], cwd: Path) -> CommandResult:
    try:
        proc = subprocess.run(
            args,
            cwd=str(cwd),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
    except FileNotFoundError as exc:
        return CommandResult(127, "", str(exc))
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


def env_snapshot() -> dict[str, str]:
    keys = [
        "CODEX_SANDBOX",
        "CODEX_APPROVAL_POLICY",
        "SANDBOX_MODE",
        "APPROVAL_POLICY",
        "MCP_SANDBOX",
    ]
    return {key: os.environ.get(key, "not-exposed") for key in keys}


def codex_cli_version(root: Path) -> str:
    result = run_command(["codex", "--version"], root)
    if result.code != 0:
        return "unavailable"
    return result.stdout or result.stderr or "unknown"


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
    codex_version = codex_cli_version(root)

    warnings: list[str] = []
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
        "## Permission / Sandbox Snapshot",
    ]
    for key, value in report["environment"].items():
        lines.append(f"- `{key}`: `{value}`")

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
