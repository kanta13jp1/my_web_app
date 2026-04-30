"""CI and deploy failure digests for GitHub Actions.

The script keeps recurring workflow failures actionable by extracting the
small part of a long log that an agent or maintainer needs next. It is
dependency-free so it can run early in CI jobs.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

VERSION_RE = re.compile(r"\b\d{14}\b")
MIGRATION_FILE_RE = re.compile(r"^(\d{14})_.*\.sql$")

DEN0_KEYWORDS = (
    "error",
    "warning",
    "lint",
    "deno",
    ".ts:",
    "supabase/functions",
)

DEPLOY_KEYWORDS = (
    "error",
    "failed",
    "remote migration",
    "schema_migrations",
    "sqlstate",
    "duplicate key",
    "repair",
    "esm.sh",
    "deno",
    "supabase",
)


def append_summary(summary_path: str | None, title: str, lines: list[str]) -> None:
    if not summary_path:
        return
    path = Path(summary_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8", newline="\n") as fh:
        fh.write(f"\n## {title}\n\n")
        for line in lines:
            fh.write(f"{line}\n")


def latest_migrations(migrations_dir: Path, limit: int) -> list[Path]:
    if not migrations_dir.exists():
        return []
    files = [
        p for p in migrations_dir.iterdir()
        if p.is_file() and MIGRATION_FILE_RE.match(p.name)
    ]
    return sorted(files, key=lambda p: p.name, reverse=True)[:limit]


def read_log_text(path: Path) -> str:
    data = path.read_bytes()
    sample = data[:2000]
    if b"\x00" in sample:
        return data.decode("utf-16", errors="replace")
    return data.decode("utf-8-sig", errors="replace")


def log_digest(log_text: str, kind: str, max_lines: int) -> list[str]:
    keywords = DEN0_KEYWORDS if kind == "deno-lint" else DEPLOY_KEYWORDS
    matched: list[str] = []
    for raw in log_text.splitlines():
        line = raw.rstrip()
        if any(k in line.lower() for k in keywords):
            matched.append(line)
    if not matched:
        matched = [line.rstrip() for line in log_text.splitlines()[-max_lines:]]
    return matched[-max_lines:]


def classify_migration_failure(log_text: str) -> tuple[str, list[str]]:
    lower = log_text.lower()
    versions = sorted(set(VERSION_RE.findall(log_text)))
    if "schema_migrations_pkey" in lower or "duplicate key" in lower:
        return "applied", versions
    if "remote migration" in lower or "migration versions not found" in lower:
        return "reverted", versions
    return "unknown", versions


def run_command(command: list[str], log_path: Path) -> int:
    proc = subprocess.run(
        command,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    output = proc.stdout or ""
    print(output, end="")
    with log_path.open("a", encoding="utf-8", newline="\n") as fh:
        fh.write(f"\n$ {' '.join(command)}\n")
        fh.write(output)
        fh.write(f"\nexit={proc.returncode}\n")
    return proc.returncode


def summarize_log(args: argparse.Namespace) -> int:
    log_path = Path(args.log)
    if not log_path.exists():
        print(f"log file not found: {log_path}", file=sys.stderr)
        return 2
    text = read_log_text(log_path)
    digest = log_digest(text, args.kind, args.max_lines)
    lines = [
        f"- Log: `{log_path}`",
        f"- Extracted lines: {len(digest)}",
        "",
        "```text",
        *digest,
        "```",
    ]
    append_summary(args.summary, f"{args.kind} failure digest", lines)
    print("\n".join(lines))
    return 0


def supabase_db_push(args: argparse.Namespace) -> int:
    log_dir = Path(args.log_dir)
    log_dir.mkdir(parents=True, exist_ok=True)
    push_log = log_dir / "supabase-db-push.log"
    migration_list_log = log_dir / "supabase-migration-list.log"

    recent = latest_migrations(Path(args.migrations_dir), args.recent_limit)
    timestamp = datetime.now(timezone.utc).isoformat()
    summary_lines = [
        f"- Checked at: `{timestamp}`",
        f"- Recent local migration files: {len(recent)}",
    ]
    if recent:
        summary_lines.append("")
        summary_lines.append("```text")
        summary_lines.extend(p.name for p in recent)
        summary_lines.append("```")
    append_summary(args.summary, "Supabase migration preflight", summary_lines)

    with push_log.open("w", encoding="utf-8", newline="\n") as fh:
        fh.write(f"checked_at={timestamp}\n")
        fh.write("recent_migrations:\n")
        for migration in recent:
            fh.write(f"- {migration.name}\n")

    run_command(["supabase", "migration", "list"], migration_list_log)

    push_args = ["supabase", "db", "push"]
    if args.include_all:
        push_args.append("--include-all")
    first_exit = run_command(push_args, push_log)
    if first_exit == 0:
        append_summary(args.summary, "Supabase migration result", ["- `supabase db push` succeeded on the first attempt."])
        return 0

    log_text = read_log_text(push_log)
    repair_status, versions = classify_migration_failure(log_text)
    digest = log_digest(log_text, "supabase", args.max_digest_lines)
    failure_lines = [
        f"- First attempt exit: `{first_exit}`",
        f"- Repair classification: `{repair_status}`",
        f"- Extracted versions: `{', '.join(versions) if versions else 'none'}`",
        "",
        "```text",
        *digest,
        "```",
    ]
    append_summary(args.summary, "Supabase migration failure digest", failure_lines)

    if repair_status == "unknown" or not versions:
        print("No safe migration repair action detected; leaving failure intact.")
        return first_exit

    for version in versions:
        run_command(["supabase", "migration", "repair", "--status", repair_status, version], push_log)

    retry_exit = run_command(push_args, push_log)
    result = "succeeded" if retry_exit == 0 else "failed"
    append_summary(
        args.summary,
        "Supabase migration repair retry",
        [
            f"- Repair status used: `{repair_status}`",
            f"- Versions: `{', '.join(versions)}`",
            f"- Retry result: `{result}`",
        ],
    )
    return retry_exit


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract CI/deploy failure digests")
    sub = parser.add_subparsers(dest="command", required=True)

    summarize = sub.add_parser("summarize-log")
    summarize.add_argument("log")
    summarize.add_argument("--kind", default="generic")
    summarize.add_argument("--summary")
    summarize.add_argument("--max-lines", type=int, default=80)
    summarize.set_defaults(func=summarize_log)

    supabase = sub.add_parser("supabase-db-push")
    supabase.add_argument("--log-dir", default=".deploy-logs")
    supabase.add_argument("--summary")
    supabase.add_argument("--migrations-dir", default="supabase/migrations")
    supabase.add_argument("--recent-limit", type=int, default=10)
    supabase.add_argument("--max-digest-lines", type=int, default=80)
    supabase.add_argument("--include-all", action="store_true")
    supabase.set_defaults(func=supabase_db_push)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
