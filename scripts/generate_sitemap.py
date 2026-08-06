#!/usr/bin/env python3
"""実在ルートのみの sitemap.xml を生成する (SEO 監査 H3: 肥大・陳腐化の解消)。

旧 web/sitemap.xml は 1990 URL のうち約 88% が実体のない /vs-* (routeless、
LandingPage にフォールバック) で、クロールバジェットを浪費し品質シグナルを毀損して
いた。本スクリプトは (1) トップ、(2) 厳選 prerender 済み /vs-<slug> (comparison-
routes.json)、(3) 実在する公開ルートのみを含む sitemap を、当日の lastmod で生成する。

使い方:
  # 生成してリポジトリの正本を更新
  python scripts/generate_sitemap.py --out web/sitemap.xml --date 2026-07-09
  # CI: build 済みディレクトリにも出力 (flutter build web の後)
  python scripts/generate_sitemap.py --out build/web/sitemap.xml
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# 実在する公開ルート (client-side でも real な Flutter ページを描画するもの)。
# doorway 化していた routeless URL は含めない。(path, priority, changefreq)
PUBLIC_ROUTES: list[tuple[str, str, str]] = [
    ("/", "1.0", "daily"),
    ("/competitors", "0.8", "weekly"),
    ("/public-memos", "0.7", "daily"),
    ("/ai-university", "0.7", "weekly"),
    ("/gemini-university", "0.7", "weekly"),
    ("/ai-university-content", "0.6", "weekly"),
    ("/ai-university-ranking", "0.6", "weekly"),
    ("/ai-university-voice", "0.6", "weekly"),
    ("/project-gantt", "0.6", "daily"),
    ("/development-achievements", "0.6", "weekly"),
    ("/tech-blog-tracker", "0.5", "daily"),
    ("/real-world-danshari", "0.5", "weekly"),
    ("/ai-image-generator", "0.5", "weekly"),
    ("/public-guitar-gallery", "0.5", "weekly"),
    ("/philosophy", "0.5", "monthly"),
    ("/ai-dev-principles", "0.5", "monthly"),
    ("/referral", "0.4", "monthly"),
]


def build_sitemap(base_url: str, vs_slugs: list[str], date: str) -> str:
    base = base_url.rstrip("/")
    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    ]

    def url_entry(loc: str, priority: str, changefreq: str) -> None:
        lines.append("  <url>")
        lines.append(f"    <loc>{loc}</loc>")
        lines.append(f"    <lastmod>{date}</lastmod>")
        lines.append(f"    <changefreq>{changefreq}</changefreq>")
        lines.append(f"    <priority>{priority}</priority>")
        lines.append("  </url>")

    for path, priority, changefreq in PUBLIC_ROUTES:
        url_entry(f"{base}{path}", priority, changefreq)

    for slug in vs_slugs:
        url_entry(f"{base}/vs-{slug}", "0.8", "weekly")

    lines.append("</urlset>")
    lines.append("")
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", required=True, help="出力先 sitemap.xml パス")
    ap.add_argument("--routes", default="web/seo/comparison-routes.json")
    ap.add_argument("--base-url", default=None)
    ap.add_argument("--date", default=None,
                    help="lastmod (YYYY-MM-DD)。省略時は本日 (UTC)")
    args = ap.parse_args(argv)

    config = json.loads(Path(args.routes).read_text(encoding="utf-8"))
    base_url = (args.base_url or config["site"]).rstrip("/")
    vs_slugs = [r["slug"] for r in config["routes"]]

    date = args.date
    if not date:
        # CI で当日日付を使う。テスト時は --date で固定できる。
        import datetime
        date = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")

    xml = build_sitemap(base_url, vs_slugs, date)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(xml, encoding="utf-8")
    total = len(PUBLIC_ROUTES) + len(vs_slugs)
    print(f"wrote {total} URLs to {out} (lastmod={date})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
