#!/usr/bin/env python3
"""Audit active docs and workflows for stale multi-instance routing.

The repository still keeps historical 12-fleet / PS#1-6 records. Those are
allowed only when a file clearly marks the text as legacy. Active instructions
for new sessions must point to Claude Code #1 + Codex #1.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import asdict, dataclass
from datetime import date
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]

ACTIVE_FILES = [
    ".github/COMPRESSED_PROMPT_V3.md",
    ".github/workflows/instance-role-audit.yml",
    ".github/workflows/wbs-staleness-audit.yml",
    "docs/CODEX_WORKFLOW.md",
    "docs/FLEET_2_INSTANCE_TRANSITION.md",
    "docs/WBS_2_INSTANCE_ROUTING.md",
]

LEGACY_PATTERNS = [
    re.compile(r"\bPS#?[1-6]\b", re.IGNORECASE),
    re.compile(r"\bCodex#?2\b", re.IGNORECASE),
    re.compile(r"\b12[- ]?fleet\b", re.IGNORECASE),
    re.compile(r"\b3[- ]?instance\b", re.IGNORECASE),
    re.compile(r"Claude Code 10", re.IGNORECASE),
    re.compile(r"Codex 2", re.IGNORECASE),
    re.compile(r"vscode win ps1", re.IGNORECASE),
]

CANONICAL_PATTERNS = [
    re.compile(r"Current 2-Instance Override", re.IGNORECASE),
    re.compile(r"2-instance", re.IGNORECASE),
    re.compile(r"Claude Code #1", re.IGNORECASE),
    re.compile(r"Codex #1", re.IGNORECASE),
    re.compile(r"legacy", re.IGNORECASE),
]


@dataclass
class Hit:
    path: str
    line: int
    text: str


@dataclass
class FileAudit:
    path: str
    legacy_hits: int
    canonical_marker: bool
    status: str
    samples: list[Hit]


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def scan_file(path: Path) -> FileAudit:
    rel = path.relative_to(REPO_ROOT).as_posix()
    text = read_text(path)
    canonical_marker = any(pattern.search(text) for pattern in CANONICAL_PATTERNS)
    hits: list[Hit] = []
    for line_no, line in enumerate(text.splitlines(), start=1):
        if any(pattern.search(line) for pattern in LEGACY_PATTERNS):
            hits.append(Hit(rel, line_no, line.strip()[:220]))
    status = "ok"
    if hits and not canonical_marker:
        status = "needs_marker"
    return FileAudit(rel, len(hits), canonical_marker, status, hits[:8])


def render_markdown(audits: list[FileAudit]) -> str:
    today = date.today().isoformat()
    lines = [
        f"# 2-Instance Routing Audit ({today})",
        "",
        "Canonical owner model: Claude Code #1 (Windows app) + Codex #1 (Windows app).",
        "Historical 12-fleet / PS#1-6 references are acceptable only when the file clearly marks them as legacy.",
        "",
        "| file | legacy refs | marker | status |",
        "| --- | ---: | --- | --- |",
    ]
    for audit in audits:
        marker = "yes" if audit.canonical_marker else "no"
        lines.append(
            f"| `{audit.path}` | {audit.legacy_hits} | {marker} | {audit.status} |"
        )
    lines.append("")
    lines.append("## Samples")
    for audit in audits:
        if not audit.samples:
            continue
        lines.append("")
        lines.append(f"### `{audit.path}`")
        for hit in audit.samples:
            lines.append(f"- L{hit.line}: `{hit.text}`")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--fail-on-active", action="store_true")
    args = parser.parse_args()

    audits = [
        scan_file(REPO_ROOT / rel)
        for rel in ACTIVE_FILES
        if (REPO_ROOT / rel).exists()
    ]
    if args.json:
        print(json.dumps([asdict(audit) for audit in audits], ensure_ascii=False, indent=2))
    else:
        markdown = render_markdown(audits)
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(markdown, encoding="utf-8")
        print(markdown)
    if args.fail_on_active and any(audit.status != "ok" for audit in audits):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
