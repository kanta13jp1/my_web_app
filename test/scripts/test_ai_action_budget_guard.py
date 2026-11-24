#!/usr/bin/env python3
"""Offline unit tests for scripts/ai_action_budget_guard.py (#2609)."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re
import socket
import sys
import unittest
from unittest import mock

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "scripts"))
import ai_action_budget_guard as budget_guard

_BEGIN_ATOMIC = b"ATOMIC"
_END_ATOMIC = b"END"
_MIGRATION_PATH = (
    _REPO_ROOT / "supabase" / "migrations" / "20261124002300_create_ai_action_budget_ledger.sql"
)
_REPOSITORY_PATH = (
    _REPO_ROOT / "lib" / "features" / "ai_action_budget" / "data" / "supabase_ai_action_budget_repository.dart"
)


class _SqlState:
    """Base FSM state mirroring supabase/cli v2.84.2 pkg/parser/state.go."""

    name = "unknown"

    def next(self, ch: str, data: bytes) -> _SqlState | None:
        return self


class _ReadyState(_SqlState):
    name = "ready"

    def next(self, ch: str, data: bytes) -> _SqlState | None:
        if ch == "$":
            offset = len(data) - len(ch.encode("utf-8"))
            return _TagState(offset=offset)
        if ch in ("'", '"'):
            return _QuoteState(delimiter=ch)
        if ch == "-":
            return _CommentState()
        if ch == "/":
            return _BlockState()
        if ch == "\\":
            return _EscapeState()
        if ch == ";":
            return None
        if ch == "(":
            return _AtomicState(prev=self, delimiter=b")")
        if ch in ("c", "C"):
            offset = len(data) - len(_BEGIN_ATOMIC)
            if offset >= 0 and data[offset:].lower() == b"atomic":
                return _AtomicState(prev=self, delimiter=_END_ATOMIC)
        return self


class _CommentState(_SqlState):
    name = "comment"

    def next(self, ch: str, data: bytes) -> _SqlState | None:
        if ch == "-":
            return _DollarState(delimiter=b"\n")
        return _ReadyState().next(ch, data)


@dataclass
class _BlockState(_SqlState):
    depth: int = 0
    name: str = "block"

    def next(self, ch: str, data: bytes) -> _SqlState | None:
        window = data[-2:]
        if window == b"/*":
            self.depth += 1
            return self
        if self.depth == 0:
            return _ReadyState().next(ch, data)
        if window == b"*/":
            self.depth -= 1
            if self.depth == 0:
                return _ReadyState()
        return self


@dataclass
class _QuoteState(_SqlState):
    delimiter: str
    escape: bool = False
    name: str = "quote"

    def next(self, ch: str, data: bytes) -> _SqlState | None:
        if self.escape:
            if ch == self.delimiter:
                self.escape = False
                return self
            return _ReadyState().next(ch, data)
        if ch == self.delimiter:
            self.escape = True
        return self


@dataclass
class _DollarState(_SqlState):
    delimiter: bytes
    name: str = "dollar"

    def next(self, ch: str, data: bytes) -> _SqlState | None:
        window = data[-len(self.delimiter) :]
        if window == self.delimiter:
            return _ReadyState()
        return self


@dataclass
class _TagState(_SqlState):
    offset: int
    name: str = "tag"

    def next(self, ch: str, data: bytes) -> _SqlState | None:
        if ch == "$":
            return _DollarState(delimiter=bytes(data[self.offset :]))
        if ch.isalpha() or ch.isdigit() or ch == "_":
            return self
        return _ReadyState().next(ch, data)


class _EscapeState(_SqlState):
    name = "escape"

    def next(self, ch: str, data: bytes) -> _SqlState | None:
        return _ReadyState()


@dataclass
class _AtomicState(_SqlState):
    prev: _SqlState
    delimiter: bytes
    name: str = "atomic"

    def next(self, ch: str, data: bytes) -> _SqlState | None:
        curr = self.prev.next(ch, data)
        if curr is not None:
            self.prev = curr
        if isinstance(self.prev, _ReadyState):
            window = data[-len(self.delimiter) :]
            if len(window) == len(self.delimiter) and window.lower() == self.delimiter.lower():
                return _ReadyState()
        return self


def _is_active_ready_state(state: _SqlState) -> bool:
    while isinstance(state, _AtomicState):
        state = state.prev
    return isinstance(state, _ReadyState)


def _split_supabase_sql(sql_text: str) -> tuple[list[str], str, int]:
    """Split SQL using supabase/cli v2.84.2 pkg/parser/state.go and token.go rules.

    Returns (statements, end_state_name, unquoted_atomic_hits).
    """
    state: _SqlState = _ReadyState()
    token_bytes = bytearray()
    statements: list[str] = []
    unquoted_atomic_hits = 0

    for ch in sql_text:
        token_bytes.extend(ch.encode("utf-8"))
        # Mirror ReadyState.Next case 'c'/'C' (state.go:46-52) in active unquoted SQL.
        if _is_active_ready_state(state) and ch in ("c", "C") and token_bytes[-6:].lower() == b"atomic":
            unquoted_atomic_hits += 1

        next_state = state.next(ch, bytes(token_bytes))
        if next_state is None:
            trimmed = token_bytes.decode("utf-8").rstrip(";").strip()
            if trimmed:
                statements.append(trimmed)
            token_bytes.clear()
            state = _ReadyState()
        else:
            state = next_state

    if token_bytes:
        trimmed = token_bytes.decode("utf-8").rstrip(";").strip()
        if trimmed:
            statements.append(trimmed)

    return statements, state.name, unquoted_atomic_hits


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

    def test_migration_and_repository_avoid_supabase_atomic_parser_bug(self) -> None:
        migration_sql = _MIGRATION_PATH.read_text(encoding="utf-8")
        statements, end_state, unquoted_atomic_hits = _split_supabase_sql(migration_sql)

        self.assertEqual(end_state, "ready")
        self.assertEqual(unquoted_atomic_hits, 0)
        self.assertEqual(len(statements), 37)

        expected_markers = (
            'drop function if exists public."record_ai_action_usage_atomic"',
            "create or replace function public.record_ai_action_usage_tx",
            "revoke all on function public.record_ai_action_usage_tx",
            "grant execute on function public.record_ai_action_usage_tx",
            "comment on table public.ai_action_budget_configs",
            "comment on table public.ai_action_budget_ledger",
        )
        matched_indices: list[int] = []
        for marker in expected_markers:
            indices = [idx for idx, stmt in enumerate(statements) if marker in stmt.lower()]
            self.assertEqual(len(indices), 1, f"Expected exactly 1 statement matching {marker!r}")
            matched_indices.append(indices[0])

        self.assertEqual(len(set(matched_indices)), len(expected_markers))
        self.assertEqual(matched_indices, sorted(matched_indices))

        for stmt in statements:
            if "create or replace function" in stmt.lower():
                self.assertIsNone(re.search(r"atomic", stmt, re.IGNORECASE))

        broken_sql = migration_sql.replace(
            'public."record_ai_action_usage_atomic"',
            "public.record_ai_action_usage_atomic",
            1,
        )
        broken_statements, broken_end_state, broken_hits = _split_supabase_sql(broken_sql)
        self.assertEqual(broken_end_state, "atomic")
        self.assertEqual(broken_hits, 1)
        self.assertLess(len(broken_statements), len(statements))

        dart_source = _REPOSITORY_PATH.read_text(encoding="utf-8")
        self.assertRegex(dart_source, r"\.rpc\(\s*'record_ai_action_usage_tx'")
        self.assertNotIn("record_ai_action_usage_atomic", dart_source)


if __name__ == "__main__":
    unittest.main()
