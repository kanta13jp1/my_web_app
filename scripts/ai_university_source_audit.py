#!/usr/bin/env python3
"""Audit active AI University course sources without mutating production.

The source inventory is read from the existing update workflow so the audit and
the updater cannot silently drift apart. A previous JSON report can be supplied
as a baseline to identify changed or stale sources and produce a deterministic
recheck queue.
"""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import re
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Callable
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_WORKFLOW = REPO_ROOT / ".github/workflows/ai-university-update.yml"
SOURCE_PATTERN = re.compile(
    r'^\s*upsert_provider\s+"([a-z0-9_]+)"\s+"(https://[^"\s]+)"\s+"([^"]+)"',
    re.MULTILINE,
)
COURSE_EVIDENCE_FIELDS = (
    "target_audience",
    "observable_learning_outcome",
    "assessment_verification_method",
    "evidence_source_url",
    "evidence_verified_at",
)


@dataclass(frozen=True)
class FetchResult:
    status_code: int | None
    etag: str | None
    last_modified: str | None
    content_digest: str | None
    error_kind: str | None = None


FetchFn = Callable[[str, float], FetchResult]


def utc_now() -> datetime:
    return datetime.now(timezone.utc).replace(microsecond=0)


def extract_sources(workflow: Path) -> list[dict[str, str]]:
    text = workflow.read_text(encoding="utf-8")
    sources = [
        {"provider": provider, "url": url, "name": name}
        for provider, url, name in SOURCE_PATTERN.findall(text)
    ]
    seen: set[tuple[str, str]] = set()
    unique: list[dict[str, str]] = []
    for source in sources:
        key = (source["provider"], source["url"])
        if key not in seen:
            seen.add(key)
            unique.append(source)
    return unique


def extract_catalog_sources(catalog_json: Path) -> list[dict[str, str]]:
    """Return active course source URLs without copying course text or titles."""
    rows = json.loads(catalog_json.read_text(encoding="utf-8"))
    if not isinstance(rows, list):
        raise ValueError("catalog input must be a JSON array")
    sources: list[dict[str, str]] = []
    for row in rows:
        if not isinstance(row, dict) or row.get("is_active") is False:
            continue
        url = row.get("source_url")
        provider = row.get("provider") or row.get("provider_id")
        if not isinstance(url, str) or not url.startswith(("https://", "http://")):
            continue
        if not isinstance(provider, str) or not provider:
            provider = "unknown"
        record_id = str(row.get("id") or f"{provider}:{url}")
        sources.append(
            {
                "provider": provider,
                "url": url,
                "name": provider,
                "record_id": record_id,
                **{field: row.get(field) for field in COURSE_EVIDENCE_FIELDS},
            }
        )
    return sources


def default_fetch(url: str, timeout: float) -> FetchResult:
    request = Request(
        url,
        headers={
            "Accept": "application/rss+xml,application/atom+xml,application/xml,text/xml;q=0.9,*/*;q=0.5",
            "Accept-Encoding": "identity",
            "User-Agent": "my-web-app-ai-university-source-audit/1.0",
        },
    )
    try:
        with urlopen(request, timeout=timeout) as response:
            body = response.read(1_000_000)
            return FetchResult(
                status_code=response.status,
                etag=response.headers.get("ETag"),
                last_modified=response.headers.get("Last-Modified"),
                content_digest=hashlib.sha256(body).hexdigest(),
            )
    except HTTPError as exc:
        body = exc.read(1_000_000)
        return FetchResult(
            status_code=exc.code,
            etag=exc.headers.get("ETag"),
            last_modified=exc.headers.get("Last-Modified"),
            content_digest=hashlib.sha256(body).hexdigest() if body else None,
            error_kind="http_error",
        )
    except TimeoutError:
        return FetchResult(None, None, None, None, "timeout")
    except URLError:
        return FetchResult(None, None, None, None, "network_error")


def load_baseline(path: Path | None) -> dict[str, dict[str, object]]:
    if path is None or not path.exists():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    indexed: dict[str, dict[str, object]] = {}
    for source in data.get("sources", []):
        if not isinstance(source, dict) or not source.get("url"):
            continue
        indexed[str(source.get("record_id") or source["url"])] = source
        indexed.setdefault(str(source["url"]), source)
    return indexed


def _parse_timestamp(value: object) -> datetime | None:
    if not isinstance(value, str) or not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def audit_sources(
    sources: list[dict[str, str]],
    *,
    fetch: FetchFn | None = None,
    baseline: dict[str, dict[str, object]] | None = None,
    checked_at: datetime | None = None,
    stale_after: timedelta = timedelta(days=7),
    timeout: float = 15.0,
    max_workers: int = 8,
) -> dict[str, object]:
    checked_at = checked_at or utc_now()
    baseline = baseline or {}
    fetch = fetch or default_fetch
    results: list[dict[str, object]] = []
    recheck_sources: list[dict[str, object]] = []
    unique_urls = list(dict.fromkeys(source["url"] for source in sources))
    with ThreadPoolExecutor(max_workers=max(1, min(max_workers, len(unique_urls)))) as pool:
        fetched_by_url = dict(
            zip(unique_urls, pool.map(lambda url: fetch(url, timeout), unique_urls))
        )

    for source in sources:
        fetched = fetched_by_url[source["url"]]
        baseline_key = str(source.get("record_id") or source["url"])
        previous = baseline.get(baseline_key) or baseline.get(source["url"])
        changed_signals: list[str] = []
        reasons: list[str] = []

        if fetched.status_code is None or not 200 <= fetched.status_code < 400:
            reasons.append("fetch_failed")
        evidence_missing = [
            field for field in COURSE_EVIDENCE_FIELDS if not source.get(field)
        ] if "record_id" in source else []
        if evidence_missing:
            reasons.append("course_evidence_incomplete")
        if previous is None:
            reasons.append("baseline_missing")
        else:
            for key, current in (
                ("status_code", fetched.status_code),
                ("etag", fetched.etag),
                ("last_modified", fetched.last_modified),
                ("content_digest", fetched.content_digest),
            ):
                old = previous.get(key)
                if old != current:
                    changed_signals.append(key)
            if changed_signals:
                reasons.append("source_changed")
            previous_check = _parse_timestamp(previous.get("checked_at"))
            if previous_check is None or checked_at - previous_check > stale_after:
                reasons.append("baseline_stale")

        result: dict[str, object] = {
            **source,
            "checked_at": checked_at.isoformat(),
            "status_code": fetched.status_code,
            "etag": fetched.etag,
            "last_modified": fetched.last_modified,
            "content_digest": fetched.content_digest,
            "error_kind": fetched.error_kind,
            "changed_signals": changed_signals,
            "course_evidence_missing": evidence_missing,
            "course_evidence_complete": not evidence_missing,
            "recheck_required": bool(reasons),
            "recheck_reasons": reasons,
        }
        results.append(result)
        if reasons:
            recheck_sources.append(
                {
                    "provider": source["provider"],
                    "record_id": source.get("record_id"),
                    "url": source["url"],
                    "reasons": reasons,
                }
            )

    failures = sum(
        1
        for source in results
        if source["status_code"] is None
        or not 200 <= int(source["status_code"]) < 400
    )
    changed = sum(bool(source["changed_signals"]) for source in results)
    return {
        "schema_version": 1,
        "mode": "read_only_official_source_audit",
        "production_mutation": False,
        "checked_at": checked_at.isoformat(),
        "source_count": len(results),
        "failure_count": failures,
        "changed_count": changed,
        "recheck_count": len(recheck_sources),
        "sources": results,
        "recheck_sources": recheck_sources,
    }


def render_markdown(report: dict[str, object]) -> str:
    lines = [
        "# AI University Official Source Audit",
        "",
        f"- Checked at: `{report['checked_at']}`",
        "- Mode: read-only; production mutation disabled",
        f"- Sources: {report['source_count']}",
        f"- Fetch failures: {report['failure_count']}",
        f"- Changed since baseline: {report['changed_count']}",
        f"- Recheck targets: {report['recheck_count']}",
        "",
        "| Provider | HTTP | Last-Modified | ETag | SHA-256 | Change signals | Recheck |",
        "| --- | ---: | --- | --- | --- | --- | --- |",
    ]
    for source in report["sources"]:  # type: ignore[union-attr]
        digest = source["content_digest"] or "-"
        changes = ", ".join(source["changed_signals"]) or "none"
        reasons = ", ".join(source["recheck_reasons"]) or "no"
        lines.append(
            f"| `{source['provider']}` | {source['status_code'] or 'error'} | "
            f"{source['last_modified'] or '-'} | {source['etag'] or '-'} | "
            f"`{str(digest)[:16]}` | {changes} | {reasons} |"
        )
    lines.extend(["", "## Explicit recheck targets", ""])
    targets = report["recheck_sources"]
    if targets:
        for target in targets:  # type: ignore[union-attr]
            lines.append(
                f"- `{target['provider']}` — {', '.join(target['reasons'])}: {target['url']}"
            )
    else:
        lines.append("- None.")
    return "\n".join(lines) + "\n"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workflow", type=Path, default=DEFAULT_WORKFLOW)
    parser.add_argument(
        "--catalog-json",
        type=Path,
        help="Active ai_university_content rows (id/provider/source_url/is_active).",
    )
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--output-json", type=Path)
    parser.add_argument("--output-md", type=Path)
    parser.add_argument("--timeout", type=float, default=15.0)
    parser.add_argument("--max-workers", type=int, default=8)
    parser.add_argument("--stale-after-hours", type=float, default=168.0)
    parser.add_argument("--print-markdown", action="store_true")
    parser.add_argument("--strict", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    sources = (
        extract_catalog_sources(args.catalog_json)
        if args.catalog_json is not None
        else extract_sources(args.workflow)
    )
    if not sources:
        inventory = args.catalog_json or args.workflow
        raise SystemExit(f"No active official sources found in {inventory}")
    report = audit_sources(
        sources,
        baseline=load_baseline(args.baseline),
        stale_after=timedelta(hours=args.stale_after_hours),
        timeout=args.timeout,
        max_workers=args.max_workers,
    )
    report["inventory_mode"] = (
        "active_catalog_rows" if args.catalog_json is not None else "workflow_rss_fallback"
    )
    markdown = render_markdown(report)
    if args.output_json:
        args.output_json.parent.mkdir(parents=True, exist_ok=True)
        args.output_json.write_text(
            json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
    if args.output_md:
        args.output_md.parent.mkdir(parents=True, exist_ok=True)
        args.output_md.write_text(markdown, encoding="utf-8")
    if args.print_markdown:
        print(markdown, end="")
    return 1 if args.strict and report["failure_count"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
