#!/usr/bin/env python3
"""Guard GitHub Actions against known Node.js runtime deprecation floors.

GitHub Actions is moving JavaScript actions from Node.js 20 to Node.js 24.
This check catches regressions to action majors that are known to trigger the
Node.js 20 runner deprecation warning in this repository.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


WORKFLOW_DIR = Path(".github/workflows")

MIN_ACTION_MAJOR = {
    "actions/checkout": 6,
    "actions/setup-node": 6,
    "actions/setup-python": 6,
    "actions/setup-java": 5,
    "actions/upload-artifact": 6,
    "actions/download-artifact": 6,
    "actions/github-script": 9,
}

USES_RE = re.compile(
    r"^\s*(?:-\s*)?uses:\s*(?P<action>[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)@"
    r"(?P<ref>[^\s#]+)\s*(?:#\s*(?P<label>v(?P<label_major>\d+)[.\w-]*).*)?$"
)
TAG_MAJOR_RE = re.compile(r"^v?(?P<major>\d+)(?:[.\w-]*)?$", re.IGNORECASE)
FULL_SHA_RE = re.compile(r"^[0-9a-f]{40}$")


def find_violations(paths: list[Path]) -> tuple[list[str], int]:
    violations: list[str] = []
    checked = 0
    for path in paths:
        for line_number, line in enumerate(
            path.read_text(encoding="utf-8-sig").splitlines(), 1
        ):
            match = USES_RE.match(line)
            if not match:
                continue

            action = match.group("action")
            minimum_major = MIN_ACTION_MAJOR.get(action)
            if minimum_major is None:
                continue

            checked += 1
            ref = match.group("ref")
            tag_match = TAG_MAJOR_RE.fullmatch(ref)
            if FULL_SHA_RE.fullmatch(ref) and match.group("label_major"):
                major = int(match.group("label_major"))
            elif FULL_SHA_RE.fullmatch(ref):
                violations.append(
                    f"{path}:{line_number}: {action}@{ref} must include a "
                    "trailing version comment such as `# v7`"
                )
                continue
            elif tag_match:
                major = int(tag_match.group("major"))
            else:
                violations.append(
                    f"{path}:{line_number}: {action}@{ref} must include a "
                    "trailing version comment such as `# v7`"
                )
                continue

            if major < minimum_major:
                violations.append(
                    f"{path}:{line_number}: {action}@{ref} "
                    f"must be >= v{minimum_major} for the Node.js 24 runner transition"
                )
    return violations, checked


def main() -> int:
    if not WORKFLOW_DIR.exists():
        print(f"workflow directory not found: {WORKFLOW_DIR}", file=sys.stderr)
        return 1

    paths = sorted(WORKFLOW_DIR.glob("*.yml")) + sorted(WORKFLOW_DIR.glob("*.yaml"))
    violations, checked = find_violations(paths)

    if violations:
        print("GitHub Actions Node runtime floor violations:")
        for violation in violations:
            print(f"- {violation}")
        return 1

    print(f"OK: checked {checked} GitHub Actions runtime-sensitive uses")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
