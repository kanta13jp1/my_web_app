---
title: "Flutter Web SEO Guide — Meta Tags, Sitemaps, and Structured Data That Actually Work"
tags: flutter,webdev,SEO,indiedev
published: true
---

# Flutter Web SEO Guide — Meta Tags, Sitemaps, and Structured Data That Actually Work

If you've shipped a Flutter Web app and wondered why Google isn't indexing it, you're not alone. At Jibun Inc. — a Flutter Web + Supabase life management app competing with 21 rivals including Notion, Evernote, and MoneyForward — SEO is a business-critical concern. This guide covers every layer of the SEO stack for Flutter Web, from the renderer choice down to dynamic meta tag updates.

## Why Flutter Web SEO Is Uniquely Challenging

A traditional web page returns HTML that crawlers can parse immediately. Flutter Web defaults to the **CanvasKit renderer**, which paints everything into a `<canvas>` element. The resulting HTML contains almost no readable content:

```html
<!-- What Googlebot sees with CanvasKit (nearly empty) -->
<body>
  <script src="main.dart.js"></script>
  <flt-glass-pane></flt-glass-pane>
</body>
```

You have two main escape routes:

| Approach | Pros | Cons |
|----------|------|------|
| Switch to HTML renderer | Crawlers read real DOM elements | Slightly lower graphics fidelity |
| SSR / Pre-rendering | Best-in-class SEO | High implementation cost |
| `--web-renderer html` build flag | Zero code change required | Some widget differences |

Jibun Inc. uses **HTML renderer + static meta tags** as the pragmatic baseline, which covers 90% of SEO needs without major engineering effort.

## Step 1: Nail the index.html Meta Tags

`web/index.html` is the first file any crawler fetches. Meta tags here are available before the Flutter engine even boots.

```html
<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">

  <!-- Core SEO -->
  <title>Jibun Inc. — AI Life Management</title>
  <meta name="description"
    content="One app replacing Notion, Evernote, MoneyForward and 18 more.
             AI-powered life management built with Flutter Web + Supabase.">
  <meta name="robots" content="index, follow">
  <link rel="canonical" href="https://my-web-app-b67f4.web.app/">

  <!-- Open Graph -->
  <meta property="og:title" content="Jibun Inc. — AI Life Management">
  <meta property="og:description"
    content="21 competing apps unified into one Flutter Web + Supabase product.">
  <meta property="og:image"
    content="https://my-web-app-b67f4.web.app/og-image.png">
  <meta property="og:url" content="https://my-web-app-b67f4.web.app/">
  <meta property="og:type" content="website">
  <meta property="og:locale" content="ja_JP">

  <!-- Twitter Card -->
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:site" content="@kanta13jp1">
  <meta name="twitter:title" content="Jibun Inc. — AI Life Management">
  <meta name="twitter:image"
    content="https://my-web-app-b67f4.web.app/og-image.png">

  <!-- Force HTML renderer for SEO -->
  <script>window.flutterWebRenderer = "html";</script>
</head>
```

**Pro tip**: Generate a 1200×630 px `og-image.png` using your brand colors. This single image dramatically improves click-through rates on social shares.

## Step 2: Build a Proper sitemap.xml

Provide Google with the complete URL map of your app. Jibun Inc. manages 22 URLs across landing, comparison, and feature pages.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">

  <url>
    <loc>https://my-web-app-b67f4.web.app/</loc>
    <lastmod>2030-07-01</lastmod>
    <changefreq>weekly</changefreq>
    <priority>1.0</priority>
  </url>

  <url>
    <loc>https://my-web-app-b67f4.web.app/comparison</loc>
    <lastmod>2030-07-01</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.9</priority>
  </url>

  <url>
    <loc>https://my-web-app-b67f4.web.app/manual</loc>
    <lastmod>2030-06-01</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.7</priority>
  </url>

</urlset>
```

### Auto-regenerate sitemap on route changes

```python
# scripts/generate_sitemap.py
import re, datetime, pathlib

ROUTES_FILE = "lib/main.dart"
BASE_URL = "https://my-web-app-b67f4.web.app"
TODAY = datetime.date.today().isoformat()

# Extract GoRoute paths from main.dart
routes_text = pathlib.Path(ROUTES_FILE).read_text(encoding="utf-8")
paths = re.findall(r"path:\s*['\"](/[^'\"]*)['\"]", routes_text)

urls = []
for path in sorted(set(paths)):
    priority = "1.0" if path == "/" else "0.8"
    urls.append(f"""  <url>
    <loc>{BASE_URL}{path}</loc>
    <lastmod>{TODAY}</lastmod>
    <changefreq>monthly</changefreq>
    <priority>{priority}</priority>
  </url>""")

sitemap = f"""<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
{chr(10).join(urls)}
</urlset>
"""
pathlib.Path("web/sitemap.xml").write_text(sitemap, encoding="utf-8")
print(f"Generated {len(urls)} URLs")
```

## Step 3: Add JSON-LD Structured Data

Structured data helps Google display rich snippets (star ratings, price info, breadcrumbs) directly in search results.

```html
<!-- Embed in web/index.html <head> -->
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "SoftwareApplication",
      "name": "Jibun Inc.",
      "applicationCategory": "ProductivityApplication",
      "operatingSystem": "Web, iOS, Android",
      "description": "AI life management app unifying 21 competing tools.",
      "url": "https://my-web-app-b67f4.web.app/",
      "author": {
        "@type": "Person",
        "name": "kanta13jp1",
        "sameAs": "https://twitter.com/kanta13jp1"
      },
      "offers": {
        "@type": "Offer",
        "price": "0",
        "priceCurrency": "JPY",
        "availability": "https://schema.org/InStock"
      }
    },
    {
      "@type": "WebSite",
      "url": "https://my-web-app-b67f4.web.app/",
      "potentialAction": {
        "@type": "SearchAction",
        "target": {
          "@type": "EntryPoint",
          "urlTemplate": "https://my-web-app-b67f4.web.app/search?q={search_term_string}"
        },
        "query-input": "required name=search_term_string"
      }
    }
  ]
}
</script>
```

## Step 4: Dynamic Meta Tags for SPA Routes

The static `index.html` approach works for the root URL but breaks per-page SEO in a SPA. Fix this by updating meta tags at the Dart layer on every navigation.

```dart
// lib/utils/seo_helper.dart
import 'dart:js_interop';
import 'package:web/web.dart' as web;

class SeoHelper {
  static void updatePage({
    required String title,
    required String description,
    String? canonicalPath,
    String? ogImage,
  }) {
    final fullTitle = '$title | Jibun Inc.';
    final canonical = canonicalPath != null
        ? 'https://my-web-app-b67f4.web.app$canonicalPath'
        : null;

    web.document.title = fullTitle;
    _setMeta('name', 'description', description);
    _setMeta('property', 'og:title', fullTitle);
    _setMeta('property', 'og:description', description);
    if (ogImage != null) _setMeta('property', 'og:image', ogImage);
    if (canonical != null) _setCanonical(canonical);
  }

  static void _setMeta(String attr, String value, String content) {
    var el = web.document.querySelector('meta[$attr="$value"]')
        as web.HTMLMetaElement?;
    if (el == null) {
      el = web.document.createElement('meta') as web.HTMLMetaElement;
      el.setAttribute(attr, value);
      web.document.head?.appendChild(el);
    }
    el.content = content;
  }

  static void _setCanonical(String href) {
    var link = web.document.querySelector('link[rel="canonical"]')
        as web.HTMLLinkElement?;
    if (link == null) {
      link = web.document.createElement('link') as web.HTMLLinkElement;
      link.rel = 'canonical';
      web.document.head?.appendChild(link);
    }
    link.href = href;
  }
}
```

### Wire it into your GoRouter redirect

```dart
// lib/main.dart (router config)
GoRouter(
  observers: [SeoRouterObserver()],
  routes: [ ... ],
)

class SeoRouterObserver extends NavigatorObserver {
  static const _pageMeta = {
    '/': (
      title: 'Jibun Inc. — AI Life Management',
      description: 'Unified life management replacing 21 apps.',
    ),
    '/comparison': (
      title: 'App Comparison — Jibun Inc. vs Notion, Evernote & More',
      description: 'Feature-by-feature comparison with 21 competing apps.',
    ),
  };

  @override
  void didPush(Route route, Route? previousRoute) {
    final name = route.settings.name ?? '/';
    final meta = _pageMeta[name];
    if (meta != null) {
      SeoHelper.updatePage(
        title: meta.title,
        description: meta.description,
        canonicalPath: name,
      );
    }
  }
}
```

## Step 5: robots.txt and Firebase Hosting Config

```txt
# web/robots.txt
User-agent: *
Allow: /
Disallow: /admin/
Disallow: /api/

Sitemap: https://my-web-app-b67f4.web.app/sitemap.xml
```

Ensure Firebase Hosting serves these files correctly:

```json
// firebase.json (relevant snippet)
{
  "hosting": {
    "public": "build/web",
    "rewrites": [
      { "source": "/**", "destination": "/index.html" }
    ],
    "headers": [
      {
        "source": "/robots.txt",
        "headers": [{ "key": "Cache-Control", "value": "public, max-age=86400" }]
      },
      {
        "source": "/sitemap.xml",
        "headers": [{ "key": "Cache-Control", "value": "public, max-age=86400" }]
      }
    ]
  }
}
```

## Measuring Results

| Metric | Tool | Target |
|--------|------|--------|
| Index coverage | Google Search Console | 100% of routes indexed |
| Core Web Vitals | PageSpeed Insights | LCP < 2.5s, CLS < 0.1 |
| Rich snippets | Schema.org validator | No errors |
| Crawl errors | Search Console → Coverage | 0 errors |

## Summary

Flutter Web SEO requires more intentional work than React or Vue, but it's entirely achievable. The key insight: **separate what you can control statically (index.html) from what must be dynamic (per-route meta tags)**. Apply the HTML renderer, write complete meta tags, submit a sitemap, and add structured data — in that order of priority.

---

*Based on real implementation at Jibun Inc. (Flutter Web + Supabase, competing with 21 apps).*
