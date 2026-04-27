"""Detect Supabase migration timestamp collisions and suggest a repair.

Win版#132 part 47 — automation of OPERATIONS_CHARTER improvement trigger #1
("衝突しそうな割り振り") for the recurring failure mode documented in
memory/feedback_correction_20260428_migration_timestamp_collision.md:

    Multiple instances (PS#3 / PS#5 / PS#6) created migration files at the
    very same YYYYMMDD000000 timestamp on 2026-04-28; deploy-prod hit
    SQLSTATE 23505 schema_migrations_pkey UNIQUE violation; PS#1 S53 had to
    rename two of the three files to recover.

This script catches the same situation **before** the commit, by walking
supabase/migrations/, grouping files by their 14-digit timestamp prefix,
and reporting any group of size >= 2. For each collision it also prints
the smallest free timestamp on the same day in 100-second steps so the
caller can rename quickly.

Exit codes:
    0  no collision detected
    1  one or more collisions detected (caller should fail the build)
    2  invocation error (no migrations dir, etc.)

Usage:
    python scripts/check_migration_timestamps.py
    python scripts/check_migration_timestamps.py --dir supabase/migrations
    python scripts/check_migration_timestamps.py --json   # machine-readable

Designed to be cheap enough to run on every PR (no DB connection, no API
calls — just a directory listing and a regex).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

TIMESTAMP_RE = re.compile(r"^(\d{14})_")
DEFAULT_DIR = Path("supabase/migrations")


def collect_groups(migrations_dir: Path) -> dict[str, list[str]]:
    """Return a dict of {timestamp: [filename, ...]} for files matching the
    14-digit-then-underscore migration naming convention."""
    groups: dict[str, list[str]] = defaultdict(list)
    for p in sorted(migrations_dir.iterdir()):
        if not p.is_file() or p.suffix != ".sql":
            continue
        m = TIMESTAMP_RE.match(p.name)
        if not m:
            continue
        groups[m.group(1)].append(p.name)
    return groups


def suggest_free_timestamp(taken: set[str], collided_ts: str) -> str | None:
    """Find the smallest unused timestamp on the same day as `collided_ts`,
    walking forward in 100-second steps then 500-second steps. Returns the
    suggestion or None if the day is unusably saturated.
    """
    day = collided_ts[:8]  # YYYYMMDD
    base = int(collided_ts)
    # day-end ceiling: YYYYMMDD235959 (no 24h ceiling on the second component
    # because we're not really seconds — they're synthetic; Supabase only
    # cares about the lexical order)
    ceiling = int(day + "999999")
    for delta in (100, 200, 300, 500, 1000, 1500, 2000, 5000, 10000, 50000, 100000):
        candidate_int = base + delta
        if candidate_int > ceiling:
            break
        candidate = str(candidate_int).zfill(14)
        if candidate not in taken:
            return candidate
    return None


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Detect Supabase migration timestamp collisions",
    )
    ap.add_argument(
        "--dir",
        type=Path,
        default=DEFAULT_DIR,
        help=f"Path to migrations directory (default: {DEFAULT_DIR})",
    )
    ap.add_argument(
        "--json",
        action="store_true",
        help="Emit machine-readable JSON instead of human-readable text",
    )
    args = ap.parse_args()

    if not args.dir.exists() or not args.dir.is_dir():
        print(f"migrations directory not found: {args.dir}", file=sys.stderr)
        return 2

    groups = collect_groups(args.dir)
    collisions = {ts: files for ts, files in groups.items() if len(files) >= 2}
    taken = set(groups)

    payload: dict[str, object] = {
        "total_migrations": sum(len(v) for v in groups.values()),
        "unique_timestamps": len(groups),
        "collision_count": len(collisions),
        "collisions": [],
    }
    for ts, files in sorted(collisions.items()):
        suggestion = suggest_free_timestamp(taken, ts)
        payload["collisions"].append({  # type: ignore[union-attr]
            "timestamp": ts,
            "files": files,
            "suggested_free_timestamp": suggestion,
        })

    if args.json:
        print(json.dumps(payload, indent=2, ensure_ascii=False))
    else:
        print(f"scanned {payload['total_migrations']} migration files / "
              f"{payload['unique_timestamps']} unique timestamps")
        if not collisions:
            print("OK no timestamp collisions")
        else:
            print(f"FAIL {payload['collision_count']} timestamp collision(s):")
            for c in payload["collisions"]:  # type: ignore[index]
                ts = c["timestamp"]  # type: ignore[index]
                files = c["files"]  # type: ignore[index]
                suggestion = c["suggested_free_timestamp"]  # type: ignore[index]
                print(f"  {ts} ({len(files)} files):")
                for f in files:
                    print(f"    - {f}")
                if suggestion:
                    keep = files[0]
                    others = files[1:]
                    print(f"    suggestion: keep {keep}; rename one of "
                          f"{others} to use timestamp {suggestion}")
                else:
                    print("    suggestion: day is saturated — pick the next day's timestamp")

    return 0 if not collisions else 1


if __name__ == "__main__":
    raise SystemExit(main())
