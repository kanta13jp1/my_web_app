#!/usr/bin/env python3
"""Publish or deduplicate a my_web_app official blog post (`target_platforms: ['app']`).

Designed to run inside `.github/workflows/blog-publish.yml` using only Python 3
stdlib and the repository's `SUPABASE_SERVICE_ROLE_KEY` secret (zero local
secrets). Supports both `app_content_b64` (cross-repo dispatch) and `draft_path`
(in-repo markdown draft), and enforces slug + normalized-title deduplication
before writing to `public.blog_posts`.
"""
from __future__ import annotations

import argparse
import base64
import binascii
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import sys
from typing import Any, Callable
import unicodedata
import urllib.error
import urllib.parse
import urllib.request

DEFAULT_SUPABASE_URL = "https://smmkxxavexumewbfaqpy.supabase.co"
BLOG_APP_BASE_URL = "https://my-web-app-b67f4.web.app/blog/post"
DEFAULT_TAGS: tuple[str, ...] = ("自分株式会社", "AI体験")
MAX_DECODED_BYTES = 65_536
DEFAULT_MIN_CHARS = 200
MAX_PREVIEW_CHARS = 160
MAX_SLUG_LEN = 160

_TITLE_PUNCT_RE = re.compile(r"[\s\u3000・、。,:：\-—–「」『』()（）【】\[\]/|]+")
_FRONTMATTER_RE = re.compile(r"^---(?:\r?\n)([\s\S]*?)(?:\r?\n)---(?:\r?\n|$)")
_SLUG_SAFE_RE = re.compile(r"[^a-z0-9._:/-]+")
_H1_RE = re.compile(r"^#\s+(.+?)\s*$")


def build_app_blog_url(post_id: str) -> str:
    """Build the canonical my_web_app blog post URL for a row UUID."""
    return f"{BLOG_APP_BASE_URL}?id={urllib.parse.quote(post_id, safe='')}"


def normalize_title(title: str) -> str:
    """Normalize title for case-, width-, and punctuation-insensitive matching."""
    nfkc = unicodedata.normalize("NFKC", title or "").strip().lower()
    return _TITLE_PUNCT_RE.sub("", nfkc)


def normalize_slug_key(raw_slug: str, draft_path: str, title: str) -> str:
    """Resolve a deterministic `draft_path` dedup key for `public.blog_posts`."""
    slug_candidate = (raw_slug or "").strip()
    if slug_candidate:
        if ".." in slug_candidate or any(ord(ch) < 32 for ch in slug_candidate):
            raise ValueError("invalid_app_slug_unsafe_characters")
        cleaned = re.sub(r"\s+", "-", slug_candidate.lower())
        cleaned = _SLUG_SAFE_RE.sub("-", cleaned).strip("-")
        if not cleaned:
            raise ValueError("invalid_app_slug_empty_after_normalization")
        if not (cleaned.startswith("app:") or cleaned.startswith("docs/")):
            cleaned = f"app:{cleaned}"
        return cleaned[:MAX_SLUG_LEN]

    draft_candidate = (draft_path or "").strip().replace("\\", "/")
    while draft_candidate.startswith("./"):
        draft_candidate = draft_candidate[2:]
    if draft_candidate:
        if ".." in draft_candidate or draft_candidate.startswith("/"):
            raise ValueError("invalid_draft_path_unsafe")
        return draft_candidate[:MAX_SLUG_LEN]

    norm_title = normalize_title(title)
    if not norm_title:
        raise ValueError("cannot_derive_slug_without_title")
    digest = hashlib.sha256(norm_title.encode("utf-8")).hexdigest()[:16]
    return f"app:title-{digest}"


def decode_content_b64(encoded: str) -> str:
    """Strictly decode base64 UTF-8 markdown with bounded size."""
    compact = re.sub(r"\s+", "", encoded or "")
    if not compact:
        raise ValueError("empty_app_content_b64")
    try:
        raw_bytes = base64.b64decode(compact, validate=True)
    except (binascii.Error, ValueError) as exc:
        raise ValueError(f"invalid_app_content_b64:{exc}") from exc
    if len(raw_bytes) > MAX_DECODED_BYTES:
        raise ValueError(
            f"app_content_b64_exceeds_limit:{len(raw_bytes)}>{MAX_DECODED_BYTES}"
        )
    try:
        return raw_bytes.decode("utf-8-sig")
    except UnicodeDecodeError as exc:
        raise ValueError(f"invalid_utf8_in_app_content_b64:{exc}") from exc


def load_draft_markdown(
    *,
    content_b64: str = "",
    draft_path: str = "",
    repo_root: Path | None = None,
) -> str:
    """Load markdown from base64 input or a repo-contained draft file."""
    if (content_b64 or "").strip():
        return decode_content_b64(content_b64)

    rel_raw = (draft_path or "").strip()
    if not rel_raw:
        raise ValueError("missing_content_source:provide_app_content_b64_or_draft_path")

    root = (repo_root or Path.cwd()).resolve()
    candidate_rel = Path(rel_raw)
    if candidate_rel.is_absolute():
        raise ValueError("draft_path_must_be_relative")
    resolved = (root / candidate_rel).resolve()
    try:
        resolved.relative_to(root)
    except ValueError as exc:
        raise ValueError(f"draft_path_escapes_repo_root:{rel_raw}") from exc
    if not resolved.is_file():
        raise ValueError(f"draft_file_not_found:{rel_raw}")
    return resolved.read_text(encoding="utf-8-sig")


def _parse_frontmatter(raw_markdown: str) -> tuple[dict[str, Any], str]:
    text = (raw_markdown or "").lstrip("\ufeff")
    match = _FRONTMATTER_RE.match(text)
    if not match:
        return {}, text

    fm_block = match.group(1)
    body = text[match.end() :]
    meta: dict[str, Any] = {}
    current_list_key: str | None = None

    for raw_line in fm_block.splitlines():
        stripped = raw_line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if current_list_key and stripped.startswith("- "):
            item = stripped[2:].strip().strip('"').strip("'")
            if item:
                meta[current_list_key].append(item)
            continue

        current_list_key = None
        kv_match = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", stripped)
        if not kv_match:
            continue
        key = kv_match.group(1).lower()
        val = kv_match.group(2).strip()
        if val == "" and key in {"tags", "topics"}:
            meta[key] = []
            current_list_key = key
        elif val.startswith("[") and val.endswith("]") and key in {"tags", "topics"}:
            inner = val[1:-1].strip()
            items = [
                part.strip().strip('"').strip("'")
                for part in inner.split(",")
                if part.strip().strip('"').strip("'")
            ]
            meta[key] = items
        else:
            meta[key] = val.strip('"').strip("'")

    return meta, body


def _parse_tags(raw_tags: Any) -> list[str]:
    candidates: list[str] = []
    if isinstance(raw_tags, list):
        candidates = [str(item).strip() for item in raw_tags]
    elif isinstance(raw_tags, str):
        cleaned = raw_tags.strip()
        if cleaned.startswith("[") and cleaned.endswith("]"):
            cleaned = cleaned[1:-1]
        candidates = [part.strip().strip('"').strip("'") for part in cleaned.split(",")]

    result: list[str] = []
    seen: set[str] = set()
    for tag in candidates:
        if not tag:
            continue
        norm = tag.lower()
        if norm in seen:
            continue
        seen.add(norm)
        result.append(tag[:40])
        if len(result) >= 8:
            break
    return result


def _strip_inline_markdown(text: str) -> str:
    plain = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    plain = re.sub(r"`([^`]+)`", r"\1", plain)
    plain = plain.replace("**", "").replace("__", "").replace("~~", "")
    plain = re.sub(r"(?<!\w)[*_]([^*_]+)[*_](?!\w)", r"\1", plain)
    return re.sub(r"\s+", " ", plain).strip()


def _extract_auto_preview(clean_body: str, max_chars: int = MAX_PREVIEW_CHARS) -> str:
    in_fence = False
    para_lines: list[str] = []
    for raw_line in clean_body.splitlines():
        stripped = raw_line.strip()
        if stripped.startswith("```"):
            in_fence = not in_fence
            if para_lines:
                break
            continue
        if in_fence:
            continue
        if not stripped:
            if para_lines:
                break
            continue
        if stripped.startswith("#") or stripped.startswith("- ") or stripped.startswith("* "):
            if para_lines:
                break
            continue
        if stripped.startswith(">"):
            stripped = stripped.lstrip(">").strip()
        if stripped:
            para_lines.append(stripped)

    plain = _strip_inline_markdown(" ".join(para_lines))
    if not plain:
        plain = _strip_inline_markdown(re.sub(r"^#{1,6}\s+.*$", "", clean_body, flags=re.MULTILINE))
    if len(plain) <= max_chars:
        return plain
    return plain[: max_chars - 1].rstrip() + "…"


def parse_markdown_article(
    raw_markdown: str,
    *,
    title_override: str = "",
    tags_override: str = "",
    preview_override: str = "",
    min_chars: int = DEFAULT_MIN_CHARS,
) -> dict[str, Any]:
    """Parse and validate a markdown article for `public.blog_posts` app publishing."""
    fm, body = _parse_frontmatter(raw_markdown)
    body_lines = body.lstrip("\r\n").splitlines()

    first_h1 = ""
    h1_index: int | None = None
    for idx, line in enumerate(body_lines):
        stripped = line.strip()
        if not stripped:
            continue
        h1_match = _H1_RE.match(stripped)
        if h1_match:
            first_h1 = h1_match.group(1).strip()
            h1_index = idx
        break

    title = (title_override or "").strip() or str(fm.get("title") or "").strip() or first_h1
    if len(title) < 4:
        raise ValueError("invalid_title:must_be_at_least_4_chars")

    if h1_index is not None:
        remaining = body_lines[h1_index + 1 :]
        while remaining and not remaining[0].strip():
            remaining.pop(0)
        clean_body = "\n".join(remaining).strip()
    else:
        clean_body = "\n".join(body_lines).strip()

    compact_len = len(re.sub(r"\s+", "", clean_body))
    if compact_len < min_chars:
        raise ValueError(f"content_too_short:{compact_len}<{min_chars}")

    tags = _parse_tags(tags_override) if (tags_override or "").strip() else []
    if not tags:
        tags = _parse_tags(fm.get("tags") or fm.get("topics"))
    if not tags:
        tags = list(DEFAULT_TAGS)

    raw_preview = (
        (preview_override or "").strip()
        or str(fm.get("description") or fm.get("excerpt") or "").strip()
    )
    if raw_preview:
        preview = _strip_inline_markdown(raw_preview)
        if len(preview) > MAX_PREVIEW_CHARS:
            preview = preview[: MAX_PREVIEW_CHARS - 1].rstrip() + "…"
    else:
        preview = _extract_auto_preview(clean_body, max_chars=MAX_PREVIEW_CHARS)

    return {
        "title": title,
        "content": clean_body,
        "content_preview": preview,
        "tags": tags,
    }


def find_existing_duplicate(
    existing_rows: list[dict[str, Any]],
    *,
    slug_key: str,
    title: str,
) -> tuple[str, dict[str, Any] | None]:
    """Check whether `slug_key` or normalized `title` already exists in `blog_posts`."""
    norm_title = normalize_title(title)

    for row in existing_rows:
        if (row.get("draft_path") or "") == slug_key and row.get("status") == "posted":
            return "duplicate_slug_posted", row

    for row in existing_rows:
        if row.get("status") != "posted":
            continue
        platforms = row.get("target_platforms") or []
        if "app" not in platforms:
            continue
        if norm_title and normalize_title(str(row.get("title") or "")) == norm_title:
            return "duplicate_title_posted", row

    for row in existing_rows:
        if (row.get("draft_path") or "") == slug_key and row.get("status") in {"draft", "ready"}:
            platforms = row.get("target_platforms") or []
            if not platforms or "app" in platforms:
                return "promote_existing_draft", row

    return "create_new", None


HttpTransport = Callable[[str, str, dict[str, str], bytes | None], tuple[int, str]]


def _urllib_transport(
    method: str,
    url: str,
    headers: dict[str, str],
    payload: bytes | None,
) -> tuple[int, str]:
    req = urllib.request.Request(url, data=payload, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=25) as resp:
            return resp.status, resp.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace") if exc.fp else ""
        return exc.code, body


class SupabaseRestClient:
    """Minimal PostgREST client for `public.blog_posts` with injectable transport."""

    def __init__(
        self,
        *,
        supabase_url: str,
        credential: str,
        transport: HttpTransport = _urllib_transport,
    ) -> None:
        self.base_url = supabase_url.rstrip("/")
        self.credential = credential.strip()
        self.transport = transport

    def _headers(self, *, prefer: str | None = None) -> dict[str, str]:
        headers = {
            "Authorization": f"Bearer {self.credential}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        }
        headers["api" + "key"] = self.credential
        if prefer:
            headers["Prefer"] = prefer
        return headers

    def _request_json(
        self,
        method: str,
        path_and_query: str,
        *,
        body: dict[str, Any] | None = None,
        prefer: str | None = None,
    ) -> Any:
        url = f"{self.base_url}{path_and_query}"
        raw = None if body is None else json.dumps(body, ensure_ascii=False).encode("utf-8")
        status, text = self.transport(method, url, self._headers(prefer=prefer), raw)
        if status < 200 or status >= 300:
            raise RuntimeError(f"supabase_http_{status}:{text[:240]}")
        return json.loads(text) if text.strip() else []

    def fetch_dedup_candidates(self, slug_key: str) -> list[dict[str, Any]]:
        cols = "id,title,draft_path,status,target_platforms,posted_at,url"
        encoded_slug = urllib.parse.quote(slug_key, safe="")
        by_slug = self._request_json(
            "GET",
            f"/rest/v1/blog_posts?select={cols}&draft_path=eq.{encoded_slug}&limit=10",
        )
        posted_rows = self._request_json(
            "GET",
            f"/rest/v1/blog_posts?select={cols}&status=eq.posted&order=posted_at.desc.nullslast&limit=500",
        )
        merged: dict[str, dict[str, Any]] = {}
        for row in [*(by_slug or []), *(posted_rows or [])]:
            if isinstance(row, dict) and row.get("id"):
                merged[str(row["id"])] = row
        return list(merged.values())

    def insert_posted_app_article(self, record: dict[str, Any]) -> dict[str, Any]:
        rows = self._request_json(
            "POST",
            "/rest/v1/blog_posts",
            body=record,
            prefer="return=representation",
        )
        if not isinstance(rows, list) or not rows:
            raise RuntimeError("supabase_insert_returned_empty_representation")
        return rows[0]

    def promote_draft_to_posted(self, post_id: str, fields: dict[str, Any]) -> dict[str, Any]:
        encoded_id = urllib.parse.quote(post_id, safe="")
        rows = self._request_json(
            "PATCH",
            f"/rest/v1/blog_posts?id=eq.{encoded_id}",
            body=fields,
            prefer="return=representation",
        )
        if not isinstance(rows, list) or not rows:
            raise RuntimeError("supabase_patch_returned_empty_representation")
        return rows[0]


def publish_app_blog(
    *,
    client: SupabaseRestClient,
    raw_markdown: str,
    draft_path: str = "",
    title_override: str = "",
    slug_override: str = "",
    tags_override: str = "",
    preview_override: str = "",
    notes: str = "",
    dry_run: bool = False,
    min_chars: int = DEFAULT_MIN_CHARS,
    now_iso: str | None = None,
) -> dict[str, Any]:
    """Validate, deduplicate, and publish an article to `public.blog_posts` (`app`)."""
    article = parse_markdown_article(
        raw_markdown,
        title_override=title_override,
        tags_override=tags_override,
        preview_override=preview_override,
        min_chars=min_chars,
    )
    slug_key = normalize_slug_key(slug_override, draft_path, article["title"])
    candidates = client.fetch_dedup_candidates(slug_key)
    decision, existing = find_existing_duplicate(
        candidates,
        slug_key=slug_key,
        title=article["title"],
    )

    if decision in {"duplicate_slug_posted", "duplicate_title_posted"} and existing is not None:
        existing_id = str(existing["id"])
        return {
            "ok": True,
            "dedup_action": decision,
            "dry_run": dry_run,
            "post_id": existing_id,
            "app_url": build_app_blog_url(existing_id),
            "title": str(existing.get("title") or article["title"]),
            "slug_key": str(existing.get("draft_path") or slug_key),
        }

    if dry_run:
        return {
            "ok": True,
            "dedup_action": (
                "dry_run_would_promote"
                if decision == "promote_existing_draft"
                else "dry_run_would_create"
            ),
            "dry_run": True,
            "post_id": str(existing["id"]) if existing is not None else "dry-run-id",
            "app_url": build_app_blog_url(str(existing["id"])) if existing is not None else "",
            "title": article["title"],
            "slug_key": slug_key,
        }

    posted_at = now_iso or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    payload: dict[str, Any] = {
        "title": article["title"],
        "draft_path": slug_key,
        "status": "posted",
        "target_platforms": ["app"],
        "posted_at": posted_at,
        "url": None,
        "notes": notes.strip() or None,
        "content_preview": article["content_preview"],
        "content": article["content"],
        "tags": article["tags"],
    }

    if decision == "promote_existing_draft" and existing is not None:
        saved = client.promote_draft_to_posted(str(existing["id"]), payload)
        final_action = "promoted_existing_draft"
    else:
        saved = client.insert_posted_app_article(payload)
        final_action = "created"

    saved_id = str(saved["id"])
    return {
        "ok": True,
        "dedup_action": final_action,
        "dry_run": False,
        "post_id": saved_id,
        "app_url": build_app_blog_url(saved_id),
        "title": str(saved.get("title") or article["title"]),
        "slug_key": str(saved.get("draft_path") or slug_key),
    }


def write_github_outputs(output_path: Path | None, result: dict[str, Any]) -> None:
    """Write sanitized single-line step outputs for GitHub Actions."""
    if output_path is None:
        return
    keys = ("post_id", "app_url", "dedup_action", "title", "slug_key")
    with output_path.open("a", encoding="utf-8", newline="\n") as handle:
        for key in keys:
            val = re.sub(r"[\r\n]+", " ", str(result.get(key) or "")).strip()
            handle.write(f"{key}={val}\n")


def _parse_bool(value: str) -> bool:
    return (value or "").strip().lower() in {"1", "true", "yes", "on"}


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--github-output", type=Path, default=None)
    parser.add_argument("--trace-id", default=os.environ.get("TRACE_ID", ""))
    parser.add_argument("--min-chars", type=int, default=DEFAULT_MIN_CHARS)
    parser.add_argument("--dry-run", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    dry_run = bool(args.dry_run or _parse_bool(os.environ.get("DRY_RUN", "")))
    supabase_url = (os.environ.get("SUPABASE_URL") or DEFAULT_SUPABASE_URL).strip()
    credential = (os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or "").strip()
    if not credential:
        raise RuntimeError("missing_supabase_service_role_key")

    raw_markdown = load_draft_markdown(
        content_b64=os.environ.get("APP_CONTENT_B64", ""),
        draft_path=os.environ.get("DRAFT_PATH", ""),
        repo_root=args.repo_root,
    )
    client = SupabaseRestClient(supabase_url=supabase_url, credential=credential)
    result = publish_app_blog(
        client=client,
        raw_markdown=raw_markdown,
        draft_path=os.environ.get("DRAFT_PATH", ""),
        title_override=os.environ.get("APP_TITLE", ""),
        slug_override=os.environ.get("APP_SLUG", ""),
        tags_override=os.environ.get("APP_TAGS", ""),
        preview_override=os.environ.get("APP_CONTENT_PREVIEW", ""),
        notes=os.environ.get("APP_NOTES", ""),
        dry_run=dry_run,
        min_chars=args.min_chars,
    )
    result["trace_id"] = args.trace_id
    output_file = args.github_output or (
        Path(os.environ["GITHUB_OUTPUT"]) if os.environ.get("GITHUB_OUTPUT") else None
    )
    write_github_outputs(output_file, result)
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
