#!/usr/bin/env python3
"""Automated refactoring & SQL backward-compatibility linter (#2791).

Parses `dart fix --dry-run` / `dart analyze` logs into structured suggestions,
lints SQL migrations for backward-compatibility breaking changes, and renders
PR feedback Markdown referencing docs/DUAL_WRITE_TRANSITION_STANDARD.md.
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Sequence

DUAL_WRITE_DOC_REF = "docs/DUAL_WRITE_TRANSITION_STANDARD.md"

_DART_FIX_LINE_RE = re.compile(
    r"^\s*(?P<file>[^\s:]+\.dart)\s*:\s*(?P<count>\d+)\s+fix(?:es)?\b(.*)$",
    re.IGNORECASE,
)
_DART_ANALYZE_RE = re.compile(
    r"^\s*(?P<sev>info|warning|error)\s+[-•]\s+(?P<msg>.+?)\s+[-•]\s+"
    r"(?P<file>[^\s:]+\.dart):(?P<line>\d+):(?P<col>\d+)\s+[-•]\s+"
    r"(?P<code>[a-z0-9_]+)\s*$",
    re.IGNORECASE,
)

_SQL_BREAKING_RULES: tuple[tuple[re.Pattern[str], str, str], ...] = (
    (
        re.compile(r"\bDROP\s+TABLE\b", re.IGNORECASE),
        "sql-drop-table",
        "DROP TABLE breaks older clients; follow 14-day Expand/Contract.",
    ),
    (
        re.compile(r"\bDROP\s+COLUMN\b", re.IGNORECASE),
        "sql-drop-column",
        "DROP COLUMN breaks older clients; use DUAL-WRITE TRANSITION first.",
    ),
    (
        re.compile(
            r"\bALTER\s+TABLE\b[^;]*\bALTER\s+COLUMN\b[^;]*\bTYPE\b",
            re.IGNORECASE,
        ),
        "sql-alter-column-type",
        "ALTER COLUMN TYPE can lock/break readers; add a new column instead.",
    ),
    (
        re.compile(r"\bRENAME\s+COLUMN\b", re.IGNORECASE),
        "sql-rename-column",
        "RENAME COLUMN breaks active readers; add new column + dual-write.",
    ),
    (
        re.compile(r"\bTRUNCATE\b", re.IGNORECASE),
        "sql-truncate",
        "TRUNCATE is destructive and non-backward-compatible in migrations.",
    ),
)
_ADD_COL_NOT_NULL_RE = re.compile(
    r"\bADD\s+(?:COLUMN\s+)?[A-Za-z_][A-Za-z0-9_]*\b[^;]*\bNOT\s+NULL\b",
    re.IGNORECASE,
)
_DEFAULT_RE = re.compile(r"\bDEFAULT\b", re.IGNORECASE)


@dataclass(frozen=True)
class DartRefactorSuggestion:
    file_path: str
    line: int | None
    rule_code: str
    message: str
    fixable: bool


@dataclass(frozen=True)
class SqlCompatViolation:
    path: str
    line: int
    code: str
    severity: str
    message: str
    dual_write_reference: str = DUAL_WRITE_DOC_REF


@dataclass(frozen=True)
class AutoRefactorCompatReport:
    refactor_suggestions: tuple[DartRefactorSuggestion, ...]
    sql_violations: tuple[SqlCompatViolation, ...]
    has_breaking_sql: bool
    markdown: str


def parse_dart_fix_output(text: str) -> list[DartRefactorSuggestion]:
    """Parse `dart fix --dry-run` summary lines into structured items."""
    suggestions: list[DartRefactorSuggestion] = []
    for raw in text.splitlines():
        match = _DART_FIX_LINE_RE.match(raw)
        if not match:
            continue
        file_path = match.group("file").strip()
        count = int(match.group("count"))
        detail = match.group(3).strip(" ()")
        suggestions.append(
            DartRefactorSuggestion(
                file_path=file_path,
                line=None,
                rule_code="dart_fix_dry_run",
                message=f"{count} auto-fixable item(s){': ' + detail if detail else ''}",
                fixable=True,
            )
        )
    return suggestions


def parse_dart_analyze_output(text: str) -> list[DartRefactorSuggestion]:
    """Parse `dart analyze` diagnostic lines into structured suggestions."""
    suggestions: list[DartRefactorSuggestion] = []
    for raw in text.splitlines():
        match = _DART_ANALYZE_RE.match(raw)
        if not match:
            continue
        suggestions.append(
            DartRefactorSuggestion(
                file_path=match.group("file").strip(),
                line=int(match.group("line")),
                rule_code=match.group("code").strip(),
                message=f"[{match.group('sev').lower()}] {match.group('msg').strip()}",
                fixable=False,
            )
        )
    return suggestions


def _strip_sql_comments(sql: str) -> str:
    without_block = re.sub(r"/\*.*?\*/", " ", sql, flags=re.DOTALL)
    lines = []
    for line in without_block.splitlines():
        lines.append(line.split("--", 1)[0])
    return "\n".join(lines)


def lint_sql_migration(path: Path) -> list[SqlCompatViolation]:
    """Lint a SQL migration file for backward-compatibility violations."""
    if not path.exists() or not path.is_file():
        return []
    try:
        raw = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return []

    cleaned = _strip_sql_comments(raw)
    violations: list[SqlCompatViolation] = []

    for line_no, line in enumerate(cleaned.splitlines(), start=1):
        stmt = line.strip()
        if not stmt:
            continue
        for pattern, code, message in _SQL_BREAKING_RULES:
            if pattern.search(stmt):
                violations.append(
                    SqlCompatViolation(
                        path=path.as_posix(),
                        line=line_no,
                        code=code,
                        severity="breaking",
                        message=message,
                    )
                )
        if _ADD_COL_NOT_NULL_RE.search(stmt) and not _DEFAULT_RE.search(stmt):
            violations.append(
                SqlCompatViolation(
                    path=path.as_posix(),
                    line=line_no,
                    code="sql-not-null-no-default",
                    severity="breaking",
                    message=(
                        "ADD COLUMN NOT NULL without DEFAULT breaks existing "
                        "writers; add nullable or provide DEFAULT."
                    ),
                )
            )
    return violations


def render_pr_markdown(
    *,
    refactor_suggestions: Sequence[DartRefactorSuggestion],
    sql_violations: Sequence[SqlCompatViolation],
    has_breaking_sql: bool,
) -> str:
    """Render deterministic PR review Markdown for refactoring & SQL compat."""
    lines = [
        "## Auto-Refactor & Backward-Compatibility Report",
        f"- Dart Refactor/Analyze Suggestions: `{len(refactor_suggestions)}`",
        f"- SQL Backward-Compatibility Violations: `{len(sql_violations)}`",
        f"- Breaking SQL Detected: `{has_breaking_sql}`",
    ]

    if refactor_suggestions:
        lines.append("")
        lines.append("### Dart Refactoring Suggestions")
        for item in refactor_suggestions:
            loc = f":{item.line}" if item.line is not None else ""
            lines.append(
                f"- `[{item.rule_code}]` `{item.file_path}{loc}` — {item.message}"
            )

    if sql_violations:
        lines.append("")
        lines.append(
            f"### SQL Compatibility Violations (see `{DUAL_WRITE_DOC_REF}`)"
        )
        for v in sql_violations:
            lines.append(
                f"- `[{v.severity}:{v.code}]` `{v.path}:{v.line}` — {v.message}"
            )

    return "\n".join(lines) + "\n"


def evaluate_refactor_and_compat(
    *,
    sql_paths: Sequence[Path] = (),
    dart_fix_log: str = "",
    dart_analyze_log: str = "",
) -> AutoRefactorCompatReport:
    """Run Dart log parsing and SQL migration backward-compat linting."""
    suggestions = [
        *parse_dart_fix_output(dart_fix_log),
        *parse_dart_analyze_output(dart_analyze_log),
    ]
    violations: list[SqlCompatViolation] = []
    for path in sql_paths:
        violations.extend(lint_sql_migration(path))

    has_breaking_sql = len(violations) > 0
    markdown = render_pr_markdown(
        refactor_suggestions=suggestions,
        sql_violations=violations,
        has_breaking_sql=has_breaking_sql,
    )
    return AutoRefactorCompatReport(
        refactor_suggestions=tuple(suggestions),
        sql_violations=tuple(violations),
        has_breaking_sql=has_breaking_sql,
        markdown=markdown,
    )


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Auto-refactor dry-run & SQL backward-compat linter.",
    )
    parser.add_argument("--sql-files", nargs="*", default=[])
    parser.add_argument("--dart-fix-log", default="")
    parser.add_argument("--dart-analyze-log", default="")
    parser.add_argument("--markdown", action="store_true")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--fail-on-breaking", action="store_true")
    args = parser.parse_args(argv)

    fix_text = (
        Path(args.dart_fix_log).read_text(encoding="utf-8")
        if args.dart_fix_log
        else ""
    )
    analyze_text = (
        Path(args.dart_analyze_log).read_text(encoding="utf-8")
        if args.dart_analyze_log
        else ""
    )
    report = evaluate_refactor_and_compat(
        sql_paths=[Path(p) for p in args.sql_files],
        dart_fix_log=fix_text,
        dart_analyze_log=analyze_text,
    )

    if args.json:
        print(json.dumps(asdict(report), ensure_ascii=False, indent=2))
    else:
        print(report.markdown)

    if args.fail_on_breaking and report.has_breaking_sql:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
