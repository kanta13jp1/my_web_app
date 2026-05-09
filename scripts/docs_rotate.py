#!/usr/bin/env python3
"""Archive aged schedule-output docs for Issue #1984 axis E.

The default mode is a dry-run report. Use --apply to move files whose filename
contains a date older than the retention window. Filename dates are used instead
of filesystem mtimes because CI checkouts refresh mtimes on every run.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
from dataclasses import asdict, dataclass
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any


DEFAULT_TARGETS = (
    "docs/cs-notes",
    "docs/daily-reports",
    "docs/auto-blog",
)
DEFAULT_ARCHIVE_ROOT = "docs/_archive"
DATE_RE = re.compile(r"(20\d{2}-\d{2}-\d{2})")


@dataclass
class RotationCandidate:
    source: str
    destination: str
    source_bucket: str
    archive_month: str
    file_date: str
    age_days: int
    size_bytes: int
    status: str
    reason: str
    moved: bool = False


def git_root(cwd: Path) -> Path:
    current = cwd.resolve(strict=False)
    for path in (current, *current.parents):
        if (path / ".git").exists():
            return path
    raise RuntimeError(f"not inside a git worktree: {cwd}")


def norm_path(path: Path) -> str:
    return os.path.normcase(str(path.resolve(strict=False)))


def same_or_child(child: Path, parent: Path) -> bool:
    child_s = norm_path(child)
    parent_s = norm_path(parent)
    return child_s == parent_s or child_s.startswith(parent_s + os.sep)


def parse_iso_date(value: str) -> date:
    return datetime.strptime(value, "%Y-%m-%d").date()


def file_date_from_name(path: Path) -> date | None:
    match = DATE_RE.search(path.name)
    if not match:
        return None
    try:
        return parse_iso_date(match.group(1))
    except ValueError:
        return None


def relative_posix(root: Path, path: Path) -> str:
    return path.resolve(strict=False).relative_to(root.resolve(strict=False)).as_posix()


def archive_destination(root: Path, archive_root: Path, source_dir: Path, source: Path) -> Path:
    file_date = file_date_from_name(source)
    if file_date is None:
        raise ValueError(f"source filename does not contain a date: {source}")
    month = file_date.strftime("%Y-%m")
    bucket = source_dir.name
    return archive_root / month / bucket / source.name


def iter_target_files(root: Path, targets: list[str]) -> list[tuple[Path, Path]]:
    files: list[tuple[Path, Path]] = []
    for target in targets:
        target_dir = (root / target).resolve(strict=False)
        if not target_dir.exists() or not target_dir.is_dir():
            continue
        if not same_or_child(target_dir, root):
            continue
        for path in sorted(target_dir.iterdir(), key=lambda item: item.name):
            if not path.is_file():
                continue
            if path.name == ".gitkeep":
                continue
            files.append((target_dir, path))
    return files


def collect_candidates(
    *,
    root: Path,
    targets: list[str],
    archive_root: Path,
    today: date,
    age_days: int,
) -> tuple[list[RotationCandidate], dict[str, int], int]:
    candidates: list[RotationCandidate] = []
    skipped: dict[str, int] = {}
    scanned = 0

    def count_skip(reason: str) -> None:
        skipped[reason] = skipped.get(reason, 0) + 1

    archive_root = archive_root.resolve(strict=False)
    for source_dir, source in iter_target_files(root, targets):
        scanned += 1
        file_date = file_date_from_name(source)
        if file_date is None:
            count_skip("filename has no YYYY-MM-DD date")
            continue
        age = (today - file_date).days
        if age < age_days:
            count_skip(f"younger than {age_days} days")
            continue
        destination = archive_destination(root, archive_root, source_dir, source)
        if destination.exists():
            count_skip("archive destination already exists")
            continue
        try:
            size_bytes = source.stat().st_size
        except OSError:
            count_skip("source stat failed")
            continue
        candidates.append(
            RotationCandidate(
                source=relative_posix(root, source),
                destination=relative_posix(root, destination),
                source_bucket=source_dir.name,
                archive_month=file_date.strftime("%Y-%m"),
                file_date=file_date.isoformat(),
                age_days=age,
                size_bytes=size_bytes,
                status="planned",
                reason="dry-run; pass --apply to move",
            )
        )
    return candidates, skipped, scanned


def move_candidates(root: Path, candidates: list[RotationCandidate]) -> None:
    for candidate in candidates:
        source = root / candidate.source
        destination = root / candidate.destination
        try:
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(source), str(destination))
        except OSError as exc:
            candidate.status = "failed"
            candidate.reason = str(exc)
            candidate.moved = False
            continue
        candidate.status = "success"
        candidate.reason = "moved to archive"
        candidate.moved = True


def size_mb(value: int) -> float:
    return round(value / (1024 * 1024), 3)


def summary_payload(
    *,
    root: Path,
    archive_root: Path,
    targets: list[str],
    today: date,
    age_days: int,
    apply: bool,
    scanned: int,
    skipped: dict[str, int],
    candidates: list[RotationCandidate],
) -> dict[str, Any]:
    moved = [item for item in candidates if item.moved]
    failed = [item for item in candidates if item.status == "failed"]
    total_bytes = sum(item.size_bytes for item in candidates)
    moved_bytes = sum(item.size_bytes for item in moved)
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "mode": "apply" if apply else "dry-run",
        "root": str(root),
        "archive_root": relative_posix(root, archive_root),
        "targets": targets,
        "today": today.isoformat(),
        "age_days": age_days,
        "files_scanned": scanned,
        "candidates": len(candidates),
        "moved": len(moved),
        "failed": len(failed),
        "candidate_bytes": total_bytes,
        "candidate_mb": size_mb(total_bytes),
        "moved_bytes": moved_bytes,
        "moved_mb": size_mb(moved_bytes),
        "skipped": skipped,
        "items": [asdict(item) for item in candidates],
    }


def print_report(payload: dict[str, Any]) -> None:
    print("")
    print("=== Docs Rotate Report ===")
    print(f"mode: {payload['mode']}")
    print(f"today: {payload['today']}")
    print(f"age_days: {payload['age_days']}")
    print(f"archive_root: {payload['archive_root']}")
    print("")
    print(f"files scanned: {payload['files_scanned']}")
    print(f"candidates:    {payload['candidates']}")
    print(f"moved:         {payload['moved']}")
    print(f"failed:        {payload['failed']}")
    print(f"candidate MB:  {payload['candidate_mb']}")
    print(f"moved MB:      {payload['moved_mb']}")
    if payload["skipped"]:
        print("")
        print("Skipped:")
        for reason, count in sorted(payload["skipped"].items()):
            print(f"- {reason}: {count}")
    if payload["items"]:
        print("")
        print("Candidates:")
        for item in payload["items"][:40]:
            print(f"- {item['source']} -> {item['destination']} ({item['status']})")
        if len(payload["items"]) > 40:
            print(f"- ... {len(payload['items']) - 40} more")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd(), help="Repository/worktree root.")
    parser.add_argument("--age-days", type=int, default=90, help="Minimum file age in days.")
    parser.add_argument("--archive-root", default=DEFAULT_ARCHIVE_ROOT)
    parser.add_argument(
        "--target",
        action="append",
        default=None,
        help="Target directory relative to repo root. Repeatable.",
    )
    parser.add_argument("--today", help="Override today's date as YYYY-MM-DD for validation.")
    parser.add_argument("--apply", action="store_true", help="Move candidates into the archive.")
    parser.add_argument("--json", action="store_true", help="Print the machine-readable summary.")
    parser.add_argument("--json-out", type=Path, help="Write the machine-readable summary.")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    root = git_root(args.root)
    today = parse_iso_date(args.today) if args.today else date.today()
    targets = args.target or list(DEFAULT_TARGETS)
    archive_root = (root / args.archive_root).resolve(strict=False)
    if not same_or_child(archive_root, root):
        raise RuntimeError(f"archive root must stay inside repo: {archive_root}")

    candidates, skipped, scanned = collect_candidates(
        root=root,
        targets=targets,
        archive_root=archive_root,
        today=today,
        age_days=args.age_days,
    )
    if args.apply:
        move_candidates(root, candidates)

    payload = summary_payload(
        root=root,
        archive_root=archive_root,
        targets=targets,
        today=today,
        age_days=args.age_days,
        apply=args.apply,
        scanned=scanned,
        skipped=skipped,
        candidates=candidates,
    )
    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        print_report(payload)
    return 1 if payload["failed"] else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
