#!/usr/bin/env python3
"""Fail when commits or commit messages carry hook-bypass markers."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


BYPASS_PATTERNS = (
    r"Quality-Gate-Bypass\s*:",
    r"Quality-Gate-Exception\s*:",
    r"CODEX_ALLOW_HOOK_BYPASS",
    r"\bLEFTHOOK=0\b",
    r"\bgit\s+commit\b[^\n]*--no-verify\b",
)


def find_bypass_markers(text: str) -> list[str]:
    markers: list[str] = []
    for pattern in BYPASS_PATTERNS:
        if re.search(pattern, text, flags=re.IGNORECASE):
            markers.append(pattern)
    return markers


def run_git_log(commit_range: str) -> str:
    proc = subprocess.run(
        ["git", "log", "--format=%B%x00", commit_range],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0:
        print(proc.stderr.strip(), file=sys.stderr)
        return ""
    return proc.stdout


def event_range(payload: dict[str, Any]) -> str | None:
    pr = payload.get("pull_request")
    if isinstance(pr, dict):
        base = pr.get("base", {})
        head = pr.get("head", {})
        if isinstance(base, dict) and isinstance(head, dict):
            base_sha = base.get("sha")
            head_sha = head.get("sha")
            if isinstance(base_sha, str) and isinstance(head_sha, str):
                return f"{base_sha}..{head_sha}"

    before = payload.get("before")
    after = payload.get("after")
    if isinstance(before, str) and isinstance(after, str):
        if before and after and not set(before) <= {"0"}:
            return f"{before}..{after}"
    return None


def read_event(path: str | None) -> dict[str, Any]:
    if not path:
        return {}
    source = Path(path)
    if not source.exists():
        return {}
    return json.loads(source.read_text(encoding="utf-8"))


def read_message_file(path: str | None) -> str:
    if not path:
        return ""
    source = Path(path)
    if not source.exists():
        return ""
    return source.read_text(encoding="utf-8", errors="replace")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--message-file", help="Commit message file to inspect.")
    parser.add_argument("--range", dest="commit_range", help="Git commit range to inspect.")
    parser.add_argument("--github-event", help="GitHub event JSON path for deriving a range.")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    text = read_message_file(args.message_file)

    commit_range = args.commit_range
    if not commit_range:
        commit_range = event_range(read_event(args.github_event))
    if commit_range:
        text += "\n" + run_git_log(commit_range)
    elif not text:
        text = run_git_log("HEAD~1..HEAD")

    markers = find_bypass_markers(text)
    if markers:
        print("Hook bypass marker detected. Recommit through Lefthook quality gates.")
        for marker in markers:
            print(f"- matched: {marker}")
        return 1

    print("No hook bypass markers detected.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
