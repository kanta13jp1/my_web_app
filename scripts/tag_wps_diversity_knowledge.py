#!/usr/bin/env python3
"""Deterministic WPS & diversity knowledge topic tagger for intake documents (#2585).

Primary-source references only:
- UN Security Council Resolution 1325 (S/RES/1325, adopted 31 October 2000):
  women's equal participation and full involvement in conflict prevention,
  peace-building, peacekeeping, humanitarian response, post-conflict
  reconstruction, and protection from gender-based violence
  (https://www.un.org/womenwatch/osagi/wps/).
- Ministry of Foreign Affairs of Japan: 3rd National Action Plan on Women,
  Peace and Security (2023-2028)
  (https://www.mofa.go.jp/mofaj/fp/pc/page1w_000128.html /
  https://www.mofa.go.jp/files/100488960.pdf).
"""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
import json
import sys
from urllib.parse import urlparse

UNSCR_1325_URL = "https://www.un.org/womenwatch/osagi/wps/"
MOFA_WPS_NAP3_URL = "https://www.mofa.go.jp/mofaj/fp/pc/page1w_000128.html"

UNSCR_1325_REF = (
    "UNSCR 1325 (S/RES/1325, 2000-10-31): equal participation in prevention, "
    "peacebuilding, humanitarian response & protection against gender-based violence"
)
MOFA_NAP3_REF = "外務省 第3次女性・平和・安全保障に関する行動計画（2023–2028年度）"


@dataclass(frozen=True)
class TopicRule:
    topic_key: str
    tag_label: str
    weight: int
    keywords: tuple[str, ...]


TOPIC_RULES: tuple[TopicRule, ...] = (
    TopicRule(
        topic_key="wps",
        tag_label="WPS",
        weight=40,
        keywords=(
            "wps",
            "女性・平和・安全保障",
            "women, peace and security",
            "women peace and security",
            "unscr 1325",
            "s/res/1325",
            "安保理決議第1325号",
            "安保理決議1325",
            "第3次wps行動計画",
            "第3次行動計画",
        ),
    ),
    TopicRule(
        topic_key="diversity",
        tag_label="ダイバーシティ",
        weight=30,
        keywords=(
            "ダイバーシティ",
            "diversity",
            "インクルージョン",
            "inclusion",
            "de&i",
            "dei",
            "多様性方針",
            "多様性",
            "多文化共生",
        ),
    ),
    TopicRule(
        topic_key="gender",
        tag_label="ジェンダー",
        weight=30,
        keywords=(
            "ジェンダー",
            "gender",
            "ジェンダー平等",
            "男女共同参画",
            "女性活躍",
            "gender equality",
            "女性参画",
        ),
    ),
    TopicRule(
        topic_key="human_rights",
        tag_label="人権・行動計画",
        weight=20,
        keywords=(
            "行動計画",
            "人権",
            "human rights",
            "humanitarian",
            "紛争予防",
            "平和構築",
            "gender-based violence",
            "ジェンダーに基づく暴力",
        ),
    ),
)

_UNSCR_TRIGGERS: tuple[str, ...] = (
    "unscr 1325",
    "s/res/1325",
    "1325",
    "wps",
    "女性・平和・安全保障",
    "women, peace and security",
    "women peace and security",
)

_MOFA_NAP3_TRIGGERS: tuple[str, ...] = (
    "第3次",
    "第３次",
    "2023–2028",
    "2023-2028",
    "外務省",
    "mofa",
    "wps行動計画",
)


@dataclass(frozen=True)
class WpsTaggingResult:
    tags: list[str]
    primary_topic: str
    framework_references: list[str]
    matched_keywords: list[str]
    confidence_score: int
    reference_url: str
    requires_admin_review: bool
    suggested_review_status: str

    def to_dict(self) -> dict[str, object]:
        return asdict(self)


def sanitize_reference_url(raw_url: str) -> str:
    """Allow only explicit http/https URLs; reject javascript:/data: schemes."""
    cleaned = raw_url.strip()
    if not cleaned:
        return ""
    parsed = urlparse(cleaned)
    if parsed.scheme.lower() not in ("http", "https") or not parsed.netloc:
        raise ValueError(f"Unsupported reference URL scheme or host: {cleaned}")
    return cleaned


def tag_wps_diversity_text(
    *,
    title: str,
    content: str,
    reference_url: str = "",
) -> WpsTaggingResult:
    """Classify and tag an intake document for WPS, diversity, and gender topics."""
    haystack = f"{title.strip()}\n{content.strip()}".lower()
    tags: list[str] = []
    matched_keywords: list[str] = []
    seen_kw: set[str] = set()
    topic_scores: dict[str, int] = {}

    for rule in TOPIC_RULES:
        hits = 0
        for kw in rule.keywords:
            if kw.lower() in haystack:
                hits += 1
                if kw not in seen_kw:
                    seen_kw.add(kw)
                    matched_keywords.append(kw)
        if hits > 0:
            tags.append(rule.tag_label)
            topic_scores[rule.topic_key] = rule.weight + (hits - 1) * 10

    framework_references: list[str] = []
    has_unscr = any(t in haystack for t in _UNSCR_TRIGGERS)
    has_mofa_nap3 = any(t in haystack for t in _MOFA_NAP3_TRIGGERS)
    if has_unscr:
        framework_references.append(UNSCR_1325_REF)
    if has_mofa_nap3:
        framework_references.append(MOFA_NAP3_REF)

    resolved_url = sanitize_reference_url(reference_url)
    if not resolved_url:
        if has_mofa_nap3:
            resolved_url = MOFA_WPS_NAP3_URL
        elif has_unscr:
            resolved_url = UNSCR_1325_URL

    if not topic_scores:
        return WpsTaggingResult(
            tags=[],
            primary_topic="general",
            framework_references=framework_references,
            matched_keywords=[],
            confidence_score=0,
            reference_url=resolved_url,
            requires_admin_review=False,
            suggested_review_status="pending_review",
        )

    primary_topic = max(topic_scores.items(), key=lambda item: item[1])[0]
    confidence_score = min(100, sum(topic_scores.values()))
    return WpsTaggingResult(
        tags=tags,
        primary_topic=primary_topic,
        framework_references=framework_references,
        matched_keywords=matched_keywords,
        confidence_score=confidence_score,
        reference_url=resolved_url,
        requires_admin_review=True,
        suggested_review_status="pending_review",
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Tag WPS and diversity policy knowledge intake text.",
    )
    parser.add_argument("--title", default="", help="Document title")
    parser.add_argument("--content", default="", help="Document excerpt or body")
    parser.add_argument("--url", default="", help="Optional https reference URL")
    parser.add_argument("--json", action="store_true", help="Emit JSON output")
    parser.add_argument(
        "--fail-on-review-needed",
        action="store_true",
        help="Exit with code 2 when admin review is required",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        result = tag_wps_diversity_text(
            title=args.title,
            content=args.content,
            reference_url=args.url,
        )
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps(result.to_dict(), ensure_ascii=False, indent=2))
    else:
        tag_str = ", ".join(result.tags) if result.tags else "none"
        print(
            f"topic={result.primary_topic} tags=[{tag_str}] "
            f"confidence={result.confidence_score} status={result.suggested_review_status}"
        )

    if args.fail_on_review_needed and result.requires_admin_review:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
