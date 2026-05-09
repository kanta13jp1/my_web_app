#!/usr/bin/env python3
"""Safely detect and prune stale git worktrees.

The default mode is a dry-run report. Use --apply to remove only worktrees that
pass every guard:

- not the current working directory
- not the main worktree
- attached to a non-main branch
- no uncommitted files
- no open pull request for the branch
- HEAD matches its upstream
- HEAD is already contained in the selected base ref

This intentionally stays dependency-free so it can run from Windows app
sessions, GitHub Actions, or local scheduled tasks.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any


DEFAULT_BASE_REF = "origin/main"
DEFAULT_SKIP_BRANCHES = {"main", "master", "develop", "staging"}
DEFAULT_TIER1_SKIP_PREFIXES = ("codex/",)


@dataclass(frozen=True)
class CommandResult:
    code: int
    stdout: str
    stderr: str


@dataclass(frozen=True)
class WorktreeEntry:
    path: str
    head: str
    branch_ref: str
    detached: bool
    bare: bool
    locked: bool

    @property
    def branch(self) -> str:
        if not self.branch_ref:
            return ""
        prefix = "refs/heads/"
        if self.branch_ref.startswith(prefix):
            return self.branch_ref[len(prefix) :]
        return self.branch_ref


@dataclass
class WorktreeDecision:
    path: str
    branch: str
    decision: str
    reason: str
    head: str
    upstream: str = ""
    uncommitted: int = 0
    size_mb: float = 0.0
    idle_days: float = 0.0
    removed: bool = False


def run_command(args: list[str], cwd: Path, timeout: int = 60) -> CommandResult:
    try:
        proc = subprocess.run(
            args,
            cwd=str(cwd),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            timeout=timeout,
        )
    except FileNotFoundError as exc:
        return CommandResult(127, "", str(exc))
    except PermissionError as exc:
        return CommandResult(126, "", str(exc))
    except OSError as exc:
        return CommandResult(126, "", str(exc))
    except subprocess.TimeoutExpired as exc:
        stdout = exc.stdout.strip() if isinstance(exc.stdout, str) else ""
        return CommandResult(124, stdout, f"timed out after {timeout}s")
    return CommandResult(proc.returncode, proc.stdout.strip(), proc.stderr.strip())


def run_git(args: list[str], cwd: Path, timeout: int = 60) -> CommandResult:
    return run_command(["git", *args], cwd, timeout=timeout)


def git_text(args: list[str], cwd: Path, default: str = "") -> str:
    result = run_git(args, cwd)
    if result.code != 0:
        return default
    return result.stdout.strip()


def git_root(cwd: Path) -> Path:
    root = git_text(["rev-parse", "--show-toplevel"], cwd)
    if not root:
        raise RuntimeError(f"not inside a git worktree: {cwd}")
    return Path(root).resolve()


def norm_path(path: Path) -> str:
    return os.path.normcase(str(path.resolve(strict=False)))


def same_or_child(child: Path, parent: Path) -> bool:
    child_s = norm_path(child)
    parent_s = norm_path(parent)
    return child_s == parent_s or child_s.startswith(parent_s + os.sep)


def parse_worktree_list(raw: str) -> list[WorktreeEntry]:
    entries: list[WorktreeEntry] = []
    current: dict[str, Any] = {}

    def flush() -> None:
        nonlocal current
        if not current:
            return
        entries.append(
            WorktreeEntry(
                path=str(current.get("worktree", "")),
                head=str(current.get("HEAD", "")),
                branch_ref=str(current.get("branch", "")),
                detached=bool(current.get("detached", False)),
                bare=bool(current.get("bare", False)),
                locked=bool(current.get("locked", False)),
            )
        )
        current = {}

    for line in raw.splitlines():
        if not line:
            flush()
            continue
        if " " in line:
            key, value = line.split(" ", 1)
            current[key] = value
        else:
            current[line] = True
    flush()
    return entries


def worktree_entries(root: Path) -> list[WorktreeEntry]:
    raw = git_text(["worktree", "list", "--porcelain"], root)
    return parse_worktree_list(raw)


def repo_full_name(root: Path) -> str:
    result = run_command(["gh", "repo", "view", "--json", "nameWithOwner"], root)
    if result.code != 0:
        return ""
    try:
        return str(json.loads(result.stdout).get("nameWithOwner") or "")
    except json.JSONDecodeError:
        return ""


def open_pr_branches(root: Path) -> set[str]:
    if shutil.which("gh") is None:
        return set()
    repo = repo_full_name(root)
    args = ["gh", "pr", "list", "--state", "open", "--json", "headRefName"]
    if repo:
        args.extend(["--repo", repo])
    result = run_command(args, root)
    if result.code != 0:
        return set()
    try:
        payload = json.loads(result.stdout or "[]")
    except json.JSONDecodeError:
        return set()
    return {
        str(item.get("headRefName") or "").strip()
        for item in payload
        if str(item.get("headRefName") or "").strip()
    }


def status_lines(path: Path) -> list[str]:
    result = run_git(["-C", str(path), "status", "--porcelain"], path)
    if result.code != 0:
        return ["<status failed>"]
    return [line for line in result.stdout.splitlines() if line.strip()]


def branch_upstream(path: Path) -> str:
    return git_text(
        ["-C", str(path), "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"],
        path,
    )


def ref_sha(path: Path, ref: str) -> str:
    return git_text(["-C", str(path), "rev-parse", ref], path)


def is_ancestor(path: Path, older_ref: str, newer_ref: str) -> bool:
    result = run_git(["-C", str(path), "merge-base", "--is-ancestor", older_ref, newer_ref], path)
    return result.code == 0


def directory_size_mb(path: Path) -> float:
    total = 0
    for item in path.rglob("*"):
        try:
            if item.is_file():
                total += item.stat().st_size
        except OSError:
            continue
    return round(total / (1024 * 1024), 1)


def worktree_idle_days(path: Path, now: float | None = None) -> float:
    try:
        mtime = path.stat().st_mtime
    except OSError:
        return 0.0
    current = time.time() if now is None else now
    return round(max(0.0, current - mtime) / (24 * 60 * 60), 1)


def has_branch_prefix(branch: str, prefixes: tuple[str, ...]) -> bool:
    return any(branch.startswith(prefix) for prefix in prefixes)


def short_sha(value: str) -> str:
    return value[:12] if value else ""


def evaluate_worktree(
    entry: WorktreeEntry,
    *,
    cwd: Path,
    main_worktree: Path,
    base_ref: str,
    open_prs: set[str],
    skip_branches: set[str],
    measure_size: bool,
    allow_main_worktree: bool,
    allow_missing_upstream: bool,
    tier1: bool,
    min_idle_days: int,
    min_size_mb: float,
    tier1_skip_prefixes: tuple[str, ...],
) -> WorktreeDecision:
    path = Path(entry.path).resolve(strict=False)
    branch = entry.branch
    head = entry.head

    def skip(reason: str, **kwargs: Any) -> WorktreeDecision:
        return WorktreeDecision(
            path=str(path),
            branch=branch or "HEAD",
            decision="SKIP",
            reason=reason,
            head=short_sha(head),
            **kwargs,
        )

    if not entry.path:
        return skip("missing worktree path")
    if entry.bare:
        return skip("bare worktree")
    if entry.locked:
        return skip("locked worktree")
    if same_or_child(cwd, path):
        return skip("current working directory")
    if not allow_main_worktree and norm_path(path) == norm_path(main_worktree):
        return skip("main worktree")
    if not path.exists():
        return skip("missing path")
    if entry.detached or not branch:
        return skip("detached HEAD")
    if branch in skip_branches:
        return skip("protected branch")
    if tier1 and has_branch_prefix(branch, tier1_skip_prefixes):
        return skip("protected branch prefix")

    dirty = status_lines(path)
    if dirty:
        return skip("uncommitted changes", uncommitted=len(dirty))

    if branch in open_prs:
        return skip("open PR")

    upstream = branch_upstream(path)
    if not upstream and not allow_missing_upstream:
        return skip("missing upstream")

    if upstream:
        upstream_head = ref_sha(path, upstream)
        local_head = ref_sha(path, "HEAD")
        if not upstream_head:
            return skip("upstream is not resolvable", upstream=upstream)
        if local_head != upstream_head:
            return skip("HEAD differs from upstream", upstream=upstream)

    if not is_ancestor(path, "HEAD", base_ref):
        return skip(f"not merged into {base_ref}", upstream=upstream)

    size_mb = directory_size_mb(path) if measure_size else 0.0
    idle_days = worktree_idle_days(path)
    if tier1 and idle_days < min_idle_days:
        return skip(f"idle < {min_idle_days} days", upstream=upstream, size_mb=size_mb, idle_days=idle_days)
    if tier1 and size_mb < min_size_mb:
        return skip(f"size < {min_size_mb:g} MB", upstream=upstream, size_mb=size_mb, idle_days=idle_days)
    return WorktreeDecision(
        path=str(path),
        branch=branch,
        decision="PRUNE",
        reason=f"merged into {base_ref}",
        head=short_sha(head),
        upstream=upstream,
        uncommitted=0,
        size_mb=size_mb,
        idle_days=idle_days,
    )


def remove_worktree(root: Path, decision: WorktreeDecision) -> bool:
    result = run_git(["worktree", "remove", "--force", decision.path], root, timeout=180)
    return result.code == 0


def print_report(decisions: list[WorktreeDecision], *, applied: bool, base_ref: str) -> None:
    print("")
    print("=== Worktree Cleanup Report ===")
    print(f"base_ref: {base_ref}")
    print(f"mode: {'apply' if applied else 'dry-run'}")
    print("")
    headers = ("decision", "branch", "size_mb", "reason", "path")
    rows = [
        (
            item.decision,
            item.branch,
            f"{item.size_mb:.1f}" if item.size_mb else "0.0",
            item.reason,
            item.path,
        )
        for item in decisions
    ]
    widths = [len(header) for header in headers]
    for row in rows:
        for index, cell in enumerate(row):
            widths[index] = min(max(widths[index], len(cell)), 64)

    def trim(value: str, width: int) -> str:
        if len(value) <= width:
            return value
        return value[: max(0, width - 3)] + "..."

    print("  ".join(header.ljust(widths[index]) for index, header in enumerate(headers)))
    print("  ".join("-" * width for width in widths))
    for row in rows:
        print(
            "  ".join(
                trim(cell, widths[index]).ljust(widths[index])
                for index, cell in enumerate(row)
            )
        )
    print("")
    candidates = [item for item in decisions if item.decision == "PRUNE"]
    removed = [item for item in candidates if item.removed]
    reclaim = sum(item.size_mb for item in candidates)
    reclaimed = sum(item.size_mb for item in removed) if applied else reclaim
    print(f"worktrees scanned: {len(decisions)}")
    print(f"candidates:        {len(candidates)}")
    print(f"removed:           {len(removed)}")
    print(f"estimated reclaim: {reclaim:.1f} MB")
    print(f"reclaimed_mb={int(round(reclaimed))}")


def summary_payload(decisions: list[WorktreeDecision], *, applied: bool, base_ref: str) -> dict[str, Any]:
    candidates = [item for item in decisions if item.decision == "PRUNE"]
    removed = [item for item in candidates if item.removed]
    reclaimed = sum(item.size_mb for item in removed) if applied else sum(item.size_mb for item in candidates)
    reasons: dict[str, int] = {}
    for item in decisions:
        key = f"{item.decision}: {item.reason}"
        reasons[key] = reasons.get(key, 0) + 1
    return {
        "base_ref": base_ref,
        "mode": "apply" if applied else "dry-run",
        "total": len(decisions),
        "candidates": len(candidates),
        "removed": len(removed),
        "estimated_reclaim_mb": round(sum(item.size_mb for item in candidates), 1),
        "reclaimed_mb": round(reclaimed, 1),
        "reasons": reasons,
        "worktrees": [asdict(item) for item in decisions],
    }


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd(), help="Repository/worktree root.")
    parser.add_argument("--base-ref", default=DEFAULT_BASE_REF)
    parser.add_argument("--apply", action="store_true", help="Remove safe PRUNE candidates.")
    parser.add_argument("--fetch", action="store_true", help="Run git fetch --prune before scanning.")
    parser.add_argument("--json", action="store_true", help="Print the machine-readable summary.")
    parser.add_argument("--json-out", type=Path, help="Write the machine-readable summary.")
    parser.add_argument(
        "--skip-branch",
        action="append",
        default=sorted(DEFAULT_SKIP_BRANCHES),
        help="Protected branch name to skip. Repeatable.",
    )
    parser.add_argument(
        "--ignore-open-prs",
        action="store_true",
        help="Do not query GitHub open PR head branches.",
    )
    parser.add_argument(
        "--allow-main-worktree",
        action="store_true",
        help="Allow the primary worktree to be considered for pruning.",
    )
    parser.add_argument(
        "--allow-missing-upstream",
        action="store_true",
        help="Allow merged branches without an upstream to be pruned.",
    )
    parser.add_argument(
        "--no-size",
        action="store_true",
        help="Skip candidate directory size measurement.",
    )
    parser.add_argument(
        "--tier1",
        action="store_true",
        help="SessionStart-friendly stale worktree prune mode for Issue #1984 Tier 1.6.",
    )
    parser.add_argument(
        "--max-runtime-sec",
        type=int,
        default=0,
        help="Soft runtime cap. Exhausted entries are skipped gracefully.",
    )
    parser.add_argument("--min-idle-days", type=int, default=7)
    parser.add_argument("--min-size-mb", type=float, default=100.0)
    parser.add_argument(
        "--tier1-skip-prefix",
        action="append",
        default=list(DEFAULT_TIER1_SKIP_PREFIXES),
        help="Branch prefix protected in --tier1 mode. Repeatable.",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    root = git_root(args.root)
    cwd = Path.cwd().resolve(strict=False)

    if args.fetch:
        remote = args.base_ref.split("/", 1)[0] if "/" in args.base_ref else "origin"
        fetch = run_git(["fetch", "--prune", remote], root, timeout=180)
        if fetch.code != 0:
            print(f"WARNING: git fetch --prune {remote} failed: {fetch.stderr}", file=sys.stderr)

    entries = worktree_entries(root)
    if not entries:
        print("No git worktrees found.")
        return 0

    main_worktree = Path(entries[0].path).resolve(strict=False)
    open_prs = set() if args.ignore_open_prs else open_pr_branches(root)
    deadline = time.monotonic() + args.max_runtime_sec if args.max_runtime_sec > 0 else None
    decisions: list[WorktreeDecision] = []
    for entry in entries:
        if deadline is not None and time.monotonic() > deadline:
            path = Path(entry.path).resolve(strict=False)
            decisions.append(
                WorktreeDecision(
                    path=str(path),
                    branch=entry.branch or "HEAD",
                    decision="SKIP",
                    reason="runtime budget exhausted",
                    head=short_sha(entry.head),
                )
            )
            continue
        decisions.append(
            evaluate_worktree(
                entry,
                cwd=cwd,
                main_worktree=main_worktree,
                base_ref=args.base_ref,
                open_prs=open_prs,
                skip_branches=set(args.skip_branch),
                measure_size=not args.no_size,
                allow_main_worktree=args.allow_main_worktree,
                allow_missing_upstream=args.allow_missing_upstream,
                tier1=args.tier1,
                min_idle_days=args.min_idle_days,
                min_size_mb=args.min_size_mb,
                tier1_skip_prefixes=tuple(args.tier1_skip_prefix),
            )
        )

    if args.apply:
        for decision in decisions:
            if decision.decision != "PRUNE":
                continue
            decision.removed = remove_worktree(root, decision)
            if not decision.removed:
                decision.reason = f"remove failed after safe selection: {decision.reason}"
        run_git(["worktree", "prune"], root, timeout=180)

    payload = summary_payload(decisions, applied=args.apply, base_ref=args.base_ref)
    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        print_report(decisions, applied=args.apply, base_ref=args.base_ref)

    failed_removals = [
        item for item in decisions if item.decision == "PRUNE" and args.apply and not item.removed
    ]
    return 1 if failed_removals else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
