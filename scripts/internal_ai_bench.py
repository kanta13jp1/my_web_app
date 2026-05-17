#!/usr/bin/env python3
"""Build an official-source AI model comparison matrix.

The harness is intentionally deterministic: it does not call provider APIs.
It validates manually collected benchmark rows, blocks unverified SNS-only
claims from rankings, and emits JSON plus Markdown that #2521 can use as a
routing evidence input.
"""

from __future__ import annotations

import argparse
import copy
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


REPO_ROOT = Path(__file__).resolve().parents[1]
VALID_VERIFICATION_STATUSES = ("verified", "partial", "unverified")
RANKABLE_STATUS = "verified"
FORBIDDEN_SUMMARY_TERMS = ("fixed best", "always best", "best model in the world")

AXES: dict[str, dict[str, Any]] = {
    "accuracy": {
        "weight": 3,
        "description": "Spec and acceptance criteria satisfaction.",
    },
    "diff_discipline": {
        "weight": 2,
        "description": "Small, repo-patterned diff with low unrelated churn.",
    },
    "test_quality": {
        "weight": 2,
        "description": "Useful unit, integration, or CI evidence.",
    },
    "ci_signal": {
        "weight": 2,
        "description": "First-pass green rate and recovery discipline.",
    },
    "latency": {
        "weight": 1,
        "description": "Human-observed or API-measured turnaround.",
    },
    "cost": {
        "weight": 1,
        "description": "Estimated token/runtime cost for the same task.",
    },
    "safety": {
        "weight": 1,
        "description": "PII, secret, prompt-injection, and money-boundary safety.",
    },
    "thinking_budget": {
        "weight": 1,
        "description": "Reasoning-effort continuity, token budget, and billing discipline.",
    },
}

TASKS: dict[str, dict[str, str]] = {
    "B1": {
        "track": "backend",
        "title": "Asset repository month-range micro change",
        "proof": "Analyzer/test pass with small repository-patterned diff.",
    },
    "B2": {
        "track": "frontend",
        "title": "Asset dashboard compact UI chip",
        "proof": "Build or widget test plus screenshot/manual smoke evidence.",
    },
    "B3": {
        "track": "agent",
        "title": "Issue to branch to PR to CI procedure",
        "proof": "Dry-runable flow with PR/check/cleanup summary.",
    },
    "R1": {
        "track": "research",
        "title": "Official model-source intake to WBS action",
        "proof": "Official URLs, verification status, and deduplicated issue route.",
    },
}

OFFICIAL_MODEL_SLOTS: list[dict[str, Any]] = [
    {
        "provider": "openai",
        "model": "gpt-5.5",
        "verification_status": "verified",
        "official_sources": [
            "https://openai.com/index/introducing-gpt-5-5/",
            "https://developers.openai.com/api/docs/models/gpt-5.5",
        ],
        "notes": "Verified by official announcement and API model docs on 2026-05-17.",
    },
    {
        "provider": "anthropic",
        "model": "claude-opus-4-7",
        "verification_status": "verified",
        "official_sources": [
            "https://www.anthropic.com/news/claude-opus-4-7",
            "https://platform.claude.com/docs/en/build-with-claude/extended-thinking",
        ],
        "notes": "Official model label has no SNS-only Fast suffix.",
    },
    {
        "provider": "google",
        "model": "gemini-3.1-pro-preview",
        "verification_status": "verified",
        "official_sources": ["https://ai.google.dev/gemini-api/docs/models"],
        "notes": "Use exact live API model string from Google docs at run time.",
    },
    {
        "provider": "moonshot",
        "model": "kimi-k2.6",
        "verification_status": "verified",
        "official_sources": ["https://platform.kimi.ai/docs/models"],
        "notes": "Official Kimi API model list candidate.",
    },
    {
        "provider": "deepseek",
        "model": "deepseek-v4-flash",
        "verification_status": "verified",
        "official_sources": [
            "https://api-docs.deepseek.com/updates/",
            "https://api-docs.deepseek.com/quick_start/pricing/",
        ],
        "notes": "Official DeepSeek API docs candidate; compare price and safety separately.",
    },
    {
        "provider": "xai",
        "model": "grok-4.3",
        "verification_status": "verified",
        "official_sources": ["https://docs.x.ai/developers/models"],
        "notes": "Official xAI docs candidate for research-heavy tasks.",
    },
    {
        "provider": "bytedance",
        "model": "seedance-2.0",
        "verification_status": "partial",
        "official_sources": ["https://arxiv.org/abs/2604.14148"],
        "notes": "Primary paper verified; video ranking claims require separate evidence.",
    },
    {
        "provider": "mimo",
        "model": "mimo-v2.5-pro",
        "verification_status": "unverified",
        "official_sources": [],
        "notes": "SNS-only claim until an official provider source is added.",
    },
]


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def default_report() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "bench_id": "template",
        "run_date": datetime.now(timezone.utc).date().isoformat(),
        "issue": "#2520",
        "source_watch": {
            "policy": "Official sources first; SNS-only claims stay unranked.",
            "ai_tool_watch": "scripts/ai_tool_watch.py",
        },
        "tasks": copy.deepcopy(TASKS),
        "axes": copy.deepcopy(AXES),
        "models": [
            {
                **copy.deepcopy(slot),
                "scores": {axis: None for axis in AXES},
                "latency_ms": None,
                "cost_usd": None,
            }
            for slot in OFFICIAL_MODEL_SLOTS
        ],
        "verdict": (
            "No fixed strongest model. Use task-specific fit after official "
            "source verification and repeatable bench evidence."
        ),
    }


def load_report(path: Path | None) -> dict[str, Any]:
    if path is None:
        return default_report()
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def source_list(entry: dict[str, Any]) -> list[str]:
    value = entry.get("official_sources") or []
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        return [str(item) for item in value if str(item).strip()]
    return []


def numeric_score(value: Any) -> float | None:
    if value is None:
        return None
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)) and 0 <= value <= 3:
        return float(value)
    return None


def iter_model_entries(report: dict[str, Any]) -> Iterable[dict[str, Any]]:
    models = report.get("models") or report.get("providers") or []
    if isinstance(models, dict):
        for key, value in models.items():
            if isinstance(value, dict):
                provider, _, model = str(key).partition("/")
                yield {"provider": provider, "model": model or key, **value}
    elif isinstance(models, list):
        for value in models:
            if isinstance(value, dict):
                yield value


def validate_report(report: dict[str, Any]) -> list[str]:
    warnings: list[str] = []
    verdict = str(report.get("verdict", "")).lower()
    for term in FORBIDDEN_SUMMARY_TERMS:
        if term in verdict:
            warnings.append(
                f"verdict uses prohibited fixed-ranking language: {term}"
            )

    for entry in iter_model_entries(report):
        label = model_label(entry)
        status = str(entry.get("verification_status", "unverified")).lower()
        if status not in VALID_VERIFICATION_STATUSES:
            warnings.append(f"{label}: invalid verification_status={status}")
        sources = source_list(entry)
        if status in {"verified", "partial"} and not sources:
            warnings.append(f"{label}: official_sources required for {status}")
        if status != RANKABLE_STATUS and any_score_present(entry):
            warnings.append(f"{label}: scores recorded but model is not rankable")
    return warnings


def any_score_present(entry: dict[str, Any]) -> bool:
    scores = entry.get("scores") if isinstance(entry.get("scores"), dict) else {}
    return any(numeric_score(value) is not None for value in scores.values())


def model_label(entry: dict[str, Any]) -> str:
    provider = str(entry.get("provider", "unknown")).strip() or "unknown"
    model = str(entry.get("model", "unknown")).strip() or "unknown"
    return f"{provider}/{model}"


def score_entry(entry: dict[str, Any], axes: dict[str, dict[str, Any]]) -> dict[str, Any]:
    scores = entry.get("scores") if isinstance(entry.get("scores"), dict) else {}
    weighted_points = 0.0
    max_points = 0.0
    scored_axes: list[str] = []
    invalid_axes: list[str] = []

    for axis, config in axes.items():
        weight = float(config.get("weight", 1))
        value = numeric_score(scores.get(axis))
        max_points += 3 * weight
        if value is None:
            if scores.get(axis) is not None:
                invalid_axes.append(axis)
            continue
        weighted_points += value * weight
        scored_axes.append(axis)

    normalized = round((weighted_points / max_points) * 100, 2) if max_points else 0.0
    status = str(entry.get("verification_status", "unverified")).lower()
    rankable = status == RANKABLE_STATUS and bool(scored_axes)
    return {
        "label": model_label(entry),
        "provider": entry.get("provider", "unknown"),
        "model": entry.get("model", "unknown"),
        "verification_status": status,
        "rankable": rankable,
        "official_sources": source_list(entry),
        "weighted_points": round(weighted_points, 2),
        "max_points": round(max_points, 2),
        "normalized_score": normalized,
        "scored_axes": scored_axes,
        "invalid_axes": invalid_axes,
        "latency_ms": entry.get("latency_ms"),
        "cost_usd": entry.get("cost_usd"),
        "notes": entry.get("notes", ""),
    }


def evaluate_report(report: dict[str, Any]) -> dict[str, Any]:
    axes = report.get("axes") if isinstance(report.get("axes"), dict) else AXES
    scored = [score_entry(entry, axes) for entry in iter_model_entries(report)]
    ranked = sorted(
        (entry for entry in scored if entry["rankable"]),
        key=lambda entry: entry["normalized_score"],
        reverse=True,
    )
    for index, entry in enumerate(ranked, start=1):
        entry["rank"] = index
    holdouts = [entry for entry in scored if not entry["rankable"]]
    return {
        "schema_version": report.get("schema_version", 1),
        "generated_at": utc_now(),
        "bench_id": report.get("bench_id", "unknown"),
        "run_date": report.get("run_date"),
        "issue": report.get("issue", "#2520"),
        "policy": {
            "ranking_rule": "Only verified models with scores are ranked.",
            "fixed_strongest_model": "forbidden",
            "task_specific_fit": True,
        },
        "tasks": report.get("tasks", TASKS),
        "axes": axes,
        "warnings": validate_report(report),
        "ranked_models": ranked,
        "holdout_models": holdouts,
        "all_models": scored,
        "verdict": report.get("verdict", default_report()["verdict"]),
    }


def render_sources(sources: list[str]) -> str:
    if not sources:
        return "none"
    return "<br>".join(sources)


def render_markdown(evaluation: dict[str, Any]) -> str:
    lines: list[str] = [
        "# Internal AI Model Bench Report",
        "",
        f"- Issue: `{evaluation.get('issue', '#2520')}`",
        f"- Bench ID: `{evaluation.get('bench_id', 'unknown')}`",
        f"- Generated at: `{evaluation.get('generated_at')}`",
        "",
        (
            "This report measures task-specific fit. It must not be read as a "
            "fixed strongest model ranking."
        ),
        "",
        "## Policy",
        "",
        "- Rank only models with `verification_status=verified` and recorded scores.",
        "- Keep `partial` and `unverified` models as hypotheses until official sources are added.",
        "- Attach official source URLs to every ranked row.",
        "- Re-run after `ai_tool_watch` detects material model, pricing, or tool-use changes.",
        "",
        "## Ranked Verified Results",
        "",
        "| Rank | Model | Score | Sources | Notes |",
        "| --- | --- | ---: | --- | --- |",
    ]

    ranked = evaluation.get("ranked_models", [])
    if ranked:
        for entry in ranked:
            lines.append(
                "| {rank} | `{label}` | {score:.2f} | {sources} | {notes} |".format(
                    rank=entry.get("rank", ""),
                    label=entry["label"],
                    score=entry["normalized_score"],
                    sources=render_sources(entry["official_sources"]),
                    notes=str(entry.get("notes", "")).replace("|", "\\|"),
                )
            )
    else:
        lines.append("| - | No verified scored rows yet | 0.00 | - | Add provider run evidence. |")

    lines.extend(
        [
            "",
            "## Holdouts",
            "",
            "| Model | Verification | Reason | Sources |",
            "| --- | --- | --- | --- |",
        ]
    )
    for entry in evaluation.get("holdout_models", []):
        reason = "unranked until verified and scored"
        if entry["verification_status"] == "verified":
            reason = "verified but no score recorded"
        lines.append(
            f"| `{entry['label']}` | `{entry['verification_status']}` | "
            f"{reason} | {render_sources(entry['official_sources'])} |"
        )

    lines.extend(
        [
            "",
            "## Warnings",
            "",
        ]
    )
    warnings = evaluation.get("warnings", [])
    if warnings:
        lines.extend(f"- {warning}" for warning in warnings)
    else:
        lines.append("- None.")

    lines.extend(
        [
            "",
            "## Verdict",
            "",
            str(evaluation.get("verdict") or default_report()["verdict"]),
            "",
        ]
    )
    return "\n".join(lines)


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, help="Input benchmark JSON.")
    parser.add_argument("--output-json", type=Path, help="Write normalized evaluation JSON.")
    parser.add_argument("--output-md", type=Path, help="Write Markdown report.")
    parser.add_argument("--write-template", type=Path, help="Write an empty benchmark template JSON.")
    parser.add_argument("--print-markdown", action="store_true", help="Print Markdown report to stdout.")
    parser.add_argument("--strict", action="store_true", help="Exit non-zero when validation warnings exist.")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.write_template:
        write_json(args.write_template, default_report())
        return 0

    report = load_report(args.input)
    evaluation = evaluate_report(report)
    markdown = render_markdown(evaluation)

    if args.output_json:
        write_json(args.output_json, evaluation)
    if args.output_md:
        write_text(args.output_md, markdown + "\n")
    if args.print_markdown:
        print(markdown)

    if args.strict and evaluation["warnings"]:
        for warning in evaluation["warnings"]:
            print(f"WARN: {warning}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
