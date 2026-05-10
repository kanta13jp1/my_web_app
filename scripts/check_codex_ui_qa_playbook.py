#!/usr/bin/env python3
"""Validate the Codex UI QA playbook and PR-template hooks."""

from __future__ import annotations

import sys
from pathlib import Path


PLAYBOOK = Path("docs/CODEX_UI_QA_PLAYBOOK.md")
PR_TEMPLATE = Path(".github/PULL_REQUEST_TEMPLATE.md")

REQUIRED_PLAYBOOK_TERMS = (
    "Issue: #1646",
    "Claude Code #1",
    "Codex #1",
    "test/e2e/visual_evidence.spec.ts",
    "test/e2e/public_smoke.spec.ts",
    ".github/workflows/minimal-e2e-gate.yml",
    "scripts/summarize_playwright_results.mjs",
    "desktop viewport",
    "mobile viewport",
    "1440 x 1000",
    "Pixel 5",
    "console errors",
    "page errors",
    "request failures",
    "HTTP 5xx",
    "document.getAnimations",
    "Codex in-app browser",
    "prompt",
    "intended use",
    "asset path",
    "rights statement",
    "Generated imagery must not be used to imply an unverified real product state",
)

REQUIRED_TEMPLATE_TERMS = (
    "docs/CODEX_UI_QA_PLAYBOOK.md",
    "## Codex UI QA / Prototyping",
    "Changed routes/surfaces",
    "Codex in-app browser check",
    "npm run e2e:visual",
    "Desktop and mobile viewport findings",
    "Generated imagery status",
    "prompt, intended use, asset path, rights statement, and verification note",
    "Generated imagery is not being used as proof of the actual product state",
)


def missing_terms(text: str, terms: tuple[str, ...]) -> list[str]:
    return [term for term in terms if term not in text]


def validate_repo(root: Path) -> list[str]:
    failures: list[str] = []
    for relative_path, terms in (
        (PLAYBOOK, REQUIRED_PLAYBOOK_TERMS),
        (PR_TEMPLATE, REQUIRED_TEMPLATE_TERMS),
    ):
        path = root / relative_path
        if not path.exists():
            failures.append(f"{relative_path}: file is missing")
            continue
        text = path.read_text(encoding="utf-8")
        for term in missing_terms(text, terms):
            failures.append(f"{relative_path}: missing required term: {term}")
    return failures


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    failures = validate_repo(root)
    if failures:
        print("Codex UI QA playbook check: FAIL", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    print("Codex UI QA playbook check: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

