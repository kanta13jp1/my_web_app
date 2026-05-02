#!/usr/bin/env python3
"""Validate the MVP/GA readiness gate document."""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / "docs" / "product" / "MVP_GA_READINESS_GATE.md"

REQUIRED_TOKENS = (
    "WBS task: `77f54e9c-06ed-4ad2-bb96-b779e32ed5d1`",
    "GitHub issue: `#1640`",
    "Harness notebook: `bc58b50b-5fc4-4840-9a62-b397d6d3b65a`",
    "## Scope Freeze",
    "### Must Ship",
    "### Explicitly Out of MVP",
    "### Do Not Release If",
    "## Pricing And Legal Dependencies",
    "## Deterministic Checks",
    "flutter analyze",
    "flutter test",
    "python scripts/check_mvp_ga_readiness.py",
    "## Ownership",
    "## Current Blockers",
    "BLOCKER:",
    "## Automation Route",
    "#1607",
    "#1559",
)


def main() -> int:
    failures: list[str] = []

    if not DOC.exists():
        print(f"MVP/GA readiness document is missing: {DOC.relative_to(ROOT)}")
        return 1

    content = DOC.read_text(encoding="utf-8")
    for token in REQUIRED_TOKENS:
        if token not in content:
            failures.append(f"Missing required token: {token}")

    if content.count("- BLOCKER:") < 3:
        failures.append("At least three explicit BLOCKER entries are required.")

    if failures:
        print("MVP/GA readiness gate check failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("MVP/GA readiness gate check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
