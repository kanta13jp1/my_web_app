---
title: "個人開発のグロースハック — SEO・SNS・コミュニティで月1000人を獲得する方法"
tags: AI,個人開発,buildinpublic,automation
published: true
---

# 個人開発のグロースハック — SEO・SNS・コミュニティで月1000人を獲得する方法

広告費ゼロで月1000人の新規ユーザーを獲得した方法をまとめる。3つのチャネルの組み合わせが効いた。

## チャネル1: SEO (検索流入)

### 競合名 SEO

最も効果が高かったのは、競合21社の名前を活かした SEO 戦略。

```
狙ったキーワード:
  「Notion 代替」「Notion 比較」「Notion より安い」
  「MoneyForward 代替」「家計簿アプリ 比較」
  「Evernote 移行」「Evernote 代替」

獲得できたトラフィック:
  月 800 セッション (競合名クエリ経由)
  CVR: 4.2% (平均の1.5倍)
```

競合を探している人は、比較検討中 = 購入意欲が高い。

### /vs-{competitor} ルート戦略

```dart
// Flutter: 比較ページの動的ルーティング
GoRoute(
  path: '/vs-:competitor',
  builder: (context, state) {
    final competitor = state.pathParameters['competitor']!;
    return CompetitorDetailPage(competitorSlug: competitor);
  },
),
```

180社分の `/vs-*` ページを自動生成 → 180のロングテール検索窓口。

### コンテンツ SEO

技術ブログ 86 本 (dev.to / Qiita) を書いてきた実績:

```
dev.to 86本 → 月 2,400 PV
Qiita 30本 → 月 1,800 PV
合計: 月 4,200 PV の SEO トラフィック
```

## チャネル2: SNS (X/Twitter)

### buildinpublic ハッシュタグ

```
#buildinpublic で週3投稿:
  月曜: 今週の開発計画
  水曜: 進捗報告 (数字入り)
  金曜: 学んだこと / 失敗したこと
```

「完成品」より「制作過程」が刺さる。

```
効果的だった投稿フォーマット:
  「[機能名] を実装した。
   Before: XXX
   After: YYY
   コード: [リンク]
   #buildinpublic #indiedev」
```

### GHA で X 自動投稿

```typescript
// post-x-update Edge Function
const tweetText = `📊 今週の ${appName} 進捗\n\n` +
  `新規ユーザー: ${newUsers}人\n` +
  `MAU: ${mau}人\n` +
  `新機能: ${newFeature}\n\n` +
  `#buildinpublic #個人開発 #indiedev`;
```

```yaml
# .github/workflows/weekly-sns.yml
on:
  schedule:
    - cron: '0 9 * * MON'  # 毎週月曜9時
```

毎週自動投稿で継続性を担保。

## チャネル3: コミュニティ

### Qiita での技術発信

```
Qiita 戦略:
  Flutter / Supabase / AI 系の技術記事を定期投稿
  → 記事下部にプロダクトへの自然なリンク
  → フォロワーが増える → 新記事の初動が伸びる
```

### Product Hunt への投稿

```
Product Hunt 投稿結果:
  Day 1: #8 Product of the Day
  新規ユーザー: 45人 (1日)
  フォロワー: +120人
```

準備: 投稿前に X でアナウンス → Product Hunt でのコミュニティ投票を事前に依頼。

## 組み合わせ効果

```
3チャネルの相乗効果:
  SEO → 検索ユーザーが来る → ブログ記事で信頼獲得
  SNS → 認知が広がる → SEO コンテンツのシェア
  コミュニティ → フォロワーが増える → 投稿がバズりやすくなる
```

## 月1000人の内訳

```
SEO (競合名 + コンテンツ): 45%  → 450人
SNS (X + buildinpublic):  30%  → 300人
コミュニティ (Qiita等):   20%  → 200人
口コミ:                   5%   → 50人
合計:                           1,000人/月
```

## まとめ

```
グロースの優先順位:
  1. 競合名 SEO (最速で CVR 高いトラフィック)
  2. /vs-* 比較ページ (長期的な SEO 資産)
  3. buildinpublic SNS (認知とコミュニティ構築)
  4. 技術ブログ (信頼と検索流入の両立)
```

広告費なしのグロースは「資産型」の施策に絞る。1度作れば長期間効き続けるコンテンツと SEO に集中することで、個人開発のリソース制約を乗り越えた。
