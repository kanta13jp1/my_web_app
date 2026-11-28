#!/usr/bin/env python3
"""Fetch external HTTPS URLs safely and convert HTML to Markdown + structured JSON (#2639).

Uses Python standard library (`html.parser`, `ipaddress`, `socket`, `urllib`) by default,
with optional env-gated Firecrawl v1 scrape support when `FIRECRAWL_API_KEY` is provided.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
from html.parser import HTMLParser
import ipaddress
import json
import os
from pathlib import Path
import re
import socket
import sys
import urllib.error
import urllib.parse
import urllib.request

DEFAULT_TIMEOUT_SECONDS = 10
MAX_TIMEOUT_SECONDS = 15
MAX_BODY_BYTES = 2 * 1024 * 1024  # 2 MiB
MAX_REDIRECTS = 3
DEFAULT_FIRECRAWL_API_URL = "https://api.firecrawl.dev/v1/scrape"
USER_AGENT = "my-web-app-markdown-extractor/1.0 (+https://github.com/kanta13jp1/my_web_app)"

_CGNAT_NETWORK = ipaddress.ip_network("100.64.0.0/10")
_BLOCKED_HOSTNAME_SUFFIXES = (".localhost", ".local", ".internal", ".arpa")
_ALLOWED_LINK_SCHEMES = ("https", "http")


def sanitize_url_for_log(url: str) -> str:
    """Return scheme://host[:port]/path with userinfo, query, and fragment stripped."""
    try:
        parts = urllib.parse.urlsplit(url.strip())
    except ValueError:
        return "<invalid-url>"
    if not parts.scheme or not parts.hostname:
        return "<invalid-url>"
    host = parts.hostname
    if ":" in host and not host.startswith("["):
        host = f"[{host}]"
    port_suffix = f":{parts.port}" if parts.port is not None else ""
    path = parts.path or ""
    return f"{parts.scheme.lower()}://{host}{port_suffix}{path}"


def _is_forbidden_ip(ip_obj: ipaddress.IPv4Address | ipaddress.IPv6Address) -> bool:
    if isinstance(ip_obj, ipaddress.IPv6Address) and ip_obj.ipv4_mapped is not None:
        if _is_forbidden_ip(ip_obj.ipv4_mapped):
            return True
    if (
        ip_obj.is_loopback
        or ip_obj.is_private
        or ip_obj.is_link_local
        or ip_obj.is_reserved
        or ip_obj.is_multicast
        or ip_obj.is_unspecified
        or getattr(ip_obj, "is_site_local", False)
    ):
        return True
    if isinstance(ip_obj, ipaddress.IPv4Address) and ip_obj in _CGNAT_NETWORK:
        return True
    return False


def validate_https_url(url: str) -> str:
    """Validate an external HTTPS URL against SSRF, userinfo, and private-network targets."""
    cleaned = url.strip()
    if not cleaned or any(ch.isspace() or ord(ch) < 32 for ch in cleaned):
        raise ValueError("URL must not be empty or contain whitespace/control characters.")
    parts = urllib.parse.urlsplit(cleaned)
    if parts.scheme.lower() != "https":
        raise ValueError("Only https:// URLs are permitted.")
    if parts.username is not None or parts.password is not None or "@" in parts.netloc:
        raise ValueError("URL must not contain embedded credentials or userinfo.")
    hostname = (parts.hostname or "").strip().lower().rstrip(".")
    if not hostname:
        raise ValueError("URL must include a valid hostname.")
    if hostname == "localhost" or any(hostname.endswith(sfx) for sfx in _BLOCKED_HOSTNAME_SUFFIXES):
        raise ValueError(f"Blocked internal hostname: {hostname}")

    try:
        literal_ip = ipaddress.ip_address(hostname)
    except ValueError:
        literal_ip = None

    if literal_ip is not None:
        if _is_forbidden_ip(literal_ip):
            raise ValueError(f"Blocked non-public IP literal: {sanitize_url_for_log(cleaned)}")
        return cleaned

    port = parts.port or 443
    try:
        addr_infos = socket.getaddrinfo(hostname, port, type=socket.SOCK_STREAM)
    except socket.gaierror as exc:
        raise ValueError(f"DNS resolution failed for {sanitize_url_for_log(cleaned)}") from exc

    if not addr_infos:
        raise ValueError(f"No IP addresses resolved for {sanitize_url_for_log(cleaned)}")

    for info in addr_infos:
        sockaddr = info[4]
        if not sockaddr:
            continue
        raw_ip = str(sockaddr[0]).split("%", 1)[0]
        resolved_ip = ipaddress.ip_address(raw_ip)
        if _is_forbidden_ip(resolved_ip):
            raise ValueError(
                f"Blocked non-public resolved IP for {sanitize_url_for_log(cleaned)}"
            )

    return cleaned


class _SafeHttpsRedirectHandler(urllib.request.HTTPRedirectHandler):
    """Redirect handler enforcing hop limits and SSRF re-validation on every hop."""

    def __init__(self, max_redirects: int = MAX_REDIRECTS) -> None:
        super().__init__()
        self.max_redirects = max_redirects
        self._redirect_count = 0

    def redirect_request(
        self,
        req: urllib.request.Request,
        fp: object,
        code: int,
        msg: str,
        headers: object,
        newurl: str,
    ) -> urllib.request.Request:
        self._redirect_count += 1
        if self._redirect_count > self.max_redirects:
            raise urllib.error.HTTPError(
                sanitize_url_for_log(req.full_url),
                code,
                f"Exceeded maximum redirects ({self.max_redirects})",
                hdrs=headers,  # type: ignore[arg-type]
                fp=None,
            )
        joined = urllib.parse.urljoin(req.full_url, newurl)
        validated = validate_https_url(joined)
        new_headers = {
            k: v
            for k, v in req.header_items()
            if k.lower() not in ("authorization", "cookie")
        }
        return urllib.request.Request(validated, headers=new_headers, method="GET")


def _safe_http_fetch(
    url: str,
    *,
    method: str = "GET",
    headers: dict[str, str] | None = None,
    payload: object | None = None,
    timeout: int = DEFAULT_TIMEOUT_SECONDS,
    max_bytes: int = MAX_BODY_BYTES,
) -> tuple[int, str, str]:
    validated_url = validate_https_url(url)
    bounded_timeout = max(1, min(int(timeout), MAX_TIMEOUT_SECONDS))
    bounded_bytes = max(1, min(int(max_bytes), MAX_BODY_BYTES))
    safe_target = sanitize_url_for_log(validated_url)

    req_headers: dict[str, str] = {
        "User-Agent": USER_AGENT,
        "Accept": "text/html, application/json;q=0.9, text/plain;q=0.8",
    }
    if headers:
        req_headers.update(headers)

    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    req = urllib.request.Request(
        validated_url,
        data=data,
        headers=req_headers,
        method=method,
    )
    opener = urllib.request.build_opener(_SafeHttpsRedirectHandler(MAX_REDIRECTS))

    try:
        with opener.open(req, timeout=bounded_timeout) as resp:
            status = getattr(resp, "status", None)
            if status is None:
                status = resp.getcode()
            final_url = getattr(resp, "url", validated_url) or validated_url
            raw_bytes = resp.read(bounded_bytes + 1)
    except ValueError as exc:
        raise RuntimeError(f"Blocked unsafe redirect or target ({safe_target}): {exc}") from exc
    except urllib.error.HTTPError as exc:
        preview = ""
        if exc.fp is not None:
            try:
                preview = exc.read(200).decode("utf-8", errors="replace").strip()
            except OSError:
                preview = ""
        raise RuntimeError(
            f"HTTP {exc.code} from {safe_target} ({method}): {preview or exc.reason}"
        ) from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(
            f"Network error calling {safe_target} ({method}): {exc.reason}"
        ) from exc

    if status is None or not (200 <= int(status) < 300):
        raise RuntimeError(f"Unexpected HTTP {status} from {safe_target}")

    if len(raw_bytes) > bounded_bytes:
        raise RuntimeError(
            f"Response body exceeded {bounded_bytes} bytes limit for {safe_target}"
        )

    return int(status), final_url, raw_bytes.decode("utf-8", errors="replace")


def sanitize_embedded_link(raw_href: str, base_url: str) -> str:
    """Resolve relative href against base_url and strip non-HTTP(S) URI schemes."""
    candidate = raw_href.strip()
    if not candidate:
        return ""
    resolved = urllib.parse.urljoin(base_url, candidate)
    parts = urllib.parse.urlsplit(resolved)
    if parts.scheme.lower() not in _ALLOWED_LINK_SCHEMES:
        return ""
    if not parts.hostname:
        return ""
    if parts.username is not None or parts.password is not None:
        return ""
    return resolved


class _StructuredHtmlParser(HTMLParser):
    """Stdlib HTML parser generating Markdown blocks and structured extraction metadata."""

    def __init__(self, base_url: str) -> None:
        super().__init__(convert_charrefs=True)
        self.base_url = base_url
        self.title = ""
        self.description = ""
        self.headings: list[dict[str, object]] = []
        self.links: list[dict[str, str]] = []
        self.blocks: list[str] = []

        self._ignored_depth = 0
        self._in_title = False
        self._title_buf: list[str] = []
        self._heading_level: int | None = None
        self._heading_buf: list[str] = []
        self._in_paragraph = False
        self._paragraph_buf: list[str] = []
        self._in_list_item = False
        self._list_item_buf: list[str] = []
        self._in_blockquote = False
        self._blockquote_buf: list[str] = []
        self._in_pre = False
        self._pre_buf: list[str] = []
        self._link_href = ""
        self._link_buf: list[str] = []
        self._in_link = False
        self._seen_links: set[tuple[str, str]] = set()

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        t = tag.lower()
        attr_map = {k.lower(): (v or "") for k, v in attrs}

        if t in ("script", "style", "noscript", "iframe", "svg"):
            self._ignored_depth += 1
            return
        if self._ignored_depth > 0:
            return

        if t == "title":
            self._in_title = True
            self._title_buf.clear()
        elif t == "meta":
            name = (attr_map.get("name") or attr_map.get("property") or "").strip().lower()
            if name in ("description", "og:description") and not self.description:
                self.description = " ".join(attr_map.get("content", "").split())
        elif t in ("h1", "h2", "h3", "h4", "h5", "h6"):
            self._heading_level = int(t[1])
            self._heading_buf.clear()
        elif t == "p":
            self._in_paragraph = True
            self._paragraph_buf.clear()
        elif t == "li":
            self._in_list_item = True
            self._list_item_buf.clear()
        elif t == "blockquote":
            self._in_blockquote = True
            self._blockquote_buf.clear()
        elif t == "pre":
            self._in_pre = True
            self._pre_buf.clear()
        elif t == "a":
            self._in_link = True
            self._link_href = sanitize_embedded_link(attr_map.get("href", ""), self.base_url)
            self._link_buf.clear()
        elif t == "br" and self._in_paragraph:
            self._paragraph_buf.append("\n")

    def handle_endtag(self, tag: str) -> None:
        t = tag.lower()
        if t in ("script", "style", "noscript", "iframe", "svg"):
            if self._ignored_depth > 0:
                self._ignored_depth -= 1
            return
        if self._ignored_depth > 0:
            return

        if t == "title" and self._in_title:
            self._in_title = False
            if not self.title:
                self.title = " ".join("".join(self._title_buf).split())
        elif t == "a" and self._in_link:
            self._in_link = False
            link_text = " ".join("".join(self._link_buf).split())
            if self._link_href and link_text:
                pair = (link_text, self._link_href)
                if pair not in self._seen_links:
                    self._seen_links.add(pair)
                    self.links.append({"text": link_text, "url": self._link_href})
                rendered = f"[{link_text}]({self._link_href})"
            else:
                rendered = link_text
            self._append_inline(rendered)
        elif t in ("h1", "h2", "h3", "h4", "h5", "h6") and self._heading_level is not None:
            level = self._heading_level
            self._heading_level = None
            heading_text = " ".join("".join(self._heading_buf).split())
            if heading_text:
                self.headings.append({"level": level, "text": heading_text})
                self.blocks.append(f"{'#' * level} {heading_text}")
                if level == 1 and not self.title:
                    self.title = heading_text
        elif t == "p" and self._in_paragraph:
            self._in_paragraph = False
            text = _collapse_inline("".join(self._paragraph_buf))
            if text:
                self.blocks.append(text)
        elif t == "li" and self._in_list_item:
            self._in_list_item = False
            text = _collapse_inline("".join(self._list_item_buf))
            if text:
                self.blocks.append(f"- {text}")
        elif t == "blockquote" and self._in_blockquote:
            self._in_blockquote = False
            text = _collapse_inline("".join(self._blockquote_buf))
            if text:
                self.blocks.append(f"> {text}")
        elif t == "pre" and self._in_pre:
            self._in_pre = False
            code = "".join(self._pre_buf).strip("\r\n")
            if code:
                self.blocks.append(f"```\n{code}\n```")

    def handle_data(self, data: str) -> None:
        if self._ignored_depth > 0:
            return
        if self._in_title:
            self._title_buf.append(data)
            return
        if self._in_pre:
            self._pre_buf.append(data)
            return
        if self._in_link:
            self._link_buf.append(data)
            return
        self._append_inline(data)

    def _append_inline(self, text: str) -> None:
        if self._heading_level is not None:
            self._heading_buf.append(text)
        elif self._in_paragraph:
            self._paragraph_buf.append(text)
        elif self._in_list_item:
            self._list_item_buf.append(text)
        elif self._in_blockquote:
            self._blockquote_buf.append(text)


def _collapse_inline(raw: str) -> str:
    lines = [re.sub(r"[ \t]+", " ", ln).strip() for ln in raw.splitlines()]
    return "\n".join(ln for ln in lines if ln)


def html_to_markdown_and_payload(
    html_text: str,
    *,
    source_url: str,
    extractor_mode: str = "stdlib_html",
) -> dict[str, object]:
    """Convert raw HTML into clean Markdown and structured JSON metadata."""
    parser = _StructuredHtmlParser(source_url)
    parser.feed(html_text)
    parser.close()

    markdown = "\n\n".join(parser.blocks).strip()
    if not markdown and parser.title:
        markdown = f"# {parser.title}"

    key_points: list[str] = []
    seen_points: set[str] = set()
    for h in parser.headings:
        txt = str(h.get("text") or "").strip()
        if txt and txt not in seen_points:
            seen_points.add(txt)
            key_points.append(txt)
    for block in parser.blocks:
        if block.startswith("- "):
            item = block[2:].strip()
            if item and item not in seen_points:
                seen_points.add(item)
                key_points.append(item)
        if len(key_points) >= 8:
            break

    word_count = len(re.findall(r"\S+", markdown))
    return {
        "source_url": sanitize_url_for_log(source_url),
        "title": parser.title or sanitize_url_for_log(source_url),
        "description": parser.description,
        "headings": parser.headings,
        "links": parser.links,
        "key_points": key_points[:8],
        "word_count": word_count,
        "extractor_mode": extractor_mode,
        "markdown": markdown,
        "fetched_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    }


def _markdown_to_structured_payload(
    markdown: str,
    *,
    source_url: str,
    title: str = "",
    description: str = "",
    extractor_mode: str = "firecrawl_v1",
) -> dict[str, object]:
    headings: list[dict[str, object]] = []
    key_points: list[str] = []
    links: list[dict[str, str]] = []
    seen_points: set[str] = set()
    for line in markdown.splitlines():
        m_head = re.match(r"^(#{1,6})\s+(.+?)\s*$", line)
        if m_head:
            txt = m_head.group(2).strip()
            headings.append({"level": len(m_head.group(1)), "text": txt})
            if txt not in seen_points:
                seen_points.add(txt)
                key_points.append(txt)
        m_bullet = re.match(r"^[-*]\s+(.+?)\s*$", line)
        if m_bullet:
            txt = m_bullet.group(1).strip()
            if txt not in seen_points:
                seen_points.add(txt)
                key_points.append(txt)
        for m_link in re.finditer(r"\[([^\]]+)\]\(([^)]+)\)", line):
            safe_href = sanitize_embedded_link(m_link.group(2), source_url)
            if safe_href:
                links.append({"text": m_link.group(1).strip(), "url": safe_href})

    return {
        "source_url": sanitize_url_for_log(source_url),
        "title": title or (headings[0]["text"] if headings else sanitize_url_for_log(source_url)),
        "description": description,
        "headings": headings,
        "links": links,
        "key_points": key_points[:8],
        "word_count": len(re.findall(r"\S+", markdown)),
        "extractor_mode": extractor_mode,
        "markdown": markdown.strip(),
        "fetched_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    }


def extract_url_to_markdown(
    url: str,
    *,
    mode: str = "auto",
    timeout: int = DEFAULT_TIMEOUT_SECONDS,
) -> dict[str, object]:
    """Fetch URL safely and return Markdown + structured JSON extraction payload."""
    validated_target = validate_https_url(url)
    firecrawl_credential = os.environ.get("FIRECRAWL_API_KEY", "").strip()
    use_firecrawl = (
        mode == "firecrawl_v1" or (mode == "auto" and bool(firecrawl_credential))
    )

    if use_firecrawl:
        if not firecrawl_credential:
            raise RuntimeError("FIRECRAWL_API_KEY env var is required for firecrawl_v1 mode.")
        endpoint = os.environ.get("FIRECRAWL_API_URL", DEFAULT_FIRECRAWL_API_URL).strip()
        _, _, raw_json = _safe_http_fetch(
            endpoint,
            method="POST",
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {firecrawl_credential}",
            },
            payload={"url": validated_target, "formats": ["markdown"]},
            timeout=timeout,
        )
        parsed = json.loads(raw_json)
        data = parsed.get("data") if isinstance(parsed, dict) else None
        if not isinstance(data, dict) or not isinstance(data.get("markdown"), str):
            raise RuntimeError("Firecrawl response missing markdown payload.")
        meta = data.get("metadata") if isinstance(data.get("metadata"), dict) else {}
        return _markdown_to_structured_payload(
            str(data["markdown"]),
            source_url=validated_target,
            title=str(meta.get("title") or ""),
            description=str(meta.get("description") or ""),
            extractor_mode="firecrawl_v1",
        )

    _, final_url, html_body = _safe_http_fetch(
        validated_target,
        method="GET",
        timeout=timeout,
    )
    return html_to_markdown_and_payload(
        html_body,
        source_url=final_url,
        extractor_mode="stdlib_html",
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Safely extract an external HTTPS URL to Markdown and structured JSON (#2639).",
    )
    parser.add_argument("--url", required=True, help="Target https:// URL")
    parser.add_argument(
        "--mode",
        choices=("auto", "stdlib_html", "firecrawl_v1"),
        default="auto",
        help="Extractor backend mode",
    )
    parser.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT_SECONDS)
    parser.add_argument("--json-out", default="", help="Optional JSON output file path")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        result = extract_url_to_markdown(
            args.url,
            mode=args.mode,
            timeout=args.timeout,
        )
    except (ValueError, RuntimeError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    rendered = json.dumps(result, ensure_ascii=False, indent=2)
    if args.json_out:
        Path(args.json_out).write_text(rendered + "\n", encoding="utf-8", newline="\n")
    print(rendered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
