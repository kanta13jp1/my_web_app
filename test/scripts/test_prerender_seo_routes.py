#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import struct
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
  <meta property="og:image" content="https://example.com/home.png">
  <meta property="og:image:alt" content="HOME IMAGE">
  <meta property="twitter:title" content="HOME TW TITLE">
  <meta
    property="twitter:description"
    content="HOME TW DESC"
  >
  <meta property="twitter:url" content="https://my-web-app-b67f4.web.app/">
  <meta property="twitter:image" content="https://example.com/home.png">
  <meta property="twitter:image:alt" content="HOME IMAGE">
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


class HomepageSocialPreviewTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.repo_root = Path(__file__).resolve().parents[2]
        cls.index_html = (cls.repo_root / "web" / "index.html").read_text(
            encoding="utf-8"
        )
        cls.og_image = (
            cls.repo_root / "web" / "lp-og-first-action-20260720.png"
        )

    def test_home_meta_matches_brand_search_intent(self) -> None:
        self.assertIn(
            '<meta property="og:title" '
            'content="自分株式会社 | 人生を経営するAIライフマネジメントアプリ">',
            self.index_html,
        )
        self.assertIn(
            'content="自分自身を一つの会社に見立て、人生のCEOとして仕事・学習・'
            'お金・健康を経営。AIが今日やる1件まで整理します。"',
            self.index_html,
        )
        self.assertIn(
            'content="自分株式会社は、自分自身を一つの会社に見立て、仕事・学習・'
            'お金・健康を整理するライフマネジメントアプリです。'
            '登録前にAIの提案を1件試せます。"',
            self.index_html,
        )
        self.assertIn(
            '<title>自分株式会社とは？ | 人生を経営するAIライフマネジメントアプリ</title>',
            self.index_html,
        )
        self.assertNotIn('<meta\n    name="keywords"', self.index_html)
        self.assertNotIn(
            '<meta property="og:title" content="自分株式会社 | 190社以上の競合SaaS',
            self.index_html,
        )

    def test_homepage_explains_the_brand_in_visible_semantic_html(self) -> None:
        self.assertIn('<h1 id="seo-title">自分株式会社</h1>', self.index_html)
        self.assertIn('<h2 id="seo-about-title">自分株式会社とは</h2>', self.index_html)
        self.assertIn('自分が人生のCEOとして決める', self.index_html)
        self.assertIn('<h3>個人経営の基本構造</h3>', self.index_html)
        self.assertIn('<dt>売上</dt>', self.index_html)
        self.assertIn('<dt>経費</dt>', self.index_html)
        self.assertIn('<dt>資産</dt>', self.index_html)
        self.assertIn('<dt>利益</dt>', self.index_html)
        self.assertIn('個人のP/L・B/S、6部署、30日運営サイクルを読む', self.index_html)
        self.assertIn('href="/philosophy"', self.index_html)
        self.assertIn(
            '"@id": "https://my-web-app-b67f4.web.app/#software-application"',
            self.index_html,
        )

    def test_home_og_image_is_real_lp_screenshot(self) -> None:
        image_url = f"{BASE}/lp-og-first-action-20260720.png"
        self.assertIn(
            f'property="og:image"\n    content="{image_url}"',
            self.index_html,
        )
        self.assertIn(
            f'property="twitter:image"\n    content="{image_url}"',
            self.index_html,
        )
        self.assertTrue(self.og_image.is_file())
        png = self.og_image.read_bytes()
        self.assertEqual(png[:8], b"\x89PNG\r\n\x1a\n")
        self.assertEqual(struct.unpack(">II", png[16:24]), (1200, 630))

    def test_default_and_ai_university_images_remain_route_specific(self) -> None:
        self.assertIn(
            "var defaultOgImageUrl = "
            "'https://my-web-app-b67f4.web.app/lp-og-first-action-20260720.png';",
            self.index_html,
        )
        self.assertIn(
            "var aiUniversityOgImageUrl = "
            "'https://my-web-app-b67f4.web.app/ogp-image-gen2-20260428.png';",
            self.index_html,
        )
        self.assertIn(
            '"url": "https://my-web-app-b67f4.web.app/icons/Icon-512.png"',
            self.index_html,
        )


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

    def test_route_specific_social_image(self) -> None:
        route = {
            **PUBLIC_ROUTE,
            "image": "/ai-university.png",
            "image_alt": "AI大学の学習画面",
        }
        out = build_public_route_html(TEMPLATE, route, BASE)
        self.assertIn(
            '<meta property="og:image" '
            'content="https://my-web-app-b67f4.web.app/ai-university.png">',
            out,
        )
        self.assertIn(
            '<meta property="twitter:image" '
            'content="https://my-web-app-b67f4.web.app/ai-university.png">',
            out,
        )
        self.assertIn(
            '<meta property="og:image:alt" content="AI大学の学習画面">',
            out,
        )

    def test_philosophy_route_renders_original_guide_and_visible_faq(self) -> None:
        repo_root = Path(__file__).resolve().parents[2]
        routes = json.loads(
            (repo_root / "web" / "seo" / "public-routes.json").read_text(
                encoding="utf-8"
            )
        )
        route = next(
            item for item in routes["routes"] if item["path"] == "/philosophy"
        )
        index_html = (repo_root / "web" / "index.html").read_text(
            encoding="utf-8"
        )

        out = build_public_route_html(index_html, route, BASE)

        self.assertIn(
            "<title>自分株式会社とは？人生を経営する9原則と実践方法</title>",
            out,
        )
        self.assertIn("個人のP/LとB/Sで生活を見直す", out)
        self.assertIn("人生を6部署に分けて点検する", out)
        self.assertIn("30日で回す自分株式会社の運営サイクル", out)
        self.assertIn("3分でできる棚卸しの記入例", out)
        self.assertIn("架空ケース：30日でどう見直すか", out)
        self.assertIn("実在する利用者の体験談や成果ではなく", out)
        self.assertIn("このページの編集方針", out)
        self.assertIn('data-prerender="public-faq"', out)
        self.assertIn("自分株式会社とは何ですか？", out)
        self.assertIn('href="/development-achievements"', out)
        self.assertIn('href="https://github.com/kanta13jp1"', out)
        self.assertIn("GitHub @kanta13jp1", out)
        self.assertIn('<time datetime="2026-08-23">2026-08-23</time>', out)

        blocks = re.findall(
            r'<script type="application/ld\+json" data-prerender="public">'
            r"(.*?)</script>",
            out,
            re.DOTALL,
        )
        self.assertEqual(len(blocks), 1)
        parsed = json.loads(blocks[0].replace("\\u003c", "<"))
        types = [item["@type"] for item in parsed["@graph"]]
        self.assertEqual(types, ["WebPage", "BreadcrumbList", "FAQPage"])
        webpage = parsed["@graph"][0]
        self.assertEqual(webpage["datePublished"], "2026-04-18")
        self.assertEqual(webpage["dateModified"], "2026-08-23")
        faq = parsed["@graph"][2]
        self.assertEqual(len(faq["mainEntity"]), 4)

        all_blocks = re.findall(
            r'<script type="application/ld\+json"[^>]*>(.*?)</script>',
            out,
            re.DOTALL,
        )
        all_schemas = [
            json.loads(block.replace("\\u003c", "<")) for block in all_blocks
        ]
        faq_pages = []
        for schema in all_schemas:
            nodes = schema.get("@graph", [schema])
            faq_pages.extend(
                node for node in nodes if node.get("@type") == "FAQPage"
            )
        self.assertEqual(len(faq_pages), 1)
        visible_faq = re.search(
            r'<section id="philosophy-faq" data-prerender="public-faq">'
            r"(.*?)</section>",
            out,
            re.DOTALL,
        )
        self.assertIsNotNone(visible_faq)
        visible_questions = re.findall(
            r"<dt>(.*?)</dt>", visible_faq.group(1), re.DOTALL
        )
        structured_questions = [
            item["name"] for item in faq_pages[0]["mainEntity"]
        ]
        self.assertEqual(structured_questions, visible_questions)

    def test_ai_university_config_uses_dedicated_social_image(self) -> None:
        repo_root = Path(__file__).resolve().parents[2]
        routes = json.loads(
            (repo_root / "web" / "seo" / "public-routes.json").read_text(
                encoding="utf-8"
            )
        )
        route = next(
            item
            for item in routes["routes"]
            if item["path"] == "/ai-university"
        )
        index_html = (repo_root / "web" / "index.html").read_text(
            encoding="utf-8"
        )

        out = build_public_route_html(index_html, route, BASE)
        image_url = f"{BASE}/ogp-image-gen2-20260428.png"
        homepage_image_url = f"{BASE}/lp-og-first-action-20260720.png"

        self.assertRegex(
            out,
            rf'<meta\s+property="og:image"\s+content="{re.escape(image_url)}"\s*>',
        )
        self.assertRegex(
            out,
            rf'<meta\s+property="twitter:image"\s+'
            rf'content="{re.escape(image_url)}"\s*>',
        )
        self.assertIsNone(
            re.search(
                rf'<meta\s+property="og:image"\s+'
                rf'content="{re.escape(homepage_image_url)}"\s*>',
                out,
            )
        )

    def test_billing_route_exposes_approved_prices_and_direct_marker(
        self,
    ) -> None:
        repo_root = Path(__file__).resolve().parents[2]
        routes = json.loads(
            (repo_root / "web" / "seo" / "public-routes.json").read_text(
                encoding="utf-8"
            )
        )
        route = next(
            item
            for item in routes["routes"]
            if item["path"] == "/subscription-billing"
        )

        out = build_public_route_html(TEMPLATE, route, BASE)

        self.assertIn("<title>プランと応援 | 自分株式会社</title>", out)
        self.assertIn("月額980円", out)
        self.assertIn("月額2,980円", out)
        self.assertIn("1回100円", out)
        self.assertIn(
            'href="/subscription-billing?entry=static_pricing"',
            out,
        )

    def test_privacy_route_renders_approved_markdown_verbatim(self) -> None:
        repo_root = Path(__file__).resolve().parents[2]
        routes = json.loads(
            (repo_root / "web" / "seo" / "public-routes.json").read_text(
                encoding="utf-8"
            )
        )
        route = next(
            item for item in routes["routes"] if item["path"] == "/privacy"
        )
        policy = (repo_root / route["markdown_source"]).read_text(
            encoding="utf-8"
        )

        out = build_public_route_html(
            TEMPLATE,
            {**route, "_markdown_text": policy},
            BASE,
        )

        self.assertIn('data-prerender="markdown-source"', out)
        self.assertIn(
            'data-source="assets/legal/privacy_policy.md"',
            out,
        )
        self.assertIn("Privacy Policy / プライバシーポリシー", out)
        self.assertIn("ユーザーの権利", out)
        self.assertIn("Stripe, Inc.", out)
        self.assertIn(
            "本サービスはカード番号を保持しない",
            out,
        )
        self.assertNotIn("<https://stripe.com/privacy>", out)
        self.assertIn("&lt;https://stripe.com/privacy&gt;", out)


class SitemapTest(unittest.TestCase):
    def test_sitemap_contents_and_wellformed(self) -> None:
        slugs = ["notion", "evernote", "slack"]
        doc = build_sitemap(BASE, slugs, "2026-07-09")
        xml.dom.minidom.parseString(doc)  # raises if malformed
        self.assertEqual(doc.count("<loc>"), len(PUBLIC_ROUTES) + len(slugs))
        self.assertIn(f"<loc>{BASE}/</loc>", doc)
        self.assertIn(f"<loc>{BASE}/vs-notion</loc>", doc)
        self.assertIn(f"<loc>{BASE}/competitors</loc>", doc)
        self.assertIn(f"<loc>{BASE}/shop</loc>", doc)
        self.assertIn("<lastmod>2026-07-09</lastmod>", doc)
        # doorway 化していた routeless URL は含まれない
        self.assertNotIn("/vs-yamato", doc)

    def test_homepage_priority_is_highest(self) -> None:
        doc = build_sitemap(BASE, [], "2026-07-09")
        home = doc.split(f"<loc>{BASE}/</loc>")[1].split("</url>")[0]
        self.assertIn("<priority>1.0</priority>", home)

    def test_sitemap_omits_unverified_lastmod_values(self) -> None:
        doc = build_sitemap(
            BASE,
            ["notion"],
            None,
            {"/philosophy": "2026-08-23"},
        )

        self.assertEqual(doc.count("<lastmod>"), 1)
        philosophy = doc.split(f"<loc>{BASE}/philosophy</loc>")[1].split(
            "</url>", 1
        )[0]
        home = doc.split(f"<loc>{BASE}/</loc>")[1].split("</url>", 1)[0]
        comparison = doc.split(f"<loc>{BASE}/vs-notion</loc>")[1].split(
            "</url>", 1
        )[0]

        self.assertIn("<lastmod>2026-08-23</lastmod>", philosophy)
        self.assertNotIn("<lastmod>", home)
        self.assertNotIn("<lastmod>", comparison)


if __name__ == "__main__":
    unittest.main()
