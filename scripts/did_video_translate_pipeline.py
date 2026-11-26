#!/usr/bin/env python3
"""D-ID Video Translate multilingual lip-sync automation pipeline (#2660).

Implements safe request planning, fail-closed duration and estimated USD cost
guardrails, SSRF-pinned HTTPS calls to D-ID (`/translations` & `/translations/{id}`),
and deterministic dry-run / self-test diagnostics without logging secrets.
"""

from __future__ import annotations

import argparse
import http.client
import ipaddress
import json
import os
import re
import socket
import ssl
import sys
import urllib.parse
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


DID_API_BASE_URL = "https://api.d-id.com"
DEFAULT_DURATION_RATE_USD_PER_SEC = 0.035
DEFAULT_MAX_DURATION_CAP_SECONDS = 120
HARD_MAX_DURATION_CAP_SECONDS = 600
DEFAULT_MAX_COST_CAP_USD = 5.0
ALLOWED_RESULT_STATUSES = ("validating", "processing", "done", "rejected", "error")

# Verified against https://docs.d-id.com/reference/createvideotranslate
BCP47_TO_DID_LANGUAGE: dict[str, str] = {
    "ar": "Arabic",
    "bg": "Bulgarian",
    "zh": "Chinese",
    "hr": "Croatian",
    "cs": "Czech",
    "da": "Danish",
    "nl": "Dutch",
    "en": "English",
    "fil": "Filipino",
    "fi": "Finnish",
    "fr": "French",
    "de": "German",
    "el": "Greek",
    "hi": "Hindi",
    "id": "Indonesian",
    "it": "Italian",
    "ja": "Japanese",
    "ko": "Korean",
    "ms": "Malay",
    "pl": "Polish",
    "pt": "Portuguese",
    "ro": "Romanian",
    "ru": "Russian",
    "sk": "Slovak",
    "es": "Spanish",
    "sv": "Swedish",
    "ta": "Tamil",
    "tr": "Turkish",
    "uk": "Ukrainian",
}

DID_LANGUAGE_TO_BCP47: dict[str, str] = {
    name.lower(): code for code, name in BCP47_TO_DID_LANGUAGE.items()
}

_LANGUAGE_CODE_PATTERN = re.compile(r"^[a-z]{2,3}(?:-[A-Za-z0-9]{2,8})?$")


class SecurityValidationError(ValueError):
    """Raised when an external URL, host, or cap validation fails."""


class CapExceededError(ValueError):
    """Raised fail-closed when duration or estimated cost exceeds configured caps."""


@dataclass(frozen=True)
class TranslationPlan:
    source_video_id: str
    source_video_url: str
    language_codes: tuple[str, ...]
    did_languages: tuple[str, ...]
    source_language: str | None
    duration_seconds: float
    max_duration_cap_seconds: int
    estimated_cost_usd: float
    max_cost_cap_usd: float
    webhook_url: str | None


def sanitize_url_for_log(raw_url: str) -> str:
    """Strip credentials, query parameters, and fragments before logging URLs."""
    parsed = urllib.parse.urlsplit(raw_url.strip())
    host = parsed.hostname or ""
    if parsed.port:
        host = f"{host}:{parsed.port}"
    return urllib.parse.urlunsplit((parsed.scheme, host, parsed.path, "", ""))


_CGNAT_NETWORK = ipaddress.ip_network("100.64.0.0/10")


def _is_blocked_ip(ip_obj: ipaddress._BaseAddress) -> bool:
    if isinstance(ip_obj, ipaddress.IPv6Address) and ip_obj.ipv4_mapped is not None:
        return _is_blocked_ip(ip_obj.ipv4_mapped)
    if isinstance(ip_obj, ipaddress.IPv4Address) and ip_obj in _CGNAT_NETWORK:
        return True
    return (
        not ip_obj.is_global
        or ip_obj.is_private
        or ip_obj.is_loopback
        or ip_obj.is_link_local
        or ip_obj.is_multicast
        or ip_obj.is_reserved
        or ip_obj.is_unspecified
    )


def resolve_and_validate_https_url(raw_url: str, *, label: str = "url") -> tuple[urllib.parse.SplitResult, list[str]]:
    """Validate an HTTPS URL and resolve its public IPs without SSRF bypass."""
    candidate = raw_url.strip()
    parsed = urllib.parse.urlsplit(candidate)
    if parsed.scheme.lower() != "https" or not parsed.hostname:
        raise SecurityValidationError(f"{label} must be a valid https:// URL")
    if parsed.username or parsed.password:
        raise SecurityValidationError(f"{label} must not embed userinfo credentials")

    host = parsed.hostname
    port = parsed.port or 443
    try:
        ipaddress.ip_address(host)
    except ValueError:
        pass
    else:
        raise SecurityValidationError(f"{label} must use a DNS hostname rather than a literal IP")

    try:
        addr_info = socket.getaddrinfo(host, port, type=socket.SOCK_STREAM)
    except socket.gaierror as exc:
        raise SecurityValidationError(
            f"DNS lookup failed for {label} host '{host}': {exc}"
        ) from exc

    resolved_ips: list[str] = []
    for entry in addr_info:
        ip_text = entry[4][0].split("%")[0]
        ip_obj = ipaddress.ip_address(ip_text)
        if _is_blocked_ip(ip_obj):
            raise SecurityValidationError(
                f"{label} host '{host}' resolved to blocked non-public IP '{ip_text}'"
            )
        if ip_text not in resolved_ips:
            resolved_ips.append(ip_text)

    if not resolved_ips:
        raise SecurityValidationError(f"{label} host '{host}' resolved to no addresses")
    return parsed, resolved_ips


def _validate_https_syntax_only(raw_url: str, *, label: str) -> str:
    candidate = raw_url.strip()
    parsed = urllib.parse.urlsplit(candidate)
    if parsed.scheme.lower() != "https" or not parsed.hostname:
        raise SecurityValidationError(f"{label} must be a valid https:// URL")
    if parsed.username or parsed.password:
        raise SecurityValidationError(f"{label} must not embed userinfo credentials")
    if re.search(r"\s", candidate):
        raise SecurityValidationError(f"{label} must not contain whitespace")
    try:
        ipaddress.ip_address(parsed.hostname)
    except ValueError:
        pass
    else:
        raise SecurityValidationError(f"{label} must not be a raw IP literal")
    return candidate


class _PinnedHTTPSConnection(http.client.HTTPSConnection):
    """HTTPSConnection pinned to a pre-validated public IP with strict TLS."""

    def __init__(
        self,
        host: str,
        port: int,
        pinned_ip: str,
        *,
        timeout: int = 20,
    ) -> None:
        context = ssl.create_default_context()
        context.minimum_version = ssl.TLSVersion.TLSv1_2
        context.verify_mode = ssl.CERT_REQUIRED
        context.check_hostname = True
        super().__init__(host, port=port, timeout=timeout, context=context)
        self._pinned_ip = pinned_ip
        self._server_hostname = host

    def connect(self) -> None:
        raw_sock = socket.create_connection((self._pinned_ip, self.port), self.timeout)
        try:
            self.sock = self._context.wrap_socket(
                raw_sock,
                server_hostname=self._server_hostname,
            )
        except Exception:
            raw_sock.close()
            raise


def pinned_https_json_request(
    method: str,
    url: str,
    *,
    headers: dict[str, str],
    body: dict[str, Any] | None = None,
    timeout: int = 20,
) -> dict[str, Any]:
    """Perform a single SSRF-pinned HTTPS JSON request (no 3xx redirects)."""
    parsed, resolved_ips = resolve_and_validate_https_url(url, label="api_url")
    host = parsed.hostname or ""
    port = parsed.port or 443
    path = parsed.path or "/"
    if parsed.query:
        path = f"{path}?{parsed.query}"

    payload_bytes: bytes | None = None
    req_headers = dict(headers)
    req_headers["Host"] = f"{host}:{port}" if parsed.port else host
    req_headers.setdefault("Accept", "application/json")
    if body is not None:
        payload_bytes = json.dumps(body).encode("utf-8")
        req_headers.setdefault("Content-Type", "application/json")
        req_headers["Content-Length"] = str(len(payload_bytes))

    conn = _PinnedHTTPSConnection(host, port, resolved_ips[0], timeout=timeout)
    try:
        conn.request(method.upper(), path, body=payload_bytes, headers=req_headers)
        resp = conn.getresponse()
        raw = resp.read().decode("utf-8", errors="replace")
        if 300 <= resp.status < 400:
            raise SecurityValidationError(
                f"Redirects are disallowed for {sanitize_url_for_log(url)} (HTTP {resp.status})"
            )
        if not (200 <= resp.status < 300):
            raise RuntimeError(
                f"D-ID API returned HTTP {resp.status} for {sanitize_url_for_log(url)}"
            )
        return json.loads(raw) if raw else {}
    finally:
        conn.close()


def normalize_target_languages(raw_languages: list[str] | tuple[str, ...]) -> tuple[tuple[str, ...], tuple[str, ...]]:
    """Convert BCP-47 codes or language names into canonical (bcp47, did_name) tuples."""
    bcp47_codes: list[str] = []
    did_names: list[str] = []
    for item in raw_languages:
        cleaned = item.strip()
        if not cleaned:
            continue
        lowered = cleaned.lower()
        if lowered in DID_LANGUAGE_TO_BCP47:
            code = DID_LANGUAGE_TO_BCP47[lowered]
            name = BCP47_TO_DID_LANGUAGE[code]
        else:
            if not _LANGUAGE_CODE_PATTERN.match(cleaned):
                raise ValueError(f"Unsupported language identifier: '{cleaned}'")
            base = lowered.split("-")[0]
            if base not in BCP47_TO_DID_LANGUAGE:
                raise ValueError(f"Language '{cleaned}' is not supported by D-ID Video Translate")
            code = lowered
            name = BCP47_TO_DID_LANGUAGE[base]
        if code not in bcp47_codes:
            bcp47_codes.append(code)
            did_names.append(name)

    if not bcp47_codes:
        raise ValueError("At least one valid target language is required")
    return tuple(bcp47_codes), tuple(did_names)


def estimate_translation_cost_usd(
    duration_seconds: float,
    target_language_count: int,
    *,
    rate_usd_per_sec: float = DEFAULT_DURATION_RATE_USD_PER_SEC,
) -> float:
    """Return estimated USD compute cost (disclaimer: estimate only, not invoiced billing)."""
    if duration_seconds <= 0:
        raise ValueError("duration_seconds must be greater than 0")
    if target_language_count <= 0:
        raise ValueError("target_language_count must be greater than 0")
    if rate_usd_per_sec < 0:
        raise ValueError("rate_usd_per_sec cannot be negative")
    return round(duration_seconds * target_language_count * rate_usd_per_sec, 6)


def build_translation_plan(
    *,
    source_video_id: str,
    source_video_url: str,
    languages: list[str],
    duration_seconds: float,
    max_duration_cap_seconds: int = DEFAULT_MAX_DURATION_CAP_SECONDS,
    max_cost_cap_usd: float = DEFAULT_MAX_COST_CAP_USD,
    source_language: str | None = None,
    webhook_url: str | None = None,
    rate_usd_per_sec: float = DEFAULT_DURATION_RATE_USD_PER_SEC,
) -> TranslationPlan:
    """Validate URLs, target languages, and fail-closed duration/cost caps."""
    vid = source_video_id.strip()
    if not vid:
        raise ValueError("source_video_id must not be empty")
    safe_source_url = _validate_https_syntax_only(source_video_url, label="source_video_url")

    safe_webhook: str | None = None
    if webhook_url and webhook_url.strip():
        safe_webhook = _validate_https_syntax_only(webhook_url, label="webhook_url")

    if max_duration_cap_seconds <= 0 or max_duration_cap_seconds > HARD_MAX_DURATION_CAP_SECONDS:
        raise CapExceededError(
            f"max_duration_cap_seconds={max_duration_cap_seconds} must be between 1 and {HARD_MAX_DURATION_CAP_SECONDS}"
        )
    if duration_seconds <= 0:
        raise CapExceededError("duration_seconds must be positive")
    if duration_seconds > max_duration_cap_seconds:
        raise CapExceededError(
            f"Video duration {duration_seconds:.2f}s exceeds cap {max_duration_cap_seconds}s"
        )
    if max_cost_cap_usd < 0:
        raise CapExceededError("max_cost_cap_usd cannot be negative")

    bcp47_codes, did_names = normalize_target_languages(languages)
    est_cost = estimate_translation_cost_usd(
        duration_seconds,
        len(bcp47_codes),
        rate_usd_per_sec=rate_usd_per_sec,
    )
    if est_cost > max_cost_cap_usd:
        raise CapExceededError(
            f"Estimated cost USD {est_cost:.6f} exceeds cap USD {max_cost_cap_usd:.6f}"
        )

    normalized_src_lang = source_language.strip() if source_language and source_language.strip() else None
    return TranslationPlan(
        source_video_id=vid,
        source_video_url=safe_source_url,
        language_codes=bcp47_codes,
        did_languages=did_names,
        source_language=normalized_src_lang,
        duration_seconds=round(float(duration_seconds), 2),
        max_duration_cap_seconds=int(max_duration_cap_seconds),
        estimated_cost_usd=est_cost,
        max_cost_cap_usd=round(float(max_cost_cap_usd), 6),
        webhook_url=safe_webhook,
    )


def build_create_translation_payload(plan: TranslationPlan) -> dict[str, Any]:
    """Build the D-ID POST /translations JSON body."""
    payload: dict[str, Any] = {
        "source_url": plan.source_video_url,
        "languages": list(plan.did_languages),
    }
    if plan.source_language:
        payload["source_language"] = plan.source_language
    if plan.webhook_url:
        payload["webhook"] = plan.webhook_url
    return payload


def create_translations_live(
    plan: TranslationPlan,
    *,
    auth_credential: str,
    base_url: str = DID_API_BASE_URL,
    request_fn: Any = pinned_https_json_request,
) -> dict[str, Any]:
    """Submit POST /translations to D-ID after verifying caps and HTTPS endpoints."""
    cred_val = auth_credential.strip()
    if not cred_val:
        raise ValueError("D-ID API key is required for --live execution")

    # Enforce SSRF IP resolution checks for source URL and optional webhook too.
    resolve_and_validate_https_url(plan.source_video_url, label="source_video_url")
    if plan.webhook_url:
        resolve_and_validate_https_url(plan.webhook_url, label="webhook_url")

    endpoint = f"{base_url.rstrip('/')}/translations"
    body = build_create_translation_payload(plan)
    headers = {"Authorization": f"Basic {cred_val}"}
    return request_fn("POST", endpoint, headers=headers, body=body)


def poll_translation_status_live(
    translation_id: str,
    *,
    auth_credential: str,
    base_url: str = DID_API_BASE_URL,
    request_fn: Any = pinned_https_json_request,
) -> dict[str, Any]:
    """Poll GET /translations/{id} and return normalized status fields."""
    tid = translation_id.strip()
    if not tid or not re.match(r"^[A-Za-z0-9_.-]+$", tid):
        raise ValueError("Invalid translation_id format")
    cred_val = auth_credential.strip()
    if not cred_val:
        raise ValueError("D-ID API key is required to poll D-ID translation status")

    endpoint = f"{base_url.rstrip('/')}/translations/{urllib.parse.quote(tid, safe='')}"
    data = request_fn("GET", endpoint, headers={"Authorization": f"Basic {cred_val}"})
    status = str(data.get("status") or "error")
    if status not in ALLOWED_RESULT_STATUSES:
        status = "error"
    return {
        "id": data.get("id", tid),
        "status": status,
        "result_url": data.get("result_url"),
        "subtitles_url": data.get("subtitles_url"),
        "thumbnail_url": data.get("thumbnail_url"),
        "group_id": data.get("group_id"),
    }


def simulate_dry_run_result(plan: TranslationPlan) -> dict[str, Any]:
    """Produce deterministic dry-run diagnostics and simulated D-ID response."""
    request_payload = build_create_translation_payload(plan)
    simulated_items = [
        {
            "id": f"dryrun_{plan.source_video_id}_{code}",
            "language_code": code,
            "did_language": did_name,
            "status": "dry_run",
            "group_id": f"grp_dryrun_{plan.source_video_id}",
            "result_url": None,
        }
        for code, did_name in zip(plan.language_codes, plan.did_languages)
    ]
    return {
        "mode": "dry-run",
        "status": "ok",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "source_video_id": plan.source_video_id,
        "source_video_url": sanitize_url_for_log(plan.source_video_url),
        "language_codes": list(plan.language_codes),
        "did_languages": list(plan.did_languages),
        "duration_seconds": plan.duration_seconds,
        "max_duration_cap_seconds": plan.max_duration_cap_seconds,
        "estimated_cost_usd": plan.estimated_cost_usd,
        "max_cost_cap_usd": plan.max_cost_cap_usd,
        "cost_disclaimer": "Estimated USD based on configured duration rate; not billed ledger data.",
        "request_payload_preview": {
            "source_url": sanitize_url_for_log(request_payload["source_url"]),
            "languages": request_payload["languages"],
            "has_webhook": bool(plan.webhook_url),
        },
        "translations": simulated_items,
    }


def render_markdown_report(result: dict[str, Any]) -> str:
    """Format pipeline diagnostics as concise GitHub-flavored Markdown."""
    lines = [
        "### D-ID Video Translate Multilingual Lip-Sync (#2660)",
        f"- Mode: `{result.get('mode', 'dry-run')}`",
        f"- Status: `{result.get('status', 'ok')}`",
        f"- Source Video: `{result.get('source_video_id')}` (`{result.get('source_video_url')}`)",
        f"- Target Languages: `{', '.join(result.get('did_languages', []))}`",
        (
            f"- Duration / Cap: `{result.get('duration_seconds')}s` / "
            f"`{result.get('max_duration_cap_seconds')}s`"
        ),
        (
            f"- Estimated Cost: `USD {result.get('estimated_cost_usd')}` / "
            f"`USD {result.get('max_cost_cap_usd')}` "
            f"({result.get('cost_disclaimer', '')})"
        ),
    ]
    return "\n".join(lines)


def run_self_test() -> dict[str, Any]:
    """Run deterministic offline self-test of language mapping, caps, and SSRF guard."""
    plan = build_translation_plan(
        source_video_id="intro_philosophy_01",
        source_video_url="https://example.com/media/intro.mp4?token=secret",
        languages=["ja", "en", "es", "fr"],
        duration_seconds=45.0,
        max_duration_cap_seconds=120,
        max_cost_cap_usd=10.0,
    )
    assert plan.did_languages == ("Japanese", "English", "Spanish", "French")

    cap_rejected = False
    try:
        build_translation_plan(
            source_video_id="too_long",
            source_video_url="https://example.com/media/long.mp4",
            languages=["ja", "en"],
            duration_seconds=300.0,
            max_duration_cap_seconds=120,
            max_cost_cap_usd=20.0,
        )
    except CapExceededError:
        cap_rejected = True
    assert cap_rejected

    cost_rejected = False
    try:
        build_translation_plan(
            source_video_id="too_expensive",
            source_video_url="https://example.com/media/expensive.mp4",
            languages=["ja", "en", "es", "fr"],
            duration_seconds=100.0,
            max_duration_cap_seconds=120,
            max_cost_cap_usd=1.0,
        )
    except CapExceededError:
        cost_rejected = True
    assert cost_rejected

    dry = simulate_dry_run_result(plan)
    assert len(dry["translations"]) == 4
    assert "?" not in dry["source_video_url"]
    return {
        "self_test": "passed",
        "languages_mapped": list(plan.did_languages),
        "estimated_cost_usd": plan.estimated_cost_usd,
        "duration_cap_rejected": cap_rejected,
        "cost_cap_rejected": cost_rejected,
    }


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-video-id", default="intro_philosophy_01")
    parser.add_argument(
        "--source-video-url",
        default="https://example.com/videos/jibun_company_intro.mp4",
    )
    parser.add_argument("--source-language", default=None)
    parser.add_argument("--languages", default="ja,en,es,fr")
    parser.add_argument("--duration-seconds", type=float, default=30.0)
    parser.add_argument(
        "--max-duration-cap-seconds",
        type=int,
        default=DEFAULT_MAX_DURATION_CAP_SECONDS,
    )
    parser.add_argument("--max-cost-cap-usd", type=float, default=DEFAULT_MAX_COST_CAP_USD)
    parser.add_argument("--webhook-url", default=None)
    parser.add_argument("--poll-id", default=None)
    parser.add_argument("--live", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--json-out", type=Path, default=None)
    parser.add_argument("--markdown-out", type=Path, default=None)
    parser.add_argument("--github-output", type=Path, default=None)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    if args.self_test:
        print(json.dumps(run_self_test(), ensure_ascii=False))
        return 0

    lang_list = [part.strip() for part in str(args.languages).split(",") if part.strip()]
    plan = build_translation_plan(
        source_video_id=args.source_video_id,
        source_video_url=args.source_video_url,
        languages=lang_list,
        duration_seconds=args.duration_seconds,
        max_duration_cap_seconds=args.max_duration_cap_seconds,
        max_cost_cap_usd=args.max_cost_cap_usd,
        source_language=args.source_language,
        webhook_url=args.webhook_url,
    )

    use_live = bool(args.live) and not bool(args.dry_run)
    if use_live:
        did_credential = os.environ.get("D_ID_API_KEY", "").strip()
        if args.poll_id:
            poll_res = poll_translation_status_live(
                args.poll_id,
                auth_credential=did_credential,
            )
            result: dict[str, Any] = {
                "mode": "live-poll",
                "status": poll_res["status"],
                "source_video_id": plan.source_video_id,
                "source_video_url": sanitize_url_for_log(plan.source_video_url),
                "language_codes": list(plan.language_codes),
                "did_languages": list(plan.did_languages),
                "duration_seconds": plan.duration_seconds,
                "max_duration_cap_seconds": plan.max_duration_cap_seconds,
                "estimated_cost_usd": plan.estimated_cost_usd,
                "max_cost_cap_usd": plan.max_cost_cap_usd,
                "cost_disclaimer": "Estimated USD; check D-ID dashboard for billed balance.",
                "poll_result": poll_res,
            }
        else:
            api_resp = create_translations_live(
                plan,
                auth_credential=did_credential,
            )
            result = {
                "mode": "live",
                "status": "submitted",
                "source_video_id": plan.source_video_id,
                "source_video_url": sanitize_url_for_log(plan.source_video_url),
                "language_codes": list(plan.language_codes),
                "did_languages": list(plan.did_languages),
                "duration_seconds": plan.duration_seconds,
                "max_duration_cap_seconds": plan.max_duration_cap_seconds,
                "estimated_cost_usd": plan.estimated_cost_usd,
                "max_cost_cap_usd": plan.max_cost_cap_usd,
                "cost_disclaimer": "Estimated USD; check D-ID dashboard for billed balance.",
                "translations": api_resp.get("translations", []),
            }
    else:
        result = simulate_dry_run_result(plan)

    if args.json_out:
        args.json_out.write_text(
            json.dumps(result, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    markdown = render_markdown_report(result)
    if args.markdown_out:
        args.markdown_out.write_text(markdown + "\n", encoding="utf-8")
    if args.github_output:
        with args.github_output.open("a", encoding="utf-8") as gh_out:
            gh_out.write(f"status={result.get('status', 'ok')}\n")
            gh_out.write(f"mode={result.get('mode', 'dry-run')}\n")
            gh_out.write(f"language_count={len(plan.did_languages)}\n")
            gh_out.write(f"estimated_cost_usd={plan.estimated_cost_usd}\n")
            gh_out.write(f"duration_seconds={plan.duration_seconds}\n")
    print(markdown)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
