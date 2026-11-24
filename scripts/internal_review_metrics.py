#!/usr/bin/env python3
"""Calculate and validate internal review quality metrics for PRs and review records (#2725)."""

from __future__ import annotations

import argparse
import dataclasses
import json
import math
import re
import sys
from pathlib import Path

DEFAULT_MIN_REVIEW_DENSITY = 30.0
DEFAULT_MIN_FINDING_DENSITY = 1.0

_INLINE_BREAKDOWN_RE = re.compile(
    r"spec\s*:\s*(\d+)\s*/\s*design\s*:\s*(\d+)\s*/\s*security\s*:\s*(\d+)\s*/\s*uiux\s*:\s*(\d+)\s*/\s*test\s*:\s*(\d+)",
    re.IGNORECASE,
)
_TABLE_CATEGORY_PATTERNS = {
    "spec": re.compile(r"\|\s*仕様\s*\(`spec`\)\s*\|\s*(\d+)\s*\|", re.IGNORECASE),
    "design": re.compile(r"\|\s*設計\s*\(`design`\)\s*\|\s*(\d+)\s*\|", re.IGNORECASE),
    "security": re.compile(r"\|\s*セキュリティ\s*\(`security`\)\s*\|\s*(\d+)\s*\|", re.IGNORECASE),
    "uiux": re.compile(r"\|\s*UI/UX\s*\(`uiux`\)\s*\|\s*(\d+)\s*\|", re.IGNORECASE),
    "test": re.compile(r"\|\s*テスト\s*\(`test`\)\s*\|\s*(\d+)\s*\|", re.IGNORECASE),
}
_SCOPE_LINE_RE = re.compile(r"(?:対象規模|scope_size)\D*?([0-9]+(?:\.[0-9]+)?)", re.IGNORECASE)
_MINUTES_LINE_RE = re.compile(r"(?:レビュー所要時間|review_minutes)\D*?(\d+)", re.IGNORECASE)


@dataclasses.dataclass(frozen=True)
class FindingBreakdown:
    """Finding counts grouped by internal review defect category."""

    spec: int = 0
    design: int = 0
    security: int = 0
    uiux: int = 0
    test: int = 0

    def __post_init__(self) -> None:
        for field_name in ("spec", "design", "security", "uiux", "test"):
            val = getattr(self, field_name)
            if isinstance(val, bool) or not isinstance(val, int) or val < 0:
                raise ValueError(f"{field_name} must be a non-negative integer, got {val!r}")

    @property
    def total(self) -> int:
        return self.spec + self.design + self.security + self.uiux + self.test

    def to_dict(self) -> dict[str, int]:
        return {
            "spec": self.spec,
            "design": self.design,
            "security": self.security,
            "uiux": self.uiux,
            "test": self.test,
            "total": self.total,
        }


@dataclasses.dataclass(frozen=True)
class InternalReviewMetricsReport:
    """Computed internal review density and threshold compliance summary."""

    scope_size: float
    review_minutes: int
    breakdown: FindingBreakdown
    review_density: float
    finding_density: float
    minimum_review_density: float
    minimum_finding_density: float
    meets_review_density: bool
    meets_finding_density: bool
    status: str

    def to_dict(self) -> dict[str, object]:
        return {
            "scope_size": self.scope_size,
            "review_minutes": self.review_minutes,
            "findings": self.breakdown.to_dict(),
            "review_density": self.review_density,
            "finding_density": self.finding_density,
            "minimum_review_density": self.minimum_review_density,
            "minimum_finding_density": self.minimum_finding_density,
            "meets_review_density": self.meets_review_density,
            "meets_finding_density": self.meets_finding_density,
            "status": self.status,
        }


def evaluate_internal_review(
    *,
    scope_size: float,
    review_minutes: int,
    breakdown: FindingBreakdown | None = None,
    minimum_review_density: float = DEFAULT_MIN_REVIEW_DENSITY,
    minimum_finding_density: float = DEFAULT_MIN_FINDING_DENSITY,
) -> InternalReviewMetricsReport:
    """Compute review density and finding density and validate against minimums."""
    if isinstance(scope_size, bool) or not math.isfinite(scope_size) or scope_size <= 0:
        raise ValueError(f"scope_size must be a finite positive number, got {scope_size!r}")
    if isinstance(review_minutes, bool) or not isinstance(review_minutes, int) or review_minutes < 0:
        raise ValueError(f"review_minutes must be a non-negative integer, got {review_minutes!r}")
    if not math.isfinite(minimum_review_density) or minimum_review_density < 0:
        raise ValueError("minimum_review_density must be non-negative")
    if not math.isfinite(minimum_finding_density) or minimum_finding_density < 0:
        raise ValueError("minimum_finding_density must be non-negative")

    counts = breakdown or FindingBreakdown()
    review_density = round(review_minutes / scope_size, 4)
    finding_density = round(counts.total / scope_size, 4)
    meets_review = review_density >= minimum_review_density
    meets_finding = finding_density >= minimum_finding_density
    status = "pass" if (meets_review and meets_finding) else "warn"

    return InternalReviewMetricsReport(
        scope_size=scope_size,
        review_minutes=review_minutes,
        breakdown=counts,
        review_density=review_density,
        finding_density=finding_density,
        minimum_review_density=minimum_review_density,
        minimum_finding_density=minimum_finding_density,
        meets_review_density=meets_review,
        meets_finding_density=meets_finding,
        status=status,
    )


def parse_markdown_record(markdown_text: str) -> dict[str, object]:
    """Extract scope_size, review_minutes, and FindingBreakdown fields from a review markdown."""
    scope_match = _SCOPE_LINE_RE.search(markdown_text)
    minutes_match = _MINUTES_LINE_RE.search(markdown_text)
    if not scope_match:
        raise ValueError("scope_size could not be parsed from markdown")
    if not minutes_match:
        raise ValueError("review_minutes could not be parsed from markdown")

    scope_size = float(scope_match.group(1))
    review_minutes = int(minutes_match.group(1))

    inline_match = _INLINE_BREAKDOWN_RE.search(markdown_text)
    if inline_match:
        breakdown = FindingBreakdown(
            spec=int(inline_match.group(1)),
            design=int(inline_match.group(2)),
            security=int(inline_match.group(3)),
            uiux=int(inline_match.group(4)),
            test=int(inline_match.group(5)),
        )
    else:
        parsed_cats: dict[str, int] = {}
        for key, pattern in _TABLE_CATEGORY_PATTERNS.items():
            m = pattern.search(markdown_text)
            parsed_cats[key] = int(m.group(1)) if m else 0
        breakdown = FindingBreakdown(**parsed_cats)

    return {
        "scope_size": scope_size,
        "review_minutes": review_minutes,
        "breakdown": breakdown,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Internal review metrics evaluator")
    parser.add_argument("--markdown-file", type=Path, help="Path to markdown record to parse")
    parser.add_argument("--scope-size", type=float)
    parser.add_argument("--review-minutes", type=int)
    parser.add_argument("--spec", type=int, default=0)
    parser.add_argument("--design", type=int, default=0)
    parser.add_argument("--security", type=int, default=0)
    parser.add_argument("--uiux", type=int, default=0)
    parser.add_argument("--test", type=int, default=0)
    parser.add_argument("--min-review-density", type=float, default=DEFAULT_MIN_REVIEW_DENSITY)
    parser.add_argument("--min-finding-density", type=float, default=DEFAULT_MIN_FINDING_DENSITY)
    parser.add_argument("--json", action="store_true", help="Emit JSON output")
    parser.add_argument("--strict", action="store_true", help="Exit 2 when status is warn")
    args = parser.parse_args(argv)

    if args.markdown_file is not None:
        parsed = parse_markdown_record(args.markdown_file.read_text(encoding="utf-8"))
        scope_size = float(parsed["scope_size"])  # type: ignore[arg-type]
        review_minutes = int(parsed["review_minutes"])  # type: ignore[arg-type]
        breakdown = parsed["breakdown"]
        assert isinstance(breakdown, FindingBreakdown)
    else:
        if args.scope_size is None or args.review_minutes is None:
            parser.error("--scope-size and --review-minutes are required unless --markdown-file is used")
        scope_size = args.scope_size
        review_minutes = args.review_minutes
        breakdown = FindingBreakdown(
            spec=args.spec,
            design=args.design,
            security=args.security,
            uiux=args.uiux,
            test=args.test,
        )

    report = evaluate_internal_review(
        scope_size=scope_size,
        review_minutes=review_minutes,
        breakdown=breakdown,
        minimum_review_density=args.min_review_density,
        minimum_finding_density=args.min_finding_density,
    )

    if args.json:
        print(json.dumps(report.to_dict(), ensure_ascii=False, indent=2))
    else:
        print(
            f"status={report.status} scope_size={report.scope_size} "
            f"review_minutes={report.review_minutes} findings={report.breakdown.total} "
            f"review_density={report.review_density} finding_density={report.finding_density}"
        )

    if args.strict and report.status != "pass":
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
