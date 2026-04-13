---
title: "Flutter × Supabase で「AI大学」54社対応 — 個人開発で作るAIプロバイダー学習プラットフォーム"
tags: Flutter,Supabase,個人開発,buildinpublic,AI
published: true
---

# Flutter × Supabase で「AI大学」54社対応 — 個人開発で作るAIプロバイダー学習プラットフォーム

## はじめに

個人開発アプリ「自分株式会社」に、**AIプロバイダーを体系的に学べる「AI大学」機能**を追加しました。

OpenAI・Anthropic・Gemini・Mistral など、乱立するAIサービスを効率よく把握するために構築。現在 **54社のAIプロバイダー**に対応し、クイズ・スコア・ランキングで楽しく学べる仕組みにしました。

---

## なぜAI大学を作ったか

2026年時点でAIサービスの数は爆発的に増えています。

- 大手: OpenAI / Anthropic / Google / Microsoft / Meta
- 特化型: ElevenLabs (音声) / Runway (動画) / Midjourney (画像)
- オープンソース: Mistral / Llama / DeepSeek
- 国内外スタートアップ: Sakana AI / Coze / Zhipu AI ...

「どのサービスがどんな特徴を持つか」を把握しきれない問題を、アプリ内の学習コンテンツで解決しようと思いました。

---

## アーキテクチャ: DBドリブン × 自動更新

### コンテンツ管理

全コンテンツは Supabase の `ai_university_content` テーブルで管理します:

```sql
CREATE TABLE ai_university_content (
  id         uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  provider   text NOT NULL,  -- 'openai', 'anthropic', 'gemini' ...
  category   text NOT NULL,  -- 'overview', 'models', 'api', 'news'
  title      text NOT NULL,
  content    text NOT NULL,  -- Markdown 形式
  published_at date,
  UNIQUE (provider, category)
);
```

`category` が `news` のレコードは2層構成で自動更新されます:

| レイヤー | 更新頻度 | 内容 |
|---------|---------|------|
| GitHub Actions (`ai-university-update.yml`) | 2時間毎 | RSS から最新5記事タイトル + 概要 |
| Claude Code Schedule | 4時間毎 | NotebookLM Deep Research でリッチな解説に上書き |

後から書いた方が最新版になるため、朝は GitHub Actions のクイック更新、日中はClaudeのリッチ版が反映されます。

### Flutter UI: DBドリブンタブ

プロバイダーはハードコードせず、DBから動的取得します:

```dart
// providers が DB から取得した provider リスト
final tabs = providers.map((p) => Tab(
  child: Row(
    children: [
      Text(_providerMeta[p]?['emoji'] ?? '🤖'),
      const SizedBox(width: 4),
      Text(_providerMeta[p]?['name'] ?? p),
    ],
  ),
)).toList();
```

新しいプロバイダーを DB に追加するだけで UI にタブが自動で増えます。

---

## 54社への道のり (3日間)

| 日 | 追加社数 | 主なプロバイダー |
|----|---------|----------------|
| 1日目 | 9社 | Google / OpenAI / Anthropic / Microsoft / Meta / X / DeepSeek / Mistral / Perplexity |
| 2日目 | 30社 | Groq / Cohere / Amazon / Stability AI / HuggingFace / NVIDIA / IBM / Sakana AI / ... |
| 3日目 | 15社 | Midjourney / Hailuo / Adobe Firefly / Apple / Databricks / Samsung / Allen AI / Naver / ... |

1社あたり `supabase/migrations/` に SQL ファイルを1本作成。overview / models / api の3カテゴリで初期コンテンツを seed します。

---

## 学習ゲーミフィケーション

単なるコンテンツ閲覧にならないよう、学習要素を入れています:

### スコア記録

クイズに回答すると `ai_university_scores` テーブルに保存:

```sql
CREATE TABLE ai_university_scores (
  user_id   uuid REFERENCES auth.users,
  provider  text NOT NULL,
  score     int DEFAULT 0,
  UNIQUE (user_id, provider)
);
```

### 連続学習ストリーク

毎日学習するとストリーク日数が増えます:

```dart
// 今日すでに学習済みかチェック
final alreadyStudied = lastStudiedDate == today;
if (!alreadyStudied) {
  newStreak = currentStreak + 1;
}
```

### ランキング

全ユーザーのスコアを集計するビューでリーダーボードを表示:

```sql
CREATE VIEW ai_university_leaderboard AS
SELECT
  user_id,
  SUM(score) AS total_score,
  COUNT(DISTINCT provider) AS providers_studied,
  RANK() OVER (ORDER BY SUM(score) DESC) AS rank
FROM ai_university_scores
GROUP BY user_id;
```

---

## SNS シェア機能

「XX社制覇！」をシェアできる OGP カード生成機能も実装しました:

```dart
// Flutter Web: RenderRepaintBoundary → PNG → ダウンロード
final boundary = _shareKey.currentContext!
    .findRenderObject() as RenderRepaintBoundary;
final image = await boundary.toImage(pixelRatio: 2.0);
final bytes = await image.toByteData(format: ImageByteFormat.png);
// package:web/web.dart で HTMLAnchorElement.download
```

---

## 学習リマインダー

3日以上学習していないユーザーへ自動リマインダーを送信する GitHub Actions も追加:

```yaml
# .github/workflows/ai-university-reminder.yml
on:
  schedule:
    - cron: "0 0 * * *"  # 毎日09:00 JST

# notification-center EF の send_study_reminders action を呼び出し
# 3〜30日間未学習ユーザーを対象
```

---

## まとめ

| 機能 | 実装状況 |
|------|---------|
| 54社コンテンツ | ✅ DB + 自動更新 |
| クイズ + スコア | ✅ Supabase RLS直接 upsert |
| ランキング | ✅ ビュー + Flutter UI |
| ストリーク | ✅ daily streak + バッジ |
| SNS シェアカード | ✅ RenderRepaintBoundary |
| 学習リマインダー | ✅ GitHub Actions 毎日実行 |

個人開発でもこれだけの機能を3日間で実装できたのは、3インスタンス並行Claude Code体制のおかげです。

---

自分株式会社: https://my-web-app-b67f4.web.app/
#Flutter #Supabase #個人開発 #buildinpublic #AI
