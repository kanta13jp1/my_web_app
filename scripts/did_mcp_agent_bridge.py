#!/usr/bin/env python3
"""D-ID MCP Agent Bridge & 429/Upstream Alert Monitor (Issue #2662)."""

from __future__ import annotations

import argparse
import hashlib
import http.client
import ipaddress
import json
import os
import re
import socket
import ssl
import sys
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

DID_MCP_DOCS_URL = "https://docs.d-id.com/mcp"
SUPPORTED_TOOLS = (
    "did_generate_talk_video",
    "did_agent_chat",
    "did_rag_query",
    "did_mcp_docs_lookup",
)
_CGNAT_NETWORK = ipaddress.ip_network("100.64.0.0/10")


def _mask_secret(value: str) -> str:
    text = value.strip()
    if not text:
        return ""
    digest = hashlib.sha256(text.encode("utf-8")).hexdigest()[:8]
    return f"[REDACTED:{digest}]"


def _is_blocked_ip(ip_text: str) -> bool:
    try:
        ip_obj = ipaddress.ip_address(ip_text.split("%")[0])
    except ValueError:
        return True

    # Unwrap IPv4-mapped IPv6 addresses recursively (Rule #11).
    while isinstance(ip_obj, ipaddress.IPv6Address) and ip_obj.ipv4_mapped is not None:
        ip_obj = ip_obj.ipv4_mapped

    if not ip_obj.is_global:
        return True
    if isinstance(ip_obj, ipaddress.IPv4Address) and ip_obj in _CGNAT_NETWORK:
        return True
    return False


def _validate_https_webhook_url(raw_url: str) -> tuple[str, int, str, str]:
    parsed = urlparse(raw_url.strip())
    if parsed.scheme.lower() != "https":
        raise ValueError("Webhook URL must use https")
    if parsed.username or parsed.password:
        raise ValueError("Webhook URL must not contain embedded credentials")
    hostname = (parsed.hostname or "").strip().lower()
    if not hostname or hostname in {"localhost", "metadata.google.internal"}:
        raise ValueError(f"Disallowed webhook hostname: {hostname!r}")
    try:
        ipaddress.ip_address(hostname)
        raise ValueError("Direct IP literal webhook URLs are forbidden")
    except ValueError as exc:
        if "Direct IP literal" in str(exc):
            raise

    port = parsed.port or 443
    if port != 443:
        raise ValueError("Webhook port must be 443")

    infos = socket.getaddrinfo(hostname, port, type=socket.SOCK_STREAM)
    pinned_ips: list[str] = []
    for info in infos:
        addr = info[4][0]
        if _is_blocked_ip(addr):
            raise ValueError(f"Blocked non-global resolved webhook IP: {addr}")
        if addr not in pinned_ips:
            pinned_ips.append(addr)

    if not pinned_ips:
        raise ValueError("Unable to resolve any global IP for webhook host")

    path = parsed.path or "/"
    if parsed.query:
        path = f"{path}?{parsed.query}"
    return hostname, port, path, pinned_ips[0]


class _PinnedHTTPSConnection(http.client.HTTPSConnection):
    """HTTPS connection that connects directly to a pre-validated global IP with SNI."""

    def __init__(
        self,
        hostname: str,
        port: int,
        pinned_ip: str,
        timeout: float = 10.0,
    ) -> None:
        context = ssl.create_default_context()
        context.minimum_version = ssl.TLSVersion.TLSv1_2
        context.verify_mode = ssl.CERT_REQUIRED
        context.check_hostname = True
        super().__init__(hostname, port=port, timeout=timeout, context=context)
        self._pinned_ip = pinned_ip
        self._sni_host = hostname

    def connect(self) -> None:
        raw_sock = socket.create_connection(
            (self._pinned_ip, self.port),
            timeout=self.timeout,
        )
        self.sock = self._context.wrap_socket(
            raw_sock,
            server_hostname=self._sni_host,
        )


def prompt_to_mcp_invocation(
    prompt: str,
    *,
    tool_hint: str | None = None,
    dry_run: bool = True,
) -> dict[str, Any]:
    cleaned = re.sub(r"\s+", " ", prompt).strip()
    if not cleaned:
        raise ValueError("Prompt must not be empty")
    if len(cleaned) > 2000:
        raise ValueError("Prompt exceeds maximum length of 2000 characters")

    lower = cleaned.lower()
    if tool_hint and tool_hint in SUPPORTED_TOOLS:
        selected_tool = tool_hint
    elif any(k in lower for k in ("mcp", "docs", "endpoint", "仕様", "ドキュメント")):
        selected_tool = "did_mcp_docs_lookup"
    elif any(k in lower for k in ("rag", "knowledge", "ナレッジ", "検索")):
        selected_tool = "did_rag_query"
    elif any(k in lower for k in ("chat", "agent", "対話", "チャット")):
        selected_tool = "did_agent_chat"
    else:
        selected_tool = "did_generate_talk_video"

    if selected_tool == "did_generate_talk_video":
        arguments: dict[str, Any] = {"script": cleaned, "dry_run": dry_run}
    elif selected_tool == "did_agent_chat":
        arguments = {
            "agent_id": "agent_default",
            "message": cleaned,
            "dry_run": dry_run,
        }
    elif selected_tool == "did_rag_query":
        arguments = {
            "knowledge_id": "default",
            "query": cleaned[:500],
            "top_k": 5,
            "dry_run": dry_run,
        }
    else:
        arguments = {"query": cleaned[:500], "dry_run": dry_run}

    return {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/call",
        "params": {
            "name": selected_tool,
            "arguments": arguments,
        },
        "target_mcp_docs": DID_MCP_DOCS_URL,
    }


def evaluate_proxy_events(events: list[dict[str, Any]]) -> dict[str, Any]:
    total = len(events)
    rate_limited = 0
    failed = 0
    alerts: list[dict[str, Any]] = []

    for ev in events:
        status = str(ev.get("status") or "").strip().lower()
        http_status = int(ev.get("http_status") or 200)
        tool_name = str(ev.get("tool_name") or "unknown")
        if status == "rate_limited" or http_status == 429:
            rate_limited += 1
            alerts.append(
                {
                    "severity": "critical",
                    "alert_type": "rate_limit",
                    "tool_name": tool_name,
                    "http_status": http_status,
                }
            )
        elif status == "failed" or http_status >= 500:
            failed += 1
            alerts.append(
                {
                    "severity": "warning" if http_status < 500 else "critical",
                    "alert_type": "upstream_error",
                    "tool_name": tool_name,
                    "http_status": http_status,
                }
            )

    return {
        "total_events": total,
        "rate_limited_count": rate_limited,
        "failed_count": failed,
        "alert_count": len(alerts),
        "should_alert": len(alerts) > 0,
        "alerts": alerts,
    }


def post_pinned_webhook(webhook_url: str, payload: dict[str, Any]) -> int:
    hostname, port, path, pinned_ip = _validate_https_webhook_url(webhook_url)
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    conn = _PinnedHTTPSConnection(hostname, port, pinned_ip, timeout=10.0)
    try:
        conn.request(
            "POST",
            path,
            body=body,
            headers={
                "Content-Type": "application/json",
                "User-Agent": "jibun-did-mcp-bridge/1.0",
            },
        )
        resp = conn.getresponse()
        resp.read()
        if 300 <= resp.status < 400:
            raise RuntimeError(f"Webhook redirect rejected (HTTP {resp.status})")
        return resp.status
    finally:
        conn.close()


def _write_github_output(path_str: str | None, values: dict[str, Any]) -> None:
    if not path_str:
        return
    with open(path_str, "a", encoding="utf-8") as fh:
        for key, val in values.items():
            fh.write(f"{key}={val}\n")


def _run_self_test() -> None:
    inv = prompt_to_mcp_invocation("Check D-ID talks MCP endpoint docs", dry_run=True)
    assert inv["params"]["name"] == "did_mcp_docs_lookup"
    talk_inv = prompt_to_mcp_invocation("製品紹介アバター動画を作成してください", dry_run=True)
    assert talk_inv["params"]["name"] == "did_generate_talk_video"
    ev_summary = evaluate_proxy_events(
        [
            {"tool_name": "did_generate_talk_video", "status": "rate_limited", "http_status": 429},
            {"tool_name": "did_rag_query", "status": "succeeded", "http_status": 200},
        ]
    )
    assert ev_summary["should_alert"] is True
    assert ev_summary["rate_limited_count"] == 1
    assert _is_blocked_ip("127.0.0.1") is True
    assert _is_blocked_ip("100.64.0.1") is True
    assert _is_blocked_ip("::ffff:10.0.0.1") is True
    assert _is_blocked_ip("::ffff:100.64.0.5") is True
    assert _is_blocked_ip("8.8.8.8") is False


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="D-ID MCP Agent Bridge & Monitor")
    parser.add_argument("--prompt", default="D-ID MCP プロキシヘルスチェック (dry-run)")
    parser.add_argument("--tool-hint", default=None)
    parser.add_argument("--events-json", default=None)
    parser.add_argument("--webhook-url", default=os.environ.get("DID_MCP_ALERT_WEBHOOK_URL", ""))
    parser.add_argument("--json-out", default=None)
    parser.add_argument("--markdown-out", default=None)
    parser.add_argument("--github-output", default=os.environ.get("GITHUB_OUTPUT", ""))
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--live", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv)

    if args.self_test:
        _run_self_test()
        print("did_mcp_agent_bridge self-test PASSED")
        return 0

    is_live = bool(args.live and not args.dry_run)
    invocation = prompt_to_mcp_invocation(
        args.prompt,
        tool_hint=args.tool_hint,
        dry_run=not is_live,
    )

    events: list[dict[str, Any]] = []
    if args.events_json and Path(args.events_json).is_file():
        loaded = json.loads(Path(args.events_json).read_text(encoding="utf-8"))
        if isinstance(loaded, list):
            events = [row for row in loaded if isinstance(row, dict)]

    summary = evaluate_proxy_events(events)
    webhook_status = "skipped"
    if is_live and summary["should_alert"] and args.webhook_url:
        code = post_pinned_webhook(
            args.webhook_url,
            {
                "text": (
                    f"[D-ID MCP Alert] alerts={summary['alert_count']} "
                    f"rate_limited={summary['rate_limited_count']} "
                    f"failed={summary['failed_count']}"
                )
            },
        )
        webhook_status = f"sent:{code}"
    elif args.webhook_url:
        webhook_status = f"dry-run:{_mask_secret(args.webhook_url)}"

    report = {
        "mode": "live" if is_live else "dry-run",
        "invocation": invocation,
        "event_summary": summary,
        "webhook_status": webhook_status,
    }

    if args.json_out:
        Path(args.json_out).write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    if args.markdown_out:
        md = (
            f"## D-ID MCP Agent Bridge Report ({report['mode']})\n\n"
            f"- Selected Tool: `{invocation['params']['name']}`\n"
            f"- Events Checked: `{summary['total_events']}`\n"
            f"- Rate Limited (429): `{summary['rate_limited_count']}`\n"
            f"- Alerts Triggered: `{summary['alert_count']}`\n"
            f"- Webhook Status: `{webhook_status}`\n"
        )
        Path(args.markdown_out).write_text(md, encoding="utf-8")

    _write_github_output(
        args.github_output,
        {
            "mode": report["mode"],
            "selected_tool": invocation["params"]["name"],
            "alert_count": summary["alert_count"],
            "rate_limited_count": summary["rate_limited_count"],
            "webhook_status": webhook_status,
        },
    )
    print(f"did_mcp_agent_bridge completed mode={report['mode']} tool={invocation['params']['name']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
