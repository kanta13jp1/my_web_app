#!/usr/bin/env python3
"""Offline unit tests for generate_weekly_performance_report.py."""

from __future__ import annotations

from datetime import date
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
import urllib.error

SCRIPTS_DIR = Path(__file__).resolve().parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from generate_weekly_performance_report import (  # noqa: E402
    _sanitize_url_for_log,
    aggregate_weekly_metrics,
    anonymize_user_id,
    build_llm_prompt,
    detect_anomalies,
    generate_llm_insight,
    main,
    redact_pii,
    render_safe_html_report,
)


class _FakeHttpResponse:
    def __init__(self, payload: dict[str, object], status: int = 200) -> None:
        self._body = json.dumps(payload).encode("utf-8")
        self.status = status

    def read(self) -> bytes:
        return self._body

    def __enter__(self) -> _FakeHttpResponse:
        return self

    def __exit__(self, exc_type: object, exc: object, tb: object) -> bool:
        return False


class GenerateWeeklyPerformanceReportTest(unittest.TestCase):
    def test_aggregates_7_day_window_and_detects_anomalies(self) -> None:
        raw_events = [
            {"occurred_on": "2026-11-17", "tasks_completed": 1, "focus_minutes": 20, "error_count": 3},
            {"occurred_on": "2026-11-18", "tasks_completed": 1, "focus_minutes": 15, "error_count": 3},
            {"occurred_on": "2026-11-08", "tasks_completed": 10, "focus_minutes": 200, "error_count": 0},
            {"occurred_on": "2026-11-09", "tasks_completed": 10, "focus_minutes": 200, "error_count": 0},
        ]
        summary, _ = aggregate_weekly_metrics(raw_events, period_end=date(2026, 11, 18))
        self.assertEqual(summary.period_start, "2026-11-12")
        self.assertEqual(summary.period_end, "2026-11-18")
        self.assertEqual(summary.active_days, 2)
        self.assertEqual(summary.tasks_completed, 2)
        self.assertEqual(summary.prior_tasks_completed, 20)
        self.assertEqual(summary.tasks_delta_pct, -90.0)

        codes = {a.code for a in detect_anomalies(summary)}
        self.assertIn("task_completion_drop", codes)
        self.assertIn("focus_time_drop", codes)
        self.assertIn("error_spike", codes)
        self.assertIn("low_active_days", codes)

    def test_pii_is_redacted_before_llm_prompt_construction(self) -> None:
        sample_key = "".join(("sk", "-", "demo99887766"))
        fake_jwt = ".".join(("eyJ" + "hbGciOiJIUzI1NiJ9", "eyJzdWIiOiJ1c2VyIn0", "sig123456"))
        bearer_val = "Bearer " + "".join(("tok", "_xyz_", "987654"))
        raw_user_id = "user-uuid-9f1c-44aa-9999"
        phone_val = "090-1234-5678"
        email_val = "founder@example.com"

        events = [
            {
                "occurred_on": "2026-11-18",
                "user_id": raw_user_id,
                "tasks_completed": 5,
                "focus_minutes": 120,
                "error_count": 0,
                "note": f"連絡先 {email_val} / TEL {phone_val} / {bearer_val} / {sample_key} / {fake_jwt}",
            }
        ]
        summary, notes = aggregate_weekly_metrics(events, period_end=date(2026, 11, 18))
        pseudonym = anonymize_user_id(raw_user_id)
        prompt = build_llm_prompt(summary, [], pseudonym_id=pseudonym, sanitized_notes=notes)

        self.assertIn(pseudonym, prompt)
        for sensitive in (raw_user_id, email_val, phone_val, sample_key, fake_jwt, bearer_val):
            self.assertNotIn(sensitive, prompt)
        self.assertIn("[REDACTED_EMAIL]", redact_pii(email_val))

    def test_html_renderer_escapes_xss_payloads(self) -> None:
        summary, _ = aggregate_weekly_metrics([], period_end=date(2026, 11, 18))
        malicious_md = 'テスト <script>alert("xss")</script> & "onerror=alert(1)"'
        rendered = render_safe_html_report(
            summary,
            [],
            malicious_md,
            pseudonym_id="usr_abc123def456",
            delivery_status="dry_run",
        )
        self.assertNotIn("<script", rendered.lower())
        self.assertIn("&quot;onerror=alert(1)&quot;", rendered)
        self.assertIn("&amp;", rendered)

    def test_dry_run_cli_outputs_json_html_and_github_output(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            json_out = root / "report.json"
            html_out = root / "report.html"
            gh_out = root / "gh_output.txt"
            code = main(
                [
                    "--period-end",
                    "2026-11-18",
                    "--dry-run",
                    "--json-out",
                    str(json_out),
                    "--html-out",
                    str(html_out),
                    "--github-output",
                    str(gh_out),
                ]
            )
            self.assertEqual(code, 0)
            parsed = json.loads(json_out.read_text(encoding="utf-8"))
            self.assertEqual(parsed["delivery_status"], "dry_run")
            self.assertTrue(parsed["pii_redacted"])
            self.assertIn("<!DOCTYPE html>", html_out.read_text(encoding="utf-8"))
            gh_lines = gh_out.read_text(encoding="utf-8").splitlines()
            self.assertIn("delivery_status=dry_run", gh_lines)
            self.assertTrue(any(line.startswith("report_summary_json={") for line in gh_lines))

    def test_http_error_raises_runtime_error_and_scrubs_url_query(self) -> None:
        scrubbed = _sanitize_url_for_log("https://generativelanguage.googleapis.com/v1beta/models?key=xyz&foo=1#frag")
        self.assertEqual(scrubbed, "https://generativelanguage.googleapis.com/v1beta/models")

        summary, _ = aggregate_weekly_metrics([], period_end=date(2026, 11, 18))
        prompt = build_llm_prompt(summary, [], pseudonym_id="usr_000000000000")

        def fail_opener(_req: object, timeout: int = 20) -> object:
            raise urllib.error.HTTPError(
                "https://generativelanguage.googleapis.com/v1beta/models?key=secret",
                503,
                "Service Unavailable",
                {},
                io.BytesIO(b"{}"),
            )

        with self.assertRaises(RuntimeError) as ctx:
            generate_llm_insight(
                prompt,
                summary,
                [],
                dry_run=False,
                provider_key="demo",
                opener=fail_opener,
            )
        self.assertIn("HTTP error 503", str(ctx.exception))
        self.assertNotIn("key=secret", str(ctx.exception))

        def bad_status_opener(_req: object, timeout: int = 20) -> _FakeHttpResponse:
            return _FakeHttpResponse({"error": "upstream"}, status=502)

        with self.assertRaises(RuntimeError):
            generate_llm_insight(
                prompt,
                summary,
                [],
                dry_run=False,
                provider_key="demo",
                opener=bad_status_opener,
            )


if __name__ == "__main__":
    unittest.main()
