---
title: "SupabaseのRow Level Security (RLS) をFlutter Webで実践する — AI大学アプリの設計例"
tags: Flutter,Supabase,RLS,個人開発,セキュリティ
published: false
---

# SupabaseのRow Level Security (RLS) をFlutter Webで実践する

## はじめに

Supabaseを使ったFlutter Webアプリで「自分のデータは自分しか見られない」を実現するには、**Row Level Security (RLS)** が不可欠です。

この記事では、AI大学アプリ（[自分株式会社](https://my-web-app-b67f4.web.app/)）で実際に使用しているRLSの設計パターンを3つ紹介します。

- パターン1: 個人データ (スコア)
- パターン2: 操作別ポリシー (ストリーク)
- パターン3: 公開データ + 個人データの組み合わせ (バッジ)

## RLS の基本

RLSを有効にすると、`anon`キー経由のクエリは**ポリシーで許可されたデータのみ**アクセスできます。

```sql
-- RLSを有効化
ALTER TABLE my_table ENABLE ROW LEVEL SECURITY;

-- ポリシーがない状態 = 全データがブロック
-- auth.uid() = ログイン中のユーザーID
```

`service_role`キー（Edge Functions内）はRLSをバイパスします。Flutter側（anon/authenticatedキー）はRLSに従います。

## パターン1: 個人スコアデータ

AI大学のクイズ正解数を記録する `ai_university_scores` テーブル。ユーザーは自分のスコアのみ読み書き可能です。

```sql
CREATE TABLE ai_university_scores (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider_id text NOT NULL,        -- 'google' | 'openai' など
  quiz_correct boolean NOT NULL DEFAULT false,
  studied_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, provider_id)
);

ALTER TABLE ai_university_scores ENABLE ROW LEVEL SECURITY;

-- USING: SELECT/UPDATE/DELETE に適用
-- WITH CHECK: INSERT/UPDATE の新データに適用
CREATE POLICY "users_own_scores" ON ai_university_scores
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
```

Flutter側のUPSERT:

```dart
await supabase.from('ai_university_scores').upsert({
  'user_id': supabase.auth.currentUser!.id,
  'provider_id': 'google',
  'quiz_correct': true,
  'studied_at': DateTime.now().toIso8601String(),
}, onConflict: 'user_id,provider_id');
```

RLSにより `user_id` が自分以外のレコードは拒否されます。

## パターン2: 操作別ポリシー (ストリーク)

「読み取りは自分のみ」「書き込みは自分のみ」を **FOR SELECT / FOR INSERT / FOR UPDATE** に分割すると、より細かい制御が可能です。

```sql
CREATE TABLE ai_university_streaks (
  user_id         uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  current_streak  int NOT NULL DEFAULT 0,
  longest_streak  int NOT NULL DEFAULT 0,
  last_studied_date date
);

ALTER TABLE ai_university_streaks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "streaks_select_own" ON ai_university_streaks
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "streaks_insert_own" ON ai_university_streaks
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "streaks_update_own" ON ai_university_streaks
  FOR UPDATE USING (auth.uid() = user_id);
```

ストリーク更新はロジックが複雑なため、`SECURITY DEFINER` 関数経由で実行します:

```sql
CREATE OR REPLACE FUNCTION update_ai_university_streak(p_user_id uuid)
  RETURNS TABLE (current_streak int, longest_streak int, is_new_streak_day boolean)
  LANGUAGE plpgsql
  SECURITY DEFINER  -- RLSをバイパスして実行
AS $$
DECLARE
  v_today date := (now() AT TIME ZONE 'Asia/Tokyo')::date;
BEGIN
  -- 当日既に学習済みならスキップ
  IF (SELECT last_studied_date FROM ai_university_streaks WHERE user_id = p_user_id) = v_today THEN
    RETURN QUERY SELECT current_streak, longest_streak, false
      FROM ai_university_streaks WHERE user_id = p_user_id;
    RETURN;
  END IF;

  -- 連続判定: 昨日なら+1、それ以外はリセット
  -- (省略 — 実装はGitHub参照)
END;
$$;
```

Flutter側:

```dart
final result = await supabase.rpc('update_ai_university_streak', params: {
  'p_user_id': supabase.auth.currentUser!.id,
});
final streak = result[0]['current_streak'] as int;
```

## パターン3: 公開データ + 個人データの組み合わせ

ランキングビューは全員が閲覧可能、個人スコアはRLS保護という組み合わせ:

```sql
-- ランキングビューは anon でも閲覧可能
CREATE VIEW ai_university_leaderboard AS
SELECT
  user_id,
  COUNT(*) FILTER (WHERE quiz_correct)::int AS total_correct,
  RANK() OVER (ORDER BY COUNT(*) FILTER (WHERE quiz_correct) DESC) AS rank
FROM ai_university_scores
GROUP BY user_id;

GRANT SELECT ON ai_university_leaderboard TO anon, authenticated;
```

ポイント: **ビューはRLSを継承しない**。ビューにGRANTを付けることで、元テーブルのRLSを迂回した集計結果だけを公開できます。

## よくあるハマりポイント

### 1. RLS有効化後に全データが消えた？

ポリシーを追加しないとデフォルトで全件ブロックになります。

```sql
-- 確認
SELECT tablename, rowsecurity FROM pg_tables WHERE tablename = 'my_table';

-- 現在のポリシー一覧
SELECT * FROM pg_policies WHERE tablename = 'my_table';
```

### 2. service_role でもRLSが効く場合

```sql
-- service_role は RLS をバイパスする
-- ただし BYPASSRLS 権限がない場合は効かない
-- Edge Functions では service_role キーを使う
```

### 3. auth.uid() が NULL になる

非ログイン状態の `anon` アクセスでは `auth.uid()` が `NULL` を返します。

```sql
-- NULLの場合もポリシーを通したい場合
CREATE POLICY "public_read" ON my_table
  FOR SELECT USING (true);  -- 全員読み取り可
```

## まとめ

| ユースケース | パターン |
|------------|--------|
| 個人データ | USING + WITH CHECK で user_id 比較 |
| 操作別制御 | FOR SELECT / INSERT / UPDATE を分割 |
| 複雑なロジック | SECURITY DEFINER 関数 |
| 公開集計 | ビュー + GRANT |

RLSはSupabaseの最重要セキュリティ機能です。テーブル作成時に必ず有効化する習慣をつけましょう。

---
自分株式会社 (Flutter Web + Supabase): https://my-web-app-b67f4.web.app/
#Flutter #Supabase #RLS #個人開発 #セキュリティ
