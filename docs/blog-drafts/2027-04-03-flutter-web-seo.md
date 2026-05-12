---
title: "Flutter Web の SEO 対策 — SPA の canonical / OGP / JSON-LD 完全実装"
tags: flutter,AI,個人開発,postgresql
published: true
---

# Flutter Web の SEO 対策 — SPA の canonical / OGP / JSON-LD 完全実装

Flutter Web はシングルページアプリケーション (SPA) です。デフォルトでは検索エンジンに「1ページしかない」と判断されます。このプロジェクトで 175 ルートの SEO を実装した方法を全公開します。

## SPA の SEO 問題

```
通常の Web:
  /page-a → page-a.html (それぞれ独立した HTML)
  /page-b → page-b.html

Flutter Web SPA:
  /page-a → index.html (全ページが同じ HTML)
  /page-b → index.html
  → Google は /page-a と /page-b が同じページと判断
```

Flutter Web は JavaScript でルーティングする SPA。`index.html` の `<head>` を動的に書き換えるか、ビルド時に静的 HTML を生成する必要がある。

## アプローチ: index.html で静的メタタグを実装

Flutter Web SPA では、JavaScript が実行される前に `<head>` のメタタグが読まれる。Google Bot は JavaScript を実行するが、Twitter / Facebook カードなどは HTML のみ読む。

**対策**: 全 175 ルートのメタタグを `index.html` に埋め込む:

```html
<!-- index.html の JavaScript で動的に設定 -->
<script>
const COMPETITOR_META = {
  'notion': {
    title: '自分株式会社 vs Notion — 何が違うか？',
    description: 'AI統合ライフマネジメントアプリと Notion の機能比較。...',
    ogImage: '/og/vs-notion.png',
  },
  'evernote': {
    title: '自分株式会社 vs Evernote — ノートアプリとの違い',
    description: '...',
    ogImage: '/og/vs-evernote.png',
  },
  // ... 174社
};

function setMetaTags() {
  const path = window.location.pathname;
  const vsMatch = path.match(/^\/vs-([a-z0-9\-_]+)/);
  
  if (vsMatch) {
    const key = vsMatch[1];
    const meta = COMPETITOR_META[key];
    if (meta) {
      document.title = meta.title;
      document.querySelector('meta[property="og:title"]').content = meta.title;
      document.querySelector('meta[property="og:description"]').content = meta.description;
      document.querySelector('meta[property="og:image"]').content = meta.ogImage;
      document.querySelector('link[rel="canonical"]').href = `https://my-web-app-b67f4.web.app${path}`;
    }
  }
}

setMetaTags();
window.addEventListener('popstate', setMetaTags);
</script>
```

## JSON-LD 構造化データ

```html
<!-- 競合比較ページ用 JSON-LD -->
<script id="json-ld-webpage" type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "WebPage",
  "name": "自分株式会社 vs Notion",
  "description": "AI統合ライフマネジメントアプリと Notion の詳細比較",
  "url": "https://my-web-app-b67f4.web.app/vs-notion"
}
</script>
<script id="json-ld-breadcrumb" type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "BreadcrumbList",
  "itemListElement": [
    {"@type": "ListItem", "position": 1, "name": "ホーム", "item": "https://my-web-app-b67f4.web.app/"},
    {"@type": "ListItem", "position": 2, "name": "競合比較", "item": "https://my-web-app-b67f4.web.app/competitors"},
    {"@type": "ListItem", "position": 3, "name": "vs Notion"}
  ]
}
</script>
```

JSON-LD はページごとに JavaScript で書き換える:

```javascript
function updateJsonLd(competitor, url) {
  const webpageLd = document.getElementById('json-ld-webpage');
  webpageLd.textContent = JSON.stringify({
    "@context": "https://schema.org",
    "@type": "WebPage",
    "name": `自分株式会社 vs ${competitor}`,
    "url": url,
  });
}
```

## sitemap.xml: 175 ルートを全列挙

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://my-web-app-b67f4.web.app/</loc>
    <priority>1.0</priority>
    <changefreq>weekly</changefreq>
  </url>
  <url>
    <loc>https://my-web-app-b67f4.web.app/competitors</loc>
    <priority>0.9</priority>
  </url>
  <!-- 175社の vs-* ページ -->
  <url>
    <loc>https://my-web-app-b67f4.web.app/vs-notion</loc>
    <priority>0.8</priority>
    <changefreq>monthly</changefreq>
  </url>
  <!-- ... -->
</urlset>
```

Firebase Hosting の `firebase.json` でキャッシュ設定:

```json
{
  "hosting": {
    "headers": [
      {
        "source": "/sitemap.xml",
        "headers": [{ "key": "Cache-Control", "value": "max-age=3600" }]
      }
    ]
  }
}
```

## canonical URL の設定

Flutter Web では URL ハッシュルーティング (`/#/page`) とパスルーティング (`/page`) の2種類がある。**SEO には pathStrategy (パスルーティング) を使う**:

```dart
// lib/main.dart
GoRouter(
  routerNeglect: false,
  routes: [...],
  // ハッシュなしの URL (SEO friendly)
);
```

```html
<!-- index.html: 動的に canonical を設定 -->
<link id="canonical-link" rel="canonical" href="https://my-web-app-b67f4.web.app/">
<script>
document.getElementById('canonical-link').href = 
  'https://my-web-app-b67f4.web.app' + window.location.pathname;
</script>
```

## Firebase Hosting のリライト設定

SPA では全 URL を `index.html` にリライトする必要がある:

```json
// firebase.json
{
  "hosting": {
    "public": "build/web",
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
```

## まとめ

Flutter Web SEO の実装ポイント:
1. **パスルーティングを使う** — ハッシュ URL は SEO に不利
2. **index.html でメタタグを動的設定** — JS で `popstate` に反応して更新
3. **JSON-LD で構造化データ** — WebPage + BreadcrumbList を全ページに
4. **sitemap.xml に全ルートを列挙** — Google に発見させる
5. **Firebase Hosting の rewrite** — 全 URL を index.html にルーティング

SPA の SEO は「できない」ではなく「工夫が必要」。175ルートで実装して Google 検索流入が増えた。
