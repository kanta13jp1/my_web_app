#!/usr/bin/env python3
"""Monitor pointer-hub config files for size drift.

The project keeps behavior and product memory in docs, while CLAUDE.md and
inject-rules.txt should remain small pointer hubs. This script is intentionally
simple so GitHub Actions can run it monthly and open a warning issue when the
hub files start carrying too much detail again.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


DEFAULT_CLAUDE_LIMIT = 300
DEFAULT_INJECT_RULES_LIMIT = 500

DEFAULT_REQUIRED_POINTERS = (
    "docs/PHILOSOPHY.md",
    "docs/AI_DEV_PRINCIPLES.md",
    "docs/AI_CHARACTER_PRINCIPLES.md",
    "docs/IMBUE_PATTERNS.md",
    "docs/COLLAB_AI_PATTERNS.md",
    "docs/AI_VIDEO_PRINCIPLES.md",
    "docs/VIBE_CODING_PRINCIPLES.md",
    "docs/PLATFORM_EVOLUTION_PRINCIPLES.md",
    "docs/SECOND_BRAIN_PRINCIPLES.md",
    "docs/INDIE_DEV_VELOCITY_PRINCIPLES.md",
    "docs/AI_FLEET_SYNERGY_PLAYBOOK.md",
    "docs/MCP_AUTH_SECURITY_PRINCIPLES.md",
)

DOC_POINTER_RE = re.compile(r"(?:\]\(|\s|^)(docs/[A-Za-z0-9_./-]+\.md)")


@dataclass(frozen=True)
class SizeCheck:
    key: str
    path: str
    limit: int
    lines: int | None
    exists: bool

    @property
    def status(self) -> str:
        if not self.exists:
            return "missing"
        if self.lines is not None and self.lines > self.limit:
            return "over_limit"
        return "ok"

    def to_json(self) -> dict[str, Any]:
        return {
            "key": self.key,
            "path": self.path,
            "limit": self.limit,
            "lines": self.lines,
            "exists": self.exists,
            "status": self.status,
        }


def repo_relative(path: Path, root: Path) -> str:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return str(path)


def count_lines(path: Path) -> int:
    text = path.read_text(encoding="utf-8", errors="replace")
    if text == "":
        return 0
    return text.count("\n") + (0 if text.endswith("\n") else 1)


def check_size(key: str, path: Path, root: Path, limit: int) -> SizeCheck:
    if not path.exists():
        return SizeCheck(key, repo_relative(path, root), limit, None, False)
    return SizeCheck(key, repo_relative(path, root), limit, count_lines(path), True)


def extract_doc_pointers(paths: list[Path], root: Path) -> set[str]:
    pointers: set[str] = set()
    for path in paths:
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for match in DOC_POINTER_RE.finditer(text):
            pointers.add(match.group(1).strip())
    return pointers


def evaluate(
    *,
    root: Path,
    claude_path: Path,
    inject_rules_path: Path,
    claude_limit: int,
    inject_rules_limit: int,
    required_pointers: tuple[str, ...],
) -> dict[str, Any]:
    size_checks = [
        check_size("claude_md", claude_path, root, claude_limit),
        check_size("inject_rules", inject_rules_path, root, inject_rules_limit),
    ]
    source_paths = [claude_path, inject_rules_path]
    pointers = extract_doc_pointers(source_paths, root)
    missing_required_pointers = [
        pointer
        for pointer in required_pointers
        if pointer not in pointers or not (root / pointer).exists()
    ]
    dangling_pointers = [
        pointer for pointer in sorted(pointers) if not (root / pointer).exists()
    ]
    warnings = [
        f"{check.key}:{check.status}"
        for check in size_checks
        if check.status != "ok"
    ]
    if missing_required_pointers:
        warnings.append("required_pointers:missing")
    if dangling_pointers:
        warnings.append("doc_pointers:dangling")

    return {
        "size_checks": [check.to_json() for check in size_checks],
        "required_pointers": list(required_pointers),
        "missing_required_pointers": missing_required_pointers,
        "dangling_pointers": dangling_pointers,
        "has_warnings": bool(warnings),
        "warnings": warnings,
    }


def render_summary(report: dict[str, Any]) -> str:
    lines = [
        "## Config Size Monitor",
        "",
        "| Target | Lines | Limit | Status |",
        "|---|---:|---:|---|",
    ]
    for check in report["size_checks"]:
        line_count = "-" if check["lines"] is None else str(check["lines"])
        lines.append(
            f"| `{check['path']}` | {line_count} | {check['limit']} | `{check['status']}` |"
        )
    lines.extend(
        [
            "",
            f"- Missing required pointers: {len(report['missing_required_pointers'])}",
            f"- Dangling docs pointers: {len(report['dangling_pointers'])}",
            f"- Result: {'warning' if report['has_warnings'] else 'ok'}",
        ]
    )
    return "\n".join(lines) + "\n"


def render_issue_body(report: dict[str, Any]) -> str:
    lines = [
        "Config size monitor detected pointer-hub drift.",
        "",
        render_summary(report).rstrip(),
        "",
        "### Recovery",
        "",
        "1. Move durable behavior or product memory out of `CLAUDE.md` into `docs/`.",
        "2. Consolidate repeated hook rules in `.claude/inject-rules.txt` into `docs/RULES_INDEX.md`.",
        "3. Keep `CLAUDE.md` and inject rules as pointer hubs only.",
        "",
        "Routing: Claude Code owns config policy and Codex owns the monitoring workflow.",
        "",
        "Source: `scripts/config_size_monitor.py` / `.github/workflows/config-size-monitor.yml`.",
    ]
    if report["missing_required_pointers"]:
        lines.extend(["", "### Missing Required Pointers", ""])
        lines.extend(f"- `{pointer}`" for pointer in report["missing_required_pointers"])
    if report["dangling_pointers"]:
        lines.extend(["", "### Dangling Docs Pointers", ""])
        lines.extend(f"- `{pointer}`" for pointer in report["dangling_pointers"])
    return "\n".join(lines) + "\n"


def write_github_output(report: dict[str, Any], path: str) -> None:
    if not path:
        return
    missing_required = ",".join(report["missing_required_pointers"])
    dangling = ",".join(report["dangling_pointers"])
    lines = [
        f"has_warnings={str(report['has_warnings']).lower()}",
        f"missing_required_count={len(report['missing_required_pointers'])}",
        f"dangling_count={len(report['dangling_pointers'])}",
        f"missing_required={missing_required}",
        f"dangling={dangling}",
    ]
    for check in report["size_checks"]:
        lines.append(f"{check['key']}_lines={check['lines'] or 0}")
        lines.append(f"{check['key']}_status={check['status']}")
    with Path(path).open("a", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".")
    parser.add_argument("--claude-path", default="CLAUDE.md")
    parser.add_argument("--inject-rules-path", default=".claude/inject-rules.txt")
    parser.add_argument("--claude-limit", type=int, default=DEFAULT_CLAUDE_LIMIT)
    parser.add_argument("--inject-rules-limit", type=int, default=DEFAULT_INJECT_RULES_LIMIT)
    parser.add_argument("--json-output", default="")
    parser.add_argument("--issue-body", default="")
    parser.add_argument("--github-output", default=os.environ.get("GITHUB_OUTPUT", ""))
    parser.add_argument("--github-step-summary", default=os.environ.get("GITHUB_STEP_SUMMARY", ""))
    parser.add_argument("--strict", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    root = Path(args.root).resolve()
    report = evaluate(
        root=root,
        claude_path=(root / args.claude_path).resolve(),
        inject_rules_path=(root / args.inject_rules_path).resolve(),
        claude_limit=args.claude_limit,
        inject_rules_limit=args.inject_rules_limit,
        required_pointers=DEFAULT_REQUIRED_POINTERS,
    )
    summary = render_summary(report)
    print(summary)

    if args.json_output:
        Path(args.json_output).write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    if args.issue_body:
        Path(args.issue_body).write_text(render_issue_body(report), encoding="utf-8")
    if args.github_step_summary:
        with Path(args.github_step_summary).open("a", encoding="utf-8") as handle:
            handle.write(summary)
    write_github_output(report, args.github_output)

    if args.strict and report["has_warnings"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
