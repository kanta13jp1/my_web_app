---
title: "FlutterとSupabase Edge Functionsで、13の競合を打倒する「本物の」グロースダッシュボードを作った話"
emoji: "🚀"
type: "tech"
topics: ["flutter", "supabase", "deno", "個人開発", "グロースハック"]
published: false
---

## はじめに

現在、私は「自分株式会社」という、知的生産から資産管理、SNS要素までをすべて一元管理できるAI統合プラットフォームを個人開発しています。
目標は、Notion、Evernote、MoneyForward、X、Slackなど、名だたる**13の競合製品の機能を凌駕し、数億人規模のユーザーを獲得すること**です。

（2026年3月25日現在、**登録者数は私を含めて2人**です！）

スケールするための第一歩として、クライアント（Flutter Web）で複雑化していたダッシュボードの集計処理やハードコードされたダミーデータを完全に排除し、**Supabase Edge Functions（Deno）**へ移行して完全なデータ駆動アーキテクチャを構築しました。

## なぜEdge Functionへ移行したのか？

当初、ホーム画面には「開発の進捗」や「競合との機能比較」などをハードコードして表示していました。
しかし、これには以下の問題がありました。

1. **クライアントアプリの肥大化**: コードが800行を超え、メンテナンス性が低下。
2. **セキュリティとパフォーマンス**: データベースへの複数回のクエリ発行や集計処理がクライアントで行われており、動作が重くなる。
3. **Linterエラーと技術的負債**: プロジェクトの運用原則である「Linterエラー常に0」を維持しにくくなる。

## 実装したEdge Functions (本日時点)

今回、以下の4つのEdge Functionを新規作成・改修しました。

### 1. `get-home-dashboard` — ホームKPIを1リクエストに統合

ホーム画面が従来 `app_analytics`、`user_profiles`（×2クエリ）、`get_lp_view_stats` RPC と、3〜4往復していたDB通信を**1回のAPI呼び出し**に削減しました。

```typescript
// Deno + Supabase-js でセキュアに実データを集計
const [
  totalUsersResult,
  todaySignupsResult,
  analyticsResult,
  lpStatsResult,
] = await Promise.all([
  admin.from("user_profiles").select("*", { count: "exact", head: true }),
  admin.from("user_profiles")
    .select("*", { count: "exact", head: true })
    .gte("created_at", today.toISOString())
    .lt("created_at", tomorrow.toISOString()),
  admin.from("app_analytics")
    .select("date,landing_views,share_count,source_details")
    .eq("date", todayKey)
    .maybeSingle(),
  admin.rpc("get_lp_view_stats"),
]);
```

Flutter側はこれだけ：

```dart
final response = await Supabase.instance.client.functions
    .invoke('get-home-dashboard', body: <String, dynamic>{});
final data = response.data;
return _HomeMarketingKpiSummary(
  todayViews: _toIntValue(data['todayViews']),
  todayRegistrations: _toIntValue(data['todaySignups']),
  todayShares: _toIntValue(data['todayShares']),
  topShareChannelKey: data['topShareChannelKey']?.toString(),
);
```

### 2. `get-competitor-features` — 競合比較データをバックエンドへ

13製品・200以上の機能比較表がFlutter側にハードコードされていました。
これをEdge Functionへ移し、クライアントは `client.functions.invoke('get-competitor-features')` を呼ぶだけに。ローカルデータへのフォールバックも実装済みです。

### 3. `get-public-memo-preview` — 公開メモのSEO/OGP強化

Flutter Web SPAはクローラーに読まれません。
`/public-memo?id=XXX` へのアクセス時、`index.html` 内のJavaScriptが**Flutterより先に**このEdge Functionを呼び出し、`og:title`・`og:description`・`twitter:card` を書き換えます。
これでSNSシェア時にメモのタイトルと要約がカードとして表示されます。

```javascript
// index.html — Flutter ロード前に実行
if (path.endsWith('/public-memo') && memoId) {
  fetch(SUPABASE_FUNC_BASE + '/get-public-memo-preview?id=' + memoId)
    .then(res => res.json())
    .then(data => {
      document.title = data.pageTitle;
      setMeta('og:title', data.pageTitle);
      setMeta('og:description', data.ogDescription);
    });
}
```

### 4. `growth-weekly-digest` — 7日間チャネル別CVRサマリ

Landing page / Import / Public memo / Referral の各チャネルごとに、タッチ数・サインアップCTAクリック数・CVR・前週比を集計して返します。
Flutter側のGrowth Missionページに週次レポートカードとして表示しています。

## 運用原則: flutter analyze と deno lint を常に 0 に保つ

このプロジェクトの鉄則として、**`flutter analyze` と `deno lint` を常に 0 エラー**で保つことを徹底しています。
Edge Functionを追加するたびに `deno lint supabase/functions/` を実行し、型エラーや `no-explicit-any` を即修正。
FlutterもEdge Function呼び出しを追加するたびに `flutter analyze` をパスさせます。

今回の移行でも、`_normalizeDateKey` のような「Edge Function移行により不要になったメソッド」を即削除することで、Linterエラーを0件に保ちました。

## 13の競合を超えるために

単にメモが取れるアプリでは、Notionの1億人、Evernoteの2.5億人には決して届きません。
「見つかる」「移行しやすい」「AIが勝手に整理する」「他人に共有したくなる」というグロースループを回すため、今後もすべての実装を「バックエンドファースト」で進めていきます。

**「自分株式会社」の泥臭いビルド・イン・パブリックの軌跡**は、アプリのトップ画面の「Growth Roadmap」でリアルタイム公開しています。
もしよければ、最初の「3人目」のユーザーになってみませんか？

👉 [自分株式会社](https://my-web-app-b67f4.web.app/)
