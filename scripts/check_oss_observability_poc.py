#!/usr/bin/env python3
"""Validator & cost estimator for OSS AI Observability PoC (#2813)."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Sequence

DEFAULT_DOC_PATH = Path("docs/OSS_AI_OBSERVABILITY_POC.md")
_DATE_RE = re.compile(
    r"^last_reviewed\s*:\s*(\d{4}-\d{2}-\d{2})\s*$",
    re.MULTILINE,
)


@dataclass(frozen=True)
class OssCostEstimate:
    compute_usd: float
    storage_usd: float
    total_monthly_usd: float


@dataclass(frozen=True)
class OssPocValidationResult:
    ok: bool
    doc_path: str
    last_reviewed: str | None
    has_primary_refs: bool
    has_unverified_disclosure: bool
    errors: tuple[str, ...]


def estimate_monthly_oss_cost(
    *,
    compute_usd: float = 12.0,
    storage_gb: float = 20.0,
    storage_usd_per_gb: float = 0.10,
) -> OssCostEstimate:
    """Compute a simple deterministic monthly OSS infra cost estimate."""
    safe_compute = max(0.0, compute_usd)
    safe_storage = max(0.0, storage_gb) * max(0.0, storage_usd_per_gb)
    total = round(safe_compute + safe_storage, 2)
    return OssCostEstimate(
        compute_usd=round(safe_compute, 2),
        storage_usd=round(safe_storage, 2),
        total_monthly_usd=total,
    )


def validate_oss_poc_doc(
    path: Path = DEFAULT_DOC_PATH,
    *,
    today: dt.date | None = None,
    max_age_days: int = 90,
) -> OssPocValidationResult:
    """Validate PoC doc frontmatter, primary references, and disclosures."""
    if not path.exists() or not path.is_file():
        return OssPocValidationResult(
            ok=False,
            doc_path=path.as_posix(),
            last_reviewed=None,
            has_primary_refs=False,
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
        reviewed_date = dt.date.fromisoformat(last_reviewed)
        ref_today = today or dt.date.today()
        if (ref_today - reviewed_date).days > max_age_days:
            errors.append(f"Review age exceeds {max_age_days} days")

    has_primary_refs = (
        "https://opentelemetry.io/docs/specs/otlp/" in text
        and "https://langfuse.com/docs/deployment/self-host" in text
    )
    if not has_primary_refs:
        errors.append("Missing primary OTLP or Langfuse URL reference")

    has_unverified = "未確認" in text
    if not has_unverified:
        errors.append("Missing honest `未確認` disclosure")

    return OssPocValidationResult(
        ok=len(errors) == 0,
        doc_path=path.as_posix(),
        last_reviewed=last_reviewed,
        has_primary_refs=has_primary_refs,
        has_unverified_disclosure=has_unverified,
        errors=tuple(errors),
    )


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Validate OSS AI observability PoC doc & cost model.",
    )
    parser.add_argument("--doc", default=str(DEFAULT_DOC_PATH))
    parser.add_argument("--fail-on-error", action="store_true")
    args = parser.parse_args(argv)

    validation = validate_oss_poc_doc(Path(args.doc))
    estimate = estimate_monthly_oss_cost()
    print(
        json.dumps(
            {
                "validation": asdict(validation),
                "sample_monthly_oss_cost": asdict(estimate),
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    if args.fail_on_error and not validation.ok:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
