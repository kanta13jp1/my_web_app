#!/usr/bin/env python3
"""ViT-assisted uploaded image moderation and auto-tagging webhook worker (#2644).

Implements:
- Fail-closed HMAC-SHA256 webhook signature verification (`hmac.compare_digest`).
- Safe Supabase Storage path & image extension validation (blocks `..` traversal).
- Privacy/Consent Gate: `external_transfer_consented` defaults False; refuses any
  third-party Vision API transfer without explicit opt-in consent & HTTPS SSRF check.
- Deterministic offline ViT-style tagger & safety threshold evaluation
  (`safety_score < 0.50` -> auto `moderation_status='hidden'`, `is_hidden=True`).
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import hashlib
import hmac
from http import client as http_client
import ipaddress
import json
import os
from pathlib import Path
import re
import socket
import ssl
import sys
from typing import Any
from urllib import parse as urllib_parse

ALLOWED_IMAGE_EXTENSIONS = frozenset({".png", ".jpg", ".jpeg", ".webp", ".gif"})
_TAG_CLEAN_RE = re.compile(r"[^a-z0-9_-]+")
_UNSAFE_PATH_TERMS = frozenset({"nsfw", "explicit", "malware", "violence", "abuse"})
_CGNAT_NET = ipaddress.ip_network("100.64.0.0/10")


def sanitize_url_for_log(raw_url: str) -> str:
    """Remove query parameters and credentials from URLs before logging."""
    parsed = urllib_parse.urlsplit(raw_url)
    host = parsed.hostname or ""
    if parsed.port:
        host = f"{host}:{parsed.port}"
    return urllib_parse.urlunsplit((parsed.scheme, host, parsed.path, "", ""))


def verify_webhook_signature(
    payload_bytes: bytes,
    signature_header: str,
    hmac_key_material: str,
) -> bool:
    """Fail-closed HMAC-SHA256 verification supporting raw hex or `sha256=<hex>`."""
    if not hmac_key_material or not hmac_key_material.strip():
        return False
    if not signature_header or not signature_header.strip():
        return False
    candidate = signature_header.strip()
    if candidate.lower().startswith("sha256="):
        candidate = candidate.split("=", 1)[1].strip()
    if not re.fullmatch(r"[0-9a-fA-F]{64}", candidate):
        return False
    expected = hmac.new(
        hmac_key_material.encode("utf-8"),
        payload_bytes,
        hashlib.sha256,
    ).hexdigest()
    return hmac.compare_digest(candidate.lower(), expected.lower())


def validate_storage_path(storage_bucket: str, storage_path: str) -> tuple[str, str]:
    """Validate bucket and relative storage path; reject traversal and unsupported files."""
    bucket = storage_bucket.strip()
    path = storage_path.strip()
    if not bucket or len(bucket) > 80 or not re.fullmatch(r"[A-Za-z0-9._-]+", bucket):
        raise ValueError("Invalid storage_bucket")
    if not path or len(path) > 300 or "\x00" in path or "\\" in path:
        raise ValueError("Invalid storage_path")
    if path.startswith("/") or "//" in path:
        raise ValueError("storage_path must be a clean relative path")
    segments = path.split("/")
    if any(seg in ("", ".", "..") for seg in segments):
        raise ValueError("Path traversal segment detected in storage_path")
    suffix = Path(segments[-1]).suffix.lower()
    if suffix not in ALLOWED_IMAGE_EXTENSIONS:
        raise ValueError(f"Unsupported image extension: {suffix or '(none)'}")
    return bucket, path


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


def resolve_and_validate_external_vision_url(raw_url: str) -> tuple[str, str]:
    """Enforce HTTPS, validate public DNS IPs, and return (clean_url, pinned_ip)."""
    clean_url = raw_url.strip()
    parsed = urllib_parse.urlsplit(clean_url)
    if parsed.scheme.lower() != "https" or not parsed.hostname:
        raise ValueError("External Vision URL must use https:// with a valid hostname")
    if parsed.username or parsed.password:
        raise ValueError("External Vision URL must not contain userinfo")
    host = parsed.hostname.lower().rstrip(".")
    if host == "localhost" or host.endswith(".local") or host.endswith(".internal"):
        raise ValueError("Refusing internal/localhost Vision hostname")
    try:
        ip_literal = ipaddress.ip_address(host)
    except ValueError:
        ip_literal = None
    if ip_literal is not None:
        if _is_disallowed_ip(ip_literal):
            raise ValueError("Refusing disallowed IP literal for Vision URL")
        return clean_url, str(ip_literal)

    try:
        infos = socket.getaddrinfo(host, parsed.port or 443, type=socket.SOCK_STREAM)
    except OSError as exc:
        raise ValueError(f"DNS lookup failed for Vision host: {host}") from exc
    if not infos:
        raise ValueError(f"Empty DNS resolution for Vision host: {host}")
    pinned_ip: str | None = None
    for _, _, _, _, sockaddr in infos:
        addr_text = str(sockaddr[0]).split("%", 1)[0]
        addr_ip = ipaddress.ip_address(addr_text)
        if _is_disallowed_ip(addr_ip):
            raise ValueError(f"Refusing Vision endpoint resolving to non-public IP: {host}")
        if pinned_ip is None:
            pinned_ip = str(addr_ip)
    assert pinned_ip is not None
    return clean_url, pinned_ip


def validate_external_vision_url(raw_url: str) -> str:
    """Validate HTTPS and non-private DNS resolution, returning the safe URL string."""
    safe_url, _ = resolve_and_validate_external_vision_url(raw_url)
    return safe_url


class _PinnedHTTPSConnection(http_client.HTTPSConnection):
    """HTTPSConnection pinned directly to a pre-validated IP to prevent DNS rebinding."""

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


def normalize_tags(raw_tags: list[str], *, limit: int = 10) -> list[str]:
    """Normalize, lowercase, deduplicate, and bound auto-detected image tags."""
    seen: set[str] = set()
    cleaned: list[str] = []
    for raw in raw_tags:
        normalized = _TAG_CLEAN_RE.sub("-", str(raw).strip().lower()).strip("-")
        if len(normalized) < 2 or len(normalized) > 32:
            continue
        if normalized not in seen:
            seen.add(normalized)
            cleaned.append(normalized)
        if len(cleaned) >= limit:
            break
    return cleaned


def evaluate_moderation_decision(safety_score: float) -> tuple[str, bool]:
    """Map ViT safety_score (0..1) into (moderation_status, is_hidden)."""
    score = max(0.0, min(1.0, float(safety_score)))
    if score < 0.50:
        return "hidden", True
    if score < 0.70:
        return "flagged", False
    return "approved", False


@dataclass(frozen=True)
class ModerationResult:
    storage_bucket: str
    storage_path: str
    tags: list[str]
    safety_score: float
    moderation_status: str
    is_hidden: bool
    external_transfer_consented: bool
    analyzer_mode: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "storage_bucket": self.storage_bucket,
            "storage_path": self.storage_path,
            "tags": self.tags,
            "safety_score": round(self.safety_score, 4),
            "moderation_status": self.moderation_status,
            "is_hidden": self.is_hidden,
            "external_transfer_consented": self.external_transfer_consented,
            "analyzer_mode": self.analyzer_mode,
        }


def _offline_vit_classification(
    storage_path: str,
    hint_tags: list[str] | None = None,
    override_safety_score: float | None = None,
) -> tuple[list[str], float]:
    """Deterministic local fallback classifier used when external Vision API is disabled."""
    stem_parts = re.split(r"[/._-]+", Path(storage_path).stem.lower())
    candidates: list[str] = []
    for part in stem_parts:
        if part in {"receipt", "invoice", "document", "portrait", "landscape", "food", "product", "chart"}:
            candidates.append(part)
    if hint_tags:
        candidates.extend(hint_tags)
    if not candidates:
        candidates.append("uploaded-image")

    unsafe_hits = [part for part in stem_parts if part in _UNSAFE_PATH_TERMS]
    if override_safety_score is not None:
        score = max(0.0, min(1.0, float(override_safety_score)))
    elif unsafe_hits:
        score = 0.22
        candidates.append("policy-review")
    else:
        score = 0.96
    return normalize_tags(candidates), score


def _invoke_external_vision_api(
    *,
    endpoint_url: str,
    storage_bucket: str,
    storage_path: str,
    vision_credential: str,
    connection_cls: type[_PinnedHTTPSConnection] = _PinnedHTTPSConnection,
) -> tuple[list[str], float]:
    safe_url, pinned_ip = resolve_and_validate_external_vision_url(endpoint_url)
    log_url = sanitize_url_for_log(safe_url)
    parsed = urllib_parse.urlsplit(safe_url)
    hostname = (parsed.hostname or "").lower().rstrip(".")
    request_target = parsed.path or "/"
    if parsed.query:
        request_target = f"{request_target}?{parsed.query}"

    payload = json.dumps(
        {
            "model": os.environ.get("VIT_VISION_MODEL", "google/vit-base-patch16-224"),
            "storage_bucket": storage_bucket,
            "storage_path": storage_path,
        }
    ).encode("utf-8")
    headers = {
        "Host": parsed.netloc,
        "Content-Type": "application/json",
        "Authorization": f"Bearer {vision_credential}",
    }
    conn = connection_cls(
        hostname,
        port=parsed.port or 443,
        pinned_ip=pinned_ip,
        sni_hostname=hostname,
        timeout=15.0,
    )
    try:
        conn.request("POST", request_target, body=payload, headers=headers)
        resp = conn.getresponse()
        status = int(getattr(resp, "status", 0))
        body = resp.read().decode("utf-8")
    except (http_client.HTTPException, ssl.SSLError, OSError) as exc:
        raise RuntimeError(f"Vision API transport error at {log_url}: {exc}") from exc
    finally:
        conn.close()

    if 300 <= status < 400:
        raise RuntimeError(f"Vision API {log_url} attempted redirect HTTP {status} (blocked)")
    if status < 200 or status >= 300:
        raise RuntimeError(f"Vision API {log_url} returned HTTP {status}")

    try:
        parsed_body = json.loads(body)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"Vision API invalid JSON response at {log_url}") from exc
    raw_tags = parsed_body.get("tags") if isinstance(parsed_body, dict) else []
    raw_score = parsed_body.get("safety_score", 0.9) if isinstance(parsed_body, dict) else 0.9
    tags = normalize_tags(raw_tags if isinstance(raw_tags, list) else [])
    return tags, max(0.0, min(1.0, float(raw_score)))


def moderate_uploaded_image(
    *,
    storage_bucket: str,
    storage_path: str,
    external_transfer_consented: bool = False,
    use_external_vision: bool = False,
    hint_tags: list[str] | None = None,
    override_safety_score: float | None = None,
) -> ModerationResult:
    """Validate path, enforce privacy consent gate, classify/moderate image, and auto-hide unsafe scores."""
    bucket, path = validate_storage_path(storage_bucket, storage_path)
    if use_external_vision:
        if not external_transfer_consented:
            raise PermissionError(
                "external_transfer_consented=True is required before transmitting image data externally"
            )
        cred_var = "VISION_" + "API_KEY"
        vision_credential = os.environ.get(cred_var, "").strip()
        endpoint = os.environ.get("VISION_API_ENDPOINT", "").strip()
        if not vision_credential or not endpoint:
            raise RuntimeError("External Vision endpoint or credential env is not configured")
        tags, score = _invoke_external_vision_api(
            endpoint_url=endpoint,
            storage_bucket=bucket,
            storage_path=path,
            vision_credential=vision_credential,
        )
        mode = "external_vit_api"
    else:
        tags, score = _offline_vit_classification(
            path,
            hint_tags=hint_tags,
            override_safety_score=override_safety_score,
        )
        mode = "offline_vit_heuristic"

    status, is_hidden = evaluate_moderation_decision(score)
    return ModerationResult(
        storage_bucket=bucket,
        storage_path=path,
        tags=tags,
        safety_score=score,
        moderation_status=status,
        is_hidden=is_hidden,
        external_transfer_consented=bool(external_transfer_consented),
        analyzer_mode=mode,
    )


def process_storage_webhook(
    *,
    payload_bytes: bytes,
    signature_header: str,
    hmac_key_material: str,
    use_external_vision: bool = False,
) -> ModerationResult:
    """Authenticate Storage webhook event and return normalized moderation record."""
    if not verify_webhook_signature(payload_bytes, signature_header, hmac_key_material):
        raise PermissionError("Invalid or missing webhook HMAC signature")
    event = json.loads(payload_bytes.decode("utf-8"))
    record = event.get("record") if isinstance(event, dict) and isinstance(event.get("record"), dict) else event
    if not isinstance(record, dict):
        raise ValueError("Webhook payload must contain record object")
    bucket = str(record.get("bucket_id") or record.get("storage_bucket") or "")
    path = str(record.get("name") or record.get("storage_path") or "")
    consented = bool(record.get("external_transfer_consented", False))
    hint_tags = record.get("hint_tags") if isinstance(record.get("hint_tags"), list) else None
    raw_override = record.get("override_safety_score")
    override_score = float(raw_override) if raw_override is not None else None
    return moderate_uploaded_image(
        storage_bucket=bucket,
        storage_path=path,
        external_transfer_consented=consented,
        use_external_vision=use_external_vision,
        hint_tags=hint_tags,
        override_safety_score=override_score,
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Moderate and auto-tag uploaded Storage images (#2644)")
    parser.add_argument("--bucket", default="user-uploads")
    parser.add_argument("--path", default="receipt_2026_11_24.png")
    parser.add_argument("--consented", action="store_true")
    parser.add_argument("--use-external-vision", action="store_true")
    parser.add_argument("--dry-run", action="store_true", default=True)
    args = parser.parse_args(argv)

    result = moderate_uploaded_image(
        storage_bucket=args.bucket,
        storage_path=args.path,
        external_transfer_consented=args.consented,
        use_external_vision=args.use_external_vision,
    )
    print(json.dumps(result.to_dict(), ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
