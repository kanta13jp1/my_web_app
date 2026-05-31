#!/usr/bin/env python3
"""Verify expensive CI/CD workflows skip docs-only pushes."""

from __future__ import annotations

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]

DOCS_ONLY_IGNORES = [
    "docs/**",
    "memory/**",
    ".claude/**",
    ".codex/**",
    ".agents/**",
    "*.md",
    "**/*.md",
    ".github/*.md",
    ".github/**/*.md",
    ".github/ISSUE_TEMPLATE/**",
    ".github/PULL_REQUEST_TEMPLATE.md",
]

WORKFLOWS_REQUIRING_IGNORES = [
    ".github/workflows/ci.yml",
    ".github/workflows/deploy-dev.yml",
    ".github/workflows/deploy-staging.yml",
    ".github/workflows/deploy-prod.yml",
    ".github/workflows/release-notes-data.yml",
]


def _extract_paths_ignore(text: str) -> set[str]:
    lines = text.splitlines()
    values: set[str] = set()
    for index, line in enumerate(lines):
        if not re.match(r"^\s{4}paths-ignore:\s*$", line):
            continue
        for child in lines[index + 1 :]:
            if not child.startswith("      "):
                break
            match = re.match(r"^\s{6}-\s+['\"]?([^'\"]+)['\"]?\s*$", child)
            if match:
                values.add(match.group(1))
    return values


def main() -> int:
    missing: list[str] = []
    for workflow in WORKFLOWS_REQUIRING_IGNORES:
        path = ROOT / workflow
        ignores = _extract_paths_ignore(path.read_text(encoding="utf-8"))
        absent = [pattern for pattern in DOCS_ONLY_IGNORES if pattern not in ignores]
        if absent:
            missing.append(f"{workflow}: missing {', '.join(absent)}")

    if missing:
        print("CI/CD docs-only path filter check failed:", file=sys.stderr)
        for item in missing:
            print(f"- {item}", file=sys.stderr)
        return 1

    print("CI/CD docs-only path filters are present.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
