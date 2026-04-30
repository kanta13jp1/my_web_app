#!/usr/bin/env python3
"""
Detect NEW migrations (in this PR/push) that UPDATE tables with time-relative
enforcement triggers.

Root cause this prevents: PS#5 S78 (commit c698681e9)
  wbs_tasks.wbs_enforce_recovery_plan_trg checked planned_end_date < CURRENT_DATE.
  A migration doing UPDATE wbs_tasks passed when created but failed 2 days later.

Strategy:
  1. Find all tables that have BEFORE UPDATE triggers whose function body
     references CURRENT_DATE / NOW().
  2. From the set of NEW migration files (added/changed in this push or PR),
     find any that UPDATE one of those tables.
  3. Warn; exit 1 if any found.

In PR mode: GITHUB_BASE_SHA = PR base commit → git diff base..HEAD.
In push mode: GITHUB_BASE_SHA = github.event.before → git diff before..HEAD.
Fallback (initial/force push with 0000... SHA): check only HEAD~1..HEAD.

Exit codes: 0 = clean, 1 = risky migrations found
"""
import os
import re
import subprocess
import sys
from pathlib import Path

MIGRATIONS_DIR = Path("supabase/migrations")

FUNC_DEF_RE = re.compile(
    r"CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+(\w+)\s*\([^)]*\)"
    r".*?AS\s+\$\w*\$(.*?)\$\w*\$",
    re.IGNORECASE | re.DOTALL,
)
TIME_IN_BODY_RE = re.compile(
    r"\bCURRENT_DATE\b|\bNOW\s*\(\s*\)|\bCURRENT_TIMESTAMP\b",
    re.IGNORECASE,
)
TRIGGER_ATTACH_RE = re.compile(
    r"CREATE\s+(?:OR\s+REPLACE\s+)?TRIGGER\s+\S+\s+"
    r"BEFORE\s+(?:INSERT\s+OR\s+UPDATE|UPDATE\s+OR\s+INSERT|UPDATE)\s+ON\s+(\w+)",
    re.IGNORECASE,
)
EXEC_FUNC_RE = re.compile(r"EXECUTE\s+(?:FUNCTION|PROCEDURE)\s+(\w+)", re.IGNORECASE)
UPDATE_RE = re.compile(r"\bUPDATE\s+(\w+)\b", re.IGNORECASE)


def get_time_enforcement_tables() -> tuple[set[str], set[str]]:
    """Return (defining_files, sensitive_tables)."""
    time_funcs: set[str] = set()
    table_to_funcs: dict[str, set[str]] = {}
    defining_files: set[str] = set()

    for sql_file in MIGRATIONS_DIR.glob("*.sql"):
        content = sql_file.read_text(encoding="utf-8", errors="replace")
        for m in FUNC_DEF_RE.finditer(content):
            if TIME_IN_BODY_RE.search(m.group(2)):
                time_funcs.add(m.group(1).lower())
        for tm in TRIGGER_ATTACH_RE.finditer(content):
            table = tm.group(1).lower()
            rest = content[tm.start():tm.start() + 600]
            em = EXEC_FUNC_RE.search(rest)
            if em:
                table_to_funcs.setdefault(table, set()).add(em.group(1).lower())
                defining_files.add(sql_file.name)

    sensitive = {t for t, fns in table_to_funcs.items() if fns & time_funcs}
    return defining_files, sensitive


def get_new_migration_files() -> list[Path]:
    """Return migration files that are new/changed in this push vs base."""
    base_sha = os.environ.get("GITHUB_BASE_SHA") or os.environ.get("BASE_SHA")

    # Ignore all-zeros SHA (initial push / force push with no history)
    if base_sha and not base_sha.startswith("0000000"):
        result = subprocess.run(
            ["git", "diff", "--name-only", "--diff-filter=A", base_sha, "HEAD"],
            capture_output=True, text=True,
        )
        changed = [
            MIGRATIONS_DIR / Path(p).name
            for p in result.stdout.splitlines()
            if p.startswith("supabase/migrations/") and p.endswith(".sql")
        ]
        return [f for f in changed if f.exists()]

    # Fallback: check only the last commit (HEAD~1..HEAD)
    result = subprocess.run(
        ["git", "diff", "--name-only", "--diff-filter=A", "HEAD~1", "HEAD",
         "--", "supabase/migrations/*.sql"],
        capture_output=True, text=True,
    )
    added = [
        MIGRATIONS_DIR / Path(p).name
        for p in result.stdout.splitlines()
        if p.strip() and p.endswith(".sql")
    ]
    return [f for f in added if f.exists()]


def main() -> int:
    if not MIGRATIONS_DIR.exists():
        print(f"ERROR: {MIGRATIONS_DIR} not found", file=sys.stderr)
        return 1

    total = len(list(MIGRATIONS_DIR.glob("*.sql")))
    defining_files, sensitive = get_time_enforcement_tables()

    if not sensitive:
        print(f"scanned {total} migration files — no time-relative enforcement triggers found")
        return 0

    print(f"scanned {total} migrations; time-sensitive tables: {', '.join(sorted(sensitive))}")

    new_files = get_new_migration_files()
    if not new_files:
        print("no new migration files in this push — clean")
        return 0

    print(f"checking {len(new_files)} new migration file(s)...")

    NOCHECK_RE = re.compile(r"--\s*nocheck:\s*time-relative", re.IGNORECASE)

    risky = []
    for sql_file in new_files:
        if sql_file.name in defining_files:
            continue
        content = sql_file.read_text(encoding="utf-8", errors="replace")
        if NOCHECK_RE.search(content):
            print(f"  skip: {sql_file.name} (-- nocheck: time-relative)")
            continue
        for m in UPDATE_RE.finditer(content):
            if m.group(1).lower() in sensitive:
                risky.append({"file": sql_file.name, "table": m.group(1).lower()})
                break

    if not risky:
        print("clean — no new migration UPDATEs a time-constrained table")
        return 0

    print(f"\nWARN: {len(risky)} new migration(s) UPDATE time-sensitive table(s):")
    for r in risky:
        print(f"  - {r['file']}")
        print(f"    UPDATE {r['table']}")
        print(f"    This migration may fail on replay if a date constraint becomes violated.")
        print(f"    Fix: add a preceding migration to backfill constrained columns,")
        print(f"    or disable the trigger temporarily (SET session_replication_role = replica).")

    return 1


if __name__ == "__main__":
    sys.exit(main())
