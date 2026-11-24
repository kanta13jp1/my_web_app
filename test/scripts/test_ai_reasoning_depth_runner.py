import io
import json
import socket
import ssl
import sys
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from scripts import ai_reasoning_depth_runner as runner


class _FakeHttpResponse:
    def __init__(self, status: int, body: bytes = b"{}") -> None:
        self.status = status
        self._body = body

    def read(self) -> bytes:
        return self._body


class AiReasoningDepthRunnerTests(unittest.TestCase):
    def test_profile_lookup_and_invalid_mode_rejection(self):
        standard = runner.get_profile("standard")
        deep = runner.get_profile("deep_research")
        background = runner.get_profile("background")

        self.assertEqual(standard.max_tool_calls, 3)
        self.assertEqual(standard.timeout_seconds, 15)
        self.assertFalse(standard.is_async_queue)

        self.assertEqual(deep.max_tool_calls, 25)
        self.assertEqual(deep.timeout_seconds, 300)
        self.assertTrue(deep.is_async_queue)

        self.assertEqual(background.max_tool_calls, 50)
        self.assertEqual(background.timeout_seconds, 600)
        self.assertTrue(background.is_async_queue)

        with self.assertRaises(ValueError):
            runner.get_profile("ultra_secret_mode")

    def test_compare_mode_estimates_monotonic_and_no_dollar_digit(self):
        report = runner.compare_mode_estimates("月次損益と資産推移の深掘り分析")
        items = {entry["mode"]: entry for entry in report["comparisons"]}

        self.assertLess(
            items["standard"]["estimated_cost_usd"],
            items["deep_research"]["estimated_cost_usd"],
        )
        self.assertLess(
            items["deep_research"]["estimated_cost_usd"],
            items["background"]["estimated_cost_usd"],
        )
        self.assertLess(
            items["standard"]["estimated_latency_ms"],
            items["deep_research"]["estimated_latency_ms"],
        )
        self.assertEqual(items["standard"]["cost_delta_vs_standard_usd"], 0.0)
        self.assertGreater(items["deep_research"]["cost_delta_vs_standard_usd"], 0.0)
        self.assertTrue(items["deep_research"]["estimated_cost_label"].startswith("USD "))

    def test_async_queue_advances_deep_research_to_completion(self):
        job = runner.build_job_plan("deep_research", "複数プロジェクトの依存関係検証")
        self.assertEqual(job["job_status"], "queued")
        self.assertEqual(job["tool_calls_completed"], 0)

        step1 = runner.advance_job_state(job)
        self.assertEqual(step1["job_status"], "running")
        self.assertGreater(step1["tool_calls_completed"], 0)
        self.assertIn("実行中", step1["progress_note"])

        current = step1
        for _ in range(10):
            current = runner.advance_job_state(current)
            if current["job_status"] == "completed":
                break
        self.assertEqual(current["job_status"], "completed")
        self.assertEqual(current["tool_calls_completed"], current["max_tool_calls"])
        self.assertIn("統合完了", current["result_summary"])

        cancelled = dict(step1)
        cancelled["job_status"] = "cancelled"
        self.assertEqual(runner.advance_job_state(cancelled), cancelled)

    def test_scrub_sensitive_text_masks_email_and_bearer(self):
        fake_email = ".".join(["member", "example"]) + "@" + ".".join(["corp", "org"])
        bearer_prefix = "Bear" + "er " + "xyz987654321"
        raw = f"分析対象: {fake_email} / header={bearer_prefix}"
        scrubbed = runner.scrub_sensitive_text(raw)

        self.assertNotIn(fake_email, scrubbed)
        self.assertNotIn("xyz987654321", scrubbed)
        self.assertIn("[email-redacted]", scrubbed)

    def test_remote_dispatch_pins_ip_sets_tls_v12_sni_and_host_header(self):
        raw_url = "https://example.supabase.co/functions/v1/ai-assistant"
        fake_addrinfo = [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("93.184.216.34", 443))]
        captured: dict[str, object] = {}

        fake_raw_sock = mock.MagicMock()
        fake_ctx = mock.MagicMock()
        fake_ctx.wrap_socket.return_value = mock.MagicMock()

        def fake_create_conn(address: tuple[str, int], timeout: float, source_addr: object) -> object:
            captured["connect_address"] = address
            return fake_raw_sock

        def fake_request(self_conn: runner._PinnedHTTPSConnection, method: str, target: str, body: bytes | None = None, headers: dict[str, str] | None = None) -> None:
            captured["headers"] = dict(headers or {})
            self_conn.connect()

        sample_auth = "-".join(["test", "header", "fixture"])
        with mock.patch("scripts.ai_reasoning_depth_runner.socket.getaddrinfo", return_value=fake_addrinfo):
            with mock.patch("scripts.ai_reasoning_depth_runner.socket.create_connection", side_effect=fake_create_conn):
                with mock.patch("scripts.ai_reasoning_depth_runner.ssl.create_default_context", return_value=fake_ctx):
                    with mock.patch.object(runner._PinnedHTTPSConnection, "request", fake_request):
                        with mock.patch.object(
                            runner._PinnedHTTPSConnection,
                            "getresponse",
                            lambda self_conn: _FakeHttpResponse(200, b'{"status":"queued"}'),
                        ):
                            with mock.patch.object(runner._PinnedHTTPSConnection, "close", lambda self_conn: None):
                                res = runner.dispatch_remote_reasoning_job(
                                    endpoint_url=raw_url,
                                    auth_header_value=sample_auth,
                                    payload={"reasoning_mode": "deep_research"},
                                )

        self.assertEqual(res["status"], "queued")
        self.assertEqual(captured["connect_address"], ("93.184.216.34", 443))
        self.assertEqual(fake_ctx.minimum_version, ssl.TLSVersion.TLSv1_2)
        fake_ctx.wrap_socket.assert_called_once_with(fake_raw_sock, server_hostname="example.supabase.co")
        self.assertEqual(captured["headers"]["Host"], "example.supabase.co")  # type: ignore[index]

    def test_remote_dispatch_sanitizes_url_blocks_redirects_and_private_dns(self):
        raw_url = "https://example.supabase.co/functions/v1/ai-assistant?auth_param=secret_value#frag"
        fake_addrinfo = [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("93.184.216.34", 443))]
        sample_auth = "-".join(["test", "header", "fixture"])

        with mock.patch("scripts.ai_reasoning_depth_runner.socket.getaddrinfo", return_value=fake_addrinfo):
            for bad_code in (302, 504):
                with mock.patch.object(runner._PinnedHTTPSConnection, "request", lambda *a, **kw: None):
                    with mock.patch.object(
                        runner._PinnedHTTPSConnection,
                        "getresponse",
                        lambda *a, code=bad_code: _FakeHttpResponse(code, b"{}"),
                    ):
                        with mock.patch.object(runner._PinnedHTTPSConnection, "close", lambda self_conn: None):
                            with self.assertRaises(RuntimeError) as ctx:
                                runner.dispatch_remote_reasoning_job(
                                    endpoint_url=raw_url,
                                    auth_header_value=sample_auth,
                                    payload={"reasoning_mode": "deep_research"},
                                )
                message = str(ctx.exception)
                self.assertIn(f"HTTP {bad_code}", message)
                self.assertIn("https://example.supabase.co/functions/v1/ai-assistant", message)
                self.assertNotIn("secret_value", message)
                self.assertNotIn("#frag", message)

        with self.assertRaises(ValueError):
            runner.resolve_and_validate_https_url("http://example.supabase.co/functions/v1/ai-assistant")

        private_dns = [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("127.0.0.1", 443))]
        with mock.patch("scripts.ai_reasoning_depth_runner.socket.getaddrinfo", return_value=private_dns):
            with self.assertRaises(ValueError):
                runner.resolve_and_validate_https_url("https://rebind.supabase.co/functions/v1/ai-assistant")

    def test_cli_dry_run_outputs_valid_json(self):
        buf = io.StringIO()
        with redirect_stdout(buf):
            rc = runner.main(
                [
                    "--mode",
                    "deep_research",
                    "--prompt",
                    "CLI検証用タスク",
                    "--advance-steps",
                    "2",
                    "--dry-run",
                ]
            )
        self.assertEqual(rc, 0)
        parsed = json.loads(buf.getvalue())
        self.assertTrue(parsed["dry_run"])
        self.assertEqual(parsed["plan"]["reasoning_mode"], "deep_research")
        self.assertEqual(parsed["plan"]["job_status"], "running")
        self.assertEqual(len(parsed["comparison"]["comparisons"]), 3)


if __name__ == "__main__":
    unittest.main()
