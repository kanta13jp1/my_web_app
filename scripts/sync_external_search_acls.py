#!/usr/bin/env python3
"""External-source ACL sync & RLS-guarded prompt context builder (#2655).

Ensures that permission grants and revocations from external sources are
verified with HMAC-SHA256 before updating ACL metadata, and that unauthorized
or revoked documents are strictly excluded before vector/keyword ranking and
before constructing AI prompt context snippets.
"""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
import hashlib
import hmac
import http.client
import ipaddress
import json
import math
import os
from pathlib import Path
import socket
import ssl
import sys
from typing import Any
import urllib.parse

VALID_PERMISSIONS: frozenset[str] = frozenset({"viewer", "editor"})
VALID_ACL_ACTIONS: frozenset[str] = frozenset({"grant", "revoke"})


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


@dataclass(frozen=True)
class IndexedDocument:
    id: str
    owner_user_id: str
    external_source_key: str
    title: str
    content_excerpt: str
    acl_version: int = 1
    embedding: tuple[float, ...] = ()
    updated_at: str = ""

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True)
class DocumentAclGrant:
    document_id: str
    grantee_user_id: str
    permission_level: str = "viewer"
    granted_by_user_id: str = ""
    revoked_at: str | None = None
    updated_at: str = ""

    def is_active(self) -> bool:
        return self.revoked_at is None and self.permission_level in VALID_PERMISSIONS


@dataclass(frozen=True)
class AclDeltaEvent:
    external_source_key: str
    grantee_user_id: str
    action: str
    permission_level: str = "viewer"
    occurred_at: str = ""


@dataclass(frozen=True)
class AuthorizedSearchHit:
    document_id: str
    external_source_key: str
    title: str
    content_excerpt: str
    acl_version: int
    permission_source: str
    similarity_score: float


@dataclass(frozen=True)
class GuardedPromptBundle:
    caller_user_id: str
    query: str
    hits: tuple[AuthorizedSearchHit, ...]
    excluded_document_ids: tuple[str, ...]
    prompt_context: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "caller_user_id": self.caller_user_id,
            "query": self.query,
            "hits": [asdict(h) for h in self.hits],
            "excluded_count": len(self.excluded_document_ids),
            "excluded_document_ids": list(self.excluded_document_ids),
            "prompt_context": self.prompt_context,
        }


def compute_webhook_signature(raw_body: bytes, *, hmac_key: str) -> str:
    if not hmac_key.strip():
        raise ValueError("hmac_key must not be empty")
    digest = hmac.new(
        hmac_key.encode("utf-8"),
        raw_body,
        hashlib.sha256,
    ).hexdigest()
    return f"sha256={digest}"


def verify_webhook_signature(
    raw_body: bytes,
    signature_header: str | None,
    *,
    hmac_key: str,
) -> bool:
    """Verify HMAC-SHA256 webhook signature fail-closed using constant-time compare."""
    if not signature_header or not hmac_key.strip():
        return False
    expected = compute_webhook_signature(raw_body, hmac_key=hmac_key)
    return hmac.compare_digest(signature_header.strip(), expected)


def cosine_similarity(left: tuple[float, ...], right: tuple[float, ...]) -> float:
    if not left or not right or len(left) != len(right):
        return 0.0
    dot = sum(a * b for a, b in zip(left, right))
    norm_l = math.sqrt(sum(a * a for a in left))
    norm_r = math.sqrt(sum(b * b for b in right))
    if norm_l == 0.0 or norm_r == 0.0:
        return 0.0
    return max(0.0, min(1.0, dot / (norm_l * norm_r)))


def _lexical_score(query: str, doc: IndexedDocument) -> float:
    clean = query.strip().lower()
    if not clean:
        return 0.5
    haystack = f"{doc.title} {doc.content_excerpt} {doc.external_source_key}".lower()
    if clean in haystack:
        return 0.85
    terms = [part for part in clean.split() if part]
    if not terms:
        return 0.0
    matched = sum(1 for term in terms if term in haystack)
    return round(matched / len(terms) * 0.75, 4)


def resolve_user_permission(
    doc: IndexedDocument,
    acls: list[DocumentAclGrant],
    *,
    user_id: str,
) -> str | None:
    """Return 'owner', 'editor', 'viewer', or None if access is unauthorized/revoked."""
    clean_uid = user_id.strip()
    if not clean_uid:
        return None
    if doc.owner_user_id == clean_uid:
        return "owner"
    for entry in acls:
        if (
            entry.document_id == doc.id
            and entry.grantee_user_id == clean_uid
            and entry.is_active()
        ):
            return entry.permission_level
    return None


def apply_acl_delta(
    documents: dict[str, IndexedDocument],
    acls: list[DocumentAclGrant],
    event: AclDeltaEvent,
    *,
    actor_user_id: str,
    is_trusted_sync: bool = False,
) -> tuple[dict[str, IndexedDocument], list[DocumentAclGrant], IndexedDocument]:
    """Immediately apply an ACL grant or revocation and increment acl_version."""
    action = event.action.strip().lower()
    if action not in VALID_ACL_ACTIONS:
        raise ValueError(f"Unsupported ACL action: {event.action}")
    if event.permission_level not in VALID_PERMISSIONS:
        raise ValueError(f"Unsupported permission level: {event.permission_level}")

    target_doc: IndexedDocument | None = None
    for doc in documents.values():
        if doc.external_source_key == event.external_source_key.strip():
            target_doc = doc
            break
    if target_doc is None:
        raise KeyError(f"Unknown external_source_key: {event.external_source_key}")

    if not is_trusted_sync and target_doc.owner_user_id != actor_user_id.strip():
        raise PermissionError(
            "Only the document owner or verified sync webhook may change document ACLs"
        )

    clean_grantee = event.grantee_user_id.strip()
    if not clean_grantee:
        raise ValueError("grantee_user_id must not be empty")

    ts = event.occurred_at or utc_now_iso()
    updated_acls: list[DocumentAclGrant] = []
    matched = False
    for entry in acls:
        if entry.document_id == target_doc.id and entry.grantee_user_id == clean_grantee:
            matched = True
            updated_acls.append(
                DocumentAclGrant(
                    document_id=target_doc.id,
                    grantee_user_id=clean_grantee,
                    permission_level=event.permission_level,
                    granted_by_user_id=actor_user_id.strip() or target_doc.owner_user_id,
                    revoked_at=ts if action == "revoke" else None,
                    updated_at=ts,
                )
            )
        else:
            updated_acls.append(entry)

    if not matched:
        updated_acls.append(
            DocumentAclGrant(
                document_id=target_doc.id,
                grantee_user_id=clean_grantee,
                permission_level=event.permission_level,
                granted_by_user_id=actor_user_id.strip() or target_doc.owner_user_id,
                revoked_at=ts if action == "revoke" else None,
                updated_at=ts,
            )
        )

    bumped_doc = IndexedDocument(
        id=target_doc.id,
        owner_user_id=target_doc.owner_user_id,
        external_source_key=target_doc.external_source_key,
        title=target_doc.title,
        content_excerpt=target_doc.content_excerpt,
        acl_version=target_doc.acl_version + 1,
        embedding=target_doc.embedding,
        updated_at=ts,
    )
    updated_docs = dict(documents)
    updated_docs[bumped_doc.id] = bumped_doc
    return updated_docs, updated_acls, bumped_doc


def search_and_build_prompt_context(
    documents: dict[str, IndexedDocument],
    acls: list[DocumentAclGrant],
    *,
    caller_user_id: str,
    query: str,
    query_embedding: tuple[float, ...] = (),
    max_results: int = 5,
) -> GuardedPromptBundle:
    """Filter strictly by RLS/ACL BEFORE similarity scoring and prompt assembly."""
    clean_uid = caller_user_id.strip()
    if not clean_uid:
        raise PermissionError("Authenticated caller_user_id is required")

    authorized_hits: list[AuthorizedSearchHit] = []
    excluded_ids: list[str] = []

    for doc_id in sorted(documents.keys()):
        doc = documents[doc_id]
        perm = resolve_user_permission(doc, acls, user_id=clean_uid)
        if perm is None:
            excluded_ids.append(doc.id)
            continue

        vec_score = cosine_similarity(doc.embedding, query_embedding)
        lex_score = _lexical_score(query, doc)
        combined = round(max(vec_score, lex_score), 4)
        if query.strip() and not query_embedding and lex_score <= 0.0:
            continue

        authorized_hits.append(
            AuthorizedSearchHit(
                document_id=doc.id,
                external_source_key=doc.external_source_key,
                title=doc.title,
                content_excerpt=doc.content_excerpt,
                acl_version=doc.acl_version,
                permission_source=perm,
                similarity_score=combined,
            )
        )

    authorized_hits.sort(key=lambda h: (-h.similarity_score, h.document_id))
    selected = tuple(authorized_hits[: max(1, min(max_results, 20))])

    prompt_lines = [
        f"Caller: {clean_uid}",
        f"Query: {query.strip() or '(all authorized sources)'}",
        "Authorized Context Chunks:",
    ]
    if not selected:
        prompt_lines.append("- (no authorized documents matched)")
    else:
        for hit in selected:
            prompt_lines.append(
                f"- [{hit.external_source_key} | v{hit.acl_version} | {hit.permission_source}] "
                f"{hit.title}: {hit.content_excerpt}"
            )

    return GuardedPromptBundle(
        caller_user_id=clean_uid,
        query=query,
        hits=selected,
        excluded_document_ids=tuple(excluded_ids),
        prompt_context="\n".join(prompt_lines),
    )


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
    """HTTPSConnection connecting directly to validated pinned IP with TLS SNI."""

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


def run_self_test() -> dict[str, Any]:
    docs = {
        "doc-1": IndexedDocument(
            id="doc-1",
            owner_user_id="user-owner",
            external_source_key="drive://finance-q4",
            title="Q4 予算方針",
            content_excerpt="来期の予算配分計画と承認フロー",
            acl_version=1,
            embedding=(0.9, 0.1, 0.0),
        ),
        "doc-2": IndexedDocument(
            id="doc-2",
            owner_user_id="user-other",
            external_source_key="notion://private-hr",
            title="人事評価非公開メモ",
            content_excerpt="給与と評価の極秘ドラフト",
            acl_version=1,
            embedding=(0.95, 0.05, 0.0),
        ),
    }
    acls: list[DocumentAclGrant] = [
        DocumentAclGrant(
            document_id="doc-1",
            grantee_user_id="user-alice",
            permission_level="viewer",
            granted_by_user_id="user-owner",
        ),
    ]
    before = search_and_build_prompt_context(
        docs,
        acls,
        caller_user_id="user-alice",
        query="予算",
        query_embedding=(0.9, 0.1, 0.0),
    )
    assert [h.document_id for h in before.hits] == ["doc-1"]
    assert "人事評価非公開メモ" not in before.prompt_context

    docs2, acls2, bumped = apply_acl_delta(
        docs,
        acls,
        AclDeltaEvent(
            external_source_key="drive://finance-q4",
            grantee_user_id="user-alice",
            action="revoke",
        ),
        actor_user_id="user-owner",
    )
    after = search_and_build_prompt_context(
        docs2,
        acls2,
        caller_user_id="user-alice",
        query="予算",
        query_embedding=(0.9, 0.1, 0.0),
    )
    assert len(after.hits) == 0
    assert bumped.acl_version == 2
    assert "Q4 予算方針" not in after.prompt_context
    return {
        "self_test": "passed",
        "before_hits": len(before.hits),
        "after_revoke_hits": len(after.hits),
        "acl_version": bumped.acl_version,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Sync external file ACLs and guard AI search prompt context (#2655)."
    )
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--dry-run", action="store_true", default=True)
    parser.add_argument("--delta-json", default="")
    parser.add_argument("--sig-header", default="")
    parser.add_argument("--json-out", default="")
    args = parser.parse_args(argv)

    if args.self_test:
        result = run_self_test()
        print(json.dumps(result, ensure_ascii=False))
        return 0

    if args.delta_json:
        raw_bytes = Path(args.delta_json).read_bytes()
        hmac_key = os.environ.get("EXTERNAL_ACL_WEBHOOK_HMAC", "").strip()
        if not verify_webhook_signature(raw_bytes, args.sig_header, hmac_key=hmac_key):
            print("ERROR: Invalid or missing webhook HMAC signature", file=sys.stderr)
            return 2
        payload = json.loads(raw_bytes.decode("utf-8"))
        summary = {"status": "verified_dry_run", "delta": payload}
    else:
        summary = run_self_test()

    if args.json_out:
        Path(args.json_out).write_text(
            json.dumps(summary, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
            newline="\n",
        )
    print(json.dumps(summary, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
