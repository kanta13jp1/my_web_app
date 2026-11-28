import io
import json
import socket
import sys
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from scripts import context_cache_cost_monitor as monitor


class _FakeHttpResponse:
    def __init__(self, status: int, body: bytes = b"{}") -> None:
        self.status = status
        self._body = body

    def read(self) -> bytes:
        return self._body


class ContextCacheCostMonitorTests(unittest.TestCase):
    def test_cached_payload_orders_invariant_prefix_deterministically(self) -> None:
        docs_a = [
            {"doc_id": "doc-b", "title": "B", "content": "Second doc"},
            {"doc_id": "doc-a", "title": "A", "content": "First doc"},
        ]
        docs_b = list(reversed(docs_a))

        payload_1 = monitor.build_cached_prompt_payload(
            provider="anthropic",
            model_id="claude-sonnet-4",
            system_instructions="System guard",
            invariant_documents=docs_a,
            conversation_turns=[{"role": "user", "content": "Turn 1"}],
        )
        payload_2 = monitor.build_cached_prompt_payload(
            provider="anthropic",
            model_id="claude-sonnet-4",
            system_instructions="System guard",
            invariant_documents=docs_b,
            conversation_turns=[
                {"role": "user", "content": "Turn 1"},
                {"role": "user", "content": "Turn 2"},
            ],
        )

        # Prefix must remain byte-for-byte identical even when doc input order reverses.
        self.assertEqual(payload_1["system"], payload_2["system"])
        self.assertEqual(payload_1["system"][-1]["cache_control"], {"type": "ephemeral"})
        self.assertEqual(payload_1["prefix_doc_ids"], ["doc-a", "doc-b"])

        gemini_payload = monitor.build_cached_prompt_payload(
            provider="gemini",
            model_id="gemini-2.5-flash",
            system_instructions="System guard",
            invariant_documents=docs_a,
            conversation_turns=[{"role": "user", "content": "Explain delta"}],
            cached_content_name="cachedContents/project-ctx-123",
        )
        self.assertEqual(gemini_payload["cachedContent"], "cachedContents/project-ctx-123")
        self.assertEqual(len(gemini_payload["contents"]), 1)

    def test_cold_write_vs_warm_read_savings_and_no_dollar_digit(self) -> None:
        cold = monitor.measure_cache_usage(
            request_id="req-cold-1",
            user_id="user-1",
            workflow_key="pr-review",
            model_id="claude-sonnet-4",
            cache_write_tokens=20_000,
            cache_read_tokens=0,
            uncached_input_tokens=500,
            output_tokens=200,
        )
        self.assertFalse(cold["cache_hit"])
        self.assertLess(cold["net_savings_usd"], 0)

        warm = monitor.measure_cache_usage(
            request_id="req-warm-2",
            user_id="user-1",
            workflow_key="pr-review",
            model_id="claude-sonnet-4",
            cache_write_tokens=0,
            cache_read_tokens=20_000,
            uncached_input_tokens=500,
            output_tokens=200,
        )
        self.assertTrue(warm["cache_hit"])
        self.assertGreater(warm["net_savings_usd"], 0)
        self.assertGreater(warm["savings_ratio"], 0.70)
        self.assertEqual(warm["reference_read_multiplier"], 0.1)
        self.assertTrue(warm["actual_cost_label"].startswith("USD "))
        self.assertIn("reference baseline", warm["estimate_disclaimer"])

    def test_extracts_anthropic_and_gemini_usage_metadata(self) -> None:
        a_counts = monitor.extract_provider_cache_tokens(
            "anthropic",
            {
                "cache_creation_input_tokens": 1200,
                "cache_read_input_tokens": 8000,
                "input_tokens": 300,
                "output_tokens": 450,
            },
        )
        self.assertEqual(a_counts, (1200, 8000, 300, 450))

        g_counts = monitor.extract_provider_cache_tokens(
            "gemini",
            {
                "promptTokenCount": 10000,
                "cachedContentTokenCount": 8500,
                "candidatesTokenCount": 320,
            },
        )
        self.assertEqual(g_counts, (0, 8500, 1500, 320))

    def test_workflow_and_user_aggregation(self) -> None:
        r1 = monitor.measure_cache_usage(
            request_id="r1",
            user_id="admin-1",
            workflow_key="daily-brief",
            model_id="claude-sonnet-4",
            cache_write_tokens=0,
            cache_read_tokens=10000,
            uncached_input_tokens=500,
            output_tokens=100,
        )
        r2 = monitor.measure_cache_usage(
            request_id="r2",
            user_id="user-2",
            workflow_key="pr-review",
            model_id="gemini-2.5-flash",
            cache_write_tokens=0,
            cache_read_tokens=5000,
            uncached_input_tokens=200,
            output_tokens=100,
        )
        rollup = monitor.aggregate_usage_by_workflow_and_user([r1, r2])
        self.assertEqual(len(rollup), 2)
        self.assertEqual(rollup[0]["workflow_key"], "daily-brief")
        self.assertGreater(rollup[0]["total_net_savings_usd"], 0)

    def test_pinned_https_post_pins_ip_and_blocks_redirects_and_private_dns(self) -> None:
        endpoint = "https://metrics.example.com/v1/cache-usage?sig=must_not_leak"
        fake_addrinfo = [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("93.184.216.34", 443))]
        captured: dict[str, object] = {}

        fake_raw_sock = mock.MagicMock()
        fake_ctx = mock.MagicMock()
        fake_ctx.wrap_socket.return_value = mock.MagicMock()

        def fake_create_conn(address: tuple[str, int], timeout: float, source_addr: object) -> object:
            captured["connect_address"] = address
            return fake_raw_sock

        def fake_request(self_conn: monitor._PinnedHTTPSConnection, method: str, target: str, body: bytes | None = None, headers: dict[str, str] | None = None) -> None:
            captured["headers"] = dict(headers or {})
            self_conn.connect()

        with mock.patch("scripts.context_cache_cost_monitor.socket.getaddrinfo", return_value=fake_addrinfo):
            with mock.patch("scripts.context_cache_cost_monitor.socket.create_connection", side_effect=fake_create_conn):
                with mock.patch("scripts.context_cache_cost_monitor.ssl.create_default_context", return_value=fake_ctx):
                    with mock.patch.object(monitor._PinnedHTTPSConnection, "request", fake_request):
                        with mock.patch.object(
                            monitor._PinnedHTTPSConnection,
                            "getresponse",
                            lambda self_conn: _FakeHttpResponse(201),
                        ):
                            with mock.patch.object(monitor._PinnedHTTPSConnection, "close", lambda self_conn: None):
                                status = monitor.post_usage_record_pinned(endpoint, {"request_id": "x"})

        self.assertEqual(status, 201)
        self.assertEqual(captured["connect_address"], ("93.184.216.34", 443))
        fake_ctx.wrap_socket.assert_called_once_with(fake_raw_sock, server_hostname="metrics.example.com")
        self.assertEqual(captured["headers"]["Host"], "metrics.example.com")  # type: ignore[index]

        with mock.patch("scripts.context_cache_cost_monitor.socket.getaddrinfo", return_value=fake_addrinfo):
            for bad_code in (302, 502):
                with mock.patch.object(monitor._PinnedHTTPSConnection, "request", lambda *a, **kw: None):
                    with mock.patch.object(
                        monitor._PinnedHTTPSConnection,
                        "getresponse",
                        lambda *a, code=bad_code: _FakeHttpResponse(code),
                    ):
                        with mock.patch.object(monitor._PinnedHTTPSConnection, "close", lambda self_conn: None):
                            with self.assertRaises(RuntimeError) as ctx:
                                monitor.post_usage_record_pinned(endpoint, {"request_id": "x"})
                self.assertIn(str(bad_code), str(ctx.exception))
                self.assertNotIn("must_not_leak", str(ctx.exception))
                self.assertNotIn("?", str(ctx.exception))

        private_dns = [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("10.0.0.12", 443))]
        with mock.patch("scripts.context_cache_cost_monitor.socket.getaddrinfo", return_value=private_dns):
            with self.assertRaises(ValueError):
                monitor.resolve_and_validate_https_url("https://rebind.example.com/hook")

    def test_cli_self_test_outputs_valid_json(self) -> None:
        buf = io.StringIO()
        with redirect_stdout(buf):
            rc = monitor.main(["--self-test", "--dry-run"])
        self.assertEqual(rc, 0)
        parsed = json.loads(buf.getvalue())
        self.assertEqual(parsed["self_test"], "passed")
        self.assertTrue(parsed["dry_run"])
        self.assertTrue(parsed["warm_turn"]["cache_hit"])
        self.assertEqual(parsed["ttl_1h_turn"]["cache_ttl"], "1h")
        self.assertEqual(parsed["recache_over_1h"]["status"], "expired_recache_required")

    def test_1h_ttl_payload_2x_write_latency_savings_and_over_1h_recache(self) -> None:
        docs = [
            {"doc_id": "log-1", "title": "CI Archive", "content": "Long build log trace..."},
        ]
        payload_1h = monitor.build_cached_prompt_payload(
            provider="anthropic",
            model_id="claude-sonnet-4",
            system_instructions="Invariant rules",
            invariant_documents=docs,
            conversation_turns=[{"role": "user", "content": "Continue"}],
            cache_ttl="1h",
        )
        self.assertEqual(payload_1h["cache_ttl"], "1h")
        self.assertEqual(payload_1h["anthropic_beta_header"], monitor.ANTHROPIC_EXTENDED_TTL_BETA_HEADER)
        self.assertEqual(payload_1h["system"][-1]["cache_control"], {"type": "ephemeral", "ttl": "1h"})

        cold_1h = monitor.measure_cache_usage(
            request_id="req-1h-cold",
            user_id="user-1",
            workflow_key="multi-hour-migration",
            model_id="claude-sonnet-4",
            cache_write_tokens=10_000,
            cache_read_tokens=0,
            uncached_input_tokens=200,
            output_tokens=100,
            cache_ttl="1h",
            latency_ms=2000.0,
            baseline_latency_ms=2000.0,
        )
        self.assertEqual(cold_1h["cache_write_multiplier"], 2.0)
        self.assertEqual(cold_1h["rate_card_version"], monitor.RATE_CARD_1H_VERSION)

        warm_1h = monitor.measure_cache_usage(
            request_id="req-1h-warm",
            user_id="user-1",
            workflow_key="multi-hour-migration",
            model_id="claude-sonnet-4",
            cache_write_tokens=0,
            cache_read_tokens=10_000,
            uncached_input_tokens=200,
            output_tokens=100,
            cache_ttl="1h",
            latency_ms=400.0,
            baseline_latency_ms=2000.0,
        )
        self.assertEqual(warm_1h["latency_saved_ms"], 1600.0)
        self.assertEqual(warm_1h["latency_reduction_ratio"], 0.8)

        summary = monitor.aggregate_usage_by_workflow_and_user([cold_1h, warm_1h])
        self.assertEqual(summary[0]["ttl_1h_count"], 2)
        self.assertEqual(summary[0]["avg_latency_ms"], 1200.0)
        self.assertEqual(summary[0]["avg_latency_reduction_ratio"], 0.4)

        recache = monitor.plan_long_running_recache(
            model_id="claude-sonnet-4",
            session_started_at="2026-11-25T08:00:00Z",
            last_refreshed_at="2026-11-25T08:00:00Z",
            now_iso="2026-11-25T09:10:00Z",
            recache_seq=2,
            system_instructions="Invariant rules",
            invariant_documents=docs,
            conversation_summary="Completed migration step 1-3.",
            completed_steps=["step1", "step2", "step3"],
            pending_step="step4_verify",
        )
        self.assertEqual(recache["status"], "expired_recache_required")
        self.assertTrue(recache["exceeded_one_hour_task"])
        self.assertEqual(recache["recache_seq"], 3)
        self.assertEqual(
            recache["payload"]["system"][-1]["cache_control"],
            {"type": "ephemeral", "ttl": "1h"},
        )


if __name__ == "__main__":
    unittest.main()
