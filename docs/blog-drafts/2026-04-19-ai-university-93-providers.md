---
title: "AIプロバイダー図鑑をSupabase+Flutterで作った — AI大学93社達成の設計"
tags: Flutter,Supabase,AI,個人開発,buildinpublic
published: true
---

# AIプロバイダー図鑑をSupabase+Flutterで作った

## AI大学とは

自分株式会社の「AI大学」機能は、主要AIプロバイダーを学習できるコンテンツプラットフォーム。

```
Google / OpenAI / Anthropic / Mistral / DeepSeek / Groq /
Nebius / DeepInfra / Fireworks AI / SambaNova / ... (93社)
```

各プロバイダーの概要・モデル・APIの使い方を学べる。
クイズ → スコア → ランキング → バッジ の学習フローを実装。

## 93社に至るまでの設計

### DBスキーマ

```sql
-- ai_university_content テーブル
CREATE TABLE ai_university_content (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  provider text NOT NULL,           -- "groq", "deepinfra" etc.
  category text NOT NULL,           -- "overview" | "models" | "api" | "news"
  title text NOT NULL,
  content text NOT NULL,            -- Markdown
  published_at date,
  created_at timestamptz DEFAULT now(),
  UNIQUE(provider, category)
);
```

`(provider, category)` で UNIQUE — 同じプロバイダーの同じカテゴリは1レコードのみ。
`published_at` を毎日更新すると「最新情報」バッジを表示できる。

### Flutter UI: タブ + DB駆動

```dart
// providers を DB から取得してタブを動的生成
Future<List<String>> _fetchProviders() async {
  final response = await Supabase.instance.client
      .from('ai_university_content')
      .select('provider')
      .order('provider')
      .limit(200);

  return (response as List)
      .map((r) => r['provider'] as String)
      .toSet()  // 重複除去
      .toList();
}
```

タブをハードコードしない → プロバイダーを DB に追加するだけで自動的にタブが増える。

### 新プロバイダー追加の手順 (1社15分)

1. **WebSearch** で最新情報を収集
2. **migration SQL** を作成 (`overview` / `models` / `api` の3カテゴリ)
3. **Supabase に apply** (`supabase db push`)
4. **Flutter側** は追加不要 (DB駆動)

```sql
-- 例: GMI Cloud 追加
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
  ('gmi_cloud', 'overview', 'GMI Cloud 概要', '## GMI Cloud とは\n\nGPU クラウドサービス...', '2026-04-19'),
  ('gmi_cloud', 'models', 'GMI Cloud モデル', '## 利用可能なモデル\n\n...', '2026-04-19'),
  ('gmi_cloud', 'api', 'GMI Cloud API', '## API 使用方法\n\n...', '2026-04-19')
ON CONFLICT (provider, category) DO UPDATE
  SET content = EXCLUDED.content,
      published_at = EXCLUDED.published_at;
```

### 自動更新: GitHub Actions (2時間ごと)

```yaml
# .github/workflows/ai-university-update.yml
on:
  schedule:
    - cron: '0 */2 * * *'  # 2時間ごと

jobs:
  update:
    steps:
      - name: Update news content
        run: |
          # 各プロバイダーの RSS / 公式ブログを取得
          # ai-university-content EF に UPSERT
```

**93社 × 毎2時間** で news カテゴリが自動更新される。

## 学習フロー実装

```
プロバイダー選択
  → overview / models / api を読む
  → クイズ (3問)
  → スコア記録 (ai_university_scores)
  → バッジ付与 (ai_university_badges)
  → ランキング反映 (leaderboard view)
```

FSRS (間隔反復) アルゴリズムで「復習推奨日」を計算し、
ストリーク (連続学習日数) を表示してモチベーション維持。

## まとめ

| 要素 | 設計 |
|------|------|
| コンテンツ管理 | DB駆動 (UNIQUE provider+category) |
| UI | タブ自動生成 |
| 更新 | GHA 2時間ごと自動 |
| 学習フロー | FSRS + ストリーク + バッジ |

「プロバイダーを追加する = DBレコードを追加するだけ」という設計で
93社まで拡張できた。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#Flutter #Supabase #AI #buildinpublic #個人開発
