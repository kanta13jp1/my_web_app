"""Unit tests for scripts/did_mcp_agent_bridge.py (Issue #2662)."""

import importlib.util
import pathlib
import sys
import unittest

SCRIPT_PATH = (
    pathlib.Path(__file__).resolve().parents[2]
    / "scripts"
    / "did_mcp_agent_bridge.py"
)
SPEC = importlib.util.spec_from_file_location("did_mcp_agent_bridge", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
BRIDGE = importlib.util.module_from_spec(SPEC)
sys.modules["did_mcp_agent_bridge"] = BRIDGE
SPEC.loader.exec_module(BRIDGE)


class DidMcpAgentBridgeTest(unittest.TestCase):
    def test_prompt_routes_to_all_supported_mcp_tools(self) -> None:
        docs_call = BRIDGE.prompt_to_mcp_invocation("Inspect D-ID MCP endpoint docs")
        self.assertEqual(docs_call["params"]["name"], "did_mcp_docs_lookup")

        rag_call = BRIDGE.prompt_to_mcp_invocation("RAG knowledge base lookup for onboarding")
        self.assertEqual(rag_call["params"]["name"], "did_rag_query")

        chat_call = BRIDGE.prompt_to_mcp_invocation("Send interactive agent chat greeting")
        self.assertEqual(chat_call["params"]["name"], "did_agent_chat")

        talk_call = BRIDGE.prompt_to_mcp_invocation("新機能紹介動画のナレーションを作成")
        self.assertEqual(talk_call["params"]["name"], "did_generate_talk_video")
        self.assertTrue(talk_call["params"]["arguments"]["dry_run"])

    def test_empty_prompt_rejected(self) -> None:
        with self.assertRaises(ValueError):
            BRIDGE.prompt_to_mcp_invocation("   ")

    def test_evaluate_proxy_events_triggers_rate_limit_and_upstream_alerts(self) -> None:
        summary = BRIDGE.evaluate_proxy_events(
            [
                {"tool_name": "did_generate_talk_video", "status": "rate_limited", "http_status": 429},
                {"tool_name": "did_agent_chat", "status": "failed", "http_status": 502},
                {"tool_name": "did_mcp_docs_lookup", "status": "succeeded", "http_status": 200},
            ]
        )
        self.assertTrue(summary["should_alert"])
        self.assertEqual(summary["total_events"], 3)
        self.assertEqual(summary["rate_limited_count"], 1)
        self.assertEqual(summary["failed_count"], 1)
        self.assertEqual(summary["alert_count"], 2)

    def test_ssrf_ip_block_list_handles_cgnat_and_ipv4_mapped_ipv6(self) -> None:
        for blocked in (
            "127.0.0.1",
            "10.0.0.1",
            "169.254.169.254",
            "100.64.0.1",
            "100.127.255.254",
            "::1",
            "::ffff:127.0.0.1",
            "::ffff:10.0.0.8",
            "::ffff:100.64.0.5",
            "not-an-ip",
        ):
            self.assertTrue(BRIDGE._is_blocked_ip(blocked), msg=f"expected blocked: {blocked}")

        self.assertFalse(BRIDGE._is_blocked_ip("8.8.8.8"))

    def test_webhook_url_validation_rejects_http_credentials_and_ip_literals(self) -> None:
        for bad_url in (
            "http://hooks.slack.com/services/a/b/c",
            "https://user:pass@hooks.slack.com/services/a/b/c",
            "https://localhost/hook",
            "https://169.254.169.254/latest/meta-data",
        ):
            with self.assertRaises(ValueError):
                BRIDGE._validate_https_webhook_url(bad_url)


if __name__ == "__main__":
    unittest.main()
