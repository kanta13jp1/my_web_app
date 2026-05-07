#!/usr/bin/env python3
"""Block workflow dispatch when local commits are not on the remote branch."""

from __future__ import annotations

import argparse
import fnmatch
import subprocess
import sys
from pathlib import Path


DEFAULT_IGNORE_PATHS = (".claude/settings.local.json",)


def run_git(args: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        check=check,
        capture_output=True,
        text=True,
    )


def git_text(args: list[str]) -> str:
    return run_git(args).stdout.strip()


def normalize_path(path: str) -> str:
    normalized = path.replace("\\", "/")
    while normalized.startswith("./"):
        normalized = normalized[2:]
    return normalized


def ignored(path: str, patterns: tuple[str, ...]) -> bool:
    normalized = normalize_path(path)
    return any(fnmatch.fnmatch(normalized, pattern) for pattern in patterns)


def meaningful_status(ignore_paths: tuple[str, ...]) -> list[str]:
    result = run_git(["status", "--porcelain"], check=False)
    lines: list[str] = []
    for raw in result.stdout.splitlines():
        if len(raw) < 4:
            continue
        path = raw[3:].strip()
        if " -> " in path:
            path = path.split(" -> ", 1)[1].strip()
        if ignored(path, ignore_paths):
            continue
        lines.append(raw)
    return lines


def unpushed_commits(target_ref: str) -> list[str]:
    result = run_git(["merge-base", "--is-ancestor", "HEAD", target_ref], check=False)
    if result.returncode == 0:
        return []
    return git_text(["log", "--oneline", f"{target_ref}..HEAD"]).splitlines()


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--remote", default="origin")
    parser.add_argument("--branch", default="main")
    parser.add_argument(
        "--require-clean",
        action="store_true",
        help="Also block meaningful uncommitted files before dispatch.",
    )
    parser.add_argument(
        "--ignore-path",
        action="append",
        default=list(DEFAULT_IGNORE_PATHS),
        help="Glob path to ignore for --require-clean. Repeatable.",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    target_ref = f"{args.remote}/{args.branch}"

    if run_git(["rev-parse", "--is-inside-work-tree"], check=False).returncode != 0:
        print("ERROR: not inside a git worktree.", file=sys.stderr)
        return 2

    run_git(["fetch", "--quiet", args.remote, args.branch])

    local_head = git_text(["rev-parse", "--short", "HEAD"])
    remote_head = git_text(["rev-parse", "--short", target_ref])

    commits = unpushed_commits(target_ref)
    if commits:
        print(
            f"ERROR: local HEAD {local_head} is not pushed to {target_ref} "
            f"({remote_head}).",
            file=sys.stderr,
        )
        print("Push or merge these commits before dispatching a workflow:", file=sys.stderr)
        for commit in commits:
            print(f"  {commit}", file=sys.stderr)
        return 1

    if args.require_clean:
        dirty = meaningful_status(tuple(args.ignore_path))
        if dirty:
            print(
                "ERROR: meaningful uncommitted files are present. "
                "Commit and push them before dispatching a workflow.",
                file=sys.stderr,
            )
            for line in dirty:
                print(f"  {line}", file=sys.stderr)
            return 1

    print(f"OK: local HEAD {local_head} is already contained in {target_ref} ({remote_head}).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
