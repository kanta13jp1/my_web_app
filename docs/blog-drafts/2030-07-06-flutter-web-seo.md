---
title: "Flutter Web の SEO 完全攻略 — メタタグ・サイトマップ・構造化データの実装"
tags: Flutter,SEO,webdev,個人開発
published: true
---

# Flutter Web の SEO 完全攻略 — メタタグ・サイトマップ・構造化データの実装

Flutter Web でプロダクトを作ったのに Google に全然インデックスされない、という経験はないだろうか。自分株式会社 (Jibun Inc.) の開発では、Notion・Evernote・MoneyForward など 21 社の競合と戦うために SEO は死活問題だ。本記事では Flutter Web 特有の SEO 課題と、実際に機能する対策を徹底解説する。

## Flutter Web の SEO が難しい理由

通常の Web サイトは HTML を直接返すため、Googlebot はコンテンツをすぐに読める。しかし Flutter Web はデフォルトで **CanvasKit レンダラー** を使い、`<canvas>` タグで全てを描画する。この場合 HTML にコンテンツがほぼ存在せず、クローラーはページの内容を把握できない。

```
# CanvasKit の場合、クローラーが見るHTML (ほぼ空)
<body>
  <script src="main.dart.js"></script>
  <flt-glass-pane></flt-glass-pane>  <!-- canvas に描画 -->
</body>
```

対策は 2 つある:

| 方法 | メリット | デメリット |
|------|---------|-----------|
| HTML レンダラーに切り替え | クローラーが HTML を読める | パフォーマンスが低下する場合あり |
| SSR / Pre-rendering | 本格的な SEO 対策が可能 | 実装コストが高い |
| `flutter build web --web-renderer html` | 最も手軽 | インタラクティブ性が下がる場合あり |

自分株式会社では **HTML レンダラー + 静的メタタグ** の組み合わせを採用している。

## Step 1: index.html のメタタグを正しく設定する

`web/index.html` はクローラーが最初に読むファイルだ。ここのメタタグは Flutter アプリが起動する前から有効になる。

```html
<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">

  <!-- 基本 SEO メタタグ -->
  <title>自分株式会社 — AI統合ライフマネジメント</title>
  <meta name="description" content="Notion・Evernote・MoneyForward など21社の機能を1つに統合。Flutter Web + Supabase のAI統合ライフマネジメントアプリ。">
  <meta name="keywords" content="ライフマネジメント,AI,Flutter,個人開発,タスク管理">
  <meta name="author" content="自分株式会社">
  <link rel="canonical" href="https://my-web-app-b67f4.web.app/">

  <!-- OGP (Open Graph Protocol) -->
  <meta property="og:title" content="自分株式会社 — AI統合ライフマネジメント">
  <meta property="og:description" content="21社の競合機能を1アプリに統合したAIライフマネジメントツール">
  <meta property="og:image" content="https://my-web-app-b67f4.web.app/og-image.png">
  <meta property="og:url" content="https://my-web-app-b67f4.web.app/">
  <meta property="og:type" content="website">
  <meta property="og:locale" content="ja_JP">

  <!-- Twitter Card -->
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:site" content="@kanta13jp1">
  <meta name="twitter:title" content="自分株式会社 — AI統合ライフマネジメント">
  <meta name="twitter:description" content="21社の競合機能を1アプリに統合">
  <meta name="twitter:image" content="https://my-web-app-b67f4.web.app/og-image.png">

  <!-- HTML レンダラーを指定 -->
  <script>
    window.flutterWebRenderer = "html";
  </script>
</head>
```

## Step 2: sitemap.xml を生成・維持する

Flutter Web アプリのルート一覧を XML で表現する。自分株式会社では 22 の URL を管理している。

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
        xmlns:xhtml="http://www.w3.org/1999/xhtml">

  <!-- トップページ -->
  <url>
    <loc>https://my-web-app-b67f4.web.app/</loc>
    <lastmod>2030-07-01</lastmod>
    <changefreq>weekly</changefreq>
    <priority>1.0</priority>
    <xhtml:link rel="alternate" hreflang="ja"
      href="https://my-web-app-b67f4.web.app/"/>
  </url>

  <!-- 比較ページ (競合 21 社) -->
  <url>
    <loc>https://my-web-app-b67f4.web.app/comparison</loc>
    <lastmod>2030-07-01</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.9</priority>
  </url>

  <!-- ユーザーマニュアル -->
  <url>
    <loc>https://my-web-app-b67f4.web.app/manual</loc>
    <lastmod>2030-06-01</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.7</priority>
  </url>
</urlset>
```

### GitHub Actions で sitemap を自動更新する

```yaml
# .github/workflows/update-sitemap.yml
name: Update Sitemap
on:
  push:
    branches: [main]
    paths:
      - 'lib/main.dart'  # ルート追加時にトリガー

jobs:
  sitemap:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Generate sitemap
        run: python scripts/generate_sitemap.py
      - name: Commit sitemap
        run: |
          git config --local user.email "action@github.com"
          git add web/sitemap.xml
          git diff --staged --quiet || git commit -m "chore: update sitemap"
          git push
```

## Step 3: JSON-LD 構造化データを埋め込む

Google はページの意味を構造化データから読み取る。Flutter Web では `index.html` に埋め込むのが最も確実だ。

```html
<!-- web/index.html の <head> 内 -->
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  "name": "自分株式会社",
  "applicationCategory": "ProductivityApplication",
  "operatingSystem": "Web",
  "description": "Notion・Evernote・MoneyForward など21社の機能を1つに統合したAIライフマネジメントアプリ",
  "url": "https://my-web-app-b67f4.web.app/",
  "author": {
    "@type": "Person",
    "name": "kanta13jp1",
    "url": "https://twitter.com/kanta13jp1"
  },
  "offers": {
    "@type": "Offer",
    "price": "0",
    "priceCurrency": "JPY"
  },
  "aggregateRating": {
    "@type": "AggregateRating",
    "ratingValue": "4.8",
    "reviewCount": "120"
  }
}
</script>
```

## Step 4: Flutter 側から動的にメタタグを更新する

SPA では URL 遷移時にメタタグが変わらない問題がある。`flutter_web_plugins` と `js` パッケージで解決できる。

```dart
// lib/utils/seo_helper.dart
import 'dart:js_interop';
import 'package:web/web.dart' as web;

class SeoHelper {
  /// ページ遷移時にメタタグを更新する
  static void updateMeta({
    required String title,
    required String description,
    String? ogImage,
    String? canonicalUrl,
  }) {
    // タイトル更新
    web.document.title = title;

    // description 更新
    _updateMetaTag('name', 'description', description);

    // OGP 更新
    _updateMetaTag('property', 'og:title', title);
    _updateMetaTag('property', 'og:description', description);
    if (ogImage != null) {
      _updateMetaTag('property', 'og:image', ogImage);
    }

    // canonical URL 更新
    if (canonicalUrl != null) {
      _updateLinkTag('canonical', canonicalUrl);
    }
  }

  static void _updateMetaTag(
    String attrName,
    String attrValue,
    String content,
  ) {
    final meta = web.document
        .querySelector('meta[$attrName="$attrValue"]') as web.HTMLMetaElement?;
    if (meta != null) {
      meta.content = content;
    } else {
      final newMeta = web.document.createElement('meta') as web.HTMLMetaElement;
      newMeta.setAttribute(attrName, attrValue);
      newMeta.content = content;
      web.document.head?.appendChild(newMeta);
    }
  }

  static void _updateLinkTag(String rel, String href) {
    final link = web.document
        .querySelector('link[rel="$rel"]') as web.HTMLLinkElement?;
    if (link != null) {
      link.href = href;
    }
  }
}
```

### ページクラスで使う例

```dart
// lib/pages/comparison_page.dart
@override
void initState() {
  super.initState();
  SeoHelper.updateMeta(
    title: '競合比較 — 自分株式会社 vs Notion/Evernote/MoneyForward',
    description: 'Notion・Evernote・MoneyForward など21社との機能比較。料金・機能・UXを徹底比較。',
    canonicalUrl: 'https://my-web-app-b67f4.web.app/comparison',
  );
}
```

## Step 5: Google Search Console で確認する

1. Search Console に Firebase Hosting ドメインを登録
2. `sitemap.xml` を送信: `https://my-web-app-b67f4.web.app/sitemap.xml`
3. URL 検査ツールで各ページをクロールリクエスト
4. 「モバイル ユーザビリティ」レポートで問題がないか確認

### robots.txt も忘れずに

```txt
# web/robots.txt
User-agent: *
Allow: /

Sitemap: https://my-web-app-b67f4.web.app/sitemap.xml

# 管理画面はクロール不要
Disallow: /admin
Disallow: /api/
```

## まとめ

| 対策 | 効果 | 工数 |
|------|------|------|
| HTML レンダラー指定 | クローラーが HTML を読める | 低 |
| index.html メタタグ | 基本 SEO・SNS シェア改善 | 低 |
| sitemap.xml 整備 | インデックス速度向上 | 中 |
| JSON-LD 構造化データ | リッチスニペット表示 | 中 |
| 動的メタタグ更新 | SPA でのページ別 SEO | 高 |

Flutter Web の SEO は React/Vue に比べてまだ課題が多いが、上記の対策を組み合わせれば競合他社と十分に戦える。自分株式会社では競合 21 社のキーワードを意識したコンテンツ戦略と合わせて運用している。

---

*本記事は自分株式会社 (Flutter Web + Supabase) の実装経験をもとに執筆しました。*
