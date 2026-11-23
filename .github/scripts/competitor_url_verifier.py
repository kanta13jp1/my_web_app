#!/usr/bin/env python3
"""
competitor_url_verifier.py - SSRF-safe HTTP status checker for AI-discovered source URLs (#2698).
Flags non-2xx/3xx responses (e.g., 404), network failures, or invalid/unsafe URLs with needs_manual_review=True.
"""
from __future__ import annotations

import datetime as dt
import ipaddress
import urllib.error
import urllib.parse
import urllib.request
from typing import Any, Callable

DEFAULT_TIMEOUT_SECONDS = 5.0
USER_AGENT = "JibunCompany-CompetitorVerifier/1.0"


def is_safe_public_http_url(raw_url: str | None) -> tuple[bool, str | None, str | None]:
    """Validate scheme and reject loopback/private/link-local/internal hosts."""
    if not raw_url or not isinstance(raw_url, str):
        return False, None, "Empty source URL"
    candidate = raw_url.strip()
    if not candidate:
        return False, None, "Empty source URL"

    parsed = urllib.parse.urlparse(candidate)
    if parsed.scheme.lower() not in ("http", "https"):
        return False, None, f"Unsupported URL scheme: {parsed.scheme or 'none'}"
    if parsed.username or parsed.password:
        return False, None, "Credentials in URL are not allowed"

    host = (parsed.hostname or "").strip().lower()
    if not host:
        return False, None, "Missing hostname"
    if host in ("localhost", "localhost.localdomain") or host.endswith((".local", ".internal")):
        return False, None, f"Blocked local/internal host: {host}"

    try:
        ip = ipaddress.ip_address(host)
        if (
            ip.is_private
            or ip.is_loopback
            or ip.is_link_local
            or ip.is_multicast
            or ip.is_reserved
            or ip.is_unspecified
        ):
            return False, None, f"Blocked non-public IP address: {host}"
    except ValueError:
        pass

    return True, candidate, None


def verify_source_url(
    raw_url: str | None,
    *,
    opener: Callable[..., Any] = urllib.request.urlopen,
    timeout: float = DEFAULT_TIMEOUT_SECONDS,
    checked_at: str | None = None,
) -> dict[str, Any]:
    """Check source URL reachability via HEAD (with GET fallback on 405/501)."""
    timestamp = checked_at or dt.datetime.now(dt.timezone.utc).isoformat()
    safe, normalized_url, err = is_safe_public_http_url(raw_url)
    if not safe or normalized_url is None:
        return {
            "source_url_status_code": None,
            "source_url_checked_at": timestamp,
            "source_url_error": err or "Invalid URL",
            "needs_manual_review": True,
        }

    def _probe(method: str) -> tuple[int | None, str | None]:
        req = urllib.request.Request(
            normalized_url,
            headers={"User-Agent": USER_AGENT},
            method=method,
        )
        try:
            with opener(req, timeout=timeout) as resp:
                code = int(getattr(resp, "status", 200) or 200)
                return code, None
        except urllib.error.HTTPError as http_err:
            return int(http_err.code), f"HTTP {http_err.code}: {http_err.reason}"
        except Exception as exc:
            return None, str(exc)[:200]

    status_code, probe_err = _probe("HEAD")
    if status_code in (405, 501):
        status_code, probe_err = _probe("GET")

    reachable = status_code is not None and 200 <= status_code < 400
    return {
        "source_url_status_code": status_code,
        "source_url_checked_at": timestamp,
        "source_url_error": None if reachable else (probe_err or f"HTTP {status_code}"),
        "needs_manual_review": not reachable,
    }
