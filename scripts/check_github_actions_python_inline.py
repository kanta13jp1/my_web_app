#!/usr/bin/env python3
"""Reject multiline inline Python in GitHub Actions shell blocks."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_ROOT = Path(".github/workflows")
MULTILINE_INLINE_PYTHON = re.compile(r"\bpython3?\s+-c\s+(['\"])\s*(?:#.*)?$")


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
            if MULTILINE_INLINE_PYTHON.search(line):
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
        print("Multiline inline Python is not allowed in GitHub Actions workflows.")
        print("Use a heredoc (`python3 <<'PY'`) or a single-line `python3 -c` command.")
        for path, line_number, line in violations:
            print(f"{path}:{line_number}: {line}")
        return 1

    print(f"OK: checked {len(files)} workflow files for multiline inline Python")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
