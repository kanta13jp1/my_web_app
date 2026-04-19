---
title: "SupabaseのRLSを個人開発SaaSで使い倒す — auth.uid()と6つのポリシーパターン"
tags: Supabase,PostgreSQL,個人開発,buildinpublic,security
published: false
---

# SupabaseのRLSを個人開発SaaSで使い倒す

## なぜ RLS が必要か

Supabase は PostgREST でテーブルに直接 HTTP アクセスできる。
RLS (Row Level Security) なしでは全ユーザーのデータが漏れる。

```sql
-- RLS なし → 全データが見える
GET /rest/v1/notes?select=* HTTP/1.1

-- RLS あり → 自分のデータだけ見える
```

## パターン1: 基本的な自分のデータだけ

```sql
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;

-- 自分のデータだけ読める
CREATE POLICY "notes: own read"
  ON notes FOR SELECT
  USING (user_id = auth.uid());

-- 自分のデータだけ書ける
CREATE POLICY "notes: own write"
  ON notes FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
```

`auth.uid()` が JWT から自動取得されるのが Supabase の強み。

## パターン2: 管理者は全データ見える

```sql
-- user_profiles テーブルに is_admin カラム
CREATE POLICY "notes: admin can read all"
  ON notes FOR SELECT
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.user_id = auth.uid()
        AND user_profiles.is_admin = true
    )
  );
```

管理者チェックはサブクエリで `user_profiles` を参照する。
`profiles` テーブル名ではなく `user_profiles` に注意 — 混在しやすい。

## パターン3: 公開コンテンツ (誰でも読める)

```sql
-- AI大学コンテンツは認証不要で読める
CREATE POLICY "ai_university_content: public read"
  ON ai_university_content FOR SELECT
  USING (true);  -- 全員読める

-- 書き込みは service_role のみ
CREATE POLICY "ai_university_content: service write"
  ON ai_university_content FOR ALL
  USING (auth.role() = 'service_role');
```

`auth.role() = 'service_role'` → Edge Function 経由のみ書き込み可。

## パターン4: ユーザーデータの RLS Function

重複するポリシーを関数化する:

```sql
-- 共通チェック関数
CREATE OR REPLACE FUNCTION is_own_or_admin(row_user_id uuid)
RETURNS bool AS $$
  SELECT row_user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_id = auth.uid() AND is_admin = true
    );
$$ LANGUAGE sql SECURITY DEFINER;

-- 使用
CREATE POLICY "use function"
  ON notes FOR SELECT
  USING (is_own_or_admin(user_id));
```

## パターン5: Leaderboard (集計は見えるが個人は匿名)

```sql
-- ランキングビュー: スコア集計のみ公開、user_id は隠す
CREATE VIEW ai_university_leaderboard AS
  SELECT
    ROW_NUMBER() OVER (ORDER BY total_score DESC) as rank,
    -- user_id は含めない
    total_score,
    quiz_count,
    updated_at
  FROM ai_university_scores;

-- ビューは RLS 不要 (user_id が含まれないため)
GRANT SELECT ON ai_university_leaderboard TO authenticated, anon;
```

## パターン6: Edge Function で RLS バイパス

RLS を bypass したい場合は `service_role` キーを使う Edge Function 経由:

```typescript
// supabase/functions/admin-hub/index.ts
// service_role キーで全データにアクセス可能
const supabaseAdmin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

// ↑ これは Edge Function (バックエンド) のみで使う
// フロントエンドに service_role キーを渡してはいけない
```

## よくある罠

### 1. INSERT の with CHECK を忘れる

```sql
-- ❌ USING のみ → 他人の user_id でINSERT できてしまう
CREATE POLICY "bad" ON notes FOR INSERT
  USING (user_id = auth.uid());

-- ✅ WITH CHECK も必要
CREATE POLICY "good" ON notes FOR INSERT
  WITH CHECK (user_id = auth.uid());
```

### 2. テーブル名の混在 (`profiles` vs `user_profiles`)

Supabase の例では `profiles` だが、本プロジェクトは `user_profiles`。
RLS ポリシーでテーブル名を間違えると 403 が発生する。

### 3. anon ロールと authenticated ロールの違い

```sql
-- anon: 未ログインユーザー
-- authenticated: ログイン済みユーザー
GRANT SELECT ON notes TO authenticated;  -- ログイン必須
GRANT SELECT ON public_content TO anon;  -- 誰でも
```

## まとめ

| パターン | 用途 |
|---------|------|
| 自分のデータのみ | メモ・設定・スコア |
| 管理者アクセス | 管理ダッシュボード |
| 公開コンテンツ | AI大学・ランキング |
| 集計のみ公開 | Leaderboard |
| service_role | Edge Function バックエンド |

RLS は設計時に入れると後から修正が楽。
Flutter から直接 Supabase を叩く場合は特に必須。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#Supabase #PostgreSQL #buildinpublic #個人開発 #security
