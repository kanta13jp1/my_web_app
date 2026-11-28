#!/usr/bin/env python3
"""Deterministic validator for docs/COMPETITIVE_BENCHMARK_NOTION_3_4.md (#2815)."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Sequence

DEFAULT_DOC_PATH = Path("docs/COMPETITIVE_BENCHMARK_NOTION_3_4.md")

_DATE_RE = re.compile(
    r"^last_reviewed\s*:\s*(\d{4}-\d{2}-\d{2})\s*$",
    re.MULTILINE,
)


@dataclass(frozen=True)
class NotionBenchmarkValidationResult:
    ok: bool
    doc_path: str
    last_reviewed: str | None
    has_primary_urls: bool
    has_comparison_table: bool
    has_differentiation_section: bool
    has_honest_unverified_note: bool
    errors: tuple[str, ...]


def validate_notion_benchmark_doc(
    path: Path = DEFAULT_DOC_PATH,
    *,
    today: dt.date | None = None,
    max_age_days: int = 90,
) -> NotionBenchmarkValidationResult:
    """Validate structure, primary URLs, and honest disclosure."""
    if not path.exists() or not path.is_file():
        return NotionBenchmarkValidationResult(
            ok=False,
            doc_path=path.as_posix(),
            last_reviewed=None,
            has_primary_urls=False,
            has_comparison_table=False,
            has_differentiation_section=False,
            has_honest_unverified_note=False,
            errors=("Document file does not exist",),
        )

    text = path.read_text(encoding="utf-8")
    errors: list[str] = []

    match = _DATE_RE.search(text)
    last_reviewed: str | None = None
    if not match:
        errors.append("Missing `last_reviewed: YYYY-MM-DD` frontmatter")
    else:
        last_reviewed = match.group(1)
        reviewed_date = dt.date.fromisoformat(last_reviewed)
        ref_today = today or dt.date.today()
        if (ref_today - reviewed_date).days > max_age_days:
            errors.append(f"Review age exceeds {max_age_days} days")

    has_primary_urls = "https://www.notion.com/" in text
    if not has_primary_urls:
        errors.append("Missing primary Notion URL citation")

    has_comparison_table = (
        "|" in text
        and "personal_dashboard_page.dart" in text
        and "Notion" in text
    )
    if not has_comparison_table:
        errors.append("Missing comparison table grounded in my_web_app")

    has_diff = "差別化" in text
    if not has_diff:
        errors.append("Missing differentiation proposal section")

    has_unverified = "未確認" in text or "not-run" in text
    if not has_unverified:
        errors.append("Missing honest `未確認` / `not-run` disclosure")

    return NotionBenchmarkValidationResult(
        ok=len(errors) == 0,
        doc_path=path.as_posix(),
        last_reviewed=last_reviewed,
        has_primary_urls=has_primary_urls,
        has_comparison_table=has_comparison_table,
        has_differentiation_section=has_diff,
        has_honest_unverified_note=has_unverified,
        errors=tuple(errors),
    )


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Validate Notion 3.4 competitive benchmark doc.",
    )
    parser.add_argument("--doc", default=str(DEFAULT_DOC_PATH))
    parser.add_argument("--fail-on-error", action="store_true")
    args = parser.parse_args(argv)

    res = validate_notion_benchmark_doc(Path(args.doc))
    print(json.dumps(asdict(res), ensure_ascii=False, indent=2))
    if args.fail_on_error and not res.ok:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
