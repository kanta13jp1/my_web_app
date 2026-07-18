#!/usr/bin/env python3
"""Build AI University Markdown from an RSS/Atom feed.

The scheduled workflow stores this output directly in Supabase, so failures must
exit non-zero. Otherwise a transient feed error would become user-facing content.
"""

from __future__ import annotations

import html as html_mod
import json
import os
import re
import sys
import urllib.error
import urllib.request


class FeedError(RuntimeError):
    """Raised when a feed cannot produce usable article content."""


def _firecrawl_scrape(url: str) -> str | None:
    """Return clean markdown for url via Firecrawl API, or None on any error.

    Uses onlyCleanContent=true (strips nav/ads/cookie banners) and the
    Question Format to extract a concise article summary.
    Requires FIRECRAWL_API_KEY env var; falls back silently when absent.
    """
    api_key = os.environ.get("FIRECRAWL_API_KEY", "")
    if not api_key:
        return None
    payload = json.dumps({
        "url": url,
        "formats": ["markdown"],
        "onlyCleanContent": True,
        "question": "この記事の内容を150字以内の日本語で要約してください。",
    }).encode()
    req = urllib.request.Request(
        "https://api.firecrawl.dev/v1/scrape",
        data=payload,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            body = json.loads(response.read())
        answer = (body.get("data") or {}).get("llm_extraction", {}).get("answer", "")
        if not answer:
            answer = (body.get("data") or {}).get("markdown", "")[:400]
        return answer.strip() or None
    except Exception:  # noqa: BLE001
        return None


def strip_tags(value: str) -> str:
    value = re.sub(r"<[^>]+>", " ", value)
    value = html_mod.unescape(value)
    return re.sub(r"\s+", " ", value).strip()


def fetch_text(url: str, timeout: int = 8) -> str:
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "Mozilla/5.0 (compatible; AIUniversity/1.0)"},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            status = getattr(response, "status", 200)
            if status >= 400:
                raise FeedError(f"HTTP {status}")
            body = response.read()
    except urllib.error.HTTPError as exc:
        raise FeedError(f"HTTP {exc.code}") from exc
    except Exception as exc:  # noqa: BLE001 - keep workflow diagnostics compact.
        raise FeedError("RSS取得失敗") from exc

    if not body:
        raise FeedError("RSS取得失敗")
    return body.decode("utf-8", errors="replace")


def extract_rss_desc(item: str) -> str:
    patterns = [
        r"<description\b[^>]*>(.*?)</description>",
        r"<summary\b[^>]*>(.*?)</summary>",
        r"<content:encoded\b[^>]*>(.*?)</content:encoded>",
        r"<content\b[^>]*>(.*?)</content>",
    ]
    for pattern in patterns:
        match = re.search(pattern, item, re.DOTALL)
        if match:
            text = strip_tags(match.group(1))
            if len(text) >= 20:
                return text[:400]
    return ""


def fetch_meta_description(url: str) -> str:
    if not url:
        return ""
    # Prefer Firecrawl (onlyCleanContent + Question Format) when API key is set.
    fc = _firecrawl_scrape(url)
    if fc:
        return fc[:400]
    try:
        page = fetch_text(url)
    except FeedError:
        return ""
    patterns = [
        r'<meta\s+(?:name=["\']description["\']\s+content=["\']([^"\']*)["\']'
        r'|content=["\']([^"\']*)["\']\s+name=["\']description["\'])',
        r'<meta\s+(?:property=["\']og:description["\']\s+content=["\']([^"\']*)["\']'
        r'|content=["\']([^"\']*)["\']\s+property=["\']og:description["\'])',
    ]
    for pattern in patterns:
        match = re.search(pattern, page, re.IGNORECASE)
        if match:
            desc = html_mod.unescape((match.group(1) or match.group(2) or "").strip())
            if len(desc) >= 20:
                return desc[:400]
    return ""


def extract_link(item: str) -> str:
    match = re.search(
        r"<link\b[^>]*/?>([^<]*)</link>|<link\b[^>]*href=['\"]([^'\"]+)['\"]",
        item,
        re.DOTALL,
    )
    if match:
        return (match.group(1) or match.group(2) or "").strip()
    return ""


def build_markdown(url: str, provider_name: str, today: str) -> str:
    data = fetch_text(url)
    data = re.sub(r"<!\[CDATA\[", "", data)
    data = re.sub(r"\]\]>", "", data)

    items = re.findall(r"<item\b[^>]*>(.*?)</item>", data, re.DOTALL)
    if not items:
        items = re.findall(r"<entry\b[^>]*>(.*?)</entry>", data, re.DOTALL)

    articles: list[dict[str, str]] = []
    for item in items[:5]:
        title_match = re.search(r"<title\b[^>]*>(.*?)</title>", item, re.DOTALL)
        title = strip_tags(title_match.group(1)) if title_match else ""
        if not title:
            continue
        articles.append(
            {
                "title": title,
                "desc": extract_rss_desc(item),
                "link": extract_link(item),
            }
        )

    if articles and not articles[0]["desc"] and articles[0]["link"]:
        articles[0]["desc"] = fetch_meta_description(articles[0]["link"])
    if not articles:
        raise FeedError("RSS取得失敗")

    content = f"## {provider_name} 最新情報 ({today})\n\n"
    content += "### 最新記事\n\n"
    for article in articles:
        content += f"**{article['title']}**\n"
        if article["desc"]:
            suffix = "..." if len(article["desc"]) == 400 else ""
            content += f"{article['desc']}{suffix}\n"
        if article["link"]:
            content += f"[記事を読む]({article['link']})\n"
        content += "\n"
    content += f"> 出典: {url}"
    return content


def main() -> None:
    if len(sys.argv) < 4:
        print("Usage: parse_rss.py <url> <provider_name> <today>", file=sys.stderr)
        sys.exit(1)

    url, provider_name, today = sys.argv[1], sys.argv[2], sys.argv[3]
    try:
        print(build_markdown(url, provider_name, today))
    except Exception as exc:  # noqa: BLE001 - the workflow only needs a short reason.
        print(f"RSS fetch failed for {provider_name}: {exc}", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
