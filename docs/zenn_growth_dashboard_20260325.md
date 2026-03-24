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

## 実装のポイント

以下は、今回構築したダッシュボードデータ集約用API（`get-home-dashboard`）の一部です。

```typescript
// Deno + Supabase-js でセキュアに実データを集計
const { count: totalUsers } = await admin
  .from("user_profiles")
  .select("*", { count: "exact", head: true });

const { count: todaySignups } = await admin
  .from("user_profiles")
  .select("*", { count: "exact", head: true })
  .gte("created_at", today.toISOString());
```

このように、Flutter側は単にAPIを叩いてJSONを受け取るだけの責務（UIレイヤー）に徹することで、フロントエンドを劇的に軽量化することができました。

## 13の競合を超えるために

単にメモが取れるアプリでは、Notionの1億人、Evernoteの2.5億人には決して届きません。
「見つかる」「移行しやすい」「AIが勝手に整理する」「他人に共有したくなる」というグロースループを回すため、今後もすべての実装を「バックエンドファースト」で進めていきます。

**「自分株式会社」の泥臭いビルド・イン・パブリックの軌跡**は、アプリのトップ画面の「Growth Roadmap」でリアルタイム公開しています。
もしよければ、最初の「3人目」のユーザーになってみませんか？
