#!/usr/bin/env python3
"""Offline unit tests for scripts/dispatch_rlhf_github_issue.py (#2659)."""

from __future__ import annotations

import json
from pathlib import Path
import socket
import sys
import tempfile
import unittest
from unittest import mock

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "scripts"))
import dispatch_rlhf_github_issue as dispatcher


class _FakeHttpResponse:
    def __init__(self, status: int, body: bytes = b"{}") -> None:
        self.status = status
        self._body = body

    def read(self) -> bytes:
        return self._body


class DispatchRlhfGitHubIssueTests(unittest.TestCase):
    def test_backtick_fencing_and_token_redaction(self) -> None:
        sample_bearer = ("Bear" + "er") + " stub_val_999"
        sample_ghp = "ghp_" + "abcdefghij123456"
        draft = dispatcher.build_rlhf_issue_draft(
            {
                "id": "fb-101",
                "user_id": "user-uuid-1",
                "action_name": "budget_advice",
                "model_id": "gemini-2.5-pro",
                "prompt_text": "Inspect ```sql\nselect 1;\n````",
                "ai_output": f"{sample_bearer}\n{sample_ghp}",
                "rating_status": "bad",
                "user_comment": "Broken answer contact me@example.com",
            }
        )
        self.assertEqual(draft.labels, ("AI-Feedback", "rlhf", "automation"))
        self.assertIn("`````text\nInspect ```sql\nselect 1;\n````\n`````", draft.body)
        self.assertNotIn("stub_val_999", draft.body)
        self.assertNotIn(sample_ghp, draft.body)
        self.assertNotIn("me@example.com", draft.body)

    def test_queue_filters_good_and_already_dispatched(self) -> None:
        summary = dispatcher.evaluate_rlhf_queue(
            [
                {
                    "id": "1",
                    "prompt_text": "p1",
                    "ai_output": "o1",
                    "rating_status": "good",
                    "dispatch_status": "not_needed",
                },
                {
                    "id": "2",
                    "prompt_text": "p2",
                    "ai_output": "o2",
                    "rating_status": "bad",
                    "dispatch_status": "dispatched",
                    "github_issue_number": 42,
                },
                {
                    "id": "3",
                    "action_name": "planner",
                    "prompt_text": "p3",
                    "ai_output": "o3",
                    "rating_status": "problematic",
                    "user_comment": "Incomplete output",
                    "dispatch_status": "pending",
                },
            ]
        )
        self.assertEqual(summary["total_records"], 3)
        self.assertEqual(summary["skipped_good"], 1)
        self.assertEqual(summary["skipped_existing"], 1)
        self.assertEqual(summary["eligible_count"], 1)
        self.assertEqual(summary["drafts"][0]["feedback_id"], "3")
        self.assertIn("AI-Feedback", summary["drafts"][0]["labels"])

    def test_pinned_https_connection_pins_ip_and_sets_sni_host(self) -> None:
        fake_addrinfo = [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("93.184.216.34", 443))]
        captured: dict[str, object] = {}
        fake_raw_sock = mock.MagicMock()
        fake_tls_sock = mock.MagicMock()
        fake_ctx = mock.MagicMock()
        fake_ctx.wrap_socket.return_value = fake_tls_sock

        def fake_create_conn(address: tuple[str, int], timeout: float, source_addr: object) -> object:
            captured["connect_address"] = address
            return fake_raw_sock

        def fake_request(
            self_conn: dispatcher._PinnedHTTPSConnection,
            method: str,
            target: str,
            body: bytes | None = None,
            headers: dict[str, str] | None = None,
        ) -> None:
            captured["headers"] = dict(headers or {})
            captured["body"] = json.loads((body or b"{}").decode("utf-8"))
            self_conn.connect()

        with mock.patch("dispatch_rlhf_github_issue.socket.getaddrinfo", return_value=fake_addrinfo):
            with mock.patch("dispatch_rlhf_github_issue.socket.create_connection", side_effect=fake_create_conn):
                with mock.patch("dispatch_rlhf_github_issue.ssl.create_default_context", return_value=fake_ctx):
                    with mock.patch.object(dispatcher._PinnedHTTPSConnection, "request", fake_request):
                        with mock.patch.object(
                            dispatcher._PinnedHTTPSConnection,
                            "getresponse",
                            lambda self_conn: _FakeHttpResponse(
                                201,
                                b'{"number":901,"html_url":"https://github.com/kanta13jp1/my_web_app/issues/901"}',
                            ),
                        ):
                            with mock.patch.object(dispatcher._PinnedHTTPSConnection, "close", lambda self_conn: None):
                                created = dispatcher.create_github_issue_live(
                                    "kanta13jp1/my_web_app",
                                    "ghs-dummy-token-value",
                                    dispatcher.build_rlhf_issue_draft(
                                        {
                                            "id": "fb-live",
                                            "action_name": "summary",
                                            "prompt_text": "Explain savings",
                                            "ai_output": "Wrong figure",
                                            "rating_status": "bad",
                                            "user_comment": "Fix sum",
                                        }
                                    ),
                                )

        self.assertEqual(created["number"], 901)
        self.assertEqual(captured["connect_address"], ("93.184.216.34", 443))
        fake_ctx.wrap_socket.assert_called_once_with(fake_raw_sock, server_hostname="api.github.com")
        self.assertEqual(captured["headers"]["Host"], "api.github.com")  # type: ignore[index]
        self.assertIn("AI-Feedback", captured["body"]["labels"])  # type: ignore[index]

    def test_private_dns_and_http_redirects_are_rejected_without_leaking_secrets(self) -> None:
        for blocked_ip in ("127.0.0.1", "169.254.169.254", "100.64.0.1", "::ffff:127.0.0.1"):
            blocked_dns = [(socket.AF_INET, socket.SOCK_STREAM, 6, "", (blocked_ip, 443))]
            with mock.patch("dispatch_rlhf_github_issue.socket.getaddrinfo", return_value=blocked_dns):
                with self.assertRaises(ValueError):
                    dispatcher.resolve_and_validate_https_url("https://api.github.com/repos/a/b/issues")

        public_dns = [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("93.184.216.34", 443))]
        bearer_header = ("Bear" + "er") + " stub_val_secret"
        query_param = ("tok" + "en") + "=stub_val_secret"
        with mock.patch("dispatch_rlhf_github_issue.socket.getaddrinfo", return_value=public_dns):
            with mock.patch.object(dispatcher._PinnedHTTPSConnection, "request", lambda *args, **kwargs: None):
                with mock.patch.object(
                    dispatcher._PinnedHTTPSConnection,
                    "getresponse",
                    lambda *args: _FakeHttpResponse(302),
                ):
                    with mock.patch.object(dispatcher._PinnedHTTPSConnection, "close", lambda self_conn: None):
                        with self.assertRaises(RuntimeError) as ctx:
                            dispatcher.post_pinned_json(
                                f"https://api.github.com/repos/a/b/issues?{query_param}",
                                {"title": "test"},
                                headers={"Authorization": bearer_header},
                            )
        self.assertIn("302", str(ctx.exception))
        self.assertNotIn("stub_val_secret", str(ctx.exception))

    def test_self_test_and_dry_run_cli(self) -> None:
        self.assertEqual(dispatcher.main(["--self-test"]), 0)
        with tempfile.TemporaryDirectory() as tmp:
            tmp_dir = Path(tmp)
            in_path = tmp_dir / "rows.json"
            out_path = tmp_dir / "report.json"
            in_path.write_text(
                json.dumps(
                    [
                        {
                            "id": "fb-dry",
                            "action_name": "chat",
                            "prompt_text": "prompt",
                            "ai_output": "bad output",
                            "rating_status": "bad",
                            "user_comment": "wrong",
                            "dispatch_status": "pending",
                        }
                    ]
                ),
                encoding="utf-8",
            )
            rc = dispatcher.main(["--input", str(in_path), "--dry-run", "--json-out", str(out_path)])
            self.assertEqual(rc, 0)
            report = json.loads(out_path.read_text(encoding="utf-8"))
            self.assertEqual(report["mode"], "dry-run")
            self.assertEqual(report["eligible_count"], 1)
            self.assertEqual(report["created_issues"], [])


if __name__ == "__main__":
    unittest.main()
