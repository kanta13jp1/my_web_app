#!/usr/bin/env python3
"""Offline unit tests for process_long_form_summaries.py."""

from __future__ import annotations

import io
import json
from pathlib import Path
import sys
import unittest
import urllib.error

SCRIPTS_DIR = Path(__file__).resolve().parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from process_long_form_summaries import (  # noqa: E402
    SlidingWindowRateLimiter,
    _sanitize_url_for_log,
    call_remote_summarizer,
    chunk_long_text,
    compute_backoff_seconds,
    main,
    process_document_record,
    summarize_chunked_extractive,
)


class _FakeResponse:
    def __init__(self, payload: object, status: int = 200, headers: dict[str, str] | None = None) -> None:
        self._body = json.dumps(payload).encode("utf-8")
        self.status = status
        self.headers = headers or {}

    def read(self) -> bytes:
        return self._body

    def __enter__(self) -> _FakeResponse:
        return self

    def __exit__(self, exc_type: object, exc: object, tb: object) -> bool:
        return False


class ProcessLongFormSummariesTest(unittest.TestCase):
    def test_chunks_long_text_and_summarizes_deterministically(self) -> None:
        long_text = "。".join(
            f"第{i}段落は Self-Attention 機構と長文コンテキスト保持による自動要約パイプラインの説明です"
            for i in range(1, 35)
        ) + "。"
        chunks = chunk_long_text(long_text, max_chars=500, overlap_chars=60)
        self.assertGreaterEqual(len(chunks), 2)
        summary, count = summarize_chunked_extractive(long_text, max_chunk_chars=500)
        self.assertEqual(count, len(chunks))
        self.assertTrue(len(summary) > 0)
        self.assertLess(len(summary), len(long_text))

    def test_sliding_window_rate_limiter_enforces_quota(self) -> None:
        now_val = [100.0]
        limiter = SlidingWindowRateLimiter(
            max_requests=2,
            window_seconds=60,
            clock=lambda: now_val[0],
        )
        self.assertEqual(limiter.check_and_consume("u1"), (True, 0))
        self.assertEqual(limiter.check_and_consume("u1"), (True, 0))
        allowed, retry_after = limiter.check_and_consume("u1")
        self.assertFalse(allowed)
        self.assertEqual(retry_after, 60)

        now_val[0] = 161.0
        self.assertEqual(limiter.check_and_consume("u1"), (True, 0))

    def test_process_document_record_marks_rate_limited(self) -> None:
        limiter = SlidingWindowRateLimiter(max_requests=1, window_seconds=300, clock=lambda: 10.0)
        first = process_document_record(
            {"document_id": "doc-1", "user_id": "u1", "body_text": "要約対象の最初の長文データです。" * 20},
            rate_limiter=limiter,
            dry_run=True,
        )
        second = process_document_record(
            {"document_id": "doc-2", "user_id": "u1", "body_text": "2件目は制限対象になる長文です。" * 20},
            rate_limiter=limiter,
            dry_run=True,
        )
        self.assertEqual(first.status, "completed")
        self.assertEqual(second.status, "rate_limited")
        self.assertEqual(second.retry_after_seconds, 300)

    def test_remote_429_retry_after_and_non_2xx_error_handling(self) -> None:
        self.assertEqual(compute_backoff_seconds(0, retry_after_header="12"), 12.0)
        self.assertEqual(
            _sanitize_url_for_log("https://api-inference.huggingface.co/models/bart?token=xyz"),
            "https://api-inference.huggingface.co/models/bart",
        )

        sleeps: list[float] = []
        attempts = [0]

        def flaky_opener(_req: object, timeout: int = 20) -> _FakeResponse:
            attempts[0] += 1
            if attempts[0] == 1:
                raise urllib.error.HTTPError(
                    "https://api-inference.huggingface.co/models/bart?token=secret",
                    429,
                    "Too Many Requests",
                    {"Retry-After": "4"},
                    io.BytesIO(b"{}"),
                )
            return _FakeResponse([{"summary_text": "リモートTransformer要約結果"}], status=200)

        result = call_remote_summarizer(
            "https://api-inference.huggingface.co/models/bart",
            "長文入力テキスト",
            provider_key="demo",
            opener=flaky_opener,
            sleeper=sleeps.append,
            max_retries=2,
        )
        self.assertEqual(result, "リモートTransformer要約結果")
        self.assertEqual(sleeps, [4.0])

        def always_500(_req: object, timeout: int = 20) -> _FakeResponse:
            return _FakeResponse({"error": "internal"}, status=500)

        with self.assertRaises(RuntimeError):
            call_remote_summarizer(
                "https://api-inference.huggingface.co/models/bart",
                "長文入力テキスト",
                provider_key="demo",
                opener=always_500,
                sleeper=lambda _: None,
            )

    def test_cli_dry_run_exits_zero(self) -> None:
        self.assertEqual(main(["--dry-run"]), 0)


if __name__ == "__main__":
    unittest.main()
