#!/usr/bin/env python3
"""Build the public Tiger profile catalog with staged review guidance.

The canonical persona snapshot remains the source of reviewer-specific career,
viewpoint, programme-behaviour, confidence, and review-weight evidence.  This
script combines that snapshot with public-display facts such as verified birth
dates and business summaries.  Missing facts stay missing; the script never
guesses personal information.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CATALOG_PATH = REPO_ROOT / "assets" / "data" / "tiger_reviewer_profiles.json"
DEFAULT_PERSONAS_PATH = (
    Path.home()
    / ".codex"
    / "skills"
    / "reiwa-tora-site-review-loop"
    / "references"
    / "tiger-personas.json"
)

DIMENSION_LABELS = {
    "market_demand": "市場需要",
    "customer_pain": "顧客課題",
    "revenue_model": "収益モデル",
    "unit_economics": "単位経済性",
    "scalability": "拡張性",
    "competitive_advantage": "競争優位性",
    "go_to_market": "顧客獲得",
    "founder_execution": "実行力",
    "trust_risk": "信頼・法務リスク",
}


def _bounded_confidence(value: Any) -> float:
    try:
        return min(5.0, max(0.0, float(value)))
    except (TypeError, ValueError):
        return 0.0


def _present(value: Any) -> bool:
    text = str(value or "").strip()
    return bool(text) and "未確認" not in text


def _reflection_mode(percent: int) -> str:
    if percent >= 80:
        return "profile_guided"
    if percent >= 50:
        return "profile_balanced"
    return "neutral_guarded"


def _application_rule(mode: str) -> str:
    rules = {
        "profile_guided": (
            "中立スキャン後、確認済みプロフィール由来の重点観点を"
            "指摘の優先順位づけに強く反映します。"
        ),
        "profile_balanced": (
            "中立スキャンを軸に、確認済みプロフィール由来の観点だけを"
            "補助的に反映します。"
        ),
        "neutral_guarded": (
            "中立スキャンを優先し、プロフィール由来の情報は質問候補の"
            "生成にのみ限定して反映します。"
        ),
    }
    return rules[mode] + "本人の実際の意見として断定したり、口調を模倣したりしません。"


def _metrics(persona: dict[str, Any], public_profile: dict[str, Any]) -> tuple[int, int]:
    confidence = persona.get("confidence", {})
    career = _bounded_confidence(confidence.get("career"))
    viewpoint = _bounded_confidence(confidence.get("viewpoint"))
    behaviour = _bounded_confidence(confidence.get("programme_behavior"))

    verified_birth = bool(public_profile.get("birth_date")) and bool(
        public_profile.get("birth_date_source_url")
    )
    public_fact_points = sum(
        5
        for key in ("company_role", "business_summary", "profile_url")
        if _present(public_profile.get(key))
    )
    completeness = round(
        25 * career / 5
        + 30 * viewpoint / 5
        + 15 * behaviour / 5
        + (15 if verified_birth else 0)
        + public_fact_points
    )
    reflection = round(35 * career / 5 + 45 * viewpoint / 5 + 20 * behaviour / 5)
    return min(100, completeness), min(100, reflection)


def _research_targets(
    persona: dict[str, Any], public_profile: dict[str, Any]
) -> list[str]:
    confidence = persona.get("confidence", {})
    targets: list[str] = []
    if not (
        public_profile.get("birth_date")
        and public_profile.get("birth_date_source_url")
    ):
        targets.append("生年月日の一次公開情報")
    if _bounded_confidence(confidence.get("career")) < 5:
        targets.append("現職肩書き・事業内容の一次公開情報")
    if _bounded_confidence(confidence.get("viewpoint")) < 5:
        targets.append("本人の審査姿勢が確認できる一次公開情報")
    if _bounded_confidence(confidence.get("programme_behavior")) < 4:
        targets.append("出演・出資実績の追加検証")
    return targets


def _focus_dimensions(
    personas: dict[str, Any], persona: dict[str, Any]
) -> list[dict[str, Any]]:
    model = persona.get("reviewer_model", {})
    weights = model.get("business_viability_weight_percent", {})
    questions = personas.get("question_text_ja", {})
    dimensions = model.get("primary_question_dimensions", [])
    result: list[dict[str, Any]] = []
    for dimension in dimensions[:4]:
        if dimension not in DIMENSION_LABELS:
            continue
        result.append(
            {
                "dimension": dimension,
                "label": DIMENSION_LABELS[dimension],
                "weight_percent": int(weights.get(dimension, 0)),
                "question": str(questions.get(dimension, "")).strip(),
            }
        )
    return result


def enrich_profile(
    personas: dict[str, Any],
    persona: dict[str, Any],
    public_profile: dict[str, Any],
) -> dict[str, Any]:
    career = persona.get("career", {})
    viewpoint = persona.get("public_viewpoint", {})
    behaviour = persona.get("programme_behavior", {})
    domain_labels = personas.get("domain_labels_ja", {})
    completeness, reflection = _metrics(persona, public_profile)
    mode = _reflection_mode(reflection)

    enriched = dict(public_profile)
    enriched.update(
        {
            "roster_status": persona.get(
                "roster_status", public_profile.get("roster_status", "")
            ),
            "company_role": career.get(
                "company_role", public_profile.get("company_role", "")
            ),
            "business_domains": [
                domain_labels.get(domain, domain)
                for domain in career.get("business_domains", [])
            ],
            "appearances": int(
                behaviour.get("appearances", public_profile.get("appearances", 0))
            ),
            "investment_count": int(
                behaviour.get(
                    "investment_count", public_profile.get("investment_count", 0)
                )
            ),
            "public_viewpoint_summary": viewpoint.get(
                "summary", public_profile.get("public_viewpoint_summary", "")
            ),
            "evidence_confidence": _bounded_confidence(
                persona.get("confidence", {}).get("overall")
            ),
            "profile_completeness_percent": completeness,
            "review_reflection_percent": reflection,
            "review_reflection_mode": mode,
            "review_application_rule": _application_rule(mode),
            "review_focus_dimensions": _focus_dimensions(personas, persona),
            "review_style_tags": list(viewpoint.get("style_tags", [])),
            "next_research_targets": _research_targets(persona, public_profile),
            "evidence_source_ids": list(persona.get("evidence_source_ids", [])),
        }
    )
    return enriched


def build_catalog(
    personas: dict[str, Any],
    catalog: dict[str, Any],
    *,
    batch_size: int = 5,
    round_number: int | None = None,
) -> dict[str, Any]:
    people = personas.get("people")
    profiles = catalog.get("profiles")
    if not isinstance(people, list) or not isinstance(profiles, list):
        raise ValueError("personas.people and catalog.profiles must be arrays")

    persona_by_seat = {int(item["seat"]): item for item in people}
    public_by_seat = {int(item["seat"]): item for item in profiles}
    if set(persona_by_seat) != set(public_by_seat):
        raise ValueError("canonical personas and public profiles have different seats")

    enriched_profiles: list[dict[str, Any]] = []
    for seat in sorted(persona_by_seat):
        persona = persona_by_seat[seat]
        public_profile = public_by_seat[seat]
        if str(persona.get("name")) != str(public_profile.get("name")):
            raise ValueError(f"seat {seat} has a name mismatch")
        enriched_profiles.append(enrich_profile(personas, persona, public_profile))

    queue = sorted(
        (profile for profile in enriched_profiles if profile["next_research_targets"]),
        key=lambda profile: (
            profile["profile_completeness_percent"],
            profile["review_reflection_percent"],
            profile["roster_status"] != "current",
            profile["seat"],
        ),
    )[:batch_size]
    previous_round = int(catalog.get("enrichment", {}).get("round", 0))
    effective_round = round_number if round_number is not None else max(1, previous_round)

    result = dict(catalog)
    result.update(
        {
            "schema_version": 2,
            "source_snapshot": (
                "canonical tiger-personas.json "
                f"({personas.get('snapshot_date', 'unknown')})"
            ),
            "reviewer_count": len(enriched_profiles),
            "enrichment": {
                "round": effective_round,
                "batch_size": batch_size,
                "policy": (
                    "一次公開情報を優先し、未確認情報は推測しない。"
                    "プロフィール由来のレビュー観点は証拠強度に応じて段階反映する。"
                ),
                "average_profile_completeness_percent": round(
                    sum(item["profile_completeness_percent"] for item in enriched_profiles)
                    / len(enriched_profiles),
                    1,
                ),
                "average_review_reflection_percent": round(
                    sum(item["review_reflection_percent"] for item in enriched_profiles)
                    / len(enriched_profiles),
                    1,
                ),
                "verified_birth_dates": sum(
                    1 for item in enriched_profiles if item.get("birth_date")
                ),
                "next_batch": [
                    {
                        "seat": item["seat"],
                        "name": item["name"],
                        "profile_completeness_percent": item[
                            "profile_completeness_percent"
                        ],
                        "research_targets": item["next_research_targets"],
                    }
                    for item in queue
                ],
            },
            "profiles": enriched_profiles,
        }
    )
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--personas", type=Path, default=DEFAULT_PERSONAS_PATH)
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG_PATH)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--batch-size", type=int, default=5)
    parser.add_argument("--round", type=int, dest="round_number")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.batch_size < 1:
        parser.error("--batch-size must be at least 1")

    personas = json.loads(args.personas.read_text(encoding="utf-8"))
    catalog = json.loads(args.catalog.read_text(encoding="utf-8"))
    enriched = build_catalog(
        personas,
        catalog,
        batch_size=args.batch_size,
        round_number=args.round_number,
    )
    rendered = json.dumps(enriched, ensure_ascii=False, indent=2) + "\n"
    output = args.output or args.catalog
    if args.check:
        if output.read_text(encoding="utf-8") != rendered:
            print(f"Tiger profile catalog is stale: {output}")
            return 1
    else:
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(rendered, encoding="utf-8")

    print(
        json.dumps(
            {
                "output": str(output),
                "reviewers": enriched["reviewer_count"],
                "round": enriched["enrichment"]["round"],
                "average_profile_completeness_percent": enriched["enrichment"][
                    "average_profile_completeness_percent"
                ],
                "average_review_reflection_percent": enriched["enrichment"][
                    "average_review_reflection_percent"
                ],
                "next_batch": enriched["enrichment"]["next_batch"],
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
