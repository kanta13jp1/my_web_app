#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import tempfile
import unittest
import xml.dom.minidom
from pathlib import Path

from scripts.generate_sitemap import PUBLIC_ROUTES, build_sitemap
from scripts.prerender_seo_routes import (
    build_public_route_html,
    build_route_html,
)

TEMPLATE = """<!DOCTYPE html>
<html lang="ja">
<head>
  <meta
    name="description"
    content="HOMEPAGE DESC"
  >
  <link rel="canonical" href="https://my-web-app-b67f4.web.app/">
  <meta property="og:title" content="HOME OG TITLE">
  <meta
    property="og:description"
    content="HOME OG DESC"
  >
  <meta property="og:url" content="https://my-web-app-b67f4.web.app/">
  <meta property="og:type" content="website">
  <meta property="twitter:title" content="HOME TW TITLE">
  <meta
    property="twitter:description"
    content="HOME TW DESC"
  >
  <meta property="twitter:url" content="https://my-web-app-b67f4.web.app/">
  <title>ホーム | 自分株式会社</title>
</head>
<body>
  <div id="seo-shell">
    <h1 id="seo-title">自分株式会社</h1>
    <p lang="ja">ホームページの汎用説明文。</p>
  </div>
</body>
</html>
"""

ROUTE = {
    "slug": "notion",
    "competitor": "Notion",
    "category": "ノート",
    "title": "自分株式会社 vs Notion | Notion代替",
    "description": "Notion代替の説明 <b>強調</b> と & 記号。",
    "points": ["ポイント1", "ポイント2 </script>", "ポイント3"],
}

BASE = "https://my-web-app-b67f4.web.app"


class PrerenderRouteTest(unittest.TestCase):
    def setUp(self) -> None:
        self.out = build_route_html(TEMPLATE, ROUTE, BASE)

    def test_self_canonical(self) -> None:
        self.assertIn(
            '<link rel="canonical" href="https://my-web-app-b67f4.web.app/vs-notion">',
            self.out,
        )
        self.assertNotIn(
            '<link rel="canonical" href="https://my-web-app-b67f4.web.app/">',
            self.out,
        )

    def test_route_specific_title_no_homepage_leak(self) -> None:
        self.assertIn(
            "<title>自分株式会社 vs Notion | Notion代替</title>", self.out)
        self.assertNotIn("<title>ホーム | 自分株式会社</title>", self.out)

    def test_meta_description_and_og_replaced(self) -> None:
        # 複数行 <meta> でも置換される
        self.assertNotIn("HOMEPAGE DESC", self.out)
        self.assertNotIn("HOME OG DESC", self.out)
        self.assertNotIn("HOME TW DESC", self.out)
        # description は HTML エスケープされて入る
        self.assertIn("Notion代替の説明 &lt;b&gt;強調&lt;/b&gt; と &amp; 記号。",
                      self.out)
        self.assertIn(
            '<meta property="og:type" content="article">', self.out)

    def test_seo_shell_body_has_comparison_content(self) -> None:
        self.assertIn('<h1 id="seo-title">自分株式会社 vs Notion | Notion代替</h1>',
                      self.out)
        self.assertNotIn("自分株式会社</h1>".replace("自分株式会社 vs", ""),
                         self.out.split("<h1")[0])  # sanity, no bare homepage h1
        self.assertIn('data-prerender="vs-body"', self.out)
        self.assertIn("<li>ポイント1</li>", self.out)
        self.assertIn("Notionとの比較ポイント", self.out)

    def test_jsonld_injected_and_escaped(self) -> None:
        blocks = re.findall(
            r'<script type="application/ld\+json"[^>]*>(.*?)</script>',
            self.out, re.DOTALL)
        # data-prerender="vs" の JSON-LD が1つ増える
        vs_blocks = re.findall(
            r'<script type="application/ld\+json" data-prerender="vs">(.*?)</script>',
            self.out, re.DOTALL)
        self.assertEqual(len(vs_blocks), 1)
        raw = vs_blocks[0]
        # <script> ブレイクアウト防止: 生の </script> が値由来で出ない
        self.assertNotIn("</script></script>", self.out)
        parsed = json.loads(raw.replace("\\u003c", "<"))
        types = [g["@type"] for g in parsed["@graph"]]
        self.assertEqual(types, ["WebPage", "BreadcrumbList", "FAQPage"])
        # BreadcrumbList の最終要素が自 URL
        bc = next(g for g in parsed["@graph"] if g["@type"] == "BreadcrumbList")
        self.assertEqual(bc["itemListElement"][-1]["item"], f"{BASE}/vs-notion")


PUBLIC_ROUTE = {
    "path": "/competitors",
    "title": "競合比較 174社 | 自分株式会社",
    "description": "174社以上と比較。<b>統合</b> & 一元管理。",
    "h1": "競合174社との比較",
    "points": ["ポイントA", "ポイントB </script>"],
}


class PublicRouteTest(unittest.TestCase):
    def setUp(self) -> None:
        self.out = build_public_route_html(TEMPLATE, PUBLIC_ROUTE, BASE)

    def test_self_canonical_and_title(self) -> None:
        self.assertIn(
            '<link rel="canonical" href="https://my-web-app-b67f4.web.app/competitors">',
            self.out,
        )
        self.assertIn("<title>競合比較 174社 | 自分株式会社</title>", self.out)
        self.assertNotIn("<title>ホーム | 自分株式会社</title>", self.out)

    def test_body_and_jsonld(self) -> None:
        self.assertIn('<h1 id="seo-title">競合174社との比較</h1>', self.out)
        self.assertIn('data-prerender="public-body"', self.out)
        self.assertIn("<li>ポイントA</li>", self.out)
        vs = re.findall(
            r'<script type="application/ld\+json" data-prerender="public">(.*?)</script>',
            self.out, re.DOTALL)
        self.assertEqual(len(vs), 1)
        self.assertNotIn("</script></script>", self.out)
        parsed = json.loads(vs[0].replace("\\u003c", "<"))
        self.assertEqual(parsed["@type"], "WebPage")
        self.assertEqual(parsed["url"], f"{BASE}/competitors")


class SitemapTest(unittest.TestCase):
    def test_sitemap_contents_and_wellformed(self) -> None:
        slugs = ["notion", "evernote", "slack"]
        doc = build_sitemap(BASE, slugs, "2026-07-09")
        xml.dom.minidom.parseString(doc)  # raises if malformed
        self.assertEqual(doc.count("<loc>"), len(PUBLIC_ROUTES) + len(slugs))
        self.assertIn(f"<loc>{BASE}/</loc>", doc)
        self.assertIn(f"<loc>{BASE}/vs-notion</loc>", doc)
        self.assertIn(f"<loc>{BASE}/competitors</loc>", doc)
        self.assertIn("<lastmod>2026-07-09</lastmod>", doc)
        # doorway 化していた routeless URL は含まれない
        self.assertNotIn("/vs-yamato", doc)

    def test_homepage_priority_is_highest(self) -> None:
        doc = build_sitemap(BASE, [], "2026-07-09")
        home = doc.split(f"<loc>{BASE}/</loc>")[1].split("</url>")[0]
        self.assertIn("<priority>1.0</priority>", home)


if __name__ == "__main__":
    unittest.main()
