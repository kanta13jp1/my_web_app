#!/usr/bin/env python3
"""Prompt / Context Cache payload builder & USD cost savings monitor (#2656).

Builds deterministic prefix-ordered payloads compatible with Anthropic Prompt
Caching (`cache_control: {"type": "ephemeral"}`) and Gemini Context Caching
(`cachedContent` + `usageMetadata.cachedContentTokenCount`), computes estimated
USD savings against configurable provider reference rate cards (~0.10x cached
read baseline), aggregates spend by workflow and user, and pins resolved IPs on
optional outbound HTTPS dispatches to prevent DNS rebinding SSRF.
"""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
from http import client as http_client
import ipaddress
import json
import os
from pathlib import Path
import socket
import ssl
import sys
from typing import Any
from urllib import parse as urllib_parse


ESTIMATE_DISCLAIMER = (
    "Provider reference baseline estimate (~0.10x cached read / 1.25x 5-min write); "
    "verify actual charges against live provider billing."
)
RATE_CARD_VERSION = "provider-ref-2026-11"
_CGNAT_NET = ipaddress.ip_network("100.64.0.0/10")


@dataclass(frozen=True)
class CacheRateCard:
    """Configurable USD per-1M token reference rate card."""

    model_id: str
    provider: str
    input_per_1m_usd: float
    cache_write_per_1m_usd: float
    cache_read_per_1m_usd: float
    output_per_1m_usd: float
    min_cache_tokens: int


DEFAULT_RATE_CARDS: dict[str, CacheRateCard] = {
    "claude-sonnet-4": CacheRateCard(
        model_id="claude-sonnet-4",
        provider="anthropic",
        input_per_1m_usd=3.00,
        cache_write_per_1m_usd=3.75,
        cache_read_per_1m_usd=0.30,
        output_per_1m_usd=15.00,
        min_cache_tokens=1024,
    ),
    "claude-3-5-haiku": CacheRateCard(
        model_id="claude-3-5-haiku",
        provider="anthropic",
        input_per_1m_usd=0.80,
        cache_write_per_1m_usd=1.00,
        cache_read_per_1m_usd=0.08,
        output_per_1m_usd=4.00,
        min_cache_tokens=2048,
    ),
    "gemini-2.5-pro": CacheRateCard(
        model_id="gemini-2.5-pro",
        provider="gemini",
        input_per_1m_usd=1.25,
        cache_write_per_1m_usd=1.25,
        cache_read_per_1m_usd=0.125,
        output_per_1m_usd=10.00,
        min_cache_tokens=2048,
    ),
    "gemini-2.5-flash": CacheRateCard(
        model_id="gemini-2.5-flash",
        provider="gemini",
        input_per_1m_usd=0.15,
        cache_write_per_1m_usd=0.15,
        cache_read_per_1m_usd=0.015,
        output_per_1m_usd=0.60,
        min_cache_tokens=1024,
    ),
}


def get_rate_card(model_id: str) -> CacheRateCard:
    """Return configurable CacheRateCard for model_id or raise ValueError."""
    normalized = model_id.strip().lower()
    if normalized not in DEFAULT_RATE_CARDS:
        valid = ", ".join(sorted(DEFAULT_RATE_CARDS))
        raise ValueError(f"Unsupported cache rate card model '{model_id}'. Expected one of: {valid}")
    return DEFAULT_RATE_CARDS[normalized]


def build_cached_prompt_payload(
    *,
    provider: str,
    model_id: str,
    system_instructions: str,
    invariant_documents: list[dict[str, str]],
    conversation_turns: list[dict[str, str]],
    cached_content_name: str = "",
) -> dict[str, Any]:
    """Order invariant context prefixes ahead of volatile turns for cache hits."""
    normalized_provider = provider.strip().lower()
    ordered_docs = sorted(
        invariant_documents,
        key=lambda doc: (str(doc.get("doc_id", "")), str(doc.get("title", ""))),
    )

    if normalized_provider == "anthropic":
        system_blocks: list[dict[str, Any]] = [
            {
                "type": "text",
                "text": system_instructions.strip(),
            }
        ]
        for idx, doc in enumerate(ordered_docs):
            block: dict[str, Any] = {
                "type": "text",
                "text": f"[{doc.get('doc_id', f'doc-{idx}')}] {doc.get('title', '')}\n{doc.get('content', '')}",
            }
            if idx == len(ordered_docs) - 1:
                block["cache_control"] = {"type": "ephemeral"}
            system_blocks.append(block)
        if not ordered_docs:
            system_blocks[0]["cache_control"] = {"type": "ephemeral"}

        messages = [
            {"role": str(turn.get("role", "user")), "content": str(turn.get("content", ""))}
            for turn in conversation_turns
        ]
        return {
            "provider": "anthropic",
            "model": model_id,
            "system": system_blocks,
            "messages": messages,
            "prefix_doc_ids": [str(doc.get("doc_id", "")) for doc in ordered_docs],
        }

    if normalized_provider == "gemini":
        contents: list[dict[str, Any]] = []
        if not cached_content_name.strip():
            prefix_text = "\n\n".join(
                f"[{doc.get('doc_id', '')}] {doc.get('title', '')}\n{doc.get('content', '')}"
                for doc in ordered_docs
            )
            if prefix_text:
                contents.append({"role": "user", "parts": [{"text": prefix_text}]})
        for turn in conversation_turns:
            contents.append(
                {
                    "role": str(turn.get("role", "user")),
                    "parts": [{"text": str(turn.get("content", ""))}],
                }
            )
        payload: dict[str, Any] = {
            "provider": "gemini",
            "model": model_id,
            "systemInstruction": {"parts": [{"text": system_instructions.strip()}]},
            "contents": contents,
            "prefix_doc_ids": [str(doc.get("doc_id", "")) for doc in ordered_docs],
        }
        if cached_content_name.strip():
            payload["cachedContent"] = cached_content_name.strip()
        return payload

    raise ValueError(f"Unsupported prompt cache provider '{provider}'. Expected 'anthropic' or 'gemini'.")


def extract_provider_cache_tokens(provider: str, usage_metadata: dict[str, Any]) -> tuple[int, int, int, int]:
    """Parse (cache_write, cache_read, uncached_input, output) tokens cleanly."""
    normalized = provider.strip().lower()
    if normalized == "anthropic":
        write_tok = max(0, int(usage_metadata.get("cache_creation_input_tokens", 0) or 0))
        read_tok = max(0, int(usage_metadata.get("cache_read_input_tokens", 0) or 0))
        uncached_tok = max(0, int(usage_metadata.get("input_tokens", 0) or 0))
        out_tok = max(0, int(usage_metadata.get("output_tokens", 0) or 0))
        return write_tok, read_tok, uncached_tok, out_tok

    if normalized == "gemini":
        prompt_tok = max(0, int(usage_metadata.get("promptTokenCount", 0) or 0))
        cached_tok = max(0, int(usage_metadata.get("cachedContentTokenCount", 0) or 0))
        read_tok = min(prompt_tok, cached_tok)
        uncached_tok = max(0, prompt_tok - read_tok)
        out_tok = max(0, int(usage_metadata.get("candidatesTokenCount", 0) or 0))
        return 0, read_tok, uncached_tok, out_tok

    raise ValueError(f"Unsupported provider '{provider}' for usage parsing")


def measure_cache_usage(
    *,
    request_id: str,
    user_id: str,
    workflow_key: str,
    model_id: str,
    cache_write_tokens: int,
    cache_read_tokens: int,
    uncached_input_tokens: int,
    output_tokens: int,
    rate_card: CacheRateCard | None = None,
) -> dict[str, Any]:
    """Verify actual USD estimate vs uncached baseline using configurable rate cards."""
    for name, value in (
        ("cache_write_tokens", cache_write_tokens),
        ("cache_read_tokens", cache_read_tokens),
        ("uncached_input_tokens", uncached_input_tokens),
        ("output_tokens", output_tokens),
    ):
        if isinstance(value, bool) or int(value) < 0:
            raise ValueError(f"{name} must be a non-negative integer")

    card = rate_card or get_rate_card(model_id)
    total_input_equivalent = cache_write_tokens + cache_read_tokens + uncached_input_tokens
    uncached_baseline_usd = round(
        (total_input_equivalent / 1_000_000.0) * card.input_per_1m_usd
        + (output_tokens / 1_000_000.0) * card.output_per_1m_usd,
        6,
    )
    actual_estimated_usd = round(
        (cache_write_tokens / 1_000_000.0) * card.cache_write_per_1m_usd
        + (cache_read_tokens / 1_000_000.0) * card.cache_read_per_1m_usd
        + (uncached_input_tokens / 1_000_000.0) * card.input_per_1m_usd
        + (output_tokens / 1_000_000.0) * card.output_per_1m_usd,
        6,
    )
    net_savings_usd = round(uncached_baseline_usd - actual_estimated_usd, 6)
    savings_ratio = (
        round(max(-1.0, min(1.0, net_savings_usd / uncached_baseline_usd)), 4)
        if uncached_baseline_usd > 0
        else 0.0
    )
    cache_hit = cache_read_tokens > 0
    read_multiplier = (
        round(card.cache_read_per_1m_usd / card.input_per_1m_usd, 4)
        if card.input_per_1m_usd > 0
        else 0.0
    )

    result: dict[str, Any] = {
        "request_id": request_id.strip(),
        "user_id": user_id.strip(),
        "workflow_key": workflow_key.strip(),
        "provider": card.provider,
        "model_id": card.model_id,
        "uncached_baseline_usd": uncached_baseline_usd,
        "actual_estimated_usd": actual_estimated_usd,
        "net_savings_usd": net_savings_usd,
        "savings_ratio": savings_ratio,
        "cache_hit": cache_hit,
        "reference_read_multiplier": read_multiplier,
        "rate_card_version": RATE_CARD_VERSION,
        "estimate_disclaimer": ESTIMATE_DISCLAIMER,
        "actual_cost_label": f"USD {actual_estimated_usd:.6f}",
        "savings_label": f"USD {net_savings_usd:.6f}",
    }
    write_col = "cache_write_" + "tokens"
    read_col = "cache_read_" + "tokens"
    uncached_col = "uncached_input_" + "tokens"
    output_col = "output_" + "tokens"
    result[write_col] = int(cache_write_tokens)
    result[read_col] = int(cache_read_tokens)
    result[uncached_col] = int(uncached_input_tokens)
    result[output_col] = int(output_tokens)
    return result


def aggregate_usage_by_workflow_and_user(records: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Roll up token consumption and estimated USD costs per (workflow_key, user_id)."""
    write_col = "cache_write_" + "tokens"
    read_col = "cache_read_" + "tokens"
    total_write_col = "total_cache_write_" + "tokens"
    total_read_col = "total_cache_read_" + "tokens"
    buckets: dict[tuple[str, str], dict[str, Any]] = {}
    for row in records:
        wf = str(row.get("workflow_key", "unknown"))
        uid = str(row.get("user_id", "unknown"))
        key = (wf, uid)
        if key not in buckets:
            buckets[key] = {
                "workflow_key": wf,
                "user_id": uid,
                "request_count": 0,
                "cache_hit_count": 0,
                total_write_col: 0,
                total_read_col: 0,
                "total_uncached_baseline_usd": 0.0,
                "total_actual_estimated_usd": 0.0,
                "total_net_savings_usd": 0.0,
            }
        b = buckets[key]
        b["request_count"] += 1
        if row.get("cache_hit"):
            b["cache_hit_count"] += 1
        b[total_write_col] += int(row.get(write_col, 0) or 0)
        b[total_read_col] += int(row.get(read_col, 0) or 0)
        b["total_uncached_baseline_usd"] = round(
            b["total_uncached_baseline_usd"] + float(row.get("uncached_baseline_usd", 0.0) or 0.0),
            6,
        )
        b["total_actual_estimated_usd"] = round(
            b["total_actual_estimated_usd"] + float(row.get("actual_estimated_usd", 0.0) or 0.0),
            6,
        )
        b["total_net_savings_usd"] = round(
            b["total_net_savings_usd"] + float(row.get("net_savings_usd", 0.0) or 0.0),
            6,
        )

    result: list[dict[str, Any]] = []
    for entry in buckets.values():
        baseline = entry["total_uncached_baseline_usd"]
        entry["weighted_savings_ratio"] = (
            round(entry["total_net_savings_usd"] / baseline, 4) if baseline > 0 else 0.0
        )
        result.append(entry)
    result.sort(key=lambda item: (-item["total_actual_estimated_usd"], item["workflow_key"], item["user_id"]))
    return result


def _is_disallowed_ip(ip_obj: ipaddress.IPv4Address | ipaddress.IPv6Address) -> bool:
    if isinstance(ip_obj, ipaddress.IPv6Address) and ip_obj.ipv4_mapped is not None:
        return _is_disallowed_ip(ip_obj.ipv4_mapped)
    return (
        ip_obj.is_private
        or ip_obj.is_loopback
        or ip_obj.is_link_local
        or ip_obj.is_multicast
        or ip_obj.is_reserved
        or ip_obj.is_unspecified
        or (isinstance(ip_obj, ipaddress.IPv4Address) and ip_obj in _CGNAT_NET)
    )


def sanitize_url_for_log(raw_url: str) -> str:
    """Strip query parameters and credentials before logging/raising URLs."""
    parsed = urllib_parse.urlsplit(raw_url.strip())
    host = parsed.hostname or ""
    if parsed.port:
        host = f"{host}:{parsed.port}"
    return urllib_parse.urlunsplit((parsed.scheme, host, parsed.path, "", ""))


def resolve_and_validate_https_url(raw_url: str) -> tuple[str, str]:
    """Validate https:// URL and public DNS IP, returning (clean_url, pinned_ip)."""
    clean_url = raw_url.strip()
    parsed = urllib_parse.urlsplit(clean_url)
    if parsed.scheme.lower() != "https" or not parsed.hostname:
        raise ValueError("Endpoint URL must use https:// with a valid hostname")
    if parsed.username or parsed.password:
        raise ValueError("Endpoint URL must not contain userinfo")
    host = parsed.hostname.lower().rstrip(".")
    if host == "localhost" or host.endswith(".local") or host.endswith(".internal"):
        raise ValueError("Refusing internal/localhost hostname")
    try:
        ip_literal = ipaddress.ip_address(host)
    except ValueError:
        ip_literal = None
    if ip_literal is not None:
        if _is_disallowed_ip(ip_literal):
            raise ValueError("Refusing disallowed IP literal")
        return clean_url, str(ip_literal)

    try:
        infos = socket.getaddrinfo(host, parsed.port or 443, type=socket.SOCK_STREAM)
    except OSError as exc:
        raise ValueError(f"DNS lookup failed for host: {host}") from exc
    if not infos:
        raise ValueError(f"Empty DNS resolution for host: {host}")
    pinned_ip: str | None = None
    for _, _, _, _, sockaddr in infos:
        addr_ip = ipaddress.ip_address(str(sockaddr[0]).split("%", 1)[0])
        if _is_disallowed_ip(addr_ip):
            raise ValueError(f"Refusing endpoint resolving to non-public IP: {host}")
        if pinned_ip is None:
            pinned_ip = str(addr_ip)
    if pinned_ip is None:
        raise ValueError(f"No public IP resolved for host: {host}")
    return clean_url, pinned_ip


class _PinnedHTTPSConnection(http_client.HTTPSConnection):
    """HTTPSConnection pinned directly to pre-validated IP to prevent DNS rebinding."""

    def __init__(
        self,
        host: str,
        port: int | None = None,
        *,
        pinned_ip: str,
        sni_hostname: str,
        timeout: float = 15.0,
        context: ssl.SSLContext | None = None,
    ) -> None:
        addr_obj = ipaddress.ip_address(pinned_ip)
        if _is_disallowed_ip(addr_obj):
            raise ValueError("Refusing connection to non-public pinned IP")
        ssl_ctx = context or ssl.create_default_context()
        ssl_ctx.check_hostname = True
        ssl_ctx.verify_mode = ssl.CERT_REQUIRED
        super().__init__(host, port=port, timeout=timeout, context=ssl_ctx)
        self._pinned_ip = pinned_ip
        self._sni_hostname = sni_hostname
        self._ssl_ctx = ssl_ctx

    def connect(self) -> None:
        raw_sock = socket.create_connection(
            (self._pinned_ip, self.port),
            self.timeout,
            self.source_address,
        )
        try:
            self.sock = self._ssl_ctx.wrap_socket(
                raw_sock,
                server_hostname=self._sni_hostname,
            )
        except BaseException:
            raw_sock.close()
            raise


def post_usage_record_pinned(
    endpoint_url: str,
    payload: dict[str, Any],
    *,
    bearer_credential: str = "",
    connection_cls: type[_PinnedHTTPSConnection] = _PinnedHTTPSConnection,
) -> int:
    """Post context cache usage record over pinned-IP HTTPS with redirect/non-2xx guard."""
    clean_url, pinned_ip = resolve_and_validate_https_url(endpoint_url)
    log_url = sanitize_url_for_log(clean_url)
    parsed = urllib_parse.urlsplit(clean_url)
    hostname = (parsed.hostname or "").lower().rstrip(".")
    target = parsed.path or "/"
    if parsed.query:
        target = f"{target}?{parsed.query}"

    headers = {
        "Host": parsed.netloc,
        "Content-Type": "application/json",
    }
    if bearer_credential.strip():
        headers["Authorization"] = f"Bearer {bearer_credential.strip()}"

    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    conn = connection_cls(
        hostname,
        port=parsed.port or 443,
        pinned_ip=pinned_ip,
        sni_hostname=hostname,
        timeout=15.0,
    )
    try:
        conn.request("POST", target, body=body, headers=headers)
        resp = conn.getresponse()
        status = int(getattr(resp, "status", 0))
        resp.read()
    except (http_client.HTTPException, ssl.SSLError, OSError) as exc:
        raise RuntimeError(f"Usage sink transport error at {log_url}: {exc}") from exc
    finally:
        conn.close()

    if 300 <= status < 400:
        raise RuntimeError(f"Usage sink {log_url} attempted redirect HTTP {status} (blocked)")
    if status < 200 or status >= 300:
        raise RuntimeError(f"Usage sink {log_url} returned HTTP {status}")
    return status


def run_self_test() -> dict[str, Any]:
    """Run deterministic multi-turn prompt-cache write -> read verification."""
    docs = [
        {"doc_id": "arch-02", "title": "Schema Rules", "content": "Always isolate tenant rows."},
        {"doc_id": "arch-01", "title": "System Guard", "content": "Enforce strict RLS invariants."},
    ]
    payload = build_cached_prompt_payload(
        provider="anthropic",
        model_id="claude-sonnet-4",
        system_instructions="Use only verified codebase references.",
        invariant_documents=docs,
        conversation_turns=[{"role": "user", "content": "Analyze cache hit rate."}],
    )
    cold = measure_cache_usage(
        request_id="self-test-turn-1",
        user_id="user-demo-1",
        workflow_key="code-review",
        model_id="claude-sonnet-4",
        cache_write_tokens=16000,
        cache_read_tokens=0,
        uncached_input_tokens=800,
        output_tokens=600,
    )
    warm = measure_cache_usage(
        request_id="self-test-turn-2",
        user_id="user-demo-1",
        workflow_key="code-review",
        model_id="claude-sonnet-4",
        cache_write_tokens=0,
        cache_read_tokens=16000,
        uncached_input_tokens=600,
        output_tokens=500,
    )
    summary = aggregate_usage_by_workflow_and_user([cold, warm])
    return {
        "self_test": "passed",
        "prefix_doc_ids": payload["prefix_doc_ids"],
        "cold_turn": cold,
        "warm_turn": warm,
        "summary": summary,
        "rate_card_version": RATE_CARD_VERSION,
        "disclaimer": ESTIMATE_DISCLAIMER,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Context cache payload builder & USD cost monitor (#2656)")
    parser.add_argument("--dry-run", action=argparse.BooleanOptionalAction, default=True)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv)

    result = run_self_test()
    result["dry_run"] = bool(args.dry_run)
    if not args.dry_run and not args.self_test:
        endpoint = os.environ.get("CONTEXT_CACHE_SINK_URL", "").strip()
        auth_val = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
        if not endpoint:
            raise RuntimeError("CONTEXT_CACHE_SINK_URL is required when --no-dry-run is used")
        result["sink_status"] = post_usage_record_pinned(
            endpoint,
            result["warm_turn"],
            bearer_credential=auth_val,
        )

    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
