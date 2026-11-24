#!/usr/bin/env python3
"""Deterministic legal, regulatory, and financial compliance screener for intake items (#2595)."""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Sequence


VALID_SOURCES = ("notebooklm", "github_issue", "manual")

CATEGORY_RULES: tuple[tuple[str, int, tuple[str, ...]], ...] = (
    (
        "antitrust",
        40,
        (
            "独占禁止法",
            "独禁法",
            "antitrust",
            "cartel",
            "カルテル",
            "談合",
            "優越的地位の濫用",
            "不公正な取引方法",
        ),
    ),
    (
        "competition_law",
        35,
        (
            "企業結合規制",
            "競争消費者法",
            "競争法",
            "merger control",
            "competition law",
            "公正取引委員会",
            "jftc",
            "accc",
            "市場支配力",
            "market dominance",
        ),
    ),
    (
        "financial_claim",
        30,
        (
            "財務予測",
            "売上予測",
            "業績予想",
            "利益保証",
            "株価予測",
            "earnings forecast",
            "revenue projection",
            "financial claim",
            "金融商品取引法",
            "金商法",
            "インサイダー取引",
            "insider trading",
            "有価証券報告書",
        ),
    ),
    (
        "regulatory",
        25,
        (
            "法規制",
            "輸出規制",
            "export control",
            "個人情報保護法",
            "gdpr",
            "薬機法",
            "景品表示法",
            "下請法",
            "外為法",
            "許認可",
            "regulatory",
            "sanctions",
        ),
    ),
    (
        "legal_compliance",
        20,
        (
            "法務リスク",
            "コンプライアンス違反",
            "compliance risk",
            "legal compliance",
            "著作権侵害",
            "copyright infringement",
            "特許侵害",
            "patent infringement",
            "訴訟リスク",
            "litigation",
            "契約違反",
            "breach of contract",
            "守秘義務違反",
        ),
    ),
)


@dataclass(frozen=True)
class ComplianceScreeningResult:
    intake_source: str
    title: str
    content_excerpt: str
    risk_category: str
    risk_score: int
    matched_keywords: list[str]
    requires_verification: bool
    review_status: str

    def to_dict(self) -> dict[str, object]:
        return asdict(self)


def normalize_source(raw: str | None) -> str:
    candidate = (raw or "manual").strip().lower()
    return candidate if candidate in VALID_SOURCES else "manual"


def classify_intake_text(
    title: str,
    content: str,
    *,
    intake_source: str = "manual",
) -> ComplianceScreeningResult:
    """Classify intake title/body deterministically into compliance risk metadata."""
    clean_title = (title or "").strip()
    clean_content = (content or "").strip()
    source = normalize_source(intake_source)
    haystack = f"{clean_title}\n{clean_content}".lower()

    matched_keywords: list[str] = []
    seen_keywords: set[str] = set()
    category_scores: dict[str, int] = {}

    for category, weight, keywords in CATEGORY_RULES:
        hits = 0
        for keyword in keywords:
            needle = keyword.lower()
            if needle in haystack:
                hits += 1
                if keyword not in seen_keywords:
                    seen_keywords.add(keyword)
                    matched_keywords.append(keyword)
        if hits > 0:
            category_scores[category] = weight + (hits - 1) * 10

    if not category_scores:
        return ComplianceScreeningResult(
            intake_source=source,
            title=clean_title,
            content_excerpt=clean_content[:300],
            risk_category="none",
            risk_score=0,
            matched_keywords=[],
            requires_verification=False,
            review_status="verified_safe",
        )

    primary_category = max(
        category_scores.items(),
        key=lambda item: item[1],
    )[0]
    total_score = min(100, sum(category_scores.values()))

    return ComplianceScreeningResult(
        intake_source=source,
        title=clean_title,
        content_excerpt=clean_content[:300],
        risk_category=primary_category,
        risk_score=total_score,
        matched_keywords=matched_keywords,
        requires_verification=True,
        review_status="pending",
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Deterministic legal/compliance risk screener for intake data (#2595).",
    )
    parser.add_argument("--title", default="", help="Intake item title")
    parser.add_argument("--content", default="", help="Intake item body/excerpt")
    parser.add_argument(
        "--file",
        type=Path,
        help="Optional UTF-8 JSON ({title, content, intake_source}) or text file",
    )
    parser.add_argument(
        "--source",
        default="manual",
        choices=VALID_SOURCES,
        help="Intake source origin",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print structured JSON result",
    )
    parser.add_argument(
        "--fail-on-risk",
        action="store_true",
        help="Exit with code 2 when requires_verification is true",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    args = build_parser().parse_args(argv)

    title = args.title
    content = args.content
    source = args.source

    if args.file is not None:
        raw_text = args.file.read_text(encoding="utf-8")
        if args.file.suffix.lower() == ".json":
            payload = json.loads(raw_text)
            if isinstance(payload, dict):
                title = str(payload.get("title") or title)
                content = str(payload.get("content") or payload.get("content_excerpt") or content)
                source = str(payload.get("intake_source") or source)
        else:
            if not content:
                content = raw_text

    result = classify_intake_text(title, content, intake_source=source)
    if args.json:
        print(json.dumps(result.to_dict(), ensure_ascii=False, indent=2))
    else:
        status_label = "VERIFY_REQUIRED" if result.requires_verification else "CLEAN"
        keywords_joined = ", ".join(result.matched_keywords) or "-"
        print(
            f"[{status_label}] category={result.risk_category} "
            f"score={result.risk_score} keywords={keywords_joined}"
        )

    if args.fail_on_risk and result.requires_verification:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
