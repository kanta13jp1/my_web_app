---
title: "個人開発者の SEO 完全戦略 — /vs-* ページ / 構造化データ / Core Web Vitals"
tags: AI,個人開発,buildinpublic,automation
published: true
---

# 個人開発者の SEO 完全戦略 — /vs-* ページ / 構造化データ / Core Web Vitals

「作ったけど誰も来ない」を防ぐ。個人開発で実際に機能した3つの SEO 施策を公開する。

## 施策1: /vs-* 比較ページで競合検索を獲得

「Notion alternative」「Notion vs」系の検索ボリュームは非常に大きい。

```
競合比較ページの SEO 効果:
  対象キーワード: "[競合名] alternative" / "[競合名] vs [自社名]"
  月間検索ボリューム: 数百〜数万 (競合知名度次第)
  競合の少なさ: 競合本体ページは防御しにくい → 隙間が多い
```

**実装パターン**:

```dart
// Flutter Web: GoRouter で /vs-* を動的ルーティング
GoRoute(
  path: '/vs/:competitor',
  builder: (context, state) {
    final competitor = state.pathParameters['competitor']!;
    return VsPage(competitor: competitor);
  },
),

// VsPage: 競合名に応じて動的コンテンツ
class VsPage extends StatefulWidget {
  final String competitor;
  ...
}
```

**SEO メタタグ** (index.html または head injection):

```html
<!-- /vs/notion の場合 -->
<title>自分株式会社 vs Notion: 機能・価格・UIを比較 (2026)</title>
<meta name="description" content="自分株式会社とNotionを徹底比較。
  AIライフマネジメント機能、価格、操作性の違いを解説。
  Notion からの乗り換えを検討中の方へ。" />
<link rel="canonical" href="https://example.com/vs/notion" />
```

**構造化データ (JSON-LD)**:

```json
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "自分株式会社と Notion の違いは何ですか？",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "自分株式会社は AI との統合に特化したライフマネジメントアプリです。Notion がドキュメント管理中心なのに対し、..."
      }
    }
  ]
}
```

## 施策2: Core Web Vitals の改善

Google のランキング要素。ページ速度 = 順位に直結。

```
3つの指標:
  LCP (最大コンテンツ描画): 2.5秒以内
  FID (初回入力遅延):       100ms以内
  CLS (レイアウトシフト):   0.1以下
```

**Flutter Web での対策**:

```dart
// LCP 改善: ヒーロー画像を優先ロード
// web/index.html
<link rel="preload" href="assets/hero_image.webp" as="image" />

// CLS 改善: 画像に固定サイズを指定
Image.network(
  heroImageUrl,
  width: 1200,
  height: 630,
  fit: BoxFit.cover,
)

// FID 改善: 重い処理を Isolate に移動
Future<String> processData(String data) async {
  return Isolate.run(() => _heavyComputation(data));
}
```

## 施策3: 構造化データで検索リッチリザルト取得

```json
// BreadcrumbList: パンくずリスト
{
  "@context": "https://schema.org",
  "@type": "BreadcrumbList",
  "itemListElement": [
    {"@type": "ListItem", "position": 1, "name": "ホーム", "item": "https://example.com/"},
    {"@type": "ListItem", "position": 2, "name": "比較", "item": "https://example.com/vs/"},
    {"@type": "ListItem", "position": 3, "name": "vs Notion", "item": "https://example.com/vs/notion"}
  ]
}

// SoftwareApplication: アプリ情報
{
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  "name": "自分株式会社",
  "applicationCategory": "LifestyleApplication",
  "offers": {
    "@type": "Offer",
    "price": "0",
    "priceCurrency": "JPY"
  },
  "aggregateRating": {
    "@type": "AggregateRating",
    "ratingValue": "4.8",
    "ratingCount": "124"
  }
}
```

## SEO 施策の優先順位

```
優先度 高 (3ヶ月以内に効果):
  1. /vs-* ページ作成 (競合 20社分)
  2. 構造化データ (FAQPage + BreadcrumbList)
  3. Core Web Vitals 改善 (LCP < 2.5s)

優先度 中 (6ヶ月で効果):
  4. ブログ投稿 (月4本 × 6ヶ月 = 24記事)
  5. サイトマップ更新自動化 (GHA cron)
  6. 内部リンク最適化

優先度 低 (長期):
  7. バックリンク獲得
  8. 競合20社への Product Hunt コメント
```

## 自動化: GHA でサイトマップ更新

```yaml
# sitemap-update.yml
on:
  push:
    paths:
      - 'web/sitemap.xml'
      - 'lib/pages/comparison_page.dart'

jobs:
  ping-google:
    steps:
      - name: Ping Google Search Console
        run: |
          curl "https://www.google.com/ping?sitemap=https://example.com/sitemap.xml"
```

## まとめ

```
即効性あり:  /vs-* 競合比較ページ (競合検索を直撃)
中期効果:    構造化データ (リッチリザルト取得)
継続施策:    Core Web Vitals + ブログ投稿
自動化:      GHA cron でサイトマップ ping + 更新確認
```

個人開発の SEO は「競合名でのオーガニック流入」が最もコスパ良い。競合のブランド力を SEO に転用できるのは個人開発者の特権。

