#!/usr/bin/env python3
"""RSS フィードを解析して AI大学コンテンツ用 Markdown を生成する。

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


def main() -> None:
    if len(sys.argv) < 4:
        print("Usage: parse_rss.py <url> <provider_name> <today>")
        sys.exit(1)

    url, pname, today = sys.argv[1], sys.argv[2], sys.argv[3]

    try:
        req = urllib.request.Request(
            url, headers={"User-Agent": "Mozilla/5.0 (compatible; AIUniversity/1.0)"}
        )
        data = urllib.request.urlopen(req, timeout=10).read().decode("utf-8", errors="replace")

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

            # Try description → summary → content:encoded in order
            d = re.search(
                r"<description\b[^>]*>(.*?)</description>"
                r"|<summary\b[^>]*>(.*?)</summary>"
                r"|<content:encoded\b[^>]*>(.*?)</content:encoded>",
                item,
                re.DOTALL,
            )
            desc = ""
            if d:
                raw = d.group(1) or d.group(2) or d.group(3) or ""
                desc = strip_tags(raw)[:500]

            if title:
                articles.append({"title": title, "desc": desc})

        content = f"## {pname} 最新情報 ({today})\n\n"
        if articles:
            content += "### 最新記事\n\n"
            for a in articles:
                content += f"- {a['title']}\n"
            first_desc = next((a["desc"] for a in articles if a["desc"]), "")
            if first_desc:
                suffix = "..." if len(first_desc) == 500 else ""
                content += f"\n### 最新記事の概要\n\n{first_desc}{suffix}\n"
        else:
            content += "RSS取得失敗 — 次回更新をお待ちください\n"

        content += f"\n> 出典: {url}"
        print(content)

    except Exception as exc:
        print(f"## {pname} 最新情報 ({today})\n\nRSS取得エラー: {exc}\n\n> 出典: {url}")


if __name__ == "__main__":
    main()
