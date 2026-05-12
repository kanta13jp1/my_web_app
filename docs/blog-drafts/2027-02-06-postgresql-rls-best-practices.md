---
title: "PostgreSQL RLS 実践ガイド — auth.uid() で行レベルセキュリティを実装する"
tags: supabase,AI,個人開発,postgresql
published: true
---

# PostgreSQL RLS 実践ガイド — auth.uid() で行レベルセキュリティを実装する

Supabase の Row Level Security (RLS) はデータベース層でアクセス制御を実現します。アプリケーション層でのチェック漏れを防ぎ、12インスタンス並行開発でも「認証バグが本番に漏れた」経験がゼロな理由はこれです。

## RLS の基本: なぜアプリ層チェックでは足りないか

```
アプリ層チェック:
  request → Flutter/Edge Function → 「このユーザーはアクセス可？」→ SQL
  問題: Edge Function のバグ / 新インスタンスの実装漏れ → 全データが見える

RLS:
  request → SQL実行 → PostgreSQL が自動フィルタ → 「見えるべき行だけ」返す
  問題: なし。SQL の内側でフィルタされる
```

RLS を有効にしたテーブルは、ポリシーがない限り全員に「0行」を返す。**deny-by-default** が自動適用される。

## 基本パターン: ユーザー自身のデータのみ読み書き可

```sql
-- RLS を有効化
ALTER TABLE user_notes ENABLE ROW LEVEL SECURITY;

-- 読み取り: 自分のデータのみ
CREATE POLICY "users_select_own" ON user_notes
  FOR SELECT
  USING (auth.uid() = user_id);

-- 挿入: 自分の user_id のみ
CREATE POLICY "users_insert_own" ON user_notes
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 更新: 自分のデータのみ
CREATE POLICY "users_update_own" ON user_notes
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 削除: 自分のデータのみ
CREATE POLICY "users_delete_own" ON user_notes
  FOR DELETE
  USING (auth.uid() = user_id);
```

`USING` = 「どの行が見えるか」。`WITH CHECK` = 「どの行を書けるか」。UPDATEは両方必要。

## auth.uid() の仕組み

```sql
-- auth.uid() は JWT から自動解析される
-- Supabase クライアントが Authorization: Bearer <token> を送ると
-- PostgreSQL が auth.uid() で取得できる

-- 確認方法
SELECT auth.uid();  -- 現在のセッションの user_id が返る
SELECT auth.role(); -- 'anon' または 'authenticated'
```

Edge Function では Service Role Key を使うため `auth.uid() = NULL` になる。
EF 内では RLS をバイパスして全データを扱える (= EF 内で独自チェックを実装する責任がある)。

## 共有データパターン: public + own

```sql
-- メモ: 公開 or 自分のもの
CREATE POLICY "notes_select" ON notes
  FOR SELECT
  USING (
    is_public = true
    OR auth.uid() = user_id
  );
```

## 管理者パターン

```sql
-- admin_users テーブルで管理者を管理
CREATE TABLE admin_users (user_id UUID PRIMARY KEY);

-- admin は全件読める
CREATE POLICY "admin_select_all" ON user_notes
  FOR SELECT
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM admin_users WHERE user_id = auth.uid()
    )
  );
```

EXISTS サブクエリはインデックスが効く。admin_users.user_id に PK があれば高速。

## テナントパターン (チーム/組織単位)

```sql
-- organization_members で組織メンバーを管理
CREATE POLICY "org_members_select" ON org_documents
  FOR SELECT
  USING (
    org_id IN (
      SELECT org_id FROM organization_members
      WHERE user_id = auth.uid()
    )
  );
```

このプロジェクトではシングルテナントだが、SaaS 化するならこのパターンが必須。

## RLS + Edge Function の正しい組み合わせ

```typescript
// Edge Function: Service Role Key → RLS バイパス
const supabaseAdmin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,  // 管理用
);

// ユーザーリクエスト処理時は JWT を渡す → RLS が有効になる
const supabaseUser = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_ANON_KEY')!,
  { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
);

// supabaseUser.from('user_notes').select() は RLS でフィルタされる
// supabaseAdmin.from('user_notes').select() は全件返る
```

## RLS のデバッグ

```sql
-- ポリシー一覧
SELECT schemaname, tablename, policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'user_notes';

-- 特定ユーザーとしてテスト
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "user-uuid-here"}';
SELECT * FROM user_notes;  -- RLS が適用された結果
RESET ROLE;
```

## パフォーマンス注意点

**1. `auth.uid()` は毎行評価される**  
RLS ポリシーは全行に適用される。インデックスが効く条件（`user_id = auth.uid()`）は高速だが、サブクエリを含むポリシーは重くなる。

**2. `SECURITY DEFINER` 関数で最適化**  

```sql
-- 管理者チェックを関数にキャッシュ
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid());
$$;

-- ポリシーで呼び出し
CREATE POLICY "admin_select" ON user_notes
  FOR SELECT
  USING (auth.uid() = user_id OR is_admin());
```

## まとめ

RLS の原則:
1. **全テーブルで `ENABLE ROW LEVEL SECURITY`** — 有効化忘れが最大のリスク
2. **deny-by-default を信頼する** — ポリシーゼロ = 全員に0行
3. **EF は Service Role Key で動く** — RLS バイパスなので EF 内独自チェックを忘れずに
4. **インデックスを `user_id` に貼る** — RLS フィルタが毎クエリで走る

アプリ層に認証ロジックを書くな。DB層で完結させろ。
