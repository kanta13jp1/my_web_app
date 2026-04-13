---
title: "AI大学40社体制完成 + Supabase ON CONFLICT本番デプロイ障害を修正した話"
emoji: "🎓"
type: "tech"
topics: ["Flutter", "Supabase", "PostgreSQL", "個人開発", "buildinpublic"]
published: true
---

# AI大学40社体制完成 + Supabase ON CONFLICT本番デプロイ障害を修正した話

## はじめに

Flutter Web × Supabase で開発中の自分株式会社で、本日 AI大学機能が **40社体制** に到達しました。

同時に本番デプロイが `SQLSTATE 42P10` エラーで失敗するという障害が発生。原因調査と修正を即日対応したので、その記録を共有します。

## AI大学とは

自分株式会社の「AI大学」機能は、主要 AI プロバイダー（Google/OpenAI/Anthropic など）について以下を学べる機能です：

- 各社の概要・モデル一覧・API ガイド
- クイズで知識確認
- 学習スコア・ストリーク記録
- ランキングで競争

本日で登録プロバイダーが 40社になりました：

```
google, openai, anthropic, microsoft, meta, x, deepseek, mistral, perplexity,
groq, cohere, amazon, stability, huggingface, nvidia, ibm, sakana, baidu,
oracle, reka, aleph_alpha, together_ai, fireworks_ai, replicate, writer,
ai21, voyage, elevenlabs, openrouter, ollama, runway, suno, ideogram, udio,
luma, kling, pika, assemblyai, twelve_labs, cohere(重複除外後 39社+α)
```

## 本番デプロイ障害: SQLSTATE 42P10

### エラー内容

```
ERROR: there is no unique or exclusion constraint matching
       the ON CONFLICT specification (SQLSTATE 42P10)
```

GitHub Actions の `deploy-prod.yml` が Supabase migration 適用時に失敗。

### 原因

`ai_university_content` テーブルの DDL:

```sql
CREATE TABLE IF NOT EXISTS ai_university_content (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider   text NOT NULL,
  category   text NOT NULL,
  -- ... 他カラム
);

CREATE INDEX IF NOT EXISTS ai_university_content_provider_idx
  ON ai_university_content (provider, sort_order);
```

**INDEX のみで UNIQUE 制約なし**。

一方、新しい migration（40社目前後から）は：

```sql
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES (...)
ON CONFLICT (provider, category) DO UPDATE  -- ← UNIQUE制約が必要!
  SET title = EXCLUDED.title,
      content = EXCLUDED.content;
```

`ON CONFLICT (provider, category)` は **UNIQUE 制約または EXCLUDE 制約** が必要です。
INDEX だけでは PostgreSQL は使えません。

### 修正方法

新しい migration ファイル `20260412029500_add_unique_constraint.sql` を追加：

```sql
-- Remove duplicate rows first (keep most recently updated)
DELETE FROM ai_university_content a
USING ai_university_content b
WHERE a.id < b.id
  AND a.provider = b.provider
  AND a.category = b.category;

-- Add the UNIQUE constraint required for ON CONFLICT upsert
ALTER TABLE ai_university_content
  ADD CONSTRAINT ai_university_content_provider_category_unique
  UNIQUE (provider, category);
```

**ポイント**: migration は順序通りに適用されるため、このファイルに `20260412029500` というタイムスタンプをつけて、問題の migration（`20260412030000`〜）の直前に挿入しました。

### 重複行の削除について

本番 DB に既存データがある場合、`UNIQUE` 制約追加前に重複を除去する必要があります。

```sql
DELETE FROM ai_university_content a
USING ai_university_content b
WHERE a.id < b.id          -- idが小さい方（古い方）を削除
  AND a.provider = b.provider
  AND a.category = b.category;
```

この書き方は PostgreSQL の `DELETE ... USING` 構文で、自己結合して重複を削除できます。

## PostgreSQL の ON CONFLICT まとめ

| 書き方 | 必要な前提 | 動作 |
|--------|-----------|------|
| `ON CONFLICT DO NOTHING` | 不要 | 競合時は無視 |
| `ON CONFLICT (col) DO UPDATE` | `col` に UNIQUE/EXCLUDE 制約が必要 | 競合時は UPDATE |
| `ON CONFLICT ON CONSTRAINT name` | 制約名を指定 | 制約に合致した競合時に UPDATE |

**早期の migration では `ON CONFLICT DO NOTHING`（制約不要）を使っていましたが、後から upsert に変更した際に制約を追加し忘れたのが原因でした。**

## Supabase migration の注意点

1. **migration は不可逆** — 一度 push した migration は修正ではなく新しい migration を追加して対処
2. **本番 DB のデータを変更する migration は慎重に** — `DELETE` を含む migration は特に
3. **`ON CONFLICT` を使う場合は制約を先に追加** — DDL migration → seed migration の順

## まとめ

- AI大学が 40社体制に到達
- `ON CONFLICT (provider, category)` エラーの根本原因は UNIQUE 制約の欠如
- 重複削除 + 制約追加 migration を挿入することで修正
- `supabase db push --include-all` は migration の順序が重要

自分株式会社: https://my-web-app-b67f4.web.app/

---

#buildinpublic #Flutter #Supabase #PostgreSQL #個人開発
