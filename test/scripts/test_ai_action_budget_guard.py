#!/usr/bin/env python3
"""Offline unit tests for scripts/ai_action_budget_guard.py (#2609)."""

from __future__ import annotations

from pathlib import Path
import socket
import sys
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
import ai_action_budget_guard as budget_guard


class _FakeHttpResponse:
    def __init__(self, status: int, body: bytes = b"{}") -> None:
        self.status = status
        self._body = body

    def read(self) -> bytes:
        return self._body


class AiActionBudgetGuardTests(unittest.TestCase):
    def test_cost_calculation_and_validation(self) -> None:
        # gemini-2.5-flash: 0.15 in / 0.60 out per 1M
        cost = budget_guard.estimate_action_cost_usd(
            model_id="gemini-2.5-flash",
            prompt_units=1_000_000,
            completion_units=500_000,
        )
        self.assertAlmostEqual(cost, 0.45)

        with self.assertRaises(ValueError):
            budget_guard.estimate_action_cost_usd(
                model_id="gpt-4o",
                prompt_units=-1,
                completion_units=10,
            )

    def test_warning_80_and_auto_pause_100_fail_closed(self) -> None:
        entries_85 = [
            {"action_name": "a1", "model_id": "gpt-4o", "estimated_usd": 42.50, "billing_month": "2026-11"},
            {"action_name": "old", "model_id": "gpt-4o", "estimated_usd": 99.00, "billing_month": "2026-10"},
        ]
        warn_eval = budget_guard.evaluate_monthly_budget(
            ledger_entries=entries_85,
            billing_month="2026-11",
            monthly_usd_cap=50.0,
        )
        self.assertEqual(warn_eval.tier, "warning_80")
        self.assertTrue(warn_eval.warning_80_triggered)
        self.assertFalse(warn_eval.auto_pause_triggered)
        self.assertEqual(warn_eval.exit_code, 0)
        self.assertIsNotNone(budget_guard.build_slack_alert_payload(warn_eval))
        self.assertIsNone(budget_guard.build_github_issue_alert_payload(warn_eval))

        entries_102 = entries_85 + [
            {"action_name": "a2", "model_id": "claude-sonnet-4", "estimated_usd": 8.50, "billing_month": "2026-11"},
        ]
        pause_eval = budget_guard.evaluate_monthly_budget(
            ledger_entries=entries_102,
            billing_month="2026-11",
            monthly_usd_cap=50.0,
        )
        self.assertEqual(pause_eval.tier, "paused_100")
        self.assertTrue(pause_eval.auto_pause_triggered)
        self.assertTrue(pause_eval.effective_paused)
        self.assertEqual(pause_eval.exit_code, 2)
        issue_payload = budget_guard.build_github_issue_alert_payload(pause_eval)
        self.assertIsNotNone(issue_payload)
        self.assertIn("USD 51.0000", str(issue_payload["body"]))

    def test_pre_paused_config_blocks_even_below_cap(self) -> None:
        paused_eval = budget_guard.evaluate_monthly_budget(
            ledger_entries=[{"action_name": "x", "estimated_usd": 1.0, "billing_month": "2026-11"}],
            billing_month="2026-11",
            monthly_usd_cap=50.0,
            pre_paused=True,
        )
        self.assertTrue(paused_eval.effective_paused)
        self.assertEqual(paused_eval.tier, "pre_paused")
        self.assertEqual(paused_eval.exit_code, 2)

    def test_notification_pins_resolved_ip_and_sets_sni_host(self) -> None:
        endpoint = "https://hooks.slack.example/services/test"
        fake_addrinfo = [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("93.184.216.34", 443))]
        captured: dict[str, object] = {}

        fake_raw_sock = mock.MagicMock()
        fake_tls_sock = mock.MagicMock()
        fake_ctx = mock.MagicMock()
        fake_ctx.wrap_socket.return_value = fake_tls_sock

        def fake_create_conn(address: tuple[str, int], timeout: float, source_addr: object) -> object:
            captured["connect_address"] = address
            return fake_raw_sock

        def fake_request(self_conn: budget_guard._PinnedHTTPSConnection, method: str, target: str, body: bytes | None = None, headers: dict[str, str] | None = None) -> None:
            captured["headers"] = dict(headers or {})
            self_conn.connect()

        with mock.patch("ai_action_budget_guard.socket.getaddrinfo", return_value=fake_addrinfo):
            with mock.patch("ai_action_budget_guard.socket.create_connection", side_effect=fake_create_conn):
                with mock.patch("ai_action_budget_guard.ssl.create_default_context", return_value=fake_ctx):
                    with mock.patch.object(budget_guard._PinnedHTTPSConnection, "request", fake_request):
                        with mock.patch.object(
                            budget_guard._PinnedHTTPSConnection,
                            "getresponse",
                            lambda self_conn: _FakeHttpResponse(200),
                        ):
                            with mock.patch.object(budget_guard._PinnedHTTPSConnection, "close", lambda self_conn: None):
                                status = budget_guard.post_json_notification(endpoint, {"text": "alert"})

        self.assertEqual(status, 200)
        self.assertEqual(captured["connect_address"], ("93.184.216.34", 443))
        fake_ctx.wrap_socket.assert_called_once_with(fake_raw_sock, server_hostname="hooks.slack.example")
        self.assertEqual(captured["headers"]["Host"], "hooks.slack.example")  # type: ignore[index]

    def test_notification_http_error_redirect_and_private_dns_rejected(self) -> None:
        endpoint = "https://hooks.slack.example/services/test?sig=must_not_leak"
        fake_addrinfo = [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("93.184.216.34", 443))]
        with mock.patch("ai_action_budget_guard.socket.getaddrinfo", return_value=fake_addrinfo):
            for status_code in (302, 500):
                with mock.patch.object(budget_guard._PinnedHTTPSConnection, "request", lambda *args, **kwargs: None):
                    with mock.patch.object(
                        budget_guard._PinnedHTTPSConnection,
                        "getresponse",
                        lambda *args, code=status_code: _FakeHttpResponse(code),
                    ):
                        with mock.patch.object(budget_guard._PinnedHTTPSConnection, "close", lambda self_conn: None):
                            with self.assertRaises(RuntimeError) as ctx:
                                budget_guard.post_json_notification(endpoint, {"text": "alert"})
                self.assertIn(str(status_code), str(ctx.exception))
                self.assertNotIn("must_not_leak", str(ctx.exception))
                self.assertNotIn("?", str(ctx.exception))

        private_dns = [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("127.0.0.1", 443))]
        with mock.patch("ai_action_budget_guard.socket.getaddrinfo", return_value=private_dns):
            with self.assertRaises(ValueError):
                budget_guard.resolve_and_validate_notification_url("https://rebind.slack.example/hook")


if __name__ == "__main__":
    unittest.main()
