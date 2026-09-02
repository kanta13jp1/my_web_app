#!/usr/bin/env python3
"""Reject untrusted GitHub expressions interpolated directly into `run` scripts."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_ROOT = Path(".github/workflows")
RUN_KEY = re.compile(
    r"^(?P<indent>\s*)(?:-\s+)?run\s*:\s*(?P<value>.*)$",
)
BLOCK_SCALAR = re.compile(r"^[|>][0-9+-]*(?:\s+#.*)?$")
EXPRESSION = re.compile(r"\$\{\{(?P<body>.*?)\}\}")
REFERENCE = re.compile(r"\b(?:github|inputs|steps)\.[A-Za-z0-9_.-]+")

# GitHub documents these terminal property names as potentially attacker-controlled.
# `ref_name` is included because branch names can contain shell metacharacters.
UNTRUSTED_TERMINALS = {
    "body",
    "default_branch",
    "email",
    "head_ref",
    "label",
    "message",
    "name",
    "page_name",
    "ref",
    "ref_name",
    "title",
}


def workflow_files(root: Path) -> list[Path]:
    if not root.exists():
        return []
    return sorted([*root.glob("*.yml"), *root.glob("*.yaml")])


def _is_untrusted_reference(reference: str) -> bool:
    if reference.startswith("inputs.") or reference.startswith("github.event.inputs."):
        return True
    return reference.rsplit(".", maxsplit=1)[-1] in UNTRUSTED_TERMINALS


def _line_has_untrusted_expression(line: str) -> bool:
    for expression in EXPRESSION.finditer(line):
        references = REFERENCE.findall(expression.group("body"))
        if any(_is_untrusted_reference(reference) for reference in references):
            return True
    return False


def _run_script_lines(lines: list[str]) -> list[tuple[int, str]]:
    scripts: list[tuple[int, str]] = []
    index = 0
    while index < len(lines):
        match = RUN_KEY.match(lines[index])
        if not match:
            index += 1
            continue

        value = match.group("value").strip()
        if value and not BLOCK_SCALAR.match(value):
            scripts.append((index + 1, lines[index]))
            index += 1
            continue

        run_indent = len(match.group("indent"))
        index += 1
        while index < len(lines):
            line = lines[index]
            if line.strip() and len(line) - len(line.lstrip()) <= run_indent:
                break
            scripts.append((index + 1, line))
            index += 1
    return scripts


def find_violations(paths: list[Path]) -> list[tuple[Path, int, str]]:
    violations: list[tuple[Path, int, str]] = []
    for path in paths:
        lines = path.read_text(encoding="utf-8").splitlines()
        for line_number, line in _run_script_lines(lines):
            if _line_has_untrusted_expression(line):
                violations.append((path, line_number, line.strip()))
    return violations


def main(argv: list[str] | None = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="backslashreplace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    args = parser.parse_args(argv)

    if not args.root.exists():
        print(f"workflow directory not found: {args.root}", file=sys.stderr)
        return 1

    files = workflow_files(args.root)
    violations = find_violations(files)
    if violations:
        print("Pass untrusted GitHub values through `env:` before using them in `run:`.")
        for path, line_number, line in violations:
            print(f"{path}:{line_number}: {line}")
        return 1

    print(f"OK: checked {len(files)} workflow files for script-injection risks")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
