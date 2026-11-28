#!/usr/bin/env python3
"""Audit DUAL-WRITE TRANSITION markers for 14-day zero-downtime migrations (#2774)."""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
from datetime import date
import json
from pathlib import Path
import re
import sys

SCAN_SUFFIXES = frozenset({".dart", ".ts", ".js", ".mjs", ".cjs", ".sql", ".py"})
EXCLUDED_PREFIXES = (
    ".git/",
    ".dart_tool/",
    "build/",
    "node_modules/",
    "docs/",
)
EXCLUDED_FILES = frozenset({
    "scripts/check_dual_write_markers.py",
    "scripts/test_dual_write_markers.py",
})
MARKER_PHRASE = "DUAL-WRITE TRANSITION"
ISSUE_RE = re.compile(r"\bissue\s*[:=]\s*#(\d+)\b", re.IGNORECASE)
SUNSET_RE = re.compile(r"\bsunset\s*[:=]\s*(\d{4}-\d{2}-\d{2})\b", re.IGNORECASE)
FAILSAFE_RE = re.compile(
    r"\bread-failsafe\s*[:=]\s*([A-Za-z0-9_./-]+)",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class MarkerFinding:
    path: str
    line: int
    status: str  # active | expired | invalid
    issue: str | None
    sunset: str | None
    read_failsafe: str | None
    errors: tuple[str, ...]
    raw_line: str

    def to_dict(self) -> dict[str, object]:
        payload = asdict(self)
        payload["errors"] = list(self.errors)
        return payload


def _is_scannable(rel_posix: str, include_self: bool = False) -> bool:
    if not include_self and rel_posix in EXCLUDED_FILES:
        return False
    if any(rel_posix.startswith(prefix) for prefix in EXCLUDED_PREFIXES):
        return False
    return Path(rel_posix).suffix.lower() in SCAN_SUFFIXES


def parse_marker_line(
    rel_posix: str,
    line_number: int,
    line_text: str,
    today: date,
) -> MarkerFinding:
    errors: list[str] = []

    issue_match = ISSUE_RE.search(line_text)
    issue_val = f"#{issue_match.group(1)}" if issue_match else None
    if issue_val is None:
        errors.append("missing issue=#<num>")

    sunset_match = SUNSET_RE.search(line_text)
    sunset_val = sunset_match.group(1) if sunset_match else None
    sunset_date: date | None = None
    if sunset_val is None:
        errors.append("missing sunset=YYYY-MM-DD")
    else:
        try:
            sunset_date = date.fromisoformat(sunset_val)
        except ValueError:
            errors.append(f"invalid sunset date: {sunset_val}")

    failsafe_match = FAILSAFE_RE.search(line_text)
    failsafe_val = failsafe_match.group(1) if failsafe_match else None
    if failsafe_val is None:
        errors.append("missing read-failsafe=<legacy-source>")

    if errors:
        status = "invalid"
    elif sunset_date is not None and sunset_date < today:
        status = "expired"
    else:
        status = "active"

    return MarkerFinding(
        path=rel_posix,
        line=line_number,
        status=status,
        issue=issue_val,
        sunset=sunset_val,
        read_failsafe=failsafe_val,
        errors=tuple(errors),
        raw_line=line_text.strip(),
    )


def scan_repository(
    root: Path,
    today: date | None = None,
    include_self: bool = False,
) -> list[MarkerFinding]:
    ref_date = today or date.today()
    findings: list[MarkerFinding] = []
    for file_path in sorted(root.rglob("*")):
        if not file_path.is_file():
            continue
        rel_posix = file_path.relative_to(root).as_posix()
        if not _is_scannable(rel_posix, include_self=include_self):
            continue
        text = file_path.read_text(encoding="utf-8", errors="replace")
        if MARKER_PHRASE not in text:
            continue
        for number, line in enumerate(text.splitlines(), start=1):
            if MARKER_PHRASE in line:
                findings.append(
                    parse_marker_line(rel_posix, number, line, ref_date)
                )
    return findings


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument(
        "--today",
        type=str,
        default=None,
        help="Override reference ISO date (YYYY-MM-DD) for expiration checks.",
    )
    parser.add_argument(
        "--strict-expired",
        action="store_true",
        help="Exit non-zero when expired DUAL-WRITE TRANSITION markers exist.",
    )
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)

    try:
        ref_date = date.fromisoformat(args.today) if args.today else date.today()
    except ValueError:
        print(f"Invalid --today date: {args.today}", file=sys.stderr)
        return 2

    findings = scan_repository(args.root.resolve(), today=ref_date)
    active = [f for f in findings if f.status == "active"]
    expired = [f for f in findings if f.status == "expired"]
    invalid = [f for f in findings if f.status == "invalid"]

    if args.json:
        print(
            json.dumps(
                {
                    "today": ref_date.isoformat(),
                    "active_count": len(active),
                    "expired_count": len(expired),
                    "invalid_count": len(invalid),
                    "findings": [f.to_dict() for f in findings],
                },
                ensure_ascii=False,
                indent=2,
            )
        )
    else:
        print(
            f"Dual-write markers: active={len(active)} "
            f"expired={len(expired)} invalid={len(invalid)}"
        )
        for item in invalid:
            print(
                f"INVALID {item.path}:{item.line}: {', '.join(item.errors)}"
            )
        for item in expired:
            print(
                f"EXPIRED {item.path}:{item.line}: sunset={item.sunset} "
                f"issue={item.issue}"
            )

    if invalid:
        return 1
    if args.strict_expired and expired:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
