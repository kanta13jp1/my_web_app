#!/usr/bin/env python3
"""Reject Dependabot pubspec changes that bypass repository update policy."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path


PINNED_DEPENDENCIES = frozenset({"flutter_native_splash"})
DIRECT_DEPENDENCY_SECTIONS = frozenset({"dependencies", "dev_dependencies"})
TOP_LEVEL_KEY = re.compile(r"^([A-Za-z][A-Za-z0-9_]*):(?:\s.*)?$")
DEPENDENCY_LINE = re.compile(r"^ {2}([A-Za-z][A-Za-z0-9_]*):[ \t]+(.+?)\s*$")
VERSION = re.compile(r"(?<![A-Za-z0-9_])(\d+)\.(\d+)(?:\.(\d+))?")


@dataclass(frozen=True)
class DependencyChange:
    name: str
    old_constraint: str
    new_constraint: str


def _strip_inline_comment(value: str) -> str:
    quote: str | None = None
    escaped = False
    for index, char in enumerate(value):
        if escaped:
            escaped = False
            continue
        if char == "\\" and quote == '"':
            escaped = True
            continue
        if char in {"'", '"'}:
            quote = None if quote == char else char if quote is None else quote
            continue
        if char == "#" and quote is None:
            return value[:index].rstrip()
    return value.rstrip()


def _normalize_constraint(value: str) -> str:
    value = _strip_inline_comment(value).strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        return value[1:-1].strip()
    return value


def dependency_constraints(pubspec_text: str) -> dict[str, str]:
    constraints: dict[str, str] = {}
    section: str | None = None
    for line in pubspec_text.splitlines():
        top_level = TOP_LEVEL_KEY.match(line)
        if top_level:
            name = top_level.group(1)
            section = name if name in DIRECT_DEPENDENCY_SECTIONS else None
            continue
        if section is None:
            continue
        match = DEPENDENCY_LINE.match(line)
        if not match:
            continue
        name, raw_constraint = match.groups()
        constraints[name] = _normalize_constraint(raw_constraint)
    return constraints


def dependency_changes(base_text: str, head_text: str) -> list[DependencyChange]:
    base = dependency_constraints(base_text)
    head = dependency_constraints(head_text)

    return [
        DependencyChange(name, base[name], head[name])
        for name in sorted(base.keys() & head.keys())
        if base[name] != head[name]
    ]


def _declared_major(constraint: str) -> int | None:
    match = VERSION.search(constraint)
    return int(match.group(1)) if match else None


def policy_violations(changes: list[DependencyChange]) -> list[str]:
    violations: list[str] = []
    for change in changes:
        if change.name in PINNED_DEPENDENCIES:
            violations.append(
                "pinned dependency changed: "
                f"{change.name} ({change.old_constraint} -> {change.new_constraint})"
            )
            continue

        old_major = _declared_major(change.old_constraint)
        new_major = _declared_major(change.new_constraint)
        if old_major is not None and new_major is not None and new_major > old_major:
            violations.append(
                "direct dependency major update: "
                f"{change.name} ({change.old_constraint} -> {change.new_constraint})"
            )
    return violations


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--base-pubspec",
        required=True,
        help="Path to pubspec.yaml from the pull request base commit.",
    )
    parser.add_argument(
        "--head-pubspec",
        required=True,
        help="Path to pubspec.yaml from the pull request head commit.",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    base_text = Path(args.base_pubspec).read_text(encoding="utf-8")
    head_text = Path(args.head_pubspec).read_text(encoding="utf-8")
    changes = dependency_changes(base_text, head_text)
    violations = policy_violations(changes)

    if violations:
        print("Dependabot pub policy: FAIL", file=sys.stderr)
        for violation in violations:
            print(f"- {violation}", file=sys.stderr)
        return 1

    print(f"Dependabot pub policy: PASS ({len(changes)} direct changes inspected)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
