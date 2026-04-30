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

for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(errors="replace")

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
# Detect trigger early-return: IF NEW.status = 'completed' THEN RETURN NEW
TRIGGER_EARLY_RETURN_RE = re.compile(
    r"IF\s+NEW\s*\.\s*status\s*=\s*'completed'\s+THEN\s+RETURN\s+NEW",
    re.IGNORECASE,
)
# Detect UPDATE SET status = 'completed' (trailing \b omitted: quote is not \w)
SET_COMPLETED_RE = re.compile(r"\bstatus\s*=\s*'completed'", re.IGNORECASE)


def get_time_enforcement_tables() -> tuple[set[str], set[str], set[str]]:
    """Return (defining_files, sensitive_tables, completed_safe_tables).

    completed_safe_tables: tables whose trigger function has an early-return
    for status='completed', making SET status='completed' UPDATEs always safe.
    """
    time_funcs: set[str] = set()
    early_return_funcs: set[str] = set()
    table_to_funcs: dict[str, set[str]] = {}
    defining_files: set[str] = set()

    for sql_file in MIGRATIONS_DIR.glob("*.sql"):
        content = sql_file.read_text(encoding="utf-8", errors="replace")
        for m in FUNC_DEF_RE.finditer(content):
            body = m.group(2)
            if TIME_IN_BODY_RE.search(body):
                time_funcs.add(m.group(1).lower())
            if TRIGGER_EARLY_RETURN_RE.search(body):
                early_return_funcs.add(m.group(1).lower())
        for tm in TRIGGER_ATTACH_RE.finditer(content):
            table = tm.group(1).lower()
            rest = content[tm.start():tm.start() + 600]
            em = EXEC_FUNC_RE.search(rest)
            if em:
                table_to_funcs.setdefault(table, set()).add(em.group(1).lower())
                defining_files.add(sql_file.name)

    sensitive = {t for t, fns in table_to_funcs.items() if fns & time_funcs}
    completed_safe = {t for t, fns in table_to_funcs.items() if fns & early_return_funcs}
    return defining_files, sensitive, completed_safe


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
    defining_files, sensitive, completed_safe = get_time_enforcement_tables()

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
            table = m.group(1).lower()
            if table not in sensitive:
                continue
            # Safe if trigger short-circuits for completed status and this UPDATE sets it
            if table in completed_safe:
                stmt_end = content.find(';', m.start())
                stmt = content[m.start():stmt_end + 1] if stmt_end != -1 else content[m.start():]
                if SET_COMPLETED_RE.search(stmt):
                    print(f"  skip: {sql_file.name} (UPDATE {table} SET status='completed' — trigger short-circuits)")
                    break
            risky.append({"file": sql_file.name, "table": table})
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
