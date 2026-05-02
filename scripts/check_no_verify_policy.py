#!/usr/bin/env python3
"""Detect explicit hook-bypass signals in commit messages and PR ranges.

Git does not record whether a commit was created with `git commit --no-verify`.
This guard catches explicit bypass markers that people often leave in commit
messages, while the Lefthook GitHub Action replays the hook commands to catch
the practical effect of a skipped local hook.
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


for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(errors="replace")


BYPASS_PATTERNS: tuple[re.Pattern[str], ...] = (
    re.compile(r"git\s+commit\b[^\n]*\s--no-verify\b", re.IGNORECASE),
    re.compile(r"\s--no-verify\b", re.IGNORECASE),
    re.compile(r"\[skip[ _-]?hooks?\]", re.IGNORECASE),
    re.compile(r"\[skip[ _-]?lefthook\]", re.IGNORECASE),
    re.compile(r"\b(?:LEFTHOOK|HUSKY)\s*=\s*0\b", re.IGNORECASE),
    re.compile(r"\blefthook\s+(?:skip|disable)\b", re.IGNORECASE),
)
EXCEPTION_RE = re.compile(r"^Quality-Gate-Exception:\s*(\S.+)$", re.IGNORECASE | re.MULTILINE)
RANGE_SEP = "\x1e"
FIELD_SEP = "\x1f"


@dataclass(frozen=True)
class BypassSignal:
    source: str
    pattern: str
    line: str


def has_exception_marker(text: str) -> bool:
    return bool(EXCEPTION_RE.search(text))


def find_bypass_signals(source: str, text: str) -> list[BypassSignal]:
    if has_exception_marker(text):
        return []

    signals: list[BypassSignal] = []
    for line in text.splitlines():
        for pattern in BYPASS_PATTERNS:
            if pattern.search(line):
                signals.append(
                    BypassSignal(
                        source=source,
                        pattern=pattern.pattern,
                        line=line.strip(),
                    )
                )
                break
    return signals


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def resolve_range_from_event(event_path: str | None) -> tuple[str, str] | None:
    if not event_path:
        return None

    path = Path(event_path)
    if not path.exists():
        return None

    event = json.loads(read_text(path))
    pull_request = event.get("pull_request")
    if pull_request:
        return pull_request["base"]["sha"], pull_request["head"]["sha"]

    before = event.get("before")
    after = event.get("after")
    if before and after and not str(before).startswith("0000000"):
        return str(before), str(after)

    return None


def git_log_messages(base: str, head: str) -> list[tuple[str, str]]:
    result = subprocess.run(
        [
            "git",
            "log",
            "--format=%H%x1f%B%x1e",
            f"{base}..{head}",
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    commits: list[tuple[str, str]] = []
    for record in result.stdout.split(RANGE_SEP):
        record = record.strip()
        if not record:
            continue
        if FIELD_SEP not in record:
            continue
        sha, message = record.split(FIELD_SEP, 1)
        commits.append((sha.strip(), message.strip()))
    return commits


def print_result(signals: list[BypassSignal]) -> int:
    if not signals:
        print("OK no explicit hook-bypass markers found")
        return 0

    print("FAIL explicit hook-bypass marker(s) detected:")
    for signal in signals:
        print(f"- {signal.source}: {signal.line}")
    print("")
    print("Do not bypass local gates silently. If an emergency exception is approved,")
    print("add `Quality-Gate-Exception: <issue-or-pr-url>` to the commit message")
    print("and make sure the Lefthook Quality Gate workflow is green before merge.")
    return 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--commit-msg-file", type=Path)
    parser.add_argument("--event-path", default=os.environ.get("GITHUB_EVENT_PATH"))
    parser.add_argument("--range", dest="commit_range")
    parser.add_argument("--local", action="store_true")
    args = parser.parse_args()

    signals: list[BypassSignal] = []

    if args.commit_msg_file:
        signals.extend(
            find_bypass_signals(
                str(args.commit_msg_file),
                read_text(args.commit_msg_file),
            )
        )
        return print_result(signals)

    commit_range: tuple[str, str] | None = None
    if args.commit_range:
        if ".." not in args.commit_range:
            print("--range must be formatted as base..head", file=sys.stderr)
            return 2
        base, head = args.commit_range.split("..", 1)
        commit_range = (base, head)
    else:
        commit_range = resolve_range_from_event(args.event_path)

    if commit_range:
        base, head = commit_range
        for sha, message in git_log_messages(base, head):
            short = sha[:12]
            signals.extend(find_bypass_signals(f"commit {short}", message))
        return print_result(signals)

    if args.local:
        print("OK no commit range available in local pre-commit context")
        return 0

    print("No commit range resolved; bypass marker scan skipped")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
