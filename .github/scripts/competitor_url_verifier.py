#!/usr/bin/env python3
"""
competitor_url_verifier.py - SSRF-safe HTTP status checker for AI-discovered source URLs (#2698).
Flags non-2xx/3xx responses (e.g., 404), DNS/IP SSRF targets, unsafe redirects, or network errors with needs_manual_review=True.
"""
from __future__ import annotations

import datetime as dt
import ipaddress
import socket
import urllib.error
import urllib.parse
import urllib.request
from typing import Any, Callable

DEFAULT_TIMEOUT_SECONDS = 5.0
MAX_REDIRECT_HOPS = 5
REDIRECT_STATUSES = {301, 302, 303, 307, 308}
USER_AGENT = "JibunCompany-CompetitorVerifier/1.0"


def _is_blocked_ip(raw_ip: str) -> bool:
    clean = raw_ip.strip().strip("[]").split("%", 1)[0]
    try:
        ip = ipaddress.ip_address(clean)
    except ValueError:
        return True
    mapped = getattr(ip, "ipv4_mapped", None)
    if mapped is not None:
        return _is_blocked_ip(str(mapped))
    return bool(
        not ip.is_global
        or ip.is_private
        or ip.is_loopback
        or ip.is_link_local
        or ip.is_multicast
        or ip.is_reserved
        or ip.is_unspecified
    )


def default_resolve_ips(hostname: str) -> list[str]:
    infos = socket.getaddrinfo(hostname, None, type=socket.SOCK_STREAM)
    return [str(info[4][0]) for info in infos if info[4]]


def is_safe_public_http_url(
    raw_url: str | None,
    *,
    resolver: Callable[[str], list[str]] | None = None,
) -> tuple[bool, str | None, str | None]:
    """Validate scheme, reject loopback/private/IPv6 local hosts, and validate DNS resolution."""
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

    host = (parsed.hostname or "").strip().lower().split("%", 1)[0]
    if not host:
        return False, None, "Missing hostname"
    if (
        host in ("localhost", "localhost.localdomain")
        or host.endswith((".localhost", ".local", ".internal"))
    ):
        return False, None, f"Blocked local/internal host: {host}"

    try:
        ipaddress.ip_address(host)
        is_literal = True
    except ValueError:
        is_literal = False

    if is_literal:
        if _is_blocked_ip(host):
            return False, None, f"Blocked non-public IP address: {host}"
    elif resolver is not None:
        try:
            ips = resolver(host)
        except Exception:
            return False, None, f"DNS lookup failed for {host}"
        if not ips:
            return False, None, f"DNS returned no records for {host}"
        for ip in ips:
            if _is_blocked_ip(ip):
                return False, None, f"DNS resolved to blocked IP: {ip}"

    return True, candidate, None


class _NoRedirectHandler(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):  # type: ignore[override]
        return None


def _default_no_redirect_opener(req: urllib.request.Request, timeout: float = DEFAULT_TIMEOUT_SECONDS) -> Any:
    opener = urllib.request.build_opener(_NoRedirectHandler())
    return opener.open(req, timeout=timeout)


def verify_source_url(
    raw_url: str | None,
    *,
    opener: Callable[..., Any] | None = None,
    resolver: Callable[[str], list[str]] | None = None,
    timeout: float = DEFAULT_TIMEOUT_SECONDS,
    checked_at: str | None = None,
) -> dict[str, Any]:
    """Check source URL reachability via HEAD (GET fallback on 405/501) with per-hop SSRF validation."""
    timestamp = checked_at or dt.datetime.now(dt.timezone.utc).isoformat()
    effective_opener = opener or _default_no_redirect_opener
    effective_resolver = resolver if resolver is not None else default_resolve_ips

    current_url = raw_url
    method = "HEAD"
    hop = 0

    while hop <= MAX_REDIRECT_HOPS:
        safe, normalized_url, err = is_safe_public_http_url(
            current_url, resolver=effective_resolver
        )
        if not safe or normalized_url is None:
            return {
                "source_url_status_code": None,
                "source_url_checked_at": timestamp,
                "source_url_error": err or "Invalid URL",
                "needs_manual_review": True,
            }

        req = urllib.request.Request(
            normalized_url,
            headers={"User-Agent": USER_AGENT},
            method=method,
        )
        status_code: int | None = None
        location: str | None = None
        probe_err: str | None = None

        try:
            with effective_opener(req, timeout=timeout) as resp:
                status_code = int(getattr(resp, "status", 200) or 200)
                headers = getattr(resp, "headers", None)
                if headers is not None and hasattr(headers, "get"):
                    location = headers.get("Location") or headers.get("location")
        except urllib.error.HTTPError as http_err:
            status_code = int(http_err.code)
            probe_err = f"HTTP {http_err.code}: {http_err.reason}"
            if http_err.headers is not None:
                location = http_err.headers.get("Location") or http_err.headers.get("location")
        except Exception as exc:
            return {
                "source_url_status_code": None,
                "source_url_checked_at": timestamp,
                "source_url_error": str(exc)[:200],
                "needs_manual_review": True,
            }

        if method == "HEAD" and status_code in (405, 501):
            method = "GET"
            continue

        if status_code in REDIRECT_STATUSES:
            if not location or not str(location).strip():
                return {
                    "source_url_status_code": status_code,
                    "source_url_checked_at": timestamp,
                    "source_url_error": f"HTTP {status_code} missing Location",
                    "needs_manual_review": True,
                }
            if hop >= MAX_REDIRECT_HOPS:
                return {
                    "source_url_status_code": status_code,
                    "source_url_checked_at": timestamp,
                    "source_url_error": "Too many redirects",
                    "needs_manual_review": True,
                }
            current_url = urllib.parse.urljoin(normalized_url, str(location).strip())
            hop += 1
            continue

        reachable = status_code is not None and 200 <= status_code < 400
        return {
            "source_url_status_code": status_code,
            "source_url_checked_at": timestamp,
            "source_url_error": None if reachable else (probe_err or f"HTTP {status_code}"),
            "needs_manual_review": not reachable,
        }

    return {
        "source_url_status_code": None,
        "source_url_checked_at": timestamp,
        "source_url_error": "Too many redirects",
        "needs_manual_review": True,
    }
