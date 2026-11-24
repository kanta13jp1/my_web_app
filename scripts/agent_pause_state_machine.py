#!/usr/bin/env python3
"""Agent checkpoint & lossless pause/resume state machine (#2616).

Complements scripts/evaluate_quota_thresholds.py (#2612) by managing per-run
lossless state snapshots (running -> warning_90 -> paused_lossless -> resumed /
failed), 90% immediate early-warning emission (Slack + GitHub Issue payloads),
and silent-pause protection whenever quota/credits exhaust mid-run.
"""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
import hashlib
import http.client
import ipaddress
import json
import os
from pathlib import Path
import socket
import ssl
import sys
from typing import Any
import urllib.parse

DEFAULT_WARNING_90_THRESHOLD_PCT = 90.0
PAUSE_THRESHOLD_PCT = 100.0
DEFAULT_REST_BASE_URL = "https://smmkxxavexumewbfaqpy.supabase.co/rest/v1"
VALID_PAUSE_STATUSES: tuple[str, ...] = (
    "running",
    "warning_90",
    "paused_lossless",
    "resumed",
    "failed",
)

_ALLOWED_TRANSITIONS: dict[str, frozenset[str]] = {
    "running": frozenset({"running", "warning_90", "paused_lossless", "failed"}),
    "warning_90": frozenset({"warning_90", "paused_lossless", "failed"}),
    "paused_lossless": frozenset({"paused_lossless", "resumed", "failed"}),
    "resumed": frozenset({"resumed", "running", "warning_90", "paused_lossless", "failed"}),
    "failed": frozenset({"failed"}),
}


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def compute_snapshot_sha256(snapshot: dict[str, Any]) -> str:
    """Compute a deterministic SHA-256 digest excluding any prior digest field."""
    material = {k: v for k, v in snapshot.items() if k != "snapshot_sha256"}
    canonical = json.dumps(
        material,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    )
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def build_lossless_snapshot(
    *,
    run_key: str,
    agent_name: str,
    checkpoint_seq: int,
    pending_step: str,
    cursor_payload: dict[str, Any] | None = None,
    completed_items: list[str] | None = None,
    captured_at: str | None = None,
    reason: str = "checkpoint_saved",
) -> dict[str, Any]:
    """Serialize an atomic, SHA-256 checksummed state snapshot before pausing."""
    clean_run_key = run_key.strip()
    clean_agent = agent_name.strip()
    if not clean_run_key:
        raise ValueError("run_key must not be empty")
    if not clean_agent:
        raise ValueError("agent_name must not be empty")
    if checkpoint_seq < 1:
        raise ValueError("checkpoint_seq must be >= 1")

    snapshot: dict[str, Any] = {
        "run_key": clean_run_key,
        "agent_name": clean_agent,
        "checkpoint_seq": checkpoint_seq,
        "pending_step": pending_step.strip() or "awaiting_resume",
        "cursor_payload": dict(cursor_payload or {}),
        "completed_items": list(completed_items or []),
        "reason": reason,
        "captured_at": captured_at or utc_now_iso(),
    }
    snapshot["snapshot_sha256"] = compute_snapshot_sha256(snapshot)
    return snapshot


def verify_lossless_snapshot(snapshot: dict[str, Any]) -> bool:
    """Verify snapshot integrity hash to prevent silent corruption on resume."""
    expected = str(snapshot.get("snapshot_sha256") or "").strip()
    if not expected:
        return False
    actual = compute_snapshot_sha256(snapshot)
    return actual == expected


@dataclass(frozen=True)
class AgentCheckpointState:
    run_key: str
    agent_name: str
    checkpoint_seq: int = 1
    pause_status: str = "running"
    usage_ratio_pct: float = 0.0
    warning_90_threshold_pct: float = DEFAULT_WARNING_90_THRESHOLD_PCT
    warning_90_sent: bool = False
    silent_pause_alerted: bool = False
    state_snapshot: dict[str, Any] = field(default_factory=dict)
    resumed_by: str | None = None
    resumed_at: str | None = None
    updated_at: str = field(default_factory=utc_now_iso)

    def __post_init__(self) -> None:
        if self.pause_status not in VALID_PAUSE_STATUSES:
            raise ValueError(f"Unsupported pause_status: {self.pause_status}")
        if self.checkpoint_seq < 1:
            raise ValueError("checkpoint_seq must be >= 1")
        if not (50.0 <= self.warning_90_threshold_pct <= 99.0):
            raise ValueError("warning_90_threshold_pct must be between 50 and 99")

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True)
class TransitionDecision:
    previous_status: str
    next_state: AgentCheckpointState
    should_emit_warning_90: bool
    should_emit_silent_pause_alert: bool
    slack_payload: dict[str, Any] | None
    github_issue_payload: dict[str, Any] | None
    decision_reason: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "previous_status": self.previous_status,
            "next_state": self.next_state.to_dict(),
            "should_emit_warning_90": self.should_emit_warning_90,
            "should_emit_silent_pause_alert": self.should_emit_silent_pause_alert,
            "slack_payload": self.slack_payload,
            "github_issue_payload": self.github_issue_payload,
            "decision_reason": self.decision_reason,
        }


def _assert_transition_allowed(previous_status: str, next_status: str) -> None:
    allowed = _ALLOWED_TRANSITIONS.get(previous_status, frozenset())
    if next_status not in allowed:
        raise ValueError(
            f"Illegal checkpoint transition: {previous_status} -> {next_status}"
        )


def build_slack_alert_payload(
    *,
    state: AgentCheckpointState,
    alert_kind: str,
    reason: str,
) -> dict[str, Any]:
    """Build immediate Slack alert message for 90% warning or silent-pause save."""
    header = (
        "[AGENT SILENT-PAUSE GUARD - LOSSLESS CHECKPOINT SAVED]"
        if alert_kind == "silent_pause"
        else "[AGENT 90% EARLY WARNING]"
    )
    digest = str(state.state_snapshot.get("snapshot_sha256") or "none")[:12]
    pending = str(state.state_snapshot.get("pending_step") or "unspecified")
    lines = [
        header,
        f"- run_key: {state.run_key} (agent={state.agent_name})",
        f"- status: {state.pause_status} | seq={state.checkpoint_seq}",
        f"- usage_ratio: {state.usage_ratio_pct:.2f}% (warn_at={state.warning_90_threshold_pct:.2f}%)",
        f"- pending_step: {pending} | snapshot_sha256={digest}",
        f"- reason: {reason}",
    ]
    return {"text": "\n".join(lines)}


def build_github_issue_payload(
    *,
    state: AgentCheckpointState,
    alert_kind: str,
    reason: str,
    existing_open_issues: list[dict[str, Any]] | None = None,
) -> dict[str, Any] | None:
    """Build a deduplicated GitHub Issue payload for 90% warnings or silent pauses."""
    marker = (
        f"[agent-silent-pause:{state.run_key}]"
        if alert_kind == "silent_pause"
        else f"[agent-warning-90:{state.run_key}]"
    )
    for issue in existing_open_issues or ():
        title = str(issue.get("title") or "")
        body = str(issue.get("body") or "")
        if marker in title or marker in body:
            return None

    digest = str(state.state_snapshot.get("snapshot_sha256") or "none")
    pending = str(state.state_snapshot.get("pending_step") or "unspecified")
    title = (
        f"{marker} クレジット枯渇により {state.agent_name} を無欠損一時停止 ({state.usage_ratio_pct:.1f}%)"
        if alert_kind == "silent_pause"
        else f"{marker} エージェント利用枠 {state.warning_90_threshold_pct:.0f}% 早期警告 ({state.usage_ratio_pct:.1f}%)"
    )
    body = (
        f"Marker: `{marker}`\n\n"
        f"- Run Key: `{state.run_key}`\n"
        f"- Agent: `{state.agent_name}`\n"
        f"- Pause Status: `{state.pause_status}`\n"
        f"- Checkpoint Seq: `{state.checkpoint_seq}`\n"
        f"- Usage Ratio: `{state.usage_ratio_pct:.2f}%` (Warning Threshold: `{state.warning_90_threshold_pct:.2f}%`)\n"
        f"- Pending Step Preserved: `{pending}`\n"
        f"- Snapshot SHA-256: `{digest}`\n"
        f"- Reason: {reason}\n\n"
        "## Recovery Action\n"
        "- クレジット補充・上限確認後、管理者UIまたはチェックポイント再開APIから `resumed` へ遷移してください。\n"
    )
    return {
        "title": title,
        "body": body,
        "labels": ["automation", "agent-checkpoint"],
    }


def evaluate_checkpoint_transition(
    current: AgentCheckpointState,
    *,
    usage_ratio_pct: float,
    credit_depleted: bool = False,
    upstream_silent_pause: bool = False,
    pending_step: str = "",
    cursor_payload: dict[str, Any] | None = None,
    completed_items: list[str] | None = None,
    existing_open_issues: list[dict[str, Any]] | None = None,
    now_iso: str | None = None,
) -> TransitionDecision:
    """Evaluate usage ratio and credit depletion to execute state transitions cleanly."""
    if current.pause_status == "failed":
        raise ValueError("Cannot transition out of terminal failed checkpoint")

    timestamp = now_iso or utc_now_iso()
    ratio = round(max(0.0, float(usage_ratio_pct)), 2)
    threshold = float(current.warning_90_threshold_pct)
    base_snapshot = dict(current.state_snapshot or {})

    resolved_pending = (
        pending_step.strip()
        or str(base_snapshot.get("pending_step") or "").strip()
        or "in_flight_task"
    )
    resolved_cursor = (
        dict(cursor_payload)
        if cursor_payload is not None
        else dict(base_snapshot.get("cursor_payload") or {})
    )
    resolved_completed = (
        list(completed_items)
        if completed_items is not None
        else list(base_snapshot.get("completed_items") or [])
    )

    if credit_depleted or ratio >= PAUSE_THRESHOLD_PCT or upstream_silent_pause:
        _assert_transition_allowed(current.pause_status, "paused_lossless")
        next_seq = current.checkpoint_seq + 1
        silent_detected = (
            current.pause_status in ("running", "warning_90", "resumed")
            or upstream_silent_pause
        )
        snapshot = build_lossless_snapshot(
            run_key=current.run_key,
            agent_name=current.agent_name,
            checkpoint_seq=next_seq,
            pending_step=resolved_pending,
            cursor_payload=resolved_cursor,
            completed_items=resolved_completed,
            captured_at=timestamp,
            reason="lossless_pause_on_credit_depletion",
        )
        next_state = AgentCheckpointState(
            run_key=current.run_key,
            agent_name=current.agent_name,
            checkpoint_seq=next_seq,
            pause_status="paused_lossless",
            usage_ratio_pct=ratio,
            warning_90_threshold_pct=threshold,
            warning_90_sent=True,
            silent_pause_alerted=current.silent_pause_alerted or silent_detected,
            state_snapshot=snapshot,
            resumed_by=None,
            resumed_at=None,
            updated_at=timestamp,
        )
        emit_silent_alert = not current.silent_pause_alerted or silent_detected
        reason = (
            f"Saved lossless snapshot seq={next_seq} and paused at "
            f"{ratio:.2f}% (credit_depleted={credit_depleted})"
        )
        slack_payload = (
            build_slack_alert_payload(
                state=next_state,
                alert_kind="silent_pause",
                reason=reason,
            )
            if emit_silent_alert
            else None
        )
        issue_payload = (
            build_github_issue_payload(
                state=next_state,
                alert_kind="silent_pause",
                reason=reason,
                existing_open_issues=existing_open_issues,
            )
            if emit_silent_alert
            else None
        )
        return TransitionDecision(
            previous_status=current.pause_status,
            next_state=next_state,
            should_emit_warning_90=not current.warning_90_sent,
            should_emit_silent_pause_alert=emit_silent_alert,
            slack_payload=slack_payload,
            github_issue_payload=issue_payload,
            decision_reason=reason,
        )

    if current.pause_status == "paused_lossless":
        next_state = AgentCheckpointState(
            run_key=current.run_key,
            agent_name=current.agent_name,
            checkpoint_seq=current.checkpoint_seq,
            pause_status="paused_lossless",
            usage_ratio_pct=ratio,
            warning_90_threshold_pct=threshold,
            warning_90_sent=current.warning_90_sent,
            silent_pause_alerted=current.silent_pause_alerted,
            state_snapshot=base_snapshot,
            resumed_by=None,
            resumed_at=None,
            updated_at=timestamp,
        )
        return TransitionDecision(
            previous_status="paused_lossless",
            next_state=next_state,
            should_emit_warning_90=False,
            should_emit_silent_pause_alert=False,
            slack_payload=None,
            github_issue_payload=None,
            decision_reason="Remains paused_lossless until explicit admin resume",
        )

    if ratio >= threshold:
        _assert_transition_allowed(current.pause_status, "warning_90")
        next_seq = current.checkpoint_seq + (
            1 if (pending_step or cursor_payload is not None or completed_items is not None) else 0
        )
        snapshot = (
            build_lossless_snapshot(
                run_key=current.run_key,
                agent_name=current.agent_name,
                checkpoint_seq=next_seq,
                pending_step=resolved_pending,
                cursor_payload=resolved_cursor,
                completed_items=resolved_completed,
                captured_at=timestamp,
                reason="early_warning_90_checkpoint",
            )
            if (next_seq > current.checkpoint_seq or not verify_lossless_snapshot(base_snapshot))
            else base_snapshot
        )
        emit_warn = not current.warning_90_sent
        next_state = AgentCheckpointState(
            run_key=current.run_key,
            agent_name=current.agent_name,
            checkpoint_seq=next_seq,
            pause_status="warning_90",
            usage_ratio_pct=ratio,
            warning_90_threshold_pct=threshold,
            warning_90_sent=True,
            silent_pause_alerted=current.silent_pause_alerted,
            state_snapshot=snapshot,
            resumed_by=current.resumed_by,
            resumed_at=current.resumed_at,
            updated_at=timestamp,
        )
        reason = f"Usage reached {ratio:.2f}% >= {threshold:.2f}% early-warning threshold"
        return TransitionDecision(
            previous_status=current.pause_status,
            next_state=next_state,
            should_emit_warning_90=emit_warn,
            should_emit_silent_pause_alert=False,
            slack_payload=(
                build_slack_alert_payload(
                    state=next_state,
                    alert_kind="warning_90",
                    reason=reason,
                )
                if emit_warn
                else None
            ),
            github_issue_payload=(
                build_github_issue_payload(
                    state=next_state,
                    alert_kind="warning_90",
                    reason=reason,
                    existing_open_issues=existing_open_issues,
                )
                if emit_warn
                else None
            ),
            decision_reason=reason,
        )

    next_status = "running"
    _assert_transition_allowed(current.pause_status, next_status)
    next_seq = current.checkpoint_seq + (
        1 if (pending_step or cursor_payload is not None or completed_items is not None) else 0
    )
    snapshot = (
        build_lossless_snapshot(
            run_key=current.run_key,
            agent_name=current.agent_name,
            checkpoint_seq=next_seq,
            pending_step=resolved_pending,
            cursor_payload=resolved_cursor,
            completed_items=resolved_completed,
            captured_at=timestamp,
            reason="periodic_checkpoint",
        )
        if (next_seq > current.checkpoint_seq or not verify_lossless_snapshot(base_snapshot))
        else base_snapshot
    )
    next_state = AgentCheckpointState(
        run_key=current.run_key,
        agent_name=current.agent_name,
        checkpoint_seq=next_seq,
        pause_status=next_status,
        usage_ratio_pct=ratio,
        warning_90_threshold_pct=threshold,
        warning_90_sent=False,
        silent_pause_alerted=False,
        state_snapshot=snapshot,
        resumed_by=current.resumed_by,
        resumed_at=current.resumed_at,
        updated_at=timestamp,
    )
    return TransitionDecision(
        previous_status=current.pause_status,
        next_state=next_state,
        should_emit_warning_90=False,
        should_emit_silent_pause_alert=False,
        slack_payload=None,
        github_issue_payload=None,
        decision_reason=f"Usage {ratio:.2f}% < {threshold:.2f}% (running normally)",
    )


def resume_from_checkpoint(
    paused_state: AgentCheckpointState,
    *,
    actor_user_id: str,
    actor_is_admin: bool,
    new_usage_ratio_pct: float,
    now_iso: str | None = None,
) -> tuple[AgentCheckpointState, dict[str, Any]]:
    """Restore an agent run losslessly from a verified paused checkpoint."""
    if not actor_is_admin:
        raise PermissionError("Administrator privilege required to resume paused checkpoint")
    actor_clean = actor_user_id.strip()
    if not actor_clean:
        raise ValueError("actor_user_id must not be empty")
    if paused_state.pause_status != "paused_lossless":
        raise ValueError(
            f"Only paused_lossless checkpoints can resume (got {paused_state.pause_status})"
        )
    if float(new_usage_ratio_pct) >= PAUSE_THRESHOLD_PCT:
        raise ValueError(
            f"Cannot resume while usage_ratio_pct={new_usage_ratio_pct:.2f}% >= 100%"
        )
    if not verify_lossless_snapshot(paused_state.state_snapshot):
        raise ValueError("Snapshot SHA-256 verification failed; refusing unsafe resume")

    _assert_transition_allowed(paused_state.pause_status, "resumed")
    timestamp = now_iso or utc_now_iso()
    resumed_state = AgentCheckpointState(
        run_key=paused_state.run_key,
        agent_name=paused_state.agent_name,
        checkpoint_seq=paused_state.checkpoint_seq + 1,
        pause_status="resumed",
        usage_ratio_pct=round(max(0.0, float(new_usage_ratio_pct)), 2),
        warning_90_threshold_pct=paused_state.warning_90_threshold_pct,
        warning_90_sent=float(new_usage_ratio_pct) >= paused_state.warning_90_threshold_pct,
        silent_pause_alerted=paused_state.silent_pause_alerted,
        state_snapshot=dict(paused_state.state_snapshot),
        resumed_by=actor_clean,
        resumed_at=timestamp,
        updated_at=timestamp,
    )
    restored_context = {
        "pending_step": resumed_state.state_snapshot.get("pending_step"),
        "cursor_payload": dict(resumed_state.state_snapshot.get("cursor_payload") or {}),
        "completed_items": list(resumed_state.state_snapshot.get("completed_items") or []),
        "snapshot_sha256": resumed_state.state_snapshot.get("snapshot_sha256"),
    }
    return resumed_state, restored_context


def _sanitize_url_for_log(raw_url: str) -> str:
    parsed = urllib.parse.urlsplit(raw_url)
    host = parsed.hostname or ""
    if parsed.port:
        host = f"{host}:{parsed.port}"
    return urllib.parse.urlunsplit((parsed.scheme, host, parsed.path, "", ""))


def _is_safe_public_ip(raw_ip: str) -> bool:
    try:
        ip_obj = ipaddress.ip_address(raw_ip)
    except ValueError:
        return False
    return (
        ip_obj.is_global
        and not ip_obj.is_private
        and not ip_obj.is_loopback
        and not ip_obj.is_link_local
        and not ip_obj.is_multicast
        and not ip_obj.is_reserved
        and not ip_obj.is_unspecified
    )


def validate_and_resolve_https_url(raw_url: str) -> tuple[str, str]:
    """Validate https:// URL and resolve a non-private pinned IP without DNS rebinding."""
    cleaned = raw_url.strip()
    parsed = urllib.parse.urlsplit(cleaned)
    if parsed.scheme.lower() != "https":
        raise ValueError(f"Only https:// URLs are permitted: {_sanitize_url_for_log(cleaned)}")
    if parsed.username or parsed.password:
        raise ValueError("URL credentials are not permitted")
    hostname = (parsed.hostname or "").strip().lower()
    if not hostname:
        raise ValueError("Missing destination hostname")
    port = parsed.port or 443

    try:
        ip_literal = ipaddress.ip_address(hostname)
    except ValueError:
        ip_literal = None

    if ip_literal is not None:
        if not _is_safe_public_ip(str(ip_literal)):
            raise ValueError(f"Blocked non-public IP address: {ip_literal}")
        return cleaned, str(ip_literal)

    try:
        addr_info = socket.getaddrinfo(hostname, port, type=socket.SOCK_STREAM)
    except OSError as exc:
        raise RuntimeError(f"DNS lookup failed for {hostname}: {exc}") from exc

    resolved_ips: list[str] = []
    for _, _, _, _, sockaddr in addr_info:
        cand_ip = str(sockaddr[0])
        if not _is_safe_public_ip(cand_ip):
            raise ValueError(f"Blocked non-public resolved IP {cand_ip} for {hostname}")
        if cand_ip not in resolved_ips:
            resolved_ips.append(cand_ip)
    if not resolved_ips:
        raise RuntimeError(f"No routable IP resolved for {hostname}")
    return cleaned, resolved_ips[0]


class _PinnedHTTPSConnection(http.client.HTTPSConnection):
    """HTTPSConnection that connects directly to the validated pinned IP with TLS SNI."""

    def __init__(
        self,
        *,
        host_header: str,
        tls_hostname: str,
        pinned_ip: str,
        port: int = 443,
        timeout: int = 15,
    ) -> None:
        super().__init__(host=host_header, port=port, timeout=timeout)
        self._pinned_ip = pinned_ip
        self._tls_hostname = tls_hostname

    def connect(self) -> None:
        raw_sock = socket.create_connection(
            (self._pinned_ip, self.port),
            self.timeout,
            self.source_address,
        )
        if self._tunnel_host:
            self.sock = raw_sock
            self._tunnel()
        tls_ctx = ssl.create_default_context()
        tls_ctx.minimum_version = ssl.TLSVersion.TLSv1_2
        tls_ctx.verify_mode = ssl.CERT_REQUIRED
        tls_ctx.check_hostname = True
        self.sock = tls_ctx.wrap_socket(
            raw_sock,
            server_hostname=self._tls_hostname,
        )


def _http_json(
    url: str,
    *,
    method: str = "GET",
    headers: dict[str, str],
    payload: object | None = None,
    timeout: int = 15,
) -> tuple[int, object]:
    safe_url = _sanitize_url_for_log(url)
    cleaned_url, pinned_ip = validate_and_resolve_https_url(url)
    parsed = urllib.parse.urlsplit(cleaned_url)
    hostname = parsed.hostname or ""
    port = parsed.port or 443
    netloc = parsed.netloc
    path_with_query = urllib.parse.urlunsplit(("", "", parsed.path or "/", parsed.query, ""))
    data = json.dumps(payload).encode("utf-8") if payload is not None else None

    req_headers = dict(headers)
    req_headers["Host"] = netloc
    conn = _PinnedHTTPSConnection(
        host_header=netloc,
        tls_hostname=hostname,
        pinned_ip=pinned_ip,
        port=port,
        timeout=timeout,
    )
    try:
        conn.request(method, path_with_query, body=data, headers=req_headers)
        resp = conn.getresponse()
        raw = resp.read().decode("utf-8", errors="replace")
        status = int(resp.status)
        if 300 <= status < 400:
            raise RuntimeError(f"Redirect blocked (HTTP {status}) from {method} {safe_url}")
        if status < 200 or status >= 300:
            raise RuntimeError(f"HTTP {status} from {method} {safe_url}: {raw[:240]}")
        parsed_json = json.loads(raw) if raw.strip() else {}
        return status, parsed_json
    except OSError as exc:
        raise RuntimeError(f"Network error from {method} {safe_url}: {exc}") from exc
    finally:
        conn.close()


def build_summary_markdown(decision: TransitionDecision, *, dry_run: bool) -> str:
    st = decision.next_state
    return (
        "### Agent Pause Checkpoint State Machine (#2616)\n"
        f"- Mode: `{'dry-run' if dry_run else 'live'}`\n"
        f"- Run Key: `{st.run_key}` (`{st.agent_name}`)\n"
        f"- Transition: `{decision.previous_status}` -> `{st.pause_status}` (seq `{st.checkpoint_seq}`)\n"
        f"- Usage Ratio: `{st.usage_ratio_pct:.2f}%` (warn >= `{st.warning_90_threshold_pct:.2f}%`)\n"
        f"- Warning 90% Alert: `{decision.should_emit_warning_90}` | "
        f"Silent Pause Alert: `{decision.should_emit_silent_pause_alert}`\n"
        f"- Snapshot SHA-256: `{st.state_snapshot.get('snapshot_sha256', 'none')}`\n"
    )


def run_self_test() -> dict[str, Any]:
    initial = AgentCheckpointState(
        run_key="self-test-run-01",
        agent_name="daily-digest-agent",
        checkpoint_seq=1,
        usage_ratio_pct=42.0,
        state_snapshot=build_lossless_snapshot(
            run_key="self-test-run-01",
            agent_name="daily-digest-agent",
            checkpoint_seq=1,
            pending_step="step_1_fetch",
            cursor_payload={"cursor": 10},
            completed_items=["item-1"],
            captured_at="2026-11-24T08:00:00Z",
        ),
    )
    d90 = evaluate_checkpoint_transition(
        initial,
        usage_ratio_pct=92.5,
        pending_step="step_2_summarize",
        cursor_payload={"cursor": 25},
        completed_items=["item-1", "item-2"],
        now_iso="2026-11-24T08:05:00Z",
    )
    d100 = evaluate_checkpoint_transition(
        d90.next_state,
        usage_ratio_pct=100.0,
        credit_depleted=True,
        pending_step="step_3_publish",
        now_iso="2026-11-24T08:06:00Z",
    )
    resumed, context = resume_from_checkpoint(
        d100.next_state,
        actor_user_id="00000000-0000-0000-0000-000000000001",
        actor_is_admin=True,
        new_usage_ratio_pct=15.0,
        now_iso="2026-11-24T08:10:00Z",
    )
    assert d90.next_state.pause_status == "warning_90"
    assert d90.should_emit_warning_90 is True
    assert d100.next_state.pause_status == "paused_lossless"
    assert d100.should_emit_silent_pause_alert is True
    assert resumed.pause_status == "resumed"
    assert context["cursor_payload"]["cursor"] == 25
    return {
        "self_test": "passed",
        "warning_status": d90.next_state.pause_status,
        "paused_status": d100.next_state.pause_status,
        "resumed_status": resumed.pause_status,
        "restored_cursor": context["cursor_payload"]["cursor"],
    }


def _emit_github_outputs(path_str: str, decision: TransitionDecision) -> None:
    if not path_str:
        return
    st = decision.next_state
    lines = [
        f"pause_status={st.pause_status}",
        f"checkpoint_seq={st.checkpoint_seq}",
        f"warning_90_emitted={'true' if decision.should_emit_warning_90 else 'false'}",
        f"silent_pause_emitted={'true' if decision.should_emit_silent_pause_alert else 'false'}",
    ]
    with open(path_str, "a", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Evaluate agent checkpoint transition, 90% warning, and lossless pause (#2616)."
    )
    parser.add_argument("--run-key", default="scheduled-checkpoint-audit")
    parser.add_argument("--agent-name", default="agent-worker")
    parser.add_argument("--usage-pct", type=float, default=0.0)
    parser.add_argument("--credit-depleted", action="store_true")
    parser.add_argument("--input-json", default="")
    parser.add_argument("--dry-run", action="store_true", default=True)
    parser.add_argument("--live", action="store_true", help="Disable dry-run and emit live webhooks if configured")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--json-out", default="")
    parser.add_argument("--markdown-out", default="")
    parser.add_argument("--github-output", default="")
    args = parser.parse_args(argv)

    if args.self_test:
        print(json.dumps(run_self_test(), ensure_ascii=False))
        return 0

    dry_run = not args.live
    if args.input_json:
        raw = json.loads(Path(args.input_json).read_text(encoding="utf-8"))
        current = AgentCheckpointState(
            run_key=str(raw.get("run_key") or args.run_key),
            agent_name=str(raw.get("agent_name") or args.agent_name),
            checkpoint_seq=int(raw.get("checkpoint_seq") or 1),
            pause_status=str(raw.get("pause_status") or "running"),
            usage_ratio_pct=float(raw.get("usage_ratio_pct") or 0.0),
            warning_90_threshold_pct=float(
                raw.get("warning_90_threshold_pct") or DEFAULT_WARNING_90_THRESHOLD_PCT
            ),
            warning_90_sent=bool(raw.get("warning_90_sent")),
            silent_pause_alerted=bool(raw.get("silent_pause_alerted")),
            state_snapshot=dict(raw.get("state_snapshot") or {}),
        )
        target_ratio = float(raw.get("observed_usage_ratio_pct", args.usage_pct))
        credit_depleted = bool(raw.get("credit_depleted", args.credit_depleted))
        pending_step = str(raw.get("pending_step") or "")
        cursor_payload = raw.get("cursor_payload") if isinstance(raw.get("cursor_payload"), dict) else None
    else:
        current = AgentCheckpointState(
            run_key=args.run_key,
            agent_name=args.agent_name,
            usage_ratio_pct=args.usage_pct,
        )
        target_ratio = args.usage_pct
        credit_depleted = args.credit_depleted
        pending_step = "checkpoint_verification"
        cursor_payload = {"source": "cli"}

    decision = evaluate_checkpoint_transition(
        current,
        usage_ratio_pct=target_ratio,
        credit_depleted=credit_depleted,
        pending_step=pending_step,
        cursor_payload=cursor_payload,
    )

    if not dry_run:
        slack_dest = os.environ.get("QUOTA_ALERT_WEBHOOK_URL", "").strip()
        if slack_dest and decision.slack_payload is not None:
            _http_json(
                slack_dest,
                method="POST",
                headers={"Content-Type": "application/json"},
                payload=decision.slack_payload,
            )
        gh_auth = os.environ.get("GITHUB_TOKEN", "").strip()
        repo = os.environ.get("GITHUB_REPOSITORY", "kanta13jp1/my_web_app").strip()
        if gh_auth and decision.github_issue_payload is not None and "/" in repo:
            _http_json(
                f"https://api.github.com/repos/{repo}/issues",
                method="POST",
                headers={
                    "Authorization": f"Bearer {gh_auth}",
                    "Accept": "application/vnd.github+json",
                    "X-GitHub-Api-Version": "2022-11-28",
                    "Content-Type": "application/json",
                },
                payload=decision.github_issue_payload,
            )

    md = build_summary_markdown(decision, dry_run=dry_run)
    if args.json_out:
        Path(args.json_out).write_text(
            json.dumps(decision.to_dict(), ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
            newline="\n",
        )
    if args.markdown_out:
        Path(args.markdown_out).write_text(md, encoding="utf-8", newline="\n")
    _emit_github_outputs(args.github_output, decision)
    print(md.strip())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
