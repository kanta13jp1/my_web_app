#!/usr/bin/env python3
"""Guard protected config trees against tracked files being emptied to 0 bytes.

On 2026-07-21 eight tracked files were truncated to 0 bytes in a working tree
(six GitHub Actions workflows plus ``.claude/settings.json`` and
``.claude/commands/wrap-up.md``). Nothing staged them, so nothing shipped, but a
blind ``git add -A`` would have committed the removal of the entire CI/CD
pipeline and the agent hook/permission config.

Scope is deliberately narrow. ``.github/workflows/`` and ``.claude/`` are the two
trees that fail *silently* when emptied: a 0-byte workflow simply never runs, and
a 0-byte settings.json simply drops every hook. Damage elsewhere is loud -- an
emptied file under ``lib/`` breaks the build, an emptied script fails when run --
so those trees do not need this guard.

Emptying a file in these trees is never the right operation: to retire a workflow
you delete it, which this guard allows.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from dataclasses import dataclass
from typing import Iterable


PROTECTED_PREFIXES = (".github/workflows/", ".claude/")


@dataclass(frozen=True)
class FileState:
    """Sizes of one path on both sides. ``None`` means the path is absent there."""

    path: str
    base_size: int | None
    head_size: int | None


@dataclass(frozen=True)
class EmptiedFinding:
    path: str
    base_size: int


def is_protected(path: str) -> bool:
    return path.startswith(PROTECTED_PREFIXES)


def find_emptied_files(states: Iterable[FileState]) -> list[EmptiedFinding]:
    """Return findings for protected files that are non-empty at base but empty at head."""
    findings: list[EmptiedFinding] = []
    for state in states:
        if not is_protected(state.path):
            continue
        if state.head_size is None:
            # Deleted by this change. Removing a workflow outright is legitimate.
            continue
        if state.head_size != 0:
            continue
        if state.base_size is None:
            # Brand-new empty file: nothing existed upstream, so nothing was destroyed.
            continue
        if state.base_size == 0:
            # Already empty upstream (e.g. a tracked .gitkeep). Not a regression.
            continue
        findings.append(EmptiedFinding(path=state.path, base_size=state.base_size))
    return findings


def run_git(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )


def changed_paths(base_ref: str, head_ref: str) -> list[str]:
    """Paths this change touches, via three-dot diff.

    Three-dot (merge-base..head) attributes only what this change did. A two-dot
    diff would also report everything main moved on to since the fork, which is a
    known source of false positives in this repo's PR gates.
    """
    proc = run_git(["diff", "--name-only", f"{base_ref}...{head_ref}"])
    if proc.returncode != 0:
        print(proc.stderr.strip(), file=sys.stderr)
        raise SystemExit(proc.returncode)
    return [line.strip() for line in proc.stdout.splitlines() if line.strip()]


def blob_size(ref: str, path: str) -> int | None:
    """Byte size of ``path`` at ``ref``, or ``None`` when it does not exist there."""
    proc = run_git(["cat-file", "-s", f"{ref}:{path}"])
    if proc.returncode != 0:
        return None
    try:
        return int(proc.stdout.strip())
    except ValueError:
        return None


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-ref", required=True)
    parser.add_argument("--head-ref", required=True)
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    protected = [path for path in changed_paths(args.base_ref, args.head_ref) if is_protected(path)]
    if not protected:
        print("No protected files changed; guard passed.")
        return 0

    # Sizes are compared against the base *tip*, not the merge base. A file that
    # main gained after the fork point is absent at the merge base, so a
    # merge-base comparison would silently miss an empty version of it landing
    # here and shadowing main's real content.
    states = [
        FileState(
            path=path,
            base_size=blob_size(args.base_ref, path),
            head_size=blob_size(args.head_ref, path),
        )
        for path in protected
    ]

    print(f"Checked {len(states)} protected file(s):")
    for state in states:
        base = "absent" if state.base_size is None else f"{state.base_size}B"
        head = "absent" if state.head_size is None else f"{state.head_size}B"
        print(f"- {state.path}: base={base} head={head}")

    findings = find_emptied_files(states)
    if findings:
        print()
        print("Protected files emptied to 0 bytes:")
        for finding in findings:
            print(f"- {finding.path} was {finding.base_size} bytes at base, now 0 bytes")
        print()
        print(
            "A 0-byte workflow never runs and a 0-byte .claude config drops every hook, "
            "both without any error. To retire one of these files, delete it instead of "
            "emptying it."
        )
        return 1

    print("Protected files non-empty guard passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
