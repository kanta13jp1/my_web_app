#!/usr/bin/env python3
"""Require a successful pre-commit gate before Git prepares commit messages."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Callable


MAX_STAMP_AGE_SECONDS = 300
GIT_OPERATION_MARKERS = (
    "rebase-merge",
    "rebase-apply",
    "MERGE_HEAD",
    "CHERRY_PICK_HEAD",
    "REVERT_HEAD",
    "sequencer",
)


def run_git(args: list[str]) -> str:
    proc = subprocess.run(
        ["git", *args],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or f"git {' '.join(args)} failed")
    return proc.stdout.strip()


def current_tree() -> str:
    return run_git(["write-tree"])


def stamp_path() -> Path:
    return Path(run_git(["rev-parse", "--git-path", "codex-quality/pre-commit-stamp.json"]))


def git_path(name: str) -> Path:
    return Path(run_git(["rev-parse", "--git-path", name]))


def has_git_operation_state(
    resolver: Callable[[str], Path] = git_path,
) -> bool:
    return any(resolver(marker).exists() for marker in GIT_OPERATION_MARKERS)


def write_stamp(path: Path, tree: str, now: float | None = None) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "tree": tree,
        "created_at": now if now is not None else time.time(),
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")


def read_stamp(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None
    return payload if isinstance(payload, dict) else None


def stamp_matches(
    payload: dict[str, Any] | None,
    tree: str,
    now: float | None = None,
    max_age_seconds: int = MAX_STAMP_AGE_SECONDS,
) -> bool:
    if not payload:
        return False
    if payload.get("tree") != tree:
        return False
    created_at = payload.get("created_at")
    if not isinstance(created_at, (int, float)):
        return False
    current_time = now if now is not None else time.time()
    return 0 <= current_time - float(created_at) <= max_age_seconds


def mark_pre_commit() -> int:
    path = stamp_path()
    tree = current_tree()
    write_stamp(path, tree)
    print(f"Marked pre-commit quality gate for tree {tree[:12]}.")
    return 0


def assert_pre_commit() -> int:
    if has_git_operation_state():
        return 0

    path = stamp_path()
    tree = current_tree()
    if stamp_matches(read_stamp(path), tree):
        return 0

    print(
        "Pre-commit quality gate did not run for this index. "
        "Commit normally after `npm run hooks:install`; do not use `git commit --no-verify`.",
        file=sys.stderr,
    )
    return 1


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subcommands = parser.add_subparsers(dest="command", required=True)
    subcommands.add_parser("mark-pre-commit")
    assert_parser = subcommands.add_parser("assert-pre-commit")
    assert_parser.add_argument("--message-file", help="Git commit message file path.")
    assert_parser.add_argument("--source", default="", help="Git prepare-commit-msg source.")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    if args.command == "mark-pre-commit":
        return mark_pre_commit()
    if args.command == "assert-pre-commit":
        return assert_pre_commit()
    raise AssertionError(args.command)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
