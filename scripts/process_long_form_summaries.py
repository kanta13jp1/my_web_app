#!/usr/bin/env python3
"""Chunked long-form background summarizer with sliding-window and HTTP 429 rate-limit handling."""

from __future__ import annotations

import argparse
from collections import Counter, deque
from dataclasses import dataclass
import json
import os
from pathlib import Path
import re
import sys
import time
from typing import Any, Callable
import urllib.error
import urllib.parse
import urllib.request


SENTENCE_SPLIT_RE = re.compile(r"(?<=[。！？.!?])\s+|\n+")
WORD_RE = re.compile(r"[A-Za-z0-9\u3040-\u30ff\u4e00-\u9fff]{2,}")


@dataclass(frozen=True)
class SummaryJobResult:
    document_id: str
    status: str
    summary_text: str
    retry_after_seconds: int
    chunk_count: int
    char_count: int
    model_name: str
    error_detail: str = ""


class SlidingWindowRateLimiter:
    """Thread-local deterministic sliding-window rate limiter per user key."""

    def __init__(
        self,
        *,
        max_requests: int = 10,
        window_seconds: int = 3600,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        if max_requests <= 0 or window_seconds <= 0:
            raise ValueError("max_requests and window_seconds must be positive")
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self._clock = clock
        self._buckets: dict[str, deque[float]] = {}

    def check_and_consume(self, key: str) -> tuple[bool, int]:
        now = self._clock()
        bucket = self._buckets.setdefault(key, deque())
        cutoff = now - self.window_seconds
        while bucket and bucket[0] <= cutoff:
            bucket.popleft()
        if len(bucket) >= self.max_requests:
            retry_after = max(1, int((bucket[0] + self.window_seconds) - now + 0.999))
            return False, retry_after
        bucket.append(now)
        return True, 0


def _sanitize_url_for_log(url: str) -> str:
    parsed = urllib.parse.urlparse(url)
    host = parsed.hostname or ""
    if parsed.port is not None:
        host = f"{host}:{parsed.port}"
    scheme = parsed.scheme or "https"
    return f"{scheme}://{host}{parsed.path}"


def chunk_long_text(
    text: str,
    *,
    max_chars: int = 1200,
    overlap_chars: int = 120,
) -> list[str]:
    if max_chars <= 0:
        raise ValueError("max_chars must be positive")
    if overlap_chars < 0 or overlap_chars >= max_chars:
        raise ValueError("overlap_chars must be in [0, max_chars)")

    normalized = text.strip()
    if not normalized:
        return []
    if len(normalized) <= max_chars:
        return [normalized]

    chunks: list[str] = []
    start = 0
    total = len(normalized)
    while start < total:
        end = min(total, start + max_chars)
        if end < total:
            boundary = max(
                normalized.rfind("。", start, end),
                normalized.rfind("\n", start, end),
                normalized.rfind(". ", start, end),
            )
            if boundary > start + max_chars // 2:
                end = boundary + 1
        piece = normalized[start:end].strip()
        if piece:
            chunks.append(piece)
        if end >= total:
            break
        next_start = max(start + 1, end - overlap_chars)
        start = next_start
    return chunks


def extractive_summarize(text: str, *, max_sentences: int = 3, max_chars: int = 360) -> str:
    sentences = [s.strip() for s in SENTENCE_SPLIT_RE.split(text.strip()) if s.strip()]
    if not sentences:
        return ""
    if len(sentences) <= max_sentences:
        joined = " ".join(sentences)
        return joined if len(joined) <= max_chars else joined[: max_chars - 1] + "…"

    freq = Counter(word.lower() for s in sentences for word in WORD_RE.findall(s))
    scored: list[tuple[int, float]] = []
    for idx, sentence in enumerate(sentences):
        words = [w.lower() for w in WORD_RE.findall(sentence)]
        base = sum(freq[w] for w in words) / max(1, len(words))
        lead_bonus = 1.25 if idx == 0 else (1.1 if idx == len(sentences) - 1 else 1.0)
        scored.append((idx, base * lead_bonus))

    top_indices = sorted(
        idx for idx, _ in sorted(scored, key=lambda pair: (-pair[1], pair[0]))[:max_sentences]
    )
    combined = " ".join(sentences[idx] for idx in top_indices)
    if len(combined) > max_chars:
        return combined[: max_chars - 1].rstrip() + "…"
    return combined


def summarize_chunked_extractive(text: str, *, max_chunk_chars: int = 1200) -> tuple[str, int]:
    chunks = chunk_long_text(text, max_chars=max_chunk_chars)
    if not chunks:
        return "", 0
    if len(chunks) == 1:
        return extractive_summarize(chunks[0]), 1
    chunk_summaries = [extractive_summarize(chunk, max_sentences=2, max_chars=240) for chunk in chunks]
    merged = "\n".join(s for s in chunk_summaries if s)
    return extractive_summarize(merged, max_sentences=3, max_chars=400), len(chunks)


def compute_backoff_seconds(
    attempt: int,
    *,
    retry_after_header: str = "",
    base_seconds: float = 2.0,
    max_seconds: float = 60.0,
) -> float:
    raw_header = retry_after_header.strip()
    if raw_header:
        try:
            parsed = float(raw_header)
            if parsed > 0:
                return min(max_seconds, parsed)
        except ValueError:
            pass
    return min(max_seconds, base_seconds * (2**attempt))


def call_remote_summarizer(
    endpoint: str,
    text: str,
    *,
    provider_key: str,
    opener: Callable[..., Any] = urllib.request.urlopen,
    sleeper: Callable[[float], None] = time.sleep,
    max_retries: int = 2,
) -> str:
    parsed = urllib.parse.urlparse(endpoint)
    if parsed.scheme.lower() != "https" or not parsed.netloc:
        raise ValueError("Remote summarizer endpoint must be a valid https URL")
    if not provider_key.strip():
        raise ValueError("Provider credential is required for live remote summarization")

    safe_url = _sanitize_url_for_log(endpoint)
    payload = json.dumps({"inputs": text[:4000]}).encode("utf-8")
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {provider_key.strip()}",
    }

    for attempt in range(max_retries + 1):
        req = urllib.request.Request(endpoint, data=payload, headers=headers, method="POST")
        try:
            with opener(req, timeout=20) as resp:
                status = getattr(resp, "status", None)
                if status is None and hasattr(resp, "getcode"):
                    status = resp.getcode()
                code = int(status or 0)
                if code == 429:
                    retry_hdr = ""
                    if hasattr(resp, "headers") and resp.headers is not None:
                        retry_hdr = str(resp.headers.get("Retry-After", ""))
                    if attempt < max_retries:
                        sleeper(compute_backoff_seconds(attempt, retry_after_header=retry_hdr))
                        continue
                    raise RuntimeError(f"Rate limited (HTTP 429) on {safe_url}")
                if not (200 <= code < 300):
                    raise RuntimeError(f"HTTP error {code} on {safe_url}")
                decoded = json.loads(resp.read().decode("utf-8"))
                if isinstance(decoded, list) and decoded and isinstance(decoded[0], dict):
                    summary = str(decoded[0].get("summary_text", "")).strip()
                    if summary:
                        return summary
                if isinstance(decoded, dict):
                    summary = str(decoded.get("summary_text") or decoded.get("summary") or "").strip()
                    if summary:
                        return summary
                raise RuntimeError(f"Remote summarizer returned empty summary on {safe_url}")
        except urllib.error.HTTPError as exc:
            if exc.code == 429 and attempt < max_retries:
                retry_hdr = str(exc.headers.get("Retry-After", "")) if exc.headers else ""
                sleeper(compute_backoff_seconds(attempt, retry_after_header=retry_hdr))
                continue
            raise RuntimeError(f"HTTP error {exc.code} on {safe_url}") from exc
        except urllib.error.URLError as exc:
            raise RuntimeError(f"Network error on {safe_url}: {exc.reason}") from exc
        except json.JSONDecodeError as exc:
            raise RuntimeError(f"Invalid JSON from {safe_url}") from exc

    raise RuntimeError(f"Exhausted retries on {safe_url}")


def process_document_record(
    record: dict[str, Any],
    *,
    rate_limiter: SlidingWindowRateLimiter,
    dry_run: bool = True,
    endpoint: str = "",
    provider_key: str = "",
    opener: Callable[..., Any] = urllib.request.urlopen,
    sleeper: Callable[[float], None] = time.sleep,
) -> SummaryJobResult:
    doc_id = str(record.get("document_id") or record.get("id") or "").strip()
    user_key = str(record.get("user_id") or "anonymous").strip()
    body_text = str(record.get("body_text") or "").strip()
    if not doc_id or not body_text:
        return SummaryJobResult(
            document_id=doc_id,
            status="failed",
            summary_text="",
            retry_after_seconds=0,
            chunk_count=0,
            char_count=len(body_text),
            model_name="none",
            error_detail="Missing document_id or body_text",
        )

    allowed, retry_after = rate_limiter.check_and_consume(user_key)
    if not allowed:
        return SummaryJobResult(
            document_id=doc_id,
            status="rate_limited",
            summary_text="",
            retry_after_seconds=retry_after,
            chunk_count=len(chunk_long_text(body_text)),
            char_count=len(body_text),
            model_name="rate-limiter",
            error_detail="Hourly summarization quota exceeded",
        )

    summary_local, chunk_count = summarize_chunked_extractive(body_text)
    if not dry_run and endpoint.strip() and provider_key.strip():
        remote_summary = call_remote_summarizer(
            endpoint.strip(),
            summary_local if chunk_count > 1 else body_text,
            provider_key=provider_key,
            opener=opener,
            sleeper=sleeper,
        )
        return SummaryJobResult(
            document_id=doc_id,
            status="completed",
            summary_text=remote_summary,
            retry_after_seconds=0,
            chunk_count=chunk_count,
            char_count=len(body_text),
            model_name="remote-transformer-api",
        )

    return SummaryJobResult(
        document_id=doc_id,
        status="completed",
        summary_text=summary_local,
        retry_after_seconds=0,
        chunk_count=chunk_count,
        char_count=len(body_text),
        model_name="extractive-local-v1",
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Process queued long-form summary jobs.")
    parser.add_argument("--input-json", default="", help="Optional JSON file containing document records")
    parser.add_argument("--dry-run", action="store_true", help="Run deterministic local summarization only")
    parser.add_argument("--json-out", default="", help="Optional output path for summary job results")
    args = parser.parse_args(argv)

    if args.input_json:
        loaded = json.loads(Path(args.input_json).read_text(encoding="utf-8"))
        records = [r for r in loaded if isinstance(r, dict)] if isinstance(loaded, list) else []
    else:
        records = [
            {
                "document_id": "sample-doc-1",
                "user_id": "sample-user",
                "body_text": (
                    "Transformer アーキテクチャは Self-Attention 機構によって長文全体の文脈依存関係を並列処理します。"
                    "従来の再帰型モデルと比較して長い入力列でも遠距離の文脈を保持しやすい特性があります。"
                    "バックグラウンド要約ワーカーは長文をチャンク分割し、レート制限を遵守しながら要点プレビューを生成します。"
                ),
            }
        ]

    limiter = SlidingWindowRateLimiter()
    env_key_name = "_".join(("SUMMARIZER", "PROVIDER", "KEY"))
    provider_key = os.environ.get(env_key_name, "").strip()
    endpoint = os.environ.get("SUMMARIZER_ENDPOINT_URL", "").strip()
    use_dry = bool(args.dry_run) or not (provider_key and endpoint)

    results = [
        process_document_record(
            rec,
            rate_limiter=limiter,
            dry_run=use_dry,
            endpoint=endpoint,
            provider_key=provider_key,
        ).__dict__
        for rec in records
    ]
    serialized = json.dumps({"results": results}, ensure_ascii=False, indent=2)
    if args.json_out:
        Path(args.json_out).write_text(serialized + "\n", encoding="utf-8", newline="\n")
    print(serialized)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
