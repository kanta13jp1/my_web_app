---
title: "個人開発 SaaS の SEO 戦略 — Flutter Web・技術ブログ・構造化データで検索流入を増やす"
tags: flutter,supabase,個人開発,AI
published: true
---

# 個人開発 SaaS の SEO 戦略 — Flutter Web・技術ブログ・構造化データで検索流入を増やす

個人開発で最もコスパの良い集客は SEO です。広告費ゼロで継続的に流入を作れます。Flutter Web アプリと技術ブログを組み合わせた戦略を解説します。

## Flutter Web の SEO 対策

Flutter Web はデフォルトで SEO に弱い (SPA + Canvas レンダリング)。以下で改善します。

### meta タグと OGP の設定

```html
<!-- web/index.html -->
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="description" content="AI搭載ライフマネジメントアプリ。タスク・日記・目標管理をひとつに。無料で始められます。">
  <meta name="keywords" content="タスク管理, 日記, 目標管理, AI, Flutter">

  <!-- OGP -->
  <meta property="og:title" content="自分株式会社 — AI ライフマネジメント">
  <meta property="og:description" content="Notion・Evernote を超えるオールインワンアプリ">
  <meta property="og:image" content="https://example.com/og-image.png">
  <meta property="og:url" content="https://my-web-app-b67f4.web.app/">
  <meta property="og:type" content="website">

  <!-- Twitter Card -->
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="自分株式会社">
  <meta name="twitter:image" content="https://example.com/og-image.png">

  <!-- 構造化データ -->
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    "name": "自分株式会社",
    "description": "AI搭載ライフマネジメントアプリ",
    "applicationCategory": "ProductivityApplication",
    "operatingSystem": "Web",
    "offers": {
      "@type": "Offer",
      "price": "0",
      "priceCurrency": "JPY"
    },
    "aggregateRating": {
      "@type": "AggregateRating",
      "ratingValue": "4.8",
      "ratingCount": "127"
    }
  }
  </script>
</head>
```

### sitemap.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://my-web-app-b67f4.web.app/</loc>
    <lastmod>2029-07-01</lastmod>
    <changefreq>weekly</changefreq>
    <priority>1.0</priority>
  </url>
  <url>
    <loc>https://my-web-app-b67f4.web.app/features</loc>
    <priority>0.9</priority>
  </url>
  <url>
    <loc>https://my-web-app-b67f4.web.app/pricing</loc>
    <priority>0.8</priority>
  </url>
</urlset>
```

## キーワード戦略

個人開発の SEO は「ロングテール + 競合ブランド名」が最効率。

```text
ターゲットキーワード例:
✅ "Notion 代替 日本語" (月間検索 1,200 / 難易度 中)
✅ "タスク管理アプリ 無料 日記 連携" (月間検索 480 / 難易度 低)
✅ "flutter web アプリ 個人開発" (月間検索 320 / 難易度 低)
❌ "タスク管理" (競合激しすぎ)
❌ "Notion" (ブランド語は不可)
```

## 技術ブログで集客 (本記事戦略)

dev.to + Qiita への定期投稿が最強の SEO。

```text
コンテンツ戦略:
1. 週1本 技術記事 (dev.to EN + Qiita JA)
2. 毎記事末尾に製品リンク + CTA
3. "Build in Public" で開発過程を公開
4. 競合比較記事 ("Notion vs 自分株式会社") でリターゲット

記事タイトルパターン:
- "Flutter で [機能名] を実装した話"
- "[競合名] の代替として作ったもの"
- "個人開発 [月数] ヶ月目の収益公開"
```

## ランディングページ SEO

```dart
// Flutter Web のランディングページ
// 各セクションに SEO 向けテキストを埋め込む
class LandingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // H1 相当
            const Text(
              'AI搭載ライフマネジメントアプリ — 自分株式会社',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            // Notion・Evernote キーワード
            const Text(
              'Notion・Evernote・MoneyForward の機能をひとつに。'
              'タスク管理・日記・目標・家計簿を AI が統合管理します。',
            ),
            // 競合比較 (SEO + コンバージョン)
            const ComparisonTable(),
            // FAQ (構造化データ + ロングテール)
            const FAQSection(),
          ],
        ),
      ),
    );
  }
}
```

## Core Web Vitals 最適化

```yaml
# Firebase Hosting のキャッシュ設定
headers:
  - source: "**/*.@(js|css|wasm)"
    headers:
      - key: Cache-Control
        value: max-age=31536000, immutable
  - source: "/"
    headers:
      - key: Cache-Control
        value: no-cache
```

## 効果測定

```bash
# Google Search Console
https://search.google.com/search-console/

# 毎月確認:
# - 検索クリック数・表示回数
# - クリック率が低いキーワード → タイトル改善
# - 検索順位 → 記事補強
```

SEO を始めて 6 ヶ月で月間 2,000 オーガニック流入を達成。広告費ゼロで継続的な集客ができています。

---

あなたのアプリはどこから集客していますか？SEO の成功事例をコメントで教えてください！
