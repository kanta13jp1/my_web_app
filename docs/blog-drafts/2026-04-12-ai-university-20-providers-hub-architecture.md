---
title: "Flutter × Supabase で「AI大学」を20社対応に拡張 + Edge Function 94本→15本 hub統合アーキテクチャ"
tags: Flutter,Supabase,EdgeFunction,buildinpublic
topics: ["Flutter", "Supabase", "個人開発", "アーキテクチャ"]
published: false
---

# Flutter × Supabase で「AI大学」を20社対応に拡張 + Edge Function 94本→15本 hub統合アーキテクチャ

## はじめに

個人開発アプリ「自分株式会社」でAIプロバイダー横断の学習機能「AI大学」を構築しています。
もともと9社対応だったのを、1日で20社まで拡張しました。

同時に、Supabase Edge Functionが99本の上限に引っかかった問題を、action分岐パターンで94本→15本まで削減した話も紹介します。

---

## AI大学とは

AI大学は、主要なAIプロバイダー(OpenAI、Google、Anthropic、Meta等)の最新情報をアプリ内で学べるタブ型UIです。

```
機能:
- 各プロバイダーのoveriew/models/api/newsカテゴリを学習
- クイズで理解度チェック
- 学習スコアをSupabaseに記録・ランキング表示
- シェアカード生成 (RenderRepaintBoundary→PNG)
- 連続学習ストリーク (ai_university_streaks テーブル)
```

### 20社の内訳

| カテゴリ | プロバイダー |
|---------|------------|
| Big Tech | Google, Microsoft, Meta, Apple |
| AIスタートアップ | OpenAI, Anthropic, xAI (Grok), Mistral, Perplexity, DeepSeek |
| エンタープライズ | Amazon (Nova/Bedrock), Cohere, IBM (watsonx) |
| クラウド/HW | NVIDIA, Samsung, Baidu (ERNIE) |
| 新興 | Groq, Oracle (OCI), Reka AI |
| アジア | Qwen (Alibaba) |

---

## 拡張の実装パターン

新しいAIプロバイダーを追加するのに必要なのは3ファイルだけです。

### 1. Supabase migration (seed SQL)

```sql
-- supabase/migrations/20260412000001_seed_reka_ai_university.sql
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
  ('reka', 'overview',
   'Reka AI — マルチモーダル特化の次世代LLM',
   '## Reka AI とは\n\nReka AI は2023年創業のAIスタートアップ...',
   '2026-04-12'),
  ('reka', 'models',
   'Reka Core / Flash / Edge モデルファミリー',
   '## モデル一覧\n\n### Reka Core\n- 最大規模のモデル...',
   '2026-04-12')
ON CONFLICT (provider, category) DO UPDATE
  SET title = EXCLUDED.title,
      content = EXCLUDED.content,
      published_at = EXCLUDED.published_at;
```

### 2. Flutter UI (_providerMeta マップ追加)

```dart
// lib/pages/gemini_university_v2_page.dart
static const Map<String, _ProviderMeta> _providerMeta = {
  // ... 既存エントリ
  'reka': _ProviderMeta(
    displayName: 'Reka AI',
    emoji: '🦁',
    color: Color(0xFF7B2FF7),
  ),
};
```

### 3. フォールバックコンテンツ

EFからのデータ取得が失敗した場合のオフラインコンテンツをDart側に持たせます。

```dart
static const Map<String, String> _fallback = {
  'reka': '''## Reka AI\n\nマルチモーダル特化のLLM...''',
};
```

この3点セットで1プロバイダー追加が完結します。

---

## Edge Function 99本問題とhub統合

Supabaseには**プロジェクトあたりのEdge Function上限が99本**という制限があります。

機能を追加し続けた結果、94本まで到達してしまいました。

### 解決策: action分岐パターン

各EFに `action` パラメータを追加してリクエストを振り分け、複数のEFを1本に統合します。

```typescript
// growth-hub/index.ts — 20のEFをaction分岐で統合
serve(async (req: Request) => {
  const body = await req.json();
  const action = body.action as string;

  switch (action) {
    case "referral.list":
      return handleReferralList(admin, userId);
    case "referral.create":
      return handleReferralCreate(admin, userId, body);
    case "acquisition.track":
      return handleAcquisitionTrack(admin, userId, body);
    case "roadmap.progress":
      return handleRoadmapProgress(admin, userId);
    // ... 16アクション
  }
});
```

### hub構成 (15本体制)

```
standalone (4本):
  get-home-dashboard, ai-assistant,
  growth-weekly-digest, guitar-recording-studio

macro-hub (6本):
  core-hub      — 通知・メモ・フィードバック等
  growth-hub    — グロース・紹介・ロードマップ等
  ai-hub        — AI機能全般
  admin-hub     — サポート・管理・競合監視等
  app-hub       — アプリ機能全般
  schedule-hub  — スケジュール管理等

mega-hub (5本):
  tools-hub, media-hub, enterprise-hub,
  social-commerce-hub, lifestyle-hub
```

94本 → 15本 (84%削減)

### Dart側の移行

```dart
// 旧コード
await client.functions.invoke('growth-referral',
  body: {'action': 'get_code'});

// 新コード
await client.functions.invoke('growth-hub',
  body: {'action': 'referral.list'});
```

---

## 本番CORSエラーへの対処

hub統合で旧EFが削除されると、Dart側でまだ旧EF名を呼んでいる箇所がCORSエラーになります。

```
Access to XMLHttpRequest at 'https://xxx.supabase.co/functions/v1/growth-referral'
has been blocked by CORS policy: Response to preflight request doesn't pass
access control check: No 'Access-Control-Allow-Origin' header
```

原因: 削除されたEFへのOPTIONSプリフライトが404を返すため。

対処: `grep -rn "旧EF名" lib/ --include="*.dart"` で全呼び出し箇所を洗い出し、一括更新。

---

## CI/CDへの組み込み

`.github/workflows/ci.yml` にEF本数チェックを追加しました。

```yaml
- name: Check Edge Function deploy count (ハードキャップ50本以下)
  run: |
    DEPLOYED=$(grep "supabase functions deploy" .github/workflows/deploy-prod.yml \
      | grep -v "^#\|#" | awk '{print $4}')
    DEPLOY_COUNT=$(echo "$DEPLOYED" | grep -c .)
    if [ "$DEPLOY_COUNT" -gt 50 ]; then
      echo "❌ EFハードキャップ超過: ${DEPLOY_COUNT}本 > 50本"
      exit 1
    fi
    echo "✅ EFハードキャップ内: ${DEPLOY_COUNT}本 <= 50本"
```

新しいEFを追加しようとすると自動でCIが失敗します。

---

## まとめ

| 項目 | before | after |
|-----|--------|-------|
| AI大学対応社数 | 9社 | 20社 |
| Edge Function本数 | 94本 | 15本 |
| 本番CORSエラー | あり | なし |
| CI EF上限チェック | Tier1/Tier2分類 | ハードキャップ数値チェック |

Flutter × Supabase の個人開発でスケールするアーキテクチャを模索中です。
フィードバックお待ちしています。

---

URL: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #個人開発
