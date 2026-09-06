#!/usr/bin/env python3
"""Shared helpers for the Knowledge Graph Phase 1 indexers."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import textwrap
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

from sync_memory_index import embed_rows


ALLOWED_SOURCE_TYPES = {"issue", "wbs", "doc", "memory", "notebooklm"}
DEFAULT_OUTPUT_DIR = Path("tmp/kg-indexer")
GITHUB_BLOB_BASE = "https://github.com/kanta13jp1/my_web_app/blob/main"

PII_PATTERNS: dict[str, re.Pattern[str]] = {
    "email": re.compile(r"[\w.%+-]+@[\w.-]+\.[A-Za-z]{2,}"),
    "phone": re.compile(r"(?:\+\d{1,3}[-.\s]?\d{6,14}|0[789]0[-.\s]?\d{4}[-.\s]?\d{4}|0\d{1,4}[-.\s]\d{1,4}[-.\s]\d{4})"),
    "my_number": re.compile(r"\b\d{12}\b"),
    "ip_address": re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b"),
    "credit_card": re.compile(r"\b(?:\d[ -]?){13,19}\b"),
}


@dataclass(frozen=True)
class SourceRecord:
    source_type: str
    source_id: str
    title: str
    content: str
    source_url: str = ""
    metadata: dict[str, Any] = field(default_factory=dict)
    last_synced_at: str = field(default_factory=lambda: now_iso())


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore").lstrip("\ufeff")


def first_heading(text: str, fallback: str) -> str:
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("#"):
            return stripped.lstrip("#").strip() or fallback
    return fallback


def repo_relative(path: Path, root: Path) -> str:
    return path.resolve().relative_to(root.resolve()).as_posix()


def github_blob_url(relative_path: str) -> str:
    return f"{GITHUB_BLOB_BASE}/{relative_path}"


def content_hash(content: str) -> str:
    return hashlib.sha256(content.encode("utf-8")).hexdigest()


def excerpt(content: str, width: int = 280) -> str:
    return textwrap.shorten(" ".join(content.split()), width=width, placeholder="...")


def luhn_valid(value: str) -> bool:
    digits = [int(ch) for ch in re.sub(r"\D", "", value)]
    if len(digits) < 13:
        return False
    checksum = 0
    parity = len(digits) % 2
    for index, digit in enumerate(digits):
        if index % 2 == parity:
            digit *= 2
            if digit > 9:
                digit -= 9
        checksum += digit
    return checksum % 10 == 0


def detect_pii(text: str) -> list[str]:
    categories: list[str] = []
    for name, pattern in PII_PATTERNS.items():
        matches = pattern.findall(text)
        if not matches:
            continue
        if name == "credit_card" and not any(luhn_valid(match) for match in matches):
            continue
        categories.append(name)
    return categories


def record_payload(record: SourceRecord) -> dict[str, Any]:
    if record.source_type not in ALLOWED_SOURCE_TYPES:
        raise ValueError(f"unsupported source_type: {record.source_type}")
    content = record.content.strip()
    return {
        "source_type": record.source_type,
        "source_id": record.source_id,
        "source_url": record.source_url,
        "title": record.title.strip() or record.source_id,
        "content": content,
        "excerpt": excerpt(content),
        "content_hash": content_hash(content),
        "metadata": record.metadata,
        "last_synced_at": record.last_synced_at,
        "updated_at": now_iso(),
    }


def filter_payloads(
    records: Iterable[SourceRecord],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    payloads: list[dict[str, Any]] = []
    skipped: list[dict[str, Any]] = []
    for record in records:
        categories = detect_pii("\n".join([record.title, record.content]))
        if categories:
            skipped.append(
                {
                    "source_type": record.source_type,
                    "source_id": record.source_id,
                    "source_url": record.source_url,
                    "categories": categories,
                    "skipped_at": now_iso(),
                }
            )
            continue
        payloads.append(record_payload(record))
    return payloads, skipped


def write_jsonl(path: Path, rows: Iterable[dict[str, Any]]) -> int:
    path.parent.mkdir(parents=True, exist_ok=True)
    count = 0
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False, sort_keys=True))
            handle.write("\n")
            count += 1
    return count


def upsert_supabase(
    payloads: list[dict[str, Any]],
    *,
    supabase_url: str,
    service_role_key: str,
) -> int:
    if not payloads:
        return 0
    endpoint = (
        f"{supabase_url.rstrip('/')}/rest/v1/kg_embeddings"
        "?on_conflict=source_type,source_id"
    )
    applied = 0
    for index in range(0, len(payloads), 25):
        chunk = payloads[index : index + 25]
        request = urllib.request.Request(
            endpoint,
            data=json.dumps(chunk).encode("utf-8"),
            method="POST",
            headers={
                "apikey": service_role_key,
                "Authorization": f"Bearer {service_role_key}",
                "Content-Type": "application/json",
                "Prefer": "resolution=merge-duplicates",
            },
        )
        with urllib.request.urlopen(request, timeout=60) as response:
            if response.status not in {200, 201, 204}:
                raise RuntimeError(
                    f"Supabase upsert failed: HTTP {response.status}"
                )
        applied += len(chunk)
        print(f"upserted {applied}/{len(payloads)}")
    return applied


def add_common_args(
    parser: argparse.ArgumentParser,
    *,
    default_output: str,
) -> None:
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT_DIR / default_output))
    parser.add_argument("--audit-log", default=str(DEFAULT_OUTPUT_DIR / "pii-skips.jsonl"))
    parser.add_argument("--limit", type=int, default=500)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument(
        "--with-embeddings",
        action="store_true",
        help="Generate Gemini retrieval-document embeddings before writing or applying.",
    )
    parser.add_argument("--supabase-url", default=os.environ.get("SUPABASE_URL", ""))
    parser.add_argument(
        "--service-role-key",
        default=os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
        or os.environ.get("SERVICE_ROLE_KEY", ""),
    )
    parser.add_argument("--gemini-api-key", default=os.environ.get("GEMINI_API_KEY", ""))


def finish(records: Iterable[SourceRecord], args: argparse.Namespace) -> dict[str, Any]:
    payloads, skipped = filter_payloads(records)
    embedding_status = "not_requested"
    if args.with_embeddings:
        if not args.gemini_api_key:
            raise SystemExit("--with-embeddings requires GEMINI_API_KEY")
        embed_rows(payloads, args.gemini_api_key)
        embedding_status = "generated"
    written = write_jsonl(Path(args.output), payloads)
    skipped_count = write_jsonl(Path(args.audit_log), skipped)
    applied = 0
    if args.apply:
        if not args.supabase_url or not args.service_role_key:
            raise SystemExit("--apply requires SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY")
        applied = upsert_supabase(
            payloads,
            supabase_url=args.supabase_url,
            service_role_key=args.service_role_key,
        )
    stats = {
        "output": args.output,
        "written": written,
        "skipped_pii": skipped_count,
        "applied": applied,
        "embedding_status": embedding_status,
    }
    print(json.dumps(stats, ensure_ascii=False, sort_keys=True))
    return stats
