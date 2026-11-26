#!/usr/bin/env python3
"""Living Docs staleness & Dart-doc readiness checker (#2793).

Inspects Markdown docs for `last_reviewed` (or `updated`) metadata, flags
documents exceeding `--max-age-days` (default 90), summarizes `///` Dart doc
comment readiness, and emits structured JSON + dry-run GitHub Issue payloads.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Sequence

DEFAULT_MAX_AGE_DAYS = 90

_DATE_FIELD_RE = re.compile(
    r"^(?:last_reviewed|updated)\s*:\s*(\d{4}-\d{2}-\d{2})\s*$",
    re.IGNORECASE | re.MULTILINE,
)
_DART_PUBLIC_TYPE_RE = re.compile(
    r"^\s*(?:abstract\s+)?(?:class|enum|mixin|extension)\s+([A-Za-z][A-Za-z0-9_]*)\b",
)


@dataclass(frozen=True)
class DocStalenessRecord:
    path: str
    last_reviewed: str | None
    age_days: int | None
    status: str  # fresh | stale | missing_review_date


@dataclass(frozen=True)
class DartDocReadinessRecord:
    path: str
    public_types: int
    documented_types: int
    coverage_ratio: float


@dataclass(frozen=True)
class LivingDocsReport:
    checked_at: str
    max_age_days: int
    has_stale: bool
    doc_records: tuple[DocStalenessRecord, ...]
    dart_doc_records: tuple[DartDocReadinessRecord, ...]
    dry_run_issue_payload: dict[str, object] | None


def extract_review_date(markdown_text: str) -> dt.date | None:
    """Extract `last_reviewed` or `updated` YYYY-MM-DD date from Markdown."""
    match = _DATE_FIELD_RE.search(markdown_text)
    if not match:
        return None
    try:
        return dt.date.fromisoformat(match.group(1))
    except ValueError:
        return None


def check_doc_staleness(
    path: Path,
    *,
    today: dt.date,
    max_age_days: int = DEFAULT_MAX_AGE_DAYS,
    require_frontmatter: bool = True,
) -> DocStalenessRecord:
    """Check whether a single Markdown document is fresh or stale."""
    if not path.exists() or not path.is_file():
        return DocStalenessRecord(
            path=path.as_posix(),
            last_reviewed=None,
            age_days=None,
            status="missing_review_date",
        )

    text = path.read_text(encoding="utf-8")
    reviewed = extract_review_date(text)
    if reviewed is None:
        return DocStalenessRecord(
            path=path.as_posix(),
            last_reviewed=None,
            age_days=None,
            status="missing_review_date" if require_frontmatter else "fresh",
        )

    age_days = (today - reviewed).days
    status = "stale" if age_days > max_age_days else "fresh"
    return DocStalenessRecord(
        path=path.as_posix(),
        last_reviewed=reviewed.isoformat(),
        age_days=age_days,
        status=status,
    )


def check_dart_doc_readiness(path: Path) -> DartDocReadinessRecord:
    """Measure `///` doc-comment coverage on public Dart types in a file."""
    if not path.exists() or not path.is_file():
        return DartDocReadinessRecord(
            path=path.as_posix(),
            public_types=0,
            documented_types=0,
            coverage_ratio=1.0,
        )

    lines = path.read_text(encoding="utf-8").splitlines()
    public_types = 0
    documented_types = 0

    for idx, line in enumerate(lines):
        match = _DART_PUBLIC_TYPE_RE.match(line)
        if not match:
            continue
        type_name = match.group(1)
        if type_name.startswith("_"):
            continue
        public_types += 1
        prev_idx = idx - 1
        while prev_idx >= 0 and lines[prev_idx].strip().startswith("@"):
            prev_idx -= 1
        if prev_idx >= 0 and lines[prev_idx].strip().startswith("///"):
            documented_types += 1

    ratio = (
        1.0
        if public_types == 0
        else round(documented_types / public_types, 3)
    )
    return DartDocReadinessRecord(
        path=path.as_posix(),
        public_types=public_types,
        documented_types=documented_types,
        coverage_ratio=ratio,
    )


def build_dry_run_issue_payload(
    stale_records: Sequence[DocStalenessRecord],
    *,
    checked_at: str,
    max_age_days: int,
) -> dict[str, object] | None:
    """Build a dry-run GitHub Issue payload when stale docs are found."""
    if not stale_records:
        return None
    bullet_lines = [
        f"- `{r.path}` (status=`{r.status}`, last_reviewed=`{r.last_reviewed}`, age_days=`{r.age_days}`)"
        for r in stale_records
    ]
    body = "\n".join(
        [
            "## Living Docs Staleness Alert",
            f"- Checked At: `{checked_at}`",
            f"- Threshold: `{max_age_days}` days",
            "",
            "### Documents Requiring Review",
            *bullet_lines,
        ]
    )
    return {
        "title": f"[living-docs] {len(stale_records)} stale doc(s) exceed {max_age_days}d review SLA",
        "labels": ["documentation", "living-docs"],
        "body": body,
    }


def evaluate_living_docs(
    *,
    doc_paths: Sequence[Path],
    dart_paths: Sequence[Path] = (),
    today: dt.date | None = None,
    max_age_days: int = DEFAULT_MAX_AGE_DAYS,
    require_frontmatter: bool = True,
) -> LivingDocsReport:
    """Evaluate doc staleness and Dart-doc readiness across given paths."""
    ref_today = today or dt.date.today()
    doc_records = tuple(
        check_doc_staleness(
            p,
            today=ref_today,
            max_age_days=max_age_days,
            require_frontmatter=require_frontmatter,
        )
        for p in doc_paths
    )
    dart_records = tuple(check_dart_doc_readiness(p) for p in dart_paths)
    flagged = [r for r in doc_records if r.status != "fresh"]
    payload = build_dry_run_issue_payload(
        flagged,
        checked_at=ref_today.isoformat(),
        max_age_days=max_age_days,
    )
    return LivingDocsReport(
        checked_at=ref_today.isoformat(),
        max_age_days=max_age_days,
        has_stale=len(flagged) > 0,
        doc_records=doc_records,
        dart_doc_records=dart_records,
        dry_run_issue_payload=payload,
    )


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Check living documentation staleness and Dart-doc readiness.",
    )
    parser.add_argument("--docs", nargs="*", default=[])
    parser.add_argument("--dart-files", nargs="*", default=[])
    parser.add_argument("--max-age-days", type=int, default=DEFAULT_MAX_AGE_DAYS)
    parser.add_argument("--today", default="")
    parser.add_argument("--require-frontmatter", action="store_true")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--fail-on-stale", action="store_true")
    args = parser.parse_args(argv)

    ref_today = dt.date.fromisoformat(args.today) if args.today else dt.date.today()
    report = evaluate_living_docs(
        doc_paths=[Path(p) for p in args.docs],
        dart_paths=[Path(p) for p in args.dart_files],
        today=ref_today,
        max_age_days=args.max_age_days,
        require_frontmatter=args.require_frontmatter,
    )
    print(json.dumps(asdict(report), ensure_ascii=False, indent=2))
    if args.fail_on_stale and report.has_stale:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
