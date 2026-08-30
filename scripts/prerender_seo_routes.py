#!/usr/bin/env python3
"""厳選 /vs-<slug> ルートの静的 HTML を prerender する (SEO インデックス性回復)。

自分株式会社は Flutter Web SPA で、Firebase の `** -> /index.html` rewrite により
全ルートがバイト同一の index.html を配信する。その静的 HTML の <link rel=canonical>
はトップ固定・本文は CanvasKit canvas 描画のため、非JSクローラーには全ルート同一の
トップ内容しか届かず、大多数のルートがトップへ canonical 集約されて独立インデックス
されない (SEO 監査 H1/H2/H4)。

本スクリプトは `web/seo/comparison-routes.json` の厳選競合について、テンプレート
index.html を元に build/web/vs-<slug>/index.html を生成する。各ファイルは
(a) rel=canonical を自 URL に、(b) title/description/OG をルート固有に、
(c) WebPage+BreadcrumbList+FAQPage の JSON-LD をルート固有に、
(d) seo-shell body にクロール可能な比較本文を焼き込む。
Firebase Hosting は一致する静的ファイルを ** rewrite より優先配信するため、
firebase.json を変更せず SPA も壊さずに per-route の server 配信を実現できる。

使い方 (CI): flutter build web の後・firebase deploy の前に
  python scripts/prerender_seo_routes.py \
    --template build/web/index.html --outdir build/web \
    --routes web/seo/comparison-routes.json
"""

from __future__ import annotations

import argparse
import html
import json
import re
import sys
from pathlib import Path


def replace_attr_content(html_text: str, selector_regex: str, new_value: str) -> str:
    """`<meta ... content="...">` 等の content 属性値を置換する。1 箇所のみ。"""
    escaped = html.escape(new_value, quote=True)
    return re.sub(selector_regex, lambda m: m.group(1) + escaped + m.group(3),
                 html_text, count=1)


def remove_homepage_faq_schema(html_text: str) -> str:
    """公開サブルートに引き継がれたホーム専用 FAQPage を除去する。"""
    return re.sub(
        r'\s*<script\s+type="application/ld\+json"\s+'
        r'data-homepage-schema="faq">.*?</script>',
        "",
        html_text,
        count=1,
        flags=re.DOTALL,
    )


def build_route_html(template: str, route: dict, base_url: str) -> str:
    slug = route["slug"]
    title = route["title"]
    desc = route["description"]
    competitor = route["competitor"]
    points = route.get("points", [])
    url = f"{base_url}/vs-{slug}"
    esc_title = html.escape(title)
    esc_desc = html.escape(desc)
    esc_url = html.escape(url)

    out = remove_homepage_faq_schema(template)

    # <title>
    out = re.sub(r"<title>.*?</title>",
                 f"<title>{esc_title}</title>", out, count=1, flags=re.DOTALL)

    # canonical
    out = re.sub(r'(<link rel="canonical" href=")[^"]*(">)',
                 lambda m: m.group(1) + esc_url + m.group(2), out, count=1)

    # description / OG / Twitter (name= と property= の両形式)
    out = replace_attr_content(
        out, r'(<meta\s+name="description"\s+content=")([^"]*)(")', desc)
    out = replace_attr_content(
        out, r'(<meta property="og:title" content=")([^"]*)(")', title)
    out = replace_attr_content(
        out, r'(<meta\s+property="og:description"\s+content=")([^"]*)(")', desc)
    out = replace_attr_content(
        out, r'(<meta property="og:url" content=")([^"]*)(")', url)
    out = replace_attr_content(
        out, r'(<meta property="og:type" content=")([^"]*)(")', "article")
    out = replace_attr_content(
        out, r'(<meta property="twitter:title" content=")([^"]*)(")', title)
    out = replace_attr_content(
        out, r'(<meta\s+property="twitter:description"\s+content=")([^"]*)(")', desc)
    out = replace_attr_content(
        out, r'(<meta property="twitter:url" content=")([^"]*)(")', url)

    # ルート固有 JSON-LD (WebPage + BreadcrumbList + FAQPage) を </head> 直前に注入
    faq = [
        {
            "@type": "Question",
            "name": f"{competitor}と自分株式会社は何が違うの?",
            "acceptedAnswer": {"@type": "Answer", "text": desc},
        },
        {
            "@type": "Question",
            "name": "自分株式会社は無料で使えますか?",
            "acceptedAnswer": {
                "@type": "Answer",
                "text": "はい、無料で始められます。登録なしでAI提案を1回体験でき、"
                        "登録後も基本機能は無料で利用できます。Pro/Teamは追加機能・"
                        "上限緩和・開発支援のための有料プランです。",
            },
        },
        {
            "@type": "Question",
            "name": f"{competitor}から自分株式会社へ乗り換えられますか?",
            "acceptedAnswer": {
                "@type": "Answer",
                "text": "30秒でアカウント登録でき、既存データはMarkdown形式で取り込めます。"
                        "NotionとEvernoteはインポート機能もあります。無料コアからお試しください。",
            },
        },
    ]
    graph = {
        "@context": "https://schema.org",
        "@graph": [
            {
                "@type": "WebPage",
                "@id": f"{url}#webpage",
                "url": url,
                "name": title,
                "description": desc,
                "inLanguage": "ja",
                "isPartOf": {"@id": f"{base_url}/#website"},
                "publisher": {"@id": f"{base_url}/#organization"},
                "breadcrumb": {"@id": f"{url}#breadcrumb"},
            },
            {
                "@type": "BreadcrumbList",
                "@id": f"{url}#breadcrumb",
                "itemListElement": [
                    {"@type": "ListItem", "position": 1, "name": "自分株式会社",
                     "item": f"{base_url}/"},
                    {"@type": "ListItem", "position": 2, "name": "競合比較",
                     "item": f"{base_url}/competitors"},
                    {"@type": "ListItem", "position": 3, "name": title, "item": url},
                ],
            },
            {"@type": "FAQPage", "@id": f"{url}#faq", "mainEntity": faq},
        ],
    }
    json_ld = json.dumps(graph, ensure_ascii=False).replace("<", "\\u003c")
    ld_block = (
        '  <script type="application/ld+json" data-prerender="vs">'
        f"{json_ld}</script>\n</head>"
    )
    out = out.replace("</head>", ld_block, 1)

    # seo-shell の h1 と最初の日本語段落を置換し、比較本文リストを注入
    out = re.sub(r'(<h1 id="seo-title">).*?(</h1>)',
                 lambda m: m.group(1) + esc_title + m.group(2),
                 out, count=1, flags=re.DOTALL)
    points_html = "".join(
        f"<li>{html.escape(p)}</li>" for p in points
    )
    comparison_section = (
        f'<p lang="ja">{esc_desc}</p>'
        f'<section aria-label="{html.escape(competitor)}との比較" '
        'data-prerender="vs-body">'
        f"<h2>{html.escape(competitor)}との比較ポイント</h2>"
        f"<ul>{points_html}</ul></section>"
    )
    # 最初の <p lang="ja">...</p> を比較セクションに差し替え
    out = re.sub(r'<p\b[^>]*\blang="ja"[^>]*>.*?</p>', comparison_section,
                 out, count=1, flags=re.DOTALL)

    return out


def build_public_route_html(template: str, route: dict, base_url: str) -> str:
    """実在公開ルート (競合比較以外) の静的HTML。自己参照 canonical + 固有
    title/meta/OG + WebPage JSON-LD + seo-shell にクロール可能な本文。"""
    path = route["path"]
    title = route["title"]
    desc = route["description"]
    h1 = route.get("h1", title)
    points = route.get("points", [])
    url = f"{base_url}{path}"
    esc_title = html.escape(title)
    esc_desc = html.escape(desc)
    esc_url = html.escape(url)

    out = remove_homepage_faq_schema(template)
    out = re.sub(r"<title>.*?</title>",
                 f"<title>{esc_title}</title>", out, count=1, flags=re.DOTALL)
    out = re.sub(r'(<link rel="canonical" href=")[^"]*(">)',
                 lambda m: m.group(1) + esc_url + m.group(2), out, count=1)
    out = replace_attr_content(
        out, r'(<meta\s+name="description"\s+content=")([^"]*)(")', desc)
    out = replace_attr_content(
        out, r'(<meta property="og:title" content=")([^"]*)(")', title)
    out = replace_attr_content(
        out, r'(<meta\s+property="og:description"\s+content=")([^"]*)(")', desc)
    out = replace_attr_content(
        out, r'(<meta property="og:url" content=")([^"]*)(")', url)
    out = replace_attr_content(
        out, r'(<meta property="twitter:title" content=")([^"]*)(")', title)
    out = replace_attr_content(
        out, r'(<meta\s+property="twitter:description"\s+content=")([^"]*)(")', desc)
    out = replace_attr_content(
        out, r'(<meta property="twitter:url" content=")([^"]*)(")', url)

    image = route.get("image")
    if image:
        image_url = image if image.startswith("http") else f"{base_url}{image}"
        image_alt = route.get("image_alt", title)
        out = replace_attr_content(
            out, r'(<meta\s+property="og:image"\s+content=")([^"]*)(")',
            image_url)
        out = replace_attr_content(
            out, r'(<meta\s+property="twitter:image"\s+content=")([^"]*)(")',
            image_url)
        out = replace_attr_content(
            out, r'(<meta property="og:image:alt" content=")([^"]*)(")',
            image_alt)
        out = replace_attr_content(
            out, r'(<meta property="twitter:image:alt" content=")([^"]*)(")',
            image_alt)

    web_page = {
        "@context": "https://schema.org",
        "@type": "WebPage",
        "@id": f"{url}#webpage",
        "url": url,
        "name": title,
        "description": desc,
        "inLanguage": "ja",
        "isPartOf": {"@id": f"{base_url}/#website"},
        "publisher": {"@id": f"{base_url}/#organization"},
    }
    for field in ("datePublished", "dateModified"):
        config_key = "date_published" if field == "datePublished" else "date_modified"
        if route.get(config_key):
            web_page[field] = route[config_key]

    faq = route.get("faq", [])
    if faq:
        breadcrumb = {
            "@type": "BreadcrumbList",
            "@id": f"{url}#breadcrumb",
            "itemListElement": [
                {
                    "@type": "ListItem",
                    "position": 1,
                    "name": "自分株式会社",
                    "item": f"{base_url}/",
                },
                {
                    "@type": "ListItem",
                    "position": 2,
                    "name": route.get("breadcrumb_label", h1),
                    "item": url,
                },
            ],
        }
        web_page["breadcrumb"] = {"@id": f"{url}#breadcrumb"}
        graph = {
            "@context": "https://schema.org",
            "@graph": [
                {key: value for key, value in web_page.items() if key != "@context"},
                breadcrumb,
                {
                    "@type": "FAQPage",
                    "@id": f"{url}#faq",
                    "mainEntity": [
                        {
                            "@type": "Question",
                            "name": item["question"],
                            "acceptedAnswer": {
                                "@type": "Answer",
                                "text": item["answer"],
                            },
                        }
                        for item in faq
                    ],
                },
            ],
        }
    else:
        graph = web_page
    json_ld = json.dumps(graph, ensure_ascii=False).replace("<", "\\u003c")
    out = out.replace(
        "</head>",
        '  <script type="application/ld+json" data-prerender="public">'
        f"{json_ld}</script>\n</head>", 1)

    out = re.sub(r'(<h1 id="seo-title">).*?(</h1>)',
                 lambda m: m.group(1) + html.escape(h1) + m.group(2),
                 out, count=1, flags=re.DOTALL)
    points_html = "".join(f"<li>{html.escape(p)}</li>" for p in points)
    sections_html = "".join(
        _render_public_section(item) for item in route.get("sections", [])
    )
    faq_html = _render_public_faq(faq)
    links_html = _render_public_links(route.get("links", []))
    markdown_html = _render_markdown_source(
        route.get("_markdown_text"),
        route.get("markdown_source"),
    )
    updated_html = ""
    if route.get("date_modified"):
        updated_html = (
            '<p data-prerender="public-updated">'
            f'最終更新: <time datetime="{html.escape(route["date_modified"], quote=True)}">'
            f'{html.escape(route["date_modified"])}</time></p>'
        )
    section = (
        f'<p lang="ja">{esc_desc}</p>'
        f'<section aria-label="{html.escape(h1)}" data-prerender="public-body">'
        f"<ul>{points_html}</ul></section>"
        f"{updated_html}{sections_html}{faq_html}{links_html}"
        f"{markdown_html}"
    )
    out = re.sub(
        r'<p\b[^>]*\blang="ja"[^>]*>.*?</p>',
        section,
        out,
        count=1,
        flags=re.DOTALL,
    )
    return out


def _render_public_section(section: dict) -> str:
    """Render one trusted public-route content section as semantic static HTML."""
    section_id = section.get("id")
    id_attr = (
        f' id="{html.escape(section_id, quote=True)}"' if section_id else ""
    )
    body = section.get("body")
    body_html = f"<p>{html.escape(body)}</p>" if body else ""
    points_html = "".join(
        f"<li>{html.escape(point)}</li>" for point in section.get("points", [])
    )
    list_html = f"<ul>{points_html}</ul>" if points_html else ""
    return (
        f'<section{id_attr} data-prerender="public-section">'
        f'<h2>{html.escape(section["heading"])}</h2>'
        f"{body_html}{list_html}</section>"
    )


def _render_public_faq(faq: list[dict]) -> str:
    if not faq:
        return ""
    items = "".join(
        "<div>"
        f'<dt>{html.escape(item["question"])}</dt>'
        f'<dd>{html.escape(item["answer"])}</dd>'
        "</div>"
        for item in faq
    )
    return (
        '<section id="philosophy-faq" data-prerender="public-faq">'
        f"<h2>よくある質問</h2><dl>{items}</dl></section>"
    )


def _render_public_links(links: list[dict]) -> str:
    if not links:
        return ""
    items = "".join(
        f'<li><a href="{html.escape(item["href"], quote=True)}">'
        f'{html.escape(item["label"])}</a></li>'
        for item in links
    )
    return (
        '<nav aria-label="関連ページ" data-prerender="public-links">'
        f"<h2>関連ページ</h2><ul>{items}</ul></nav>"
    )


def _render_markdown_source(markdown_text: str | None, source: str | None) -> str:
    """Expose an approved Markdown source verbatim without re-authoring it.

    Legal copy is deliberately not interpreted as arbitrary HTML. A pre-wrapped,
    escaped source keeps every heading, table, link and revision marker readable
    in the initial response while preserving the repository asset as canonical.
    """
    if markdown_text is None:
        return ""
    source_attr = (
        f' data-source="{html.escape(source, quote=True)}"' if source else ""
    )
    return (
        '<article aria-label="承認済み原文" data-prerender="markdown-source"'
        f'{source_attr}><h2>プライバシーポリシー原文</h2>'
        '<pre style="white-space:pre-wrap;overflow-wrap:anywhere">'
        f"{html.escape(markdown_text)}</pre></article>"
    )


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--template", required=True,
                    help="テンプレート index.html (通常 build/web/index.html)")
    ap.add_argument("--outdir", required=True,
                    help="出力先ルート (通常 build/web)")
    ap.add_argument("--routes", default="web/seo/comparison-routes.json")
    ap.add_argument("--public-routes", default=None,
                    help="公開ルート config (web/seo/public-routes.json)")
    ap.add_argument("--base-url", default=None,
                    help="省略時は routes JSON の site を使用")
    args = ap.parse_args(argv)

    template = Path(args.template).read_text(encoding="utf-8")
    config = json.loads(Path(args.routes).read_text(encoding="utf-8"))
    base_url = (args.base_url or config["site"]).rstrip("/")

    outdir = Path(args.outdir)
    vs_written = 0
    for route in config["routes"]:
        page = build_route_html(template, route, base_url)
        dest = outdir / f"vs-{route['slug']}" / "index.html"
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(page, encoding="utf-8")
        vs_written += 1

    pub_written = 0
    if args.public_routes:
        pub_config = json.loads(
            Path(args.public_routes).read_text(encoding="utf-8"))
        pub_base = (args.base_url or pub_config["site"]).rstrip("/")
        for route in pub_config["routes"]:
            resolved_route = dict(route)
            markdown_source = route.get("markdown_source")
            if markdown_source:
                resolved_route["_markdown_text"] = Path(markdown_source).read_text(
                    encoding="utf-8"
                )
            page = build_public_route_html(template, resolved_route, pub_base)
            dest = outdir / route["path"].strip("/") / "index.html"
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_text(page, encoding="utf-8")
            pub_written += 1

    print(f"prerendered {vs_written} /vs-* + {pub_written} public routes "
          f"into {outdir}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
