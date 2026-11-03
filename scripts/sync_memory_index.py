#!/usr/bin/env python3
"""Sync local memory markdown files into Supabase memory_index."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

EMBEDDING_DIMENSION = 768
EMBEDDING_MODEL = "models/gemini-embedding-001"
QUOTA_HTTP_CODES = {429, 503}
QUOTA_ERROR_MARKERS = (
    "RESOURCE_EXHAUSTED",
    "quota",
    "rate limit",
    "rate-limit",
    "rate_limited",
)


def title_for(path: Path, text: str) -> str:
    for line in text.splitlines():
        if line.startswith("#"):
            return line.lstrip("#").strip()[:180]
    return path.stem.replace("_", " ")[:180]


def snippet_for(text: str) -> str:
    compact = re.sub(r"\s+", " ", text).strip()
    return compact[:500]


def links_for(text: str) -> list[str]:
    return sorted(set(re.findall(r"\[\[([^\]]+)\]\]", text)))[:100]


def normalize_embedding(values: list[float]) -> list[float]:
    magnitude = sum(value * value for value in values) ** 0.5
    if magnitude <= 0:
        return values
    return [round(value / magnitude, 8) for value in values]


def embedding_text_for(row: dict) -> str:
    parts = [
        str(row.get("title") or ""),
        str(row.get("file_path") or row.get("source_id") or ""),
        str(row.get("snippet") or row.get("excerpt") or ""),
        str(row.get("content") or ""),
    ]
    return "\n".join(part for part in parts if part).strip()[:3500]


def is_embedding_quota_error(status_code: int, body: str) -> bool:
    if status_code in QUOTA_HTTP_CODES:
        return True
    lowered = body.lower()
    return any(marker.lower() in lowered for marker in QUOTA_ERROR_MARKERS)


def load_rows(memory_dir: Path) -> list[dict]:
    rows: list[dict] = []
    for path in sorted(memory_dir.rglob("*.md")):
        if ".git" in path.parts:
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        rel = path.as_posix()
        rows.append(
            {
                "file_path": rel,
                "title": title_for(path, text),
                "content": text,
                "snippet": snippet_for(text),
                "content_hash": hashlib.sha256(text.encode("utf-8")).hexdigest(),
                "source": "memory",
                "metadata": {"links": links_for(text), "bytes": len(text.encode("utf-8"))},
            }
        )
    return rows


def embed_rows(rows: list[dict], api_key: str, batch_size: int = 16) -> None:
    endpoint = (
        "https://generativelanguage.googleapis.com/v1beta/"
        "models/gemini-embedding-001:batchEmbedContents"
    )
    for index in range(0, len(rows), batch_size):
        chunk = rows[index : index + batch_size]
        requests = []
        for row in chunk:
            requests.append(
                {
                    "model": EMBEDDING_MODEL,
                    "content": {"parts": [{"text": embedding_text_for(row)}]},
                    "taskType": "RETRIEVAL_DOCUMENT",
                    "title": str(row.get("title") or row.get("file_path") or ""),
                    "outputDimensionality": EMBEDDING_DIMENSION,
                }
            )

        req = urllib.request.Request(
            endpoint,
            data=json.dumps({"requests": requests}).encode("utf-8"),
            method="POST",
            headers={
                "Content-Type": "application/json",
                "x-goog-api-key": api_key,
            },
        )
        with urllib.request.urlopen(req, timeout=60) as res:
            payload = json.loads(res.read().decode("utf-8"))

        embeddings = payload.get("embeddings") or []
        if len(embeddings) != len(chunk):
            raise RuntimeError(
                f"Gemini returned {len(embeddings)} embeddings for {len(chunk)} rows"
            )

        for row, embedding in zip(chunk, embeddings):
            values = embedding.get("values") or []
            if len(values) != EMBEDDING_DIMENSION:
                row_id = row.get("file_path") or row.get("source_id") or "unknown"
                raise RuntimeError(
                    f"Gemini embedding dimension mismatch for {row_id}: "
                    f"{len(values)} != {EMBEDDING_DIMENSION}"
                )
            row["embedding"] = normalize_embedding([float(value) for value in values])
            metadata = dict(row.get("metadata") or {})
            metadata["embedding_model"] = EMBEDDING_MODEL
            metadata["embedding_dimension"] = EMBEDDING_DIMENSION
            row["metadata"] = metadata
        print(f"embedded {min(index + len(chunk), len(rows))}/{len(rows)}")


def upsert_rows(base_url: str, service_role: str, rows: list[dict]) -> None:
    endpoint = f"{base_url.rstrip('/')}/rest/v1/memory_index?on_conflict=file_path"
    for index in range(0, len(rows), 100):
        chunk = rows[index : index + 100]
        req = urllib.request.Request(
            endpoint,
            data=json.dumps(chunk).encode("utf-8"),
            method="POST",
            headers={
                "apikey": service_role,
                "Authorization": f"Bearer {service_role}",
                "Content-Type": "application/json",
                "Prefer": "resolution=merge-duplicates",
            },
        )
        with urllib.request.urlopen(req, timeout=60) as res:
            res.read()
        print(f"upserted {min(index + len(chunk), len(rows))}/{len(rows)}")


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    parser = argparse.ArgumentParser()
    parser.add_argument("--memory-dir", default="memory")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument(
        "--with-embeddings",
        action="store_true",
        help="Generate Gemini retrieval-document embeddings when GEMINI_API_KEY is set.",
    )
    parser.add_argument(
        "--soft-fail-embedding-quota",
        action="store_true",
        help="Exit successfully when Gemini embedding quota is exhausted.",
    )
    args = parser.parse_args()

    memory_dir = Path(args.memory_dir)
    if not memory_dir.exists():
        print(f"memory directory not found: {memory_dir}", file=sys.stderr)
        return 1

    rows = load_rows(memory_dir)
    print(f"loaded {len(rows)} memory files")
    gemini_api_key = os.getenv("GEMINI_API_KEY", "")
    if args.with_embeddings:
        if gemini_api_key:
            try:
                embed_rows(rows, gemini_api_key)
            except urllib.error.HTTPError as exc:
                detail = exc.read().decode("utf-8", errors="replace")
                print(detail, file=sys.stderr)
                if args.soft_fail_embedding_quota and is_embedding_quota_error(
                    exc.code,
                    detail,
                ):
                    print(
                        "::warning::Gemini embedding quota exhausted; "
                        "memory sync skipped and will retry on the next run",
                        file=sys.stderr,
                    )
                    return 0
                return 1
        else:
            print("GEMINI_API_KEY not configured; embeddings skipped", file=sys.stderr)
    if args.dry_run:
        print(json.dumps(rows[:3], ensure_ascii=False, indent=2))
        return 0

    base_url = os.getenv("SUPABASE_URL", "")
    service_role = os.getenv("SERVICE_ROLE_KEY") or os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
    if not base_url or not service_role:
        print("SUPABASE_URL and SERVICE_ROLE_KEY are required", file=sys.stderr)
        return 1

    try:
        upsert_rows(base_url, service_role, rows)
    except urllib.error.HTTPError as exc:
        print(exc.read().decode("utf-8", errors="replace"), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
