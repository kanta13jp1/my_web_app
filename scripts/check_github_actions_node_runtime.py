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
    r"^\s*uses:\s*(?P<action>[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)@"
    r"(?P<ref>v?(?P<major>\d+)(?:[.\w-]*)?)\s*(?:#.*)?$"
)


def main() -> int:
    if not WORKFLOW_DIR.exists():
        print(f"workflow directory not found: {WORKFLOW_DIR}", file=sys.stderr)
        return 1

    violations: list[str] = []
    checked = 0
    for path in sorted(WORKFLOW_DIR.glob("*.yml")) + sorted(WORKFLOW_DIR.glob("*.yaml")):
        for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            match = USES_RE.match(line)
            if not match:
                continue

            action = match.group("action")
            minimum_major = MIN_ACTION_MAJOR.get(action)
            if minimum_major is None:
                continue

            checked += 1
            major = int(match.group("major"))
            if major < minimum_major:
                violations.append(
                    f"{path}:{line_number}: {action}@{match.group('ref')} "
                    f"must be >= v{minimum_major} for the Node.js 24 runner transition"
                )

    if violations:
        print("GitHub Actions Node runtime floor violations:")
        for violation in violations:
            print(f"- {violation}")
        return 1

    print(f"OK: checked {checked} GitHub Actions runtime-sensitive uses")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
