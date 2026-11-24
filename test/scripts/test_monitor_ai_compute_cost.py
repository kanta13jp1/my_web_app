#!/usr/bin/env python3
"""Offline unit tests for scripts/monitor_ai_compute_cost.py (#2658)."""

from __future__ import annotations

import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import monitor_ai_compute_cost as mod  # noqa: E402


class MonitorAiComputeCostTest(unittest.TestCase):
    def test_rate_card_estimation_scales_with_profile_tokens_and_latency(self) -> None:
        cpu_ev = mod.ComputeTelemetryEvent(
            user_id="u1",
            tool_name="ai-hub",
            gpu_profile="cpu-fallback",
            model_id="gemini-2.5-flash",
            input_tokens=1000,
            output_tokens=1000,
            api_request_count=1,
            latency_ms=1000,
            recorded_date="2026-11-24",
        )
        h100_ev = mod.ComputeTelemetryEvent(
            user_id="u1",
            tool_name="ai-hub",
            gpu_profile="h100-cluster",
            model_id="claude-sonnet",
            input_tokens=1000,
            output_tokens=1000,
            api_request_count=1,
            latency_ms=1000,
            recorded_date="2026-11-24",
        )
        self.assertGreater(
            mod.estimate_event_cost_usd(h100_ev),
            mod.estimate_event_cost_usd(cpu_ev),
        )

    def test_daily_monthly_and_user_utilization_aggregation(self) -> None:
        report = mod.evaluate_compute_cost_report(
            daily_threshold_usd=50.0,
            monthly_threshold_usd=500.0,
        )
        self.assertEqual(report["status"], "ok")
        self.assertFalse(report["threshold_alert_triggered"])
        self.assertEqual(report["total_requests"], 6)
        self.assertIn("2026-11-24", report["daily_breakdown"])
        self.assertIn("2026-11", report["monthly_breakdown"])
        self.assertEqual(len(report["user_utilization"]), 2)
        self.assertIn("USD", str(report["disclaimer"]))

    def test_threshold_alert_triggers_when_daily_or_monthly_exceeded(self) -> None:
        daily_breach = mod.evaluate_compute_cost_report(
            daily_threshold_usd=0.001,
            monthly_threshold_usd=500.0,
        )
        self.assertTrue(daily_breach["daily_exceeded"])
        self.assertTrue(daily_breach["threshold_alert_triggered"])
        self.assertEqual(daily_breach["status"], "alert")

        monthly_breach = mod.evaluate_compute_cost_report(
            daily_threshold_usd=0.005,
            monthly_threshold_usd=0.01,
        )
        self.assertTrue(monthly_breach["monthly_exceeded"])
        self.assertTrue(monthly_breach["threshold_alert_triggered"])

    def test_invalid_threshold_rejected(self) -> None:
        with self.assertRaises(ValueError):
            mod.evaluate_compute_cost_report(daily_threshold_usd=0.0)
        with self.assertRaises(ValueError):
            mod.evaluate_compute_cost_report(
                daily_threshold_usd=100.0,
                monthly_threshold_usd=50.0,
            )

    def test_pinned_https_rejects_ssrf_and_handles_errors_safely(self) -> None:
        with self.assertRaises(ValueError):
            mod.validate_and_resolve_https_url("http://example.com/alert")

        for private_ip in ("127.0.0.1", "172.16.0.1", "100.64.5.5", "::ffff:127.0.0.1"):
            fake_info = [(2, 1, 6, "", (private_ip, 443))]
            with mock.patch("monitor_ai_compute_cost.socket.getaddrinfo", return_value=fake_info):
                with self.assertRaises(ValueError):
                    mod.validate_and_resolve_https_url("https://ops.example.com/hook?key=secret999")

        class _FakeResp:
            def __init__(self, status: int, body: str) -> None:
                self.status = status
                self._body = body.encode("utf-8")

            def read(self) -> bytes:
                return self._body

        public_info = [(2, 1, 6, "", ("93.184.216.34", 443))]
        with mock.patch("monitor_ai_compute_cost.socket.getaddrinfo", return_value=public_info):
            with mock.patch("monitor_ai_compute_cost._PinnedHTTPSConnection") as conn_cls:
                conn_inst = conn_cls.return_value
                conn_inst.getresponse.return_value = _FakeResp(301, "")
                with self.assertRaises(RuntimeError) as ctx301:
                    mod.post_json_pinned_https(
                        "https://ops.example.com/hook?key=secret999",
                        {"alert": True},
                    )
                self.assertNotIn("secret999", str(ctx301.exception))

                conn_inst.getresponse.return_value = _FakeResp(502, "bad gateway")
                with self.assertRaises(RuntimeError) as ctx502:
                    mod.post_json_pinned_https(
                        "https://ops.example.com/hook?key=secret999",
                        {"alert": True},
                    )
                self.assertNotIn("secret999", str(ctx502.exception))

    def test_cli_self_test_and_dry_run_outputs(self) -> None:
        self.assertEqual(mod.main(["--self-test"]), 0)
        with tempfile.TemporaryDirectory() as tmp:
            json_path = Path(tmp) / "cost.json"
            md_path = Path(tmp) / "cost.md"
            gh_path = Path(tmp) / "gh_out.txt"
            rc = mod.main(
                [
                    "--dry-run",
                    "--json-out",
                    str(json_path),
                    "--markdown-out",
                    str(md_path),
                    "--github-output",
                    str(gh_path),
                ]
            )
            self.assertEqual(rc, 0)
            loaded = json.loads(json_path.read_text(encoding="utf-8"))
            self.assertEqual(loaded["status"], "ok")
            self.assertIn("threshold_alert_triggered=false", gh_path.read_text(encoding="utf-8"))
            self.assertIn("Mode: `dry-run`", md_path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
