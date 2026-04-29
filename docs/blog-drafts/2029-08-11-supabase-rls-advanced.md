---
title: "Supabase RLS 実践 — マルチテナント対応の行レベルセキュリティ設計"
tags: flutter,dart,個人開発,AI
published: true
---

# Supabase RLS 実践 — マルチテナント対応の行レベルセキュリティ設計

Supabase の Row Level Security (RLS) は SQL の `CREATE POLICY` で実装します。適切に設計すれば、アプリケーションコードに権限チェックを書かなくてよくなります。マルチテナント SaaS での実践パターンをまとめます。

## RLS の基本

```sql
-- RLS を有効化
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- 自分のレコードのみ SELECT 可能
CREATE POLICY "own_tasks_select"
  ON tasks FOR SELECT
  USING (user_id = auth.uid());

-- INSERT は user_id = 自分 のみ
CREATE POLICY "own_tasks_insert"
  ON tasks FOR INSERT
  WITH CHECK (user_id = auth.uid());
```

## マルチテナント: Organization ベース

```sql
-- organizations テーブル
CREATE TABLE organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL
);

-- organization_members: ユーザー ↔ 組織 の中間テーブル
CREATE TABLE organization_members (
  org_id  UUID REFERENCES organizations(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  role    TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'member')),
  PRIMARY KEY (org_id, user_id)
);

-- helper 関数: ユーザーの所属 org 一覧
CREATE OR REPLACE FUNCTION my_org_ids()
RETURNS SETOF UUID
LANGUAGE SQL STABLE SECURITY DEFINER AS $$
  SELECT org_id FROM organization_members WHERE user_id = auth.uid()
$$;

-- projects テーブル
CREATE TABLE projects (
  id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  name   TEXT NOT NULL
);

ALTER TABLE projects ENABLE ROW LEVEL SECURITY;

-- 自分の組織のプロジェクトのみアクセス可
CREATE POLICY "org_projects_select"
  ON projects FOR SELECT
  USING (org_id IN (SELECT my_org_ids()));

-- INSERT: 自分が admin 以上の組織のみ
CREATE POLICY "org_projects_insert"
  ON projects FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organization_members
      WHERE org_id = projects.org_id
        AND user_id = auth.uid()
        AND role IN ('owner', 'admin')
    )
  );

-- DELETE: owner のみ
CREATE POLICY "org_projects_delete"
  ON projects FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM organization_members
      WHERE org_id = projects.org_id
        AND user_id = auth.uid()
        AND role = 'owner'
    )
  );
```

## JWT カスタムクレームを使った高速化

毎回 `organization_members` を JOIN すると重くなります。JWT に `org_id` を埋め込む方式で回避できます。

```sql
-- auth.users の app_metadata に組織情報を保存
-- (Supabase Auth Hooks / Edge Function で更新)

-- カスタムクレームへのアクセス
CREATE OR REPLACE FUNCTION auth_org_ids()
RETURNS SETOF UUID
LANGUAGE SQL STABLE AS $$
  SELECT jsonb_array_elements_text(
    (auth.jwt() -> 'app_metadata' -> 'org_ids')
  )::UUID
$$;

-- ポリシーで利用
CREATE POLICY "jwt_org_select"
  ON projects FOR SELECT
  USING (org_id IN (SELECT auth_org_ids()));
```

```typescript
// Edge Function: ログイン後に JWT を更新
// supabase/functions/update-jwt-claims/index.ts
import { createClient } from 'jsr:@supabase/supabase-js@2';

Deno.serve(async (req) => {
  const { user_id } = await req.json();
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  const { data: memberships } = await supabase
    .from('organization_members')
    .select('org_id')
    .eq('user_id', user_id);

  const orgIds = memberships?.map(m => m.org_id) ?? [];

  await supabase.auth.admin.updateUserById(user_id, {
    app_metadata: { org_ids: orgIds }
  });

  return new Response(JSON.stringify({ ok: true }));
});
```

## パブリック読み取り + 認証済み書き込み

```sql
-- 公開コンテンツ (例: ブログ記事)
CREATE TABLE posts (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id  UUID REFERENCES auth.users(id),
  title      TEXT NOT NULL,
  body       TEXT NOT NULL,
  published  BOOLEAN DEFAULT false
);

ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- 公開された記事は誰でも読める
CREATE POLICY "published_posts_select"
  ON posts FOR SELECT
  USING (published = true OR author_id = auth.uid());

-- 書き込みは author のみ
CREATE POLICY "own_posts_write"
  ON posts FOR ALL
  USING (author_id = auth.uid())
  WITH CHECK (author_id = auth.uid());
```

## Service Role と RLS のバイパス

Edge Function 内でフルアクセスが必要な場合は `SUPABASE_SERVICE_ROLE_KEY` を使います。

```typescript
// ⚠️ RLS を完全バイパス — サーバーサイドのみで使用
const adminClient = createClient(url, serviceRoleKey);
const { data } = await adminClient.from('tasks').select('*'); // 全ユーザーのデータ取得
```

```typescript
// ユーザーのリクエストには anon/user JWT を使う (RLS が適用される)
const userClient = createClient(url, anonKey, {
  global: { headers: { Authorization: `Bearer ${userJwt}` } }
});
```

## RLS のパフォーマンスチェック

```sql
-- ポリシーが index を使っているか確認
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM projects WHERE org_id = 'xxx';

-- user_id / org_id にインデックスを張る (必須)
CREATE INDEX ON tasks (user_id);
CREATE INDEX ON projects (org_id);
CREATE INDEX ON organization_members (user_id);
```

## まとめ

| パターン | 用途 |
|--------|------|
| `auth.uid()` | 個人データ保護の基本 |
| 中間テーブル + helper 関数 | マルチテナント組織権限 |
| JWT カスタムクレーム | 高速化 (DB JOIN 削減) |
| `published` フラグ | 公開/非公開コンテンツ |
| Service Role | サーバーサイド管理処理 |

RLS を正しく設計してから、セキュリティ監査で「アプリ層に権限チェックが不要」と評価されました。

---

Supabase RLS で詰まった部分があればコメントで教えてください！
