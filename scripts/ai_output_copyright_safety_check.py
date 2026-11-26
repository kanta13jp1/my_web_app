#!/usr/bin/env python3
"""Deterministic AI output copyright overlap and safety validator."""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
import json
import re
from typing import Iterable

SAFETY_CATEGORY_LABELS: dict[str, str] = {
    "csae": "Child Sexual Abuse and Exploitation",
    "self_harm": "Self-Harm or Suicide Instruction",
    "illicit_drugs": "Illicit Drug Manufacturing or Trafficking",
    "cyber_attack": "Cyberattack or Malware Exploitation",
    "violence": "Severe Violence or Weapons Instruction",
}

_CATEGORY_PATTERNS: dict[str, tuple[re.Pattern[str], ...]] = {
    "csae": (
        re.compile(r"\bchild\s+sexual\b", re.IGNORECASE),
        re.compile(r"\bcsam\b", re.IGNORECASE),
        re.compile(r"児童性的虐待"),
    ),
    "self_harm": (
        re.compile(r"\bhow\s+to\s+commit\s+suicide\b", re.IGNORECASE),
        re.compile(r"\bself[-\s]?harm\s+instructions\b", re.IGNORECASE),
        re.compile(r"自殺の方法"),
    ),
    "illicit_drugs": (
        re.compile(r"\bsynthesize\s+methamphetamine\b", re.IGNORECASE),
        re.compile(r"\bhow\s+to\s+cook\s+meth\b", re.IGNORECASE),
        re.compile(r"違法薬物の製造"),
    ),
    "cyber_attack": (
        re.compile(r"\bransomware\s+payload\b", re.IGNORECASE),
        re.compile(r"\bcredential\s+harvesting\s+kit\b", re.IGNORECASE),
        re.compile(r"ランサムウェアの作り方"),
    ),
    "violence": (
        re.compile(r"\bbuild\s+an\s+improvised\s+explosive\b", re.IGNORECASE),
        re.compile(r"\bpipe\s+bomb\s+instructions\b", re.IGNORECASE),
        re.compile(r"爆発物の製造方法"),
    ),
}

_NON_WORD_RE = re.compile(r"[^\w\s]+", re.UNICODE)


@dataclass(frozen=True)
class SourceReference:
    source_id: str
    text: str


@dataclass(frozen=True)
class QuoteOverlapFinding:
    source_id: str
    word_count: int
    quote_count: int
    excerpt: str


@dataclass(frozen=True)
class DryRunIssueAlertPayload:
    title: str
    labels: list[str]
    body: str
    dry_run: bool = True


@dataclass(frozen=True)
class ValidationResult:
    allowed: bool
    blocked_categories: list[str]
    quote_violations: list[QuoteOverlapFinding]
    issue_alert_payload: DryRunIssueAlertPayload | None


def _tokenize_words(text: str) -> list[str]:
    cleaned = _NON_WORD_RE.sub(" ", text.lower()).strip()
    return cleaned.split() if cleaned else []


def _find_verbatim_matches(
    output_words: list[str],
    source_words: list[str],
    min_len: int,
) -> list[tuple[int, str]]:
    if len(output_words) < min_len or len(source_words) < min_len:
        return []

    matches: list[tuple[int, str]] = []
    i = 0
    while i <= len(output_words) - min_len:
        best_len = 0
        for j in range(len(source_words) - min_len + 1):
            k = 0
            while (
                i + k < len(output_words)
                and j + k < len(source_words)
                and output_words[i + k] == source_words[j + k]
            ):
                k += 1
            if k > best_len:
                best_len = k
        if best_len >= min_len:
            excerpt = " ".join(output_words[i : i + min(best_len, 20)])
            matches.append((best_len, excerpt))
            i += best_len
        else:
            i += 1
    return matches


def build_issue_alert_payload(
    blocked_categories: list[str],
    quote_violations: list[QuoteOverlapFinding],
) -> DryRunIssueAlertPayload:
    lines = [
        "## AI Output Copyright & Safety Validation Alert (Dry-Run)",
        "",
        "- Blocked safety categories: "
        + (", ".join(blocked_categories) if blocked_categories else "none"),
        f"- Quote overlap violations: {len(quote_violations)}",
    ]
    for finding in quote_violations:
        lines.append(
            f"  - source={finding.source_id} words={finding.word_count} "
            f"quotes={finding.quote_count}"
        )
    return DryRunIssueAlertPayload(
        title="[security][ai-guard] AI出力の著作権・安全性バリデーション検知",
        labels=["security", "automation"],
        body="\n".join(lines),
        dry_run=True,
    )


def validate_ai_output(
    output_text: str,
    sources: Iterable[SourceReference] = (),
    *,
    max_words_per_quote: int = 15,
    max_quotes_per_source: int = 1,
    min_quote_words_for_count: int = 6,
) -> ValidationResult:
    blocked_categories = [
        category
        for category, patterns in _CATEGORY_PATTERNS.items()
        if any(pattern.search(output_text) for pattern in patterns)
    ]

    output_words = _tokenize_words(output_text)
    quote_violations: list[QuoteOverlapFinding] = []
    for source in sources:
        source_words = _tokenize_words(source.text)
        matches = _find_verbatim_matches(
            output_words,
            source_words,
            min_quote_words_for_count,
        )
        max_words = max((length for length, _ in matches), default=0)
        if max_words > max_words_per_quote or len(matches) > max_quotes_per_source:
            quote_violations.append(
                QuoteOverlapFinding(
                    source_id=source.source_id,
                    word_count=max_words,
                    quote_count=len(matches),
                    excerpt=matches[0][1] if matches else "",
                )
            )

    allowed = not blocked_categories and not quote_violations
    payload = (
        None
        if allowed
        else build_issue_alert_payload(blocked_categories, quote_violations)
    )
    return ValidationResult(
        allowed=allowed,
        blocked_categories=blocked_categories,
        quote_violations=quote_violations,
        issue_alert_payload=payload,
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate AI output for copyright overlap and safety."
    )
    parser.add_argument(
        "--sample-dry-run",
        action="store_true",
        help="Run built-in clean and violation samples in dry-run mode.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit JSON output.",
    )
    parser.add_argument(
        "--fail-on-violation",
        action="store_true",
        help="Exit non-zero if a checked sample is blocked.",
    )
    args = parser.parse_args()

    if args.sample_dry_run:
        clean = validate_ai_output(
            "Cashflow summary shows positive balance.",
            [SourceReference("ledger-1", "Monthly ledger confirmed positive balance.")],
        )
        report = {"ok": clean.allowed, "sample": asdict(clean)}
        if args.json:
            print(json.dumps(report, ensure_ascii=False, indent=2))
        else:
            print(f"ok={clean.allowed}")
        return 0 if (clean.allowed or not args.fail_on_violation) else 1

    parser.print_help()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
