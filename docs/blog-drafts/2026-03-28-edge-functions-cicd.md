---
title: "Claude Code 4インスタンス並列開発 + Edge Functions全量CI/CDデプロイを整備した話"
tags: Flutter,Supabase,ClaudeCode,EdgeFunction,buildinpublic
published: true
---

# ブログ下書き 2026-03-28 (Edge Functions CI/CD)

## タイトル案

1. **Claude Code 4インスタンス並列開発 + Edge Functions全量CI/CDデプロイを整備した話**
2. **自分株式会社 開発日記 #10: Web/VSCode/Windows/PowerShell 4インスタンス協調開発**
3. **FlutterWeb×Supabase: Edge Functions 36本を全てCI/CDに乗せた話**

## 投稿先候補

- [x] Zenn (技術詳細系)
- [x] Qiita (実用系)
- [ ] note (エッセイ系)
- [ ] dev.to (英語版)

## 本文下書き（1500〜2000字）

### はじめに

自分株式会社（Flutter Web + Supabase）は、Notion・Evernote・MoneyForward・X など21の競合SaaSを超える統合プラットフォームを1人で開発中です。

今日は **Claude Code を4インスタンス同時実行**する開発体制を構築し、Edge Functions の CI/CD を完備した話をします。

### 4インスタンス並列開発の役割分担

```text
VSCode版（Claude Code IDE）  → lib/ フロントエンド実装
Web版（claude.ai/code）       → supabase/functions/ Edge Functions
Windows版（デスクトップアプリ）  → docs/ ドキュメント・マイグレーション
PowerShell（ターミナル）         → 全体管理・CI監視
```

各インスタンスが担当ディレクトリを守り、開始前に `git pull --rebase origin main` を必ず実行することで競合を防いでいます。

### 問題: Edge Functions がCI/CDに含まれていなかった

`deploy-prod.yml` を確認すると、以下の7つの Edge Functions がデプロイ対象に含まれていませんでした:

- `check-competitor-updates` — 競合14社のWeb可用性チェック
- `health-check` — DB接続・テーブル可用性チェック
- `analyze-reality` — リアリティチェックAI
- `trigger-analysis` — 選挙分析トリガー
- `local-election-intelligence` — 地方選挙インテリジェンス
- `agent-runtime-cycle` — AIエージェント定期サイクル

これらは手動デプロイが必要な状態で、CI/CDの恩恵を受けられていませんでした。

### 解決: deploy-prod.yml に全関数を追加

```yaml
- name: Deploy Supabase Edge Functions
  run: |
    # 既存の関数...
    supabase functions deploy reply-support-request --no-verify-jwt
    supabase functions deploy post-x-update --no-verify-jwt
    # 今回追加
    supabase functions deploy check-competitor-updates --no-verify-jwt
    supabase functions deploy get-competitor-monitoring --no-verify-jwt
    supabase functions deploy health-check --no-verify-jwt
    supabase functions deploy analyze-reality --no-verify-jwt
    supabase functions deploy trigger-analysis --no-verify-jwt
    supabase functions deploy local-election-intelligence --no-verify-jwt
    supabase functions deploy agent-runtime-cycle --no-verify-jwt
```

### 新規作成: get-competitor-monitoring Edge Function

`check-competitor-updates` は競合サイトをPOSTで叩いてDBに記録しますが、
管理者UIからそのデータを参照するGETエンドポイントがありませんでした。

新規作成した `get-competitor-monitoring` の設計:

```typescript
// GET /functions/v1/get-competitor-monitoring?days=7&limit=50
serve(async (req) => {
  const url = new URL(req.url);
  const days = parseInt(url.searchParams.get("days") ?? "7", 10);
  const limit = Math.min(parseInt(url.searchParams.get("limit") ?? "50", 10), 100);

  const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();

  const { data } = await supabase
    .from("competitor_monitoring")
    .select("*")
    .gte("checked_at", since)
    .order("checked_at", { ascending: false })
    .limit(limit);

  // 競合ごとの最新結果をまとめる
  const latestByCompetitor = {};
  for (const row of data ?? []) {
    if (!latestByCompetitor[row.competitor_key]) {
      latestByCompetitor[row.competitor_key] = {
        key: row.competitor_key,
        name: row.competitor_name,
        available: row.available,
        latency_ms: row.latency_ms,
        checked_at: row.checked_at,
      };
    }
  }

  return new Response(JSON.stringify({
    competitors: Object.values(latestByCompetitor),
    summary: { total, available, availabilityPct },
  }));
});
```

役割分担の明確化:

- `check-competitor-updates` (POST): 実際にサイトを叩いてDBに記録
- `get-competitor-monitoring` (GET): DBから最新結果を取得してUIに提供

### EdgeFunctionSummaryCard による UI カバレッジ可視化

`lib/widgets/edge_function_summary_card.dart` には全36 Edge Functions の UI 接続状況が一覧で表示されます。

```text
Edge Functions 実装状況
全 35 件 | UI 実装済: 31 件 | UI未実装: 4 件 (89%)
```

UI 未実装の関数（サーバーサイド専用を除く）には警告アイコンが表示され、
詳細ページ（`/edge-functions`）から手動テストも可能です。

### flutter analyze 0件維持の重要性

4インスタンスが並列で `lib/` を変更すると `flutter analyze` のエラーが増えるリスクがあります。
Web インスタンスは `supabase/functions/` のみを担当し、`lib/` には触れないことで Dart 解析エラーの発生を抑えています。

### まとめ

- **Edge Functions 36本全てを CI/CD に乗せ完備**
- **新規 `get-competitor-monitoring`** で管理者 UI に競合可用性データを提供
- **4インスタンス並列開発体制** でフロント/バックエンド/ドキュメントを同時進行
- CI/CD の恩恵を受けられていなかった7関数を `deploy-prod.yml` に追加

---

サービスURL: [自分株式会社](https://my-web-app-b67f4.web.app/)
タグ: \#FlutterWeb \#Supabase \#buildinpublic \#ClaudeCode \#EdgeFunctions
