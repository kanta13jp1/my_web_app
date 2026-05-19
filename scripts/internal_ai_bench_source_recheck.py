#!/usr/bin/env python3
"""Recheck official source evidence for the internal AI bench.

This script performs only public HTTP reads of official or primary URLs. It
does not call provider generation APIs, use API keys, rank models, or change
the #2521 routing defaults. The output is a source-evidence report that should
be attached before live provider scoring is approved.
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from scripts import internal_ai_bench


FetchResult = tuple[int | None, str, str]
FetchFn = Callable[[str, float], FetchResult]


@dataclass(frozen=True)
class SourceRule:
    url: str
    required_terms: tuple[str, ...]
    optional_terms: tuple[str, ...] = ()


MODEL_SOURCE_RULES: dict[str, tuple[SourceRule, ...]] = {
    "openai/gpt-5.5": (
        SourceRule(
            "https://openai.com/index/introducing-gpt-5-5/",
            ("Introducing GPT", "GPT"),
            ("GPT-5.5", "GPT\u20115.5", "API"),
        ),
        SourceRule(
            "https://developers.openai.com/api/docs/models/gpt-5.5",
            ("GPT-5.5", "Pricing"),
            ("1,050,000 context window", "Responses"),
        ),
    ),
    "anthropic/claude-opus-4-7": (
        SourceRule(
            "https://www.anthropic.com/news/claude-opus-4-7",
            ("Claude Opus 4.7",),
            ("claude-opus-4-7", "Opus 4.6"),
        ),
    ),
    "google/gemini-3.1-pro-preview": (
        SourceRule(
            "https://ai.google.dev/gemini-api/docs/models",
            ("Gemini 3.1 Pro Preview",),
            ("Gemini 3 Pro Preview", "deprecated"),
        ),
    ),
    "moonshot/kimi-k2.6": (
        SourceRule(
            "https://platform.kimi.ai/docs/models",
            ("kimi-k2.6",),
            ("Kimi K2.6", "Context 256k"),
        ),
    ),
    "deepseek/deepseek-v4-flash": (
        SourceRule(
            "https://api-docs.deepseek.com/updates/",
            ("DeepSeek-V4", "deepseek-v4-flash"),
            ("V4-Flash", "Anthropic interface"),
        ),
        SourceRule(
            "https://api-docs.deepseek.com/quick_start/pricing/",
            ("deepseek",),
            ("pricing", "v4"),
        ),
    ),
    "xai/grok-4.3": (
        SourceRule(
            "https://docs.x.ai/developers/models",
            ("grok-4.3",),
            ("Which model should I choose?", "pricing"),
        ),
    ),
    "bytedance/seedance-2.0": (
        SourceRule(
            "https://arxiv.org/abs/2604.14148",
            ("Seedance",),
            ("2.0", "video"),
        ),
    ),
}


REJECTED_SNS_CLAIMS: list[dict[str, str]] = [
    {
        "claim": "anthropic/opus-4.7-fast",
        "reason": "Official Anthropic source names Claude Opus 4.7; no Fast suffix is treated as a model slot.",
    },
    {
        "claim": "mimo/mimo-v2.5-pro",
        "reason": "No official source URL is attached in the bench template.",
    },
]


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def default_fetch(url: str, timeout: float) -> FetchResult:
    request = Request(
        url,
        headers={
            "Accept": "text/html,application/xhtml+xml,text/plain;q=0.9,*/*;q=0.8",
            "Accept-Encoding": "identity",
            "User-Agent": "my-web-app-ai-bench-source-recheck/1.0",
        },
    )
    try:
        with urlopen(request, timeout=timeout) as response:
            body = response.read(750_000)
            charset = response.headers.get_content_charset() or "utf-8"
            return response.status, body.decode(charset, errors="replace"), ""
    except HTTPError as exc:
        body = exc.read(120_000)
        charset = exc.headers.get_content_charset() or "utf-8"
        return exc.code, body.decode(charset, errors="replace"), str(exc)
    except (TimeoutError, URLError) as exc:
        return None, "", str(exc)


def normalize_text(value: str) -> str:
    return value.replace("\u2011", "-").replace("\u2010", "-").lower()


def contains_term(text: str, term: str) -> bool:
    return normalize_text(term) in normalize_text(text)


def check_rule(rule: SourceRule, fetch: FetchFn, timeout: float) -> dict[str, Any]:
    status_code, body, error = fetch(rule.url, timeout)
    required = [
        {"term": term, "present": contains_term(body, term)}
        for term in rule.required_terms
    ]
    optional = [
        {"term": term, "present": contains_term(body, term)}
        for term in rule.optional_terms
    ]
    ok = bool(status_code and 200 <= status_code < 400) and all(
        item["present"] for item in required
    )
    return {
        "url": rule.url,
        "status_code": status_code,
        "ok": ok,
        "required_terms": required,
        "optional_terms": optional,
        "error": error,
    }


def model_rules(label: str, sources: list[str]) -> tuple[SourceRule, ...]:
    if label in MODEL_SOURCE_RULES:
        return MODEL_SOURCE_RULES[label]
    return tuple(SourceRule(url, ()) for url in sources)


def recheck_report(
    bench_report: dict[str, Any],
    fetch: FetchFn | None = None,
    timeout: float = 20.0,
) -> dict[str, Any]:
    fetch = fetch or default_fetch
    models: list[dict[str, Any]] = []
    warnings: list[str] = []

    for entry in internal_ai_bench.iter_model_entries(bench_report):
        label = internal_ai_bench.model_label(entry)
        status = str(entry.get("verification_status", "unverified")).lower()
        sources = internal_ai_bench.source_list(entry)
        rules = model_rules(label, sources)

        source_checks = [check_rule(rule, fetch, timeout) for rule in rules]
        source_ok = bool(source_checks) and all(check["ok"] for check in source_checks)
        rankable_after_recheck = status == internal_ai_bench.RANKABLE_STATUS and source_ok

        if status == internal_ai_bench.RANKABLE_STATUS and not source_ok:
            warnings.append(f"{label}: verified slot failed current source recheck")

        models.append(
            {
                "label": label,
                "provider": entry.get("provider"),
                "model": entry.get("model"),
                "declared_verification_status": status,
                "source_ok": source_ok,
                "rankable_after_recheck": rankable_after_recheck,
                "source_checks": source_checks,
                "notes": entry.get("notes", ""),
            }
        )

    return {
        "schema_version": 1,
        "generated_at": utc_now(),
        "issue": bench_report.get("issue", "#2520"),
        "bench_id": bench_report.get("bench_id", "template"),
        "mode": "official_source_recheck",
        "live_provider_calls": False,
        "operator_approval_required_for_live": True,
        "policy": {
            "rank_only_verified_models_after_source_recheck": True,
            "fixed_strongest_model": "forbidden",
            "paid_api_calls": "forbidden_in_this_script",
            "routing_default_rule": "#2521 routing defaults require scored bench evidence or a feature flag.",
        },
        "models": models,
        "rejected_sns_claims": REJECTED_SNS_CLAIMS,
        "warnings": warnings,
    }


def render_term_list(items: list[dict[str, Any]]) -> str:
    if not items:
        return "none"
    return ", ".join(
        f"{item['term']}={'ok' if item['present'] else 'missing'}" for item in items
    )


def render_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# Internal AI Bench Official Source Recheck",
        "",
        f"- Issue: `{report.get('issue', '#2520')}`",
        f"- Bench ID: `{report.get('bench_id', 'template')}`",
        f"- Generated at: `{report.get('generated_at')}`",
        "- Live provider calls: disabled",
        "- Paid API usage: forbidden in this script",
        "- Routing impact: none; #2521 defaults still need scored bench evidence or a feature flag",
        "",
        "## Model Source Results",
        "",
        "| Model | Declared status | Source recheck | Rankable after recheck | Sources |",
        "| --- | --- | --- | --- | --- |",
    ]
    for model in report.get("models", []):
        checks = model.get("source_checks", [])
        source_lines = []
        for check in checks:
            status = check.get("status_code") or "error"
            ok = "ok" if check.get("ok") else "fail"
            required = render_term_list(check.get("required_terms", []))
            source_lines.append(
                f"{check.get('url')} ({status}, {ok}; required: {required})"
            )
        sources = " ; ".join(source_lines) if source_lines else "none"
        lines.append(
            "| `{label}` | `{status}` | {source_ok} | {rankable} | {sources} |".format(
                label=model["label"],
                status=model["declared_verification_status"],
                source_ok="pass" if model["source_ok"] else "fail",
                rankable="yes" if model["rankable_after_recheck"] else "no",
                sources=sources,
            )
        )

    lines.extend(
        [
            "",
            "## Rejected SNS Claims",
            "",
            "| Claim | Reason |",
            "| --- | --- |",
        ]
    )
    for claim in report.get("rejected_sns_claims", []):
        lines.append(f"| `{claim['claim']}` | {claim['reason']} |")

    lines.extend(["", "## Warnings", ""])
    warnings = report.get("warnings", [])
    if warnings:
        lines.extend(f"- {warning}" for warning in warnings)
    else:
        lines.append("- None.")

    lines.extend(
        [
            "",
            "## Next Gate",
            "",
            "If this report passes, the next step is an explicitly approved live provider run with synthetic fixtures only. No production routing change should be made from source recheck evidence alone.",
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
    parser.add_argument("--input", type=Path, default=REPO_ROOT / "docs/ai-bench/results/template.json")
    parser.add_argument("--output-json", type=Path)
    parser.add_argument("--output-md", type=Path)
    parser.add_argument("--timeout", type=float, default=20.0)
    parser.add_argument("--print-markdown", action="store_true")
    parser.add_argument("--strict", action="store_true", help="Exit non-zero when a verified slot fails source recheck.")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    bench_report = internal_ai_bench.load_report(args.input)
    report = recheck_report(bench_report, timeout=args.timeout)
    markdown = render_markdown(report)

    if args.output_json:
        write_json(args.output_json, report)
    if args.output_md:
        write_text(args.output_md, markdown + "\n")
    if args.print_markdown:
        print(markdown)

    if args.strict and report["warnings"]:
        for warning in report["warnings"]:
            print(f"WARN: {warning}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
