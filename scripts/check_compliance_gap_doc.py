#!/usr/bin/env python3
"""Deterministic validator for docs/ENTERPRISE_COMPLIANCE_GAP_ANALYSIS.md (#2812)."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Sequence

DEFAULT_DOC_PATH = Path("docs/ENTERPRISE_COMPLIANCE_GAP_ANALYSIS.md")
REQUIRED_FRAMEWORKS = ("SOC2 Type II", "HIPAA", "PCI DSS")
REQUIRED_PROVIDERS = ("Supabase", "OpenAI", "Anthropic", "Google Cloud")

_DATE_RE = re.compile(
    r"^last_reviewed\s*:\s*(\d{4}-\d{2}-\d{2})\s*$",
    re.MULTILINE,
)


@dataclass(frozen=True)
class ComplianceDocValidationResult:
    ok: bool
    doc_path: str
    last_reviewed: str | None
    missing_frameworks: tuple[str, ...]
    missing_providers: tuple[str, ...]
    has_unverified_disclosure: bool
    errors: tuple[str, ...]


def validate_compliance_gap_doc(
    path: Path = DEFAULT_DOC_PATH,
    *,
    today: dt.date | None = None,
    max_age_days: int = 90,
) -> ComplianceDocValidationResult:
    """Validate structure, review date, and honest disclosure in gap doc."""
    if not path.exists() or not path.is_file():
        return ComplianceDocValidationResult(
            ok=False,
            doc_path=path.as_posix(),
            last_reviewed=None,
            missing_frameworks=REQUIRED_FRAMEWORKS,
            missing_providers=REQUIRED_PROVIDERS,
            has_unverified_disclosure=False,
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
        try:
            reviewed_date = dt.date.fromisoformat(last_reviewed)
            ref_today = today or dt.date.today()
            if (ref_today - reviewed_date).days > max_age_days:
                errors.append(
                    f"Document review age exceeds {max_age_days} days"
                )
        except ValueError:
            errors.append(f"Invalid last_reviewed date: {last_reviewed}")

    missing_frameworks = tuple(
        fw for fw in REQUIRED_FRAMEWORKS if fw not in text
    )
    if missing_frameworks:
        errors.append(
            f"Missing framework coverage: {', '.join(missing_frameworks)}"
        )

    missing_providers = tuple(
        p for p in REQUIRED_PROVIDERS if p not in text
    )
    if missing_providers:
        errors.append(
            f"Missing provider matrix entries: {', '.join(missing_providers)}"
        )

    has_unverified = "未確認" in text
    if not has_unverified:
        errors.append(
            "Expected explicit `未確認` disclosure for unverified claims"
        )

    return ComplianceDocValidationResult(
        ok=len(errors) == 0,
        doc_path=path.as_posix(),
        last_reviewed=last_reviewed,
        missing_frameworks=missing_frameworks,
        missing_providers=missing_providers,
        has_unverified_disclosure=has_unverified,
        errors=tuple(errors),
    )


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Validate enterprise compliance gap analysis doc.",
    )
    parser.add_argument("--doc", default=str(DEFAULT_DOC_PATH))
    parser.add_argument("--max-age-days", type=int, default=90)
    parser.add_argument("--fail-on-error", action="store_true")
    args = parser.parse_args(argv)

    res = validate_compliance_gap_doc(
        Path(args.doc),
        max_age_days=args.max_age_days,
    )
    print(json.dumps(asdict(res), ensure_ascii=False, indent=2))
    if args.fail_on_error and not res.ok:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
