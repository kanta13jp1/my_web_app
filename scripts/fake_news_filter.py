#!/usr/bin/env python3
"""Score news-like signals before they enter automation queues.

The filter is intentionally dependency-free. It does not try to decide truth;
it highlights weak sourcing, social-only claims, sensational language, and
HTTP/source failures so downstream workflows can route risky items to review
instead of creating issues or drafts automatically.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any
from urllib.parse import urlparse


UTC = dt.timezone.utc

OFFICIAL_DOMAIN_HINTS = (
    "anthropic.com",
    "apple.com",
    "blog.google",
    "claude.com",
    "cloud.google.com",
    "cursor.com",
    "developers.google.com",
    "developers.openai.com",
    "docs.devin.ai",
    "docs.github.com",
    "github.blog",
    "github.com",
    "microsoft.com",
    "notion.so",
    "openai.com",
    "supabase.com",
)

SOCIAL_DOMAINS = (
    "bsky.app",
    "facebook.com",
    "instagram.com",
    "linkedin.com",
    "reddit.com",
    "tiktok.com",
    "x.com",
    "youtube.com",
)

SENSATIONAL_TERMS = (
    "100x",
    "breakthrough",
    "crazy",
    "destroy",
    "explodes",
    "guaranteed",
    "insane",
    "kill",
    "secret",
    "shocking",
)

UNVERIFIED_TERMS = (
    "alleged",
    "anonymous",
    "claim",
    "claims",
    "leak",
    "leaked",
    "rumor",
    "rumour",
    "single-source",
    "unconfirmed",
    "unverified",
)


@dataclass(frozen=True)
class NormalizedEntry:
    entry_id: str
    title: str
    text: str
    url: str
    source: str
    source_label: str
    status: int | None
    raw: dict[str, Any]


@dataclass(frozen=True)
class FilterResult:
    entry_id: str
    title: str
    url: str
    source: str
    source_label: str
    confidence: float
    verdict: str
    risk_flags: list[str]
    reasons: list[str]


def now_iso() -> str:
    return dt.datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def stable_id(*parts: str) -> str:
    import hashlib

    payload = "\n".join(part for part in parts if part).encode("utf-8", "replace")
    return "nf-" + hashlib.sha256(payload).hexdigest()[:12]


def clamp(value: float, low: float = 0.0, high: float = 1.0) -> float:
    return max(low, min(high, value))


def domain_from_url(url: str) -> str:
    if not url:
        return ""
    parsed = urlparse(url if "://" in url else f"https://{url}")
    return (parsed.netloc or "").lower().removeprefix("www.")


def is_official_domain(url: str) -> bool:
    domain = domain_from_url(url)
    return any(domain == hint or domain.endswith(f".{hint}") for hint in OFFICIAL_DOMAIN_HINTS)


def is_social_domain(url: str) -> bool:
    domain = domain_from_url(url)
    return any(domain == hint or domain.endswith(f".{hint}") for hint in SOCIAL_DOMAINS)


def text_value(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, (int, float, bool)):
        return str(value)
    if isinstance(value, list):
        return " ".join(text_value(item) for item in value)
    if isinstance(value, dict):
        return " ".join(text_value(item) for item in value.values())
    return str(value).strip()


def extract_status(entry: dict[str, Any]) -> int | None:
    for key in ("status", "http_status", "httpCode", "http"):
        value = entry.get(key)
        if isinstance(value, int):
            return value
        if isinstance(value, str):
            match = re.search(r"\b(\d{3})\b", value)
            if match:
                return int(match.group(1))
    return None


def normalize_entry(item: Any, source_label: str = "") -> NormalizedEntry:
    if not isinstance(item, dict):
        title = text_value(item)[:120] or "untitled"
        text = text_value(item)
        return NormalizedEntry(
            entry_id=stable_id(title, text),
            title=title,
            text=text,
            url="",
            source="",
            source_label=source_label,
            status=None,
            raw={"value": item},
        )

    title = (
        text_value(item.get("title"))
        or text_value(item.get("name"))
        or text_value(item.get("latest_signal"))
        or text_value(item.get("slug"))
        or "untitled"
    )
    url = text_value(item.get("url") or item.get("source_url") or item.get("website"))
    source = text_value(item.get("owner") or item.get("source") or item.get("name"))
    snippets = item.get("snippets")
    text = " ".join(
        part
        for part in (
            title,
            text_value(item.get("summary")),
            text_value(item.get("body")),
            text_value(item.get("description")),
            text_value(item.get("latest_signal")),
            text_value(snippets),
            text_value(item.get("classification")),
        )
        if part
    )
    entry_id = text_value(item.get("id") or item.get("entry_id")) or stable_id(title, url, text)
    return NormalizedEntry(
        entry_id=entry_id,
        title=title[:180],
        text=text,
        url=url,
        source=source,
        source_label=source_label,
        status=extract_status(item),
        raw=item,
    )


def entries_from_json(data: Any, source_label: str = "") -> list[NormalizedEntry]:
    if isinstance(data, list):
        return [normalize_entry(item, source_label) for item in data]
    if not isinstance(data, dict):
        return [normalize_entry(data, source_label)]

    if isinstance(data.get("sources"), list):
        return [normalize_entry(item, source_label or "ai-tool-watch") for item in data["sources"]]

    notebook_rows: list[dict[str, Any]] = []
    for key, classification in (("true_gap", "TRUE_GAP"), ("dup_open", "DUP_OPEN")):
        rows = data.get(key)
        if isinstance(rows, list):
            for row in rows:
                if isinstance(row, dict):
                    notebook_rows.append({**row, "classification": classification})
    if notebook_rows:
        return [normalize_entry(item, source_label or "notebooklm-issue-crosscheck") for item in notebook_rows]

    for key in ("entries", "items", "notebooks", "changed_sources"):
        rows = data.get(key)
        if isinstance(rows, list):
            return [normalize_entry(item, source_label) for item in rows]

    return [normalize_entry(data, source_label)]


def entries_from_text(text: str, source_label: str = "") -> list[NormalizedEntry]:
    entries: list[NormalizedEntry] = []
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("<!--"):
            continue
        if stripped.startswith("|") and stripped.endswith("|") and "---" not in stripped:
            cells = [cell.strip() for cell in stripped.strip("|").split("|")]
            if len(cells) >= 2 and cells[0].lower() not in {"name", "competitor", "url"}:
                title = cells[0]
                url = next((cell for cell in cells if cell.startswith("http")), "")
                status = next((cell for cell in cells if "HTTP" in cell), "")
                entries.append(
                    normalize_entry(
                        {
                            "title": title,
                            "url": url,
                            "status": status,
                            "summary": " ".join(cells),
                        },
                        source_label,
                    )
                )
                continue
        if stripped.startswith(("- ", "* ", "## ")):
            entries.append(normalize_entry(stripped.lstrip("-*# "), source_label))
    return entries


def load_entries(path: Path, source_label: str = "") -> list[NormalizedEntry]:
    if str(path) == "-":
        content = sys.stdin.read()
        return entries_from_text(content, source_label)
    content = path.read_text(encoding="utf-8", errors="replace")
    if path.suffix.lower() == ".json":
        return entries_from_json(json.loads(content), source_label or path.stem)
    return entries_from_text(content, source_label or path.stem)


def assess_entry(entry: NormalizedEntry, min_confidence: float = 0.6) -> FilterResult:
    text = f"{entry.title}\n{entry.text}".lower()
    score = 0.55
    reasons: list[str] = []
    flags: list[str] = []

    if entry.url:
        score += 0.12
        reasons.append("has source URL")
        if is_official_domain(entry.url):
            score += 0.18
            reasons.append("source domain is official or primary")
        if is_social_domain(entry.url):
            score -= 0.22
            flags.append("social_only_source")
            reasons.append("social source needs corroboration")
    else:
        score -= 0.16
        flags.append("missing_source_url")
        reasons.append("missing source URL")

    if entry.status is not None:
        if 200 <= entry.status < 400:
            score += 0.08
            reasons.append(f"HTTP {entry.status} reachable")
        elif entry.status >= 400 or entry.status == 0:
            score -= 0.12
            flags.append("source_http_problem")
            reasons.append(f"source HTTP status {entry.status}")

    sensational_hits = [term for term in SENSATIONAL_TERMS if term in text]
    if sensational_hits:
        score -= min(0.18, 0.06 * len(sensational_hits))
        flags.append("sensational_language")
        reasons.append("sensational terms: " + ", ".join(sensational_hits[:4]))

    unverified_hits = [term for term in UNVERIFIED_TERMS if term in text]
    if unverified_hits:
        score -= min(0.22, 0.07 * len(unverified_hits))
        flags.append("unverified_language")
        reasons.append("unverified terms: " + ", ".join(unverified_hits[:4]))

    if len(entry.text) >= 80:
        score += 0.04
        reasons.append("has enough context for review")

    classification = str(entry.raw.get("classification", ""))
    if classification == "TRUE_GAP":
        score -= 0.04
        reasons.append("TRUE_GAP requires human triage before issue creation")

    confidence = round(clamp(score), 3)
    if confidence >= min_confidence and "social_only_source" not in flags:
        verdict = "pass"
    elif confidence >= max(0.35, min_confidence - 0.22):
        verdict = "review"
    else:
        verdict = "drop"

    return FilterResult(
        entry_id=entry.entry_id,
        title=entry.title,
        url=entry.url,
        source=entry.source,
        source_label=entry.source_label,
        confidence=confidence,
        verdict=verdict,
        risk_flags=flags,
        reasons=reasons,
    )


def filter_entries(entries: list[NormalizedEntry], min_confidence: float = 0.6) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    for entry in entries:
        result = assess_entry(entry, min_confidence=min_confidence)
        results.append({"entry": asdict(entry), "filter": asdict(result)})
    return results


def summarize(results: list[dict[str, Any]]) -> dict[str, Any]:
    by_verdict = {"pass": 0, "review": 0, "drop": 0}
    risk_flags: dict[str, int] = {}
    for row in results:
        result = row["filter"]
        by_verdict[result["verdict"]] = by_verdict.get(result["verdict"], 0) + 1
        for flag in result["risk_flags"]:
            risk_flags[flag] = risk_flags.get(flag, 0) + 1
    return {
        "total": len(results),
        "by_verdict": by_verdict,
        "risk_flags": dict(sorted(risk_flags.items())),
    }


def render_markdown(payload: dict[str, Any]) -> str:
    lines = [
        "# Fake-News Filter Report",
        "",
        f"- Generated at: `{payload['generated_at']}`",
        f"- Entries: `{payload['summary']['total']}`",
        f"- Verdicts: `{payload['summary']['by_verdict']}`",
        "",
        "## Review Queue",
    ]
    review_rows = [
        row for row in payload["entries"] if row["filter"]["verdict"] in {"review", "drop"}
    ]
    if not review_rows:
        lines.append("- No risky entries detected.")
    else:
        for row in review_rows[:30]:
            result = row["filter"]
            flags = ", ".join(result["risk_flags"]) or "none"
            lines.append(
                f"- `{result['verdict']}` {result['title']} "
                f"(confidence={result['confidence']}, flags={flags})"
            )
    return "\n".join(lines) + "\n"


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", action="append", required=True, help="JSON/Markdown source path; repeatable")
    parser.add_argument("--output", default="", help="Write JSON report to this path")
    parser.add_argument("--markdown", default="", help="Write Markdown report to this path")
    parser.add_argument("--source-label", default="", help="Override source label for all inputs")
    parser.add_argument("--min-confidence", type=float, default=0.6)
    parser.add_argument("--print-only", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    entries: list[NormalizedEntry] = []
    for raw_path in args.input:
        entries.extend(load_entries(Path(raw_path), args.source_label))

    results = filter_entries(entries, min_confidence=args.min_confidence)
    payload = {
        "generated_at": now_iso(),
        "min_confidence": args.min_confidence,
        "summary": summarize(results),
        "entries": results,
    }
    rendered = render_markdown(payload)

    if args.output:
        out = Path(args.output)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if args.markdown:
        md = Path(args.markdown)
        md.parent.mkdir(parents=True, exist_ok=True)
        md.write_text(rendered, encoding="utf-8", newline="\n")
    if args.print_only or not args.output:
        print(rendered)

    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        summary = payload["summary"]
        with open(output, "a", encoding="utf-8") as fh:
            fh.write(f"filter_pass_count={summary['by_verdict'].get('pass', 0)}\n")
            fh.write(f"filter_review_count={summary['by_verdict'].get('review', 0)}\n")
            fh.write(f"filter_drop_count={summary['by_verdict'].get('drop', 0)}\n")
            if args.output:
                fh.write(f"filter_report={args.output}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
