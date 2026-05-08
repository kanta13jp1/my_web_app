#!/usr/bin/env python3
"""Track per-session disk deltas for Issue #1984 Tier 2.0.

The script appends a small CSV row at SessionStart and SessionEnd. It is safe to
run locally or in CI; warning files are only emitted when a threshold is crossed.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import shutil
import sys
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from statistics import median
from typing import Any


HEADER = [
    "ts",
    "session_id",
    "phase",
    "c_free_gb",
    "reclaim_mb_session",
    "reclaim_mb_7d_median",
]


@dataclass(frozen=True)
class DeltaRow:
    ts: datetime
    session_id: str
    phase: str
    c_free_gb: float
    reclaim_mb_session: float | None
    reclaim_mb_7d_median: float | None


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def parse_timestamp(value: str) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def parse_optional_float(value: str) -> float | None:
    if value == "":
        return None
    try:
        return float(value)
    except ValueError:
        return None


def read_rows(path: Path) -> list[DeltaRow]:
    if not path.exists():
        return []
    rows: list[DeltaRow] = []
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        for item in reader:
            ts = parse_timestamp(item.get("ts", ""))
            if ts is None:
                continue
            rows.append(
                DeltaRow(
                    ts=ts,
                    session_id=item.get("session_id", ""),
                    phase=item.get("phase", ""),
                    c_free_gb=parse_optional_float(item.get("c_free_gb", "")) or 0.0,
                    reclaim_mb_session=parse_optional_float(item.get("reclaim_mb_session", "")),
                    reclaim_mb_7d_median=parse_optional_float(item.get("reclaim_mb_7d_median", "")),
                )
            )
    return rows


def append_row(path: Path, row: dict[str, str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    exists = path.exists()
    with path.open("a", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=HEADER)
        if not exists:
            writer.writeheader()
        writer.writerow(row)


def c_free_gb() -> float:
    target = "C:\\" if os.name == "nt" else str(Path.home())
    try:
        usage = shutil.disk_usage(target)
    except OSError:
        usage = shutil.disk_usage(str(Path.cwd()))
    return round(usage.free / (1024**3), 2)


def default_session_id() -> str:
    explicit = os.environ.get("CLAUDE_SESSION_ID") or os.environ.get("CODEX_SESSION_ID")
    if explicit:
        return explicit[:16]
    basis = str(Path.cwd().resolve(strict=False)).encode("utf-8", errors="ignore")
    return hashlib.sha1(basis).hexdigest()[:8]


def seven_day_reclaims(rows: list[DeltaRow], now: datetime) -> list[float]:
    cutoff = now - timedelta(days=7)
    return [
        row.reclaim_mb_session
        for row in rows
        if row.phase == "end"
        and row.ts >= cutoff
        and row.reclaim_mb_session is not None
        and row.reclaim_mb_session >= 0
    ]


def median_reclaim_mb(rows: list[DeltaRow], now: datetime) -> float | None:
    values = seven_day_reclaims(rows, now)
    if not values:
        return None
    return round(float(median(values)), 1)


def latest_start_free(rows: list[DeltaRow], session_id: str) -> float | None:
    for row in reversed(rows):
        if row.session_id == session_id and row.phase == "start":
            return row.c_free_gb
    return None


def c_free_delta_7d(rows: list[DeltaRow], current_free_gb: float, now: datetime) -> float | None:
    cutoff = now - timedelta(days=7)
    window = [row for row in rows if row.ts >= cutoff]
    if not window:
        return None
    return round(current_free_gb - window[0].c_free_gb, 2)


def warnings_for(
    *,
    current_free_gb: float,
    reclaim_median_mb: float | None,
    free_delta_7d_gb: float | None,
    median_floor_mb: float,
    free_floor_gb: float,
    seven_day_delta_floor_gb: float,
) -> list[str]:
    warnings: list[str] = []
    if reclaim_median_mb is not None and reclaim_median_mb < median_floor_mb:
        warnings.append(f"7-day median reclaim {reclaim_median_mb} MB < {median_floor_mb:g} MB")
    if free_delta_7d_gb is not None and free_delta_7d_gb < seven_day_delta_floor_gb:
        warnings.append(f"C: free 7-day delta {free_delta_7d_gb} GB < {seven_day_delta_floor_gb:g} GB")
    if current_free_gb < free_floor_gb:
        warnings.append(f"C: free {current_free_gb} GB < {free_floor_gb:g} GB")
    return warnings


def write_warning(path: Path, warnings: list[str], payload: dict[str, Any]) -> Path:
    path.mkdir(parents=True, exist_ok=True)
    target = path / f"warning_{datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')}.md"
    lines = [
        "# Session Delta Warning",
        "",
        "## Warnings",
        "",
        *[f"- {item}" for item in warnings],
        "",
        "## Payload",
        "",
        "```json",
        json.dumps(payload, ensure_ascii=False, indent=2),
        "```",
        "",
    ]
    target.write_text("\n".join(lines), encoding="utf-8")
    return target


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase", choices=("start", "end"), required=True)
    parser.add_argument("--session-id", default=default_session_id())
    parser.add_argument("--log-path", type=Path, default=Path.home() / ".claude" / "logs" / "session-delta.csv")
    parser.add_argument("--warning-dir", type=Path, default=Path.home() / "cleanup_reports")
    parser.add_argument("--c-free-gb", type=float, help="Override current C: free GB for tests.")
    parser.add_argument("--reclaim-mb", type=float, help="Override session reclaim MB.")
    parser.add_argument("--median-floor-mb", type=float, default=100.0)
    parser.add_argument("--free-floor-gb", type=float, default=30.0)
    parser.add_argument("--seven-day-delta-floor-gb", type=float, default=-3.0)
    parser.add_argument("--no-warning-file", action="store_true")
    parser.add_argument("--json", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    rows = read_rows(args.log_path)
    now = now_utc()
    current_free = round(args.c_free_gb if args.c_free_gb is not None else c_free_gb(), 2)

    reclaim_mb = args.reclaim_mb
    if reclaim_mb is None and args.phase == "end":
        start_free = latest_start_free(rows, args.session_id)
        if start_free is not None:
            reclaim_mb = round((current_free - start_free) * 1024, 1)

    reclaim_median = median_reclaim_mb(rows, now)
    if reclaim_mb is not None:
        reclaim_median = median_reclaim_mb(
            [
                *rows,
                DeltaRow(now, args.session_id, args.phase, current_free, reclaim_mb, None),
            ],
            now,
        )
    free_delta = c_free_delta_7d(rows, current_free, now)
    warnings = warnings_for(
        current_free_gb=current_free,
        reclaim_median_mb=reclaim_median,
        free_delta_7d_gb=free_delta,
        median_floor_mb=args.median_floor_mb,
        free_floor_gb=args.free_floor_gb,
        seven_day_delta_floor_gb=args.seven_day_delta_floor_gb,
    )

    row = {
        "ts": now.isoformat().replace("+00:00", "Z"),
        "session_id": args.session_id,
        "phase": args.phase,
        "c_free_gb": f"{current_free:.2f}",
        "reclaim_mb_session": "" if reclaim_mb is None else f"{reclaim_mb:.1f}",
        "reclaim_mb_7d_median": "" if reclaim_median is None else f"{reclaim_median:.1f}",
    }
    append_row(args.log_path, row)

    payload: dict[str, Any] = {
        "phase": args.phase,
        "session_id": args.session_id,
        "log_path": str(args.log_path),
        "c_free_gb": current_free,
        "reclaim_mb_session": reclaim_mb,
        "reclaim_mb_7d_median": reclaim_median,
        "c_free_delta_7d_gb": free_delta,
        "warnings": warnings,
        "warning_path": "",
    }
    if warnings and not args.no_warning_file:
        payload["warning_path"] = str(write_warning(args.warning_dir, warnings, payload))

    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        print(f"session_delta phase={args.phase} c_free_gb={current_free} warnings={len(warnings)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
