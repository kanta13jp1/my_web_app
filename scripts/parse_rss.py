#!/usr/bin/env python3
"""RSS/Atom フィードを解析して AI大学コンテンツ用 Markdown を生成する。

RSSにdescriptionがない場合、最初の記事URLのmeta descriptionを取得して概要とする。

Usage: python3 scripts/parse_rss.py <rss_url> <provider_name> <today_YYYY-MM-DD>
"""
import sys
import urllib.request
import re
import html as html_mod


def strip_tags(s: str) -> str:
    s = re.sub(r"<[^>]+>", " ", s)
    s = html_mod.unescape(s)
    return re.sub(r"\s+", " ", s).strip()


def fetch_text(url: str, timeout: int = 8) -> str:
    try:
        req = urllib.request.Request(
            url, headers={"User-Agent": "Mozilla/5.0 (compatible; AIUniversity/1.0)"}
        )
        return urllib.request.urlopen(req, timeout=timeout).read().decode("utf-8", errors="replace")
    except Exception:
        return ""


def extract_rss_desc(item: str) -> str:
    """RSS item から description/summary/content を試みる (20文字以上なら採用)"""
    patterns = [
        r"<description\b[^>]*>(.*?)</description>",
        r"<summary\b[^>]*>(.*?)</summary>",
        r"<content:encoded\b[^>]*>(.*?)</content:encoded>",
        r"<content\b[^>]*>(.*?)</content>",
    ]
    for pat in patterns:
        m = re.search(pat, item, re.DOTALL)
        if m:
            text = strip_tags(m.group(1))
            if len(text) >= 20:
                return text[:400]
    return ""


def fetch_meta_description(url: str) -> str:
    """記事ページの <meta name="description"> を取得する"""
    if not url:
        return ""
    html = fetch_text(url)
    if not html:
        return ""
    m = re.search(
        r'<meta\s+(?:name=["\']description["\']\s+content=["\']([^"\']*)["\']'
        r'|content=["\']([^"\']*)["\']s+\name=["\']description["\'])',
        html,
        re.IGNORECASE,
    )
    if m:
        desc = html_mod.unescape((m.group(1) or m.group(2) or "").strip())
        if len(desc) >= 20:
            return desc[:400]
    # fallback: og:description
    m2 = re.search(
        r'<meta\s+(?:property=["\']og:description["\']\s+content=["\']([^"\']*)["\']'
        r'|content=["\']([^"\']*)["\']s+\property=["\']og:description["\'])',
        html,
        re.IGNORECASE,
    )
    if m2:
        desc = html_mod.unescape((m2.group(1) or m2.group(2) or "").strip())
        if len(desc) >= 20:
            return desc[:400]
    return ""


def extract_link(item: str) -> str:
    """RSS item から記事URLを取得する"""
    m = re.search(r"<link\b[^>]*/?>([^<]*)</link>|<link\b[^>]*href=['\"]([^'\"]+)['\"]", item, re.DOTALL)
    if m:
        return (m.group(1) or m.group(2) or "").strip()
    return ""


def main() -> None:
    if len(sys.argv) < 4:
        print("Usage: parse_rss.py <url> <provider_name> <today>")
        sys.exit(1)

    url, pname, today = sys.argv[1], sys.argv[2], sys.argv[3]

    try:
        data = fetch_text(url)
        if not data:
            raise RuntimeError("RSS取得失敗")

        # CDATA unwrap
        data = re.sub(r"<!\[CDATA\[", "", data)
        data = re.sub(r"\]\]>", "", data)

        # Extract items (RSS) or entries (Atom)
        items = re.findall(r"<item\b[^>]*>(.*?)</item>", data, re.DOTALL)
        if not items:
            items = re.findall(r"<entry\b[^>]*>(.*?)</entry>", data, re.DOTALL)

        articles = []
        for item in items[:5]:
            t = re.search(r"<title\b[^>]*>(.*?)</title>", item, re.DOTALL)
            title = strip_tags(t.group(1)) if t else ""
            desc = extract_rss_desc(item)
            link = extract_link(item)
            if title:
                articles.append({"title": title, "desc": desc, "link": link})

        # RSS に description がない場合、最初の記事ページから meta description を取得
        if articles and not articles[0]["desc"] and articles[0]["link"]:
            articles[0]["desc"] = fetch_meta_description(articles[0]["link"])

        content = f"## {pname} 最新情報 ({today})\n\n"
        if articles:
            content += "### 最新記事\n\n"
            for a in articles:
                content += f"**{a['title']}**\n"
                if a["desc"]:
                    suffix = "..." if len(a["desc"]) == 400 else ""
                    content += f"{a['desc']}{suffix}\n"
                if a["link"]:
                    content += f"[記事を読む]({a['link']})\n"
                content += "\n"
        else:
            content += "RSS取得失敗 — 次回更新をお待ちください\n"

        content += f"> 出典: {url}"
        print(content)

    except Exception as exc:
        print(f"## {pname} 最新情報 ({today})\n\nRSS取得エラー: {exc}\n\n> 出典: {url}")


if __name__ == "__main__":
    main()
