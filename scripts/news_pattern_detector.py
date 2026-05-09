#!/usr/bin/env python3
"""Detect repeated product/news patterns after source-risk filtering.

This script consumes JSON or Markdown reports already produced by repository
automation, runs the local fake-news filter, clusters surviving entries by
company/topic, and writes a small JSON/Markdown report. It is deterministic and
does not call external LLM APIs.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any

try:
    from scripts.fake_news_filter import (
        NormalizedEntry,
        filter_entries,
        load_entries,
        now_iso,
        summarize,
    )
except ImportError:  # pragma: no cover - used when executed as scripts/news_pattern_detector.py
    from fake_news_filter import (  # type: ignore
        NormalizedEntry,
        filter_entries,
        load_entries,
        now_iso,
        summarize,
    )


COMPANY_TERMS: dict[str, tuple[str, ...]] = {
    "anthropic": ("anthropic", "claude", "claude code"),
    "cursor": ("cursor",),
    "devin": ("devin", "cognition"),
    "github": ("github", "copilot"),
    "google": ("google", "gemini", "notebooklm"),
    "microsoft": ("microsoft", "azure", "copilot studio"),
    "notion": ("notion",),
    "openai": ("openai", "codex", "chatgpt"),
    "supabase": ("supabase",),
}

TOPIC_TERMS: dict[str, tuple[str, ...]] = {
    "agentic-workflows": ("agent", "agents", "automation", "workflow", "orchestration"),
    "ci-quality": ("ci", "test", "quality", "review", "gate", "ultrareview"),
    "cost-pricing": ("price", "pricing", "cost", "billing", "credit", "quota", "100x"),
    "mcp-integration": ("mcp", "connector", "tool", "integration"),
    "news-confidence": ("fake", "rumor", "unverified", "single-source", "source"),
    "product-release": ("release", "changelog", "launch", "ga", "version"),
    "security-policy": ("auth", "hmac", "permission", "security", "origin"),
}


def stable_key(*parts: str) -> str:
    payload = "\n".join(parts).encode("utf-8", "replace")
    return "np-" + hashlib.sha256(payload).hexdigest()[:12]


def tags_for(text: str, table: dict[str, tuple[str, ...]]) -> list[str]:
    lowered = text.lower()
    tags = []
    for tag, terms in table.items():
        if any(re.search(rf"\b{re.escape(term.lower())}\b", lowered) for term in terms):
            tags.append(tag)
    return tags


def entry_text(row: dict[str, Any]) -> str:
    entry = row["entry"]
    return " ".join(
        str(entry.get(key, ""))
        for key in ("title", "text", "url", "source", "source_label")
        if entry.get(key)
    )


def cluster_key(row: dict[str, Any]) -> tuple[str, str]:
    text = entry_text(row)
    companies = tags_for(text, COMPANY_TERMS)
    topics = tags_for(text, TOPIC_TERMS)
    company = companies[0] if companies else "multi-source"
    topic = topics[0] if topics else "general-signal"
    return company, topic


def detect_patterns(
    filtered_rows: list[dict[str, Any]],
    min_confidence: float = 0.55,
    issue_threshold: int = 3,
    max_patterns: int = 20,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    groups: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    for row in filtered_rows:
        result = row["filter"]
        if result["verdict"] == "drop" or result["confidence"] < min_confidence:
            continue
        company, topic = cluster_key(row)
        groups[(company, topic)].append(row)
        if company != "multi-source":
            groups[("multi-source", topic)].append(row)

    patterns: list[dict[str, Any]] = []
    for (company, topic), rows in groups.items():
        if len(rows) < 2:
            continue
        avg_conf = round(sum(r["filter"]["confidence"] for r in rows) / len(rows), 3)
        flags = sorted({flag for r in rows for flag in r["filter"]["risk_flags"]})
        titles = [r["entry"]["title"] for r in rows[:5]]
        risk_level = "review" if flags else "normal"
        patterns.append(
            {
                "id": stable_key(company, topic, *titles),
                "company": company,
                "topic": topic,
                "entry_count": len(rows),
                "average_confidence": avg_conf,
                "risk_level": risk_level,
                "risk_flags": flags,
                "evidence_titles": titles,
                "recommended_action": recommended_action(company, topic, risk_level),
            }
        )

    patterns.sort(key=lambda p: (p["entry_count"], p["average_confidence"]), reverse=True)
    patterns = patterns[:max_patterns]
    issue_candidates = [
        pattern
        for pattern in patterns
        if pattern["entry_count"] >= issue_threshold
        and pattern["average_confidence"] >= max(min_confidence, 0.62)
        and pattern["risk_level"] != "review"
    ]
    return patterns, issue_candidates


def recommended_action(company: str, topic: str, risk_level: str) -> str:
    if risk_level == "review":
        return "Hold for human review before creating issues or blog drafts."
    if topic == "cost-pricing":
        return "Compare pricing impact against Jibun Company cost discipline and WBS priorities."
    if topic == "ci-quality":
        return "Route to CI/readiness gate owners if repeated failures or quality gates are affected."
    if topic == "product-release":
        return "Route changed release signals into WBS/issue triage with source links."
    if company != "multi-source":
        return f"Review {company} movement for competitor-monitoring follow-up."
    return "Review repeated signal for a scoped follow-up issue only if source confidence stays high."


def build_report(
    source_paths: list[str],
    entries: list[NormalizedEntry],
    filtered_rows: list[dict[str, Any]],
    min_confidence: float,
    issue_threshold: int,
    max_patterns: int,
) -> dict[str, Any]:
    patterns, issue_candidates = detect_patterns(
        filtered_rows,
        min_confidence=min_confidence,
        issue_threshold=issue_threshold,
        max_patterns=max_patterns,
    )
    return {
        "generated_at": now_iso(),
        "source_files": source_paths,
        "min_confidence": min_confidence,
        "entries_total": len(entries),
        "filter_summary": summarize(filtered_rows),
        "entries": filtered_rows,
        "patterns": patterns,
        "issue_candidates": issue_candidates,
    }


def render_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# News Pattern Detector Report",
        "",
        f"- Generated at: `{report['generated_at']}`",
        f"- Sources: `{', '.join(report['source_files'])}`",
        f"- Entries scanned: `{report['entries_total']}`",
        f"- Patterns: `{len(report['patterns'])}`",
        f"- Issue candidates: `{len(report['issue_candidates'])}`",
        "",
        "## Patterns",
    ]
    if not report["patterns"]:
        lines.append("- No repeated high-confidence pattern detected.")
    else:
        for pattern in report["patterns"]:
            lines.append(
                f"- **{pattern['company']} / {pattern['topic']}**: "
                f"{pattern['entry_count']} entries, confidence={pattern['average_confidence']}, "
                f"risk={pattern['risk_level']}"
            )
            lines.append(f"  - Action: {pattern['recommended_action']}")
            for title in pattern["evidence_titles"][:3]:
                lines.append(f"  - Evidence: {title}")

    lines.extend(["", "## Filter Summary", ""])
    lines.append("```json")
    lines.append(json.dumps(report["filter_summary"], ensure_ascii=False, indent=2))
    lines.append("```")
    return "\n".join(lines) + "\n"


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", action="append", required=True, help="JSON/Markdown report path; repeatable")
    parser.add_argument("--output", required=True, help="Write JSON pattern report")
    parser.add_argument("--markdown", default="", help="Write Markdown pattern report")
    parser.add_argument("--label", default="", help="Source label override for filter entries")
    parser.add_argument("--min-confidence", type=float, default=0.55)
    parser.add_argument("--issue-threshold", type=int, default=3)
    parser.add_argument("--max-patterns", type=int, default=20)
    parser.add_argument("--print-only", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    entries: list[NormalizedEntry] = []
    for source in args.source:
        entries.extend(load_entries(Path(source), args.label))

    filtered_rows = filter_entries(entries, min_confidence=args.min_confidence)
    report = build_report(
        args.source,
        entries,
        filtered_rows,
        min_confidence=args.min_confidence,
        issue_threshold=args.issue_threshold,
        max_patterns=args.max_patterns,
    )

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    rendered = render_markdown(report)
    if args.markdown:
        markdown_path = Path(args.markdown)
        markdown_path.parent.mkdir(parents=True, exist_ok=True)
        markdown_path.write_text(rendered, encoding="utf-8", newline="\n")
    if args.print_only:
        print(rendered)

    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        with open(output, "a", encoding="utf-8") as fh:
            fh.write(f"pattern_count={len(report['patterns'])}\n")
            fh.write(f"issue_candidate_count={len(report['issue_candidates'])}\n")
            fh.write(f"pattern_report={args.output}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
