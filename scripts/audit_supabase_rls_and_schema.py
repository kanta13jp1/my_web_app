#!/usr/bin/env python3
"""Deterministic Supabase RLS & schema governance auditor (#4131).

Scans supabase/migrations/*.sql for CREATE TABLE statements and verifies
whether ENABLE ROW LEVEL SECURITY and at least one CREATE POLICY exist.
"""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
import json
from pathlib import Path
import re
import sys

_CREATE_TABLE_RE = re.compile(
    r"CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?"
    r"([a-zA-Z0-9_.\"]+)",
    re.IGNORECASE,
)

_ENABLE_RLS_RE = re.compile(
    r"ALTER\s+TABLE\s+(?:IF\s+EXISTS\s+)?(?:ONLY\s+)?"
    r"([a-zA-Z0-9_.\"]+)\s+ENABLE\s+ROW\s+LEVEL\s+SECURITY",
    re.IGNORECASE,
)

_CREATE_POLICY_RE = re.compile(
    r"CREATE\s+POLICY\s+(?:\"?[^\s\"]+\"?|\S+)\s+ON\s+([a-zA-Z0-9_.\"]+)",
    re.IGNORECASE,
)


def normalize_table_name(raw_name: str) -> str:
    """Normalize [schema.]table_name to lowercase without quotes."""
    cleaned = raw_name.replace('"', "").strip().lower()
    if cleaned.startswith("public."):
        cleaned = cleaned[len("public.") :]
    return cleaned


@dataclass(frozen=True)
class RlsAuditSummary:
    total_migrations: int
    total_tables: int
    tables_with_rls: int
    tables_with_policy: int
    tables_missing_rls: list[str]
    tables_missing_policy: list[str]
    table_sources: dict[str, str]


def audit_migrations_dir(migrations_dir: Path) -> RlsAuditSummary:
    """Scan all *.sql files in migrations_dir for RLS & policy coverage."""
    if not migrations_dir.is_dir():
        raise FileNotFoundError(
            f"Migrations directory not found: {migrations_dir}",
        )

    sql_files = sorted(migrations_dir.glob("*.sql"))
    table_sources: dict[str, str] = {}
    rls_tables: set[str] = set()
    policy_tables: set[str] = set()

    for sql_path in sql_files:
        text = sql_path.read_text(encoding="utf-8", errors="replace")
        for match in _CREATE_TABLE_RE.finditer(text):
            tbl = normalize_table_name(match.group(1))
            if tbl not in table_sources:
                table_sources[tbl] = sql_path.name
        for match in _ENABLE_RLS_RE.finditer(text):
            rls_tables.add(normalize_table_name(match.group(1)))
        for match in _CREATE_POLICY_RE.finditer(text):
            policy_tables.add(normalize_table_name(match.group(1)))

    all_tables = sorted(table_sources.keys())
    missing_rls = [t for t in all_tables if t not in rls_tables]
    missing_policy = [t for t in all_tables if t not in policy_tables]

    return RlsAuditSummary(
        total_migrations=len(sql_files),
        total_tables=len(all_tables),
        tables_with_rls=len(all_tables) - len(missing_rls),
        tables_with_policy=len(all_tables) - len(missing_policy),
        tables_missing_rls=missing_rls,
        tables_missing_policy=missing_policy,
        table_sources=table_sources,
    )


def render_markdown(summary: RlsAuditSummary) -> str:
    """Render a concise Markdown inventory from RlsAuditSummary."""
    lines: list[str] = [
        "## Supabase RLS & Schema Governance Inventory",
        "",
        f"- **Migrations scanned**: {summary.total_migrations}",
        f"- **Tables discovered**: {summary.total_tables}",
        (
            f"- **Tables with RLS enabled**: "
            f"{summary.tables_with_rls}/{summary.total_tables}"
        ),
        (
            f"- **Tables with >=1 policy**: "
            f"{summary.tables_with_policy}/{summary.total_tables}"
        ),
        f"- **Missing RLS count**: {len(summary.tables_missing_rls)}",
        f"- **Missing policy count**: {len(summary.tables_missing_policy)}",
    ]
    return "\n".join(lines) + "\n"


def _parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Audit Supabase migrations for CREATE TABLE RLS coverage.",
    )
    parser.add_argument(
        "--migrations-dir",
        default="supabase/migrations",
        help="Directory containing *.sql migration files.",
    )
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--markdown", action="store_true")
    parser.add_argument("--fail-on-gap", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv if argv is not None else sys.argv[1:])
    summary = audit_migrations_dir(Path(args.migrations_dir))
    if args.json:
        print(json.dumps(asdict(summary), ensure_ascii=False, indent=2))
    elif args.markdown:
        print(render_markdown(summary), end="")
    else:
        print(
            f"migrations={summary.total_migrations} "
            f"tables={summary.total_tables} "
            f"missing_rls={len(summary.tables_missing_rls)} "
            f"missing_policy={len(summary.tables_missing_policy)}"
        )

    if args.fail_on_gap and (
        summary.tables_missing_rls or summary.tables_missing_policy
    ):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
