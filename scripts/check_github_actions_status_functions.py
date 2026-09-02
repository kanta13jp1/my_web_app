#!/usr/bin/env python3
"""Reject GitHub Actions status functions outside an `if` condition."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_ROOT = Path(".github/workflows")
STATUS_FUNCTION = re.compile(
    r"\$\{\{[^}]*\b(?:always|cancelled|failure|success)\s*\(",
)
IF_KEY = re.compile(r"^\s*(?:-\s+)?if\s*:")


def workflow_files(root: Path) -> list[Path]:
    if not root.exists():
        return []
    return sorted([*root.glob("*.yml"), *root.glob("*.yaml")])


def find_violations(paths: list[Path]) -> list[tuple[Path, int, str]]:
    violations: list[tuple[Path, int, str]] = []
    for path in paths:
        for line_number, line in enumerate(
            path.read_text(encoding="utf-8").splitlines(),
            start=1,
        ):
            if STATUS_FUNCTION.search(line) and not IF_KEY.match(line):
                violations.append((path, line_number, line.strip()))
    return violations


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    args = parser.parse_args(argv)

    if not args.root.exists():
        print(f"workflow directory not found: {args.root}", file=sys.stderr)
        return 1

    files = workflow_files(args.root)
    violations = find_violations(files)
    if violations:
        print("GitHub Actions status functions are only valid in `if` conditions.")
        for path, line_number, line in violations:
            print(f"{path}:{line_number}: {line}")
        return 1

    print(f"OK: checked {len(files)} workflow files for status-function placement")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
