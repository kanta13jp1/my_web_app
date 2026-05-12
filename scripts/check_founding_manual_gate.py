#!/usr/bin/env python3
"""Validate the founding manual gate document."""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / "docs" / "business" / "FOUNDING_MANUAL_GATE.md"

REQUIRED_TOKENS = (
    "GitHub issue: `#1662`",
    "Related GA gate: `#1640`, PR `#1661`",
    "Harness notebook: `bc58b50b-5fc4-4840-9a62-b397d6d3b65a`",
    "## Manual Decision Register",
    "108a24dc-abee-4bec-90f4-56c8b558f616",
    "0fa38c4f-0d9e-43e3-8ca0-2643c8888e28",
    "5e34304e-7731-4aa2-9ba0-c8ff9654ccd8",
    "282c7660-933f-4a55-a004-638da077c416",
    "c1436a87-8248-40b6-b8fa-4f4c3502889f",
    "f9c7fd37-f2c5-494a-9438-9bba424218d1",
    "69d5bbad-84ba-4fa6-89c0-b7375a6c75cf",
    "## Existing Source Notes",
    "docs/research/2026-04-25_legal_entity_decision.md",
    "docs/research/2026-04-25_trade_name_head_office_decision.md",
    "docs/research/2026-04-25_professional_advisor_selection_checklist.md",
    "## Release Interaction",
    "#1633",
    "#1330",
    "#1185",
    "## Session Routing Rules",
    "Codex must not",
    "## Evidence Comment Template",
    "## Automation Route",
    "#1607",
    "#1559",
)


def main() -> int:
    failures: list[str] = []

    if not DOC.exists():
        print(f"Founding manual gate document is missing: {DOC.relative_to(ROOT)}")
        return 1

    content = DOC.read_text(encoding="utf-8")
    for token in REQUIRED_TOKENS:
        if token not in content:
            failures.append(f"Missing required token: {token}")

    if content.count("| `") < 7:
        failures.append("Manual Decision Register must include at least seven WBS rows.")

    if "Codex must not invent or approve" not in content:
        failures.append("Manual evidence boundary is missing.")

    if failures:
        print("Founding manual gate check failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("Founding manual gate check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
