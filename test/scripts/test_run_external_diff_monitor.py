#!/usr/bin/env python3
"""Unit tests for scripts/run_external_diff_monitor.py (#2740)."""

from __future__ import annotations

import json
from pathlib import Path
import sys
import unittest

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "scripts"))

import run_external_diff_monitor as mod  # noqa: E402


class _FakeHttpResponse:
    def __init__(self, status: int, body: dict[str, object]) -> None:
        self.status = status
        self._raw = json.dumps(body).encode("utf-8")

    def read(self) -> bytes:
        return self._raw

    def __enter__(self) -> "_FakeHttpResponse":
        return self

    def __exit__(self, *_args: object) -> None:
        return None


class ExternalDiffMonitorTests(unittest.TestCase):
    def test_structured_diff_and_pct_threshold(self) -> None:
        prev = {"kpi": {"revenue": 1000}, "state": "ok"}
        curr = {"kpi": {"revenue": 1350}, "state": "warn", "note": "spike"}
        diffs = mod.compute_structured_diff(prev, curr)
        self.assertEqual(len(diffs), 3)

        rule = mod.TriggerRule(
            rule_id="r1",
            rule_name="Revenue delta",
            source_key="stripe_daily",
            field_path="kpi.revenue",
            operator="pct_change_gte",
            threshold_value="25",
            severity="critical",
        )
        matches = mod.evaluate_diff_rules([rule], "stripe_daily", diffs, curr)
        self.assertEqual(len(matches), 1)
        self.assertIn("35.0%", matches[0]["reason"])

    def test_email_template_escapes_html_injection(self) -> None:
        rule = mod.TriggerRule(
            rule_id="r2",
            rule_name="<xss>",
            source_key="webhook_src",
            field_path="msg",
            operator="contains",
            threshold_value="alert",
            severity="warning",
        )
        diffs = mod.compute_structured_diff({"msg": "ok"}, {"msg": "<script>1</script>"})
        rendered = mod.format_email_alert_payload(
            "webhook_src", rule, "matched", diffs, "2026-11-25T11:00:00Z"
        )
        self.assertIn("&lt;script&gt;1&lt;/script&gt;", rendered["html"])
        self.assertIn("&lt;xss&gt;", rendered["html"])

    def test_dry_run_makes_zero_http_calls(self) -> None:
        called = False

        def fail_opener(*_args: object, **_kwargs: object) -> object:
            nonlocal called
            called = True
            raise AssertionError("Should not invoke HTTP in dry-run")

        res = mod.dispatch_batch_scan_http(
            items=[{"user_id": "u1", "source_key": "feed", "payload": {"x": 1}}],
            endpoint_url="https://example.test/core-hub",
            auth_header_value="",
            dry_run=True,
            opener=fail_opener,
        )
        self.assertFalse(called)
        self.assertFalse(res["dispatched"])
        self.assertEqual(res["mode"], "dry_run")

    def test_live_dispatch_with_mocked_transport(self) -> None:
        captured: dict[str, object] = {}

        def mock_opener(req: object, timeout: int = 20) -> _FakeHttpResponse:
            captured["url"] = getattr(req, "full_url", "")
            captured["timeout"] = timeout
            return _FakeHttpResponse(200, {"success": True, "processed": 1})

        res = mod.dispatch_batch_scan_http(
            items=[{"user_id": "u1", "source_key": "feed", "payload": {"x": 2}}],
            endpoint_url="https://example.test/core-hub",
            auth_header_value="mock-cred",
            dry_run=False,
            opener=mock_opener,
        )
        self.assertTrue(res["dispatched"])
        self.assertEqual(res["status_code"], 200)
        self.assertEqual(captured["url"], "https://example.test/core-hub")

    def test_self_test_succeeds(self) -> None:
        self.assertEqual(mod.run_self_test(), 0)


if __name__ == "__main__":
    unittest.main()
