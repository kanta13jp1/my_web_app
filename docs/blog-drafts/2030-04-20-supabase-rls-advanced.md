---
title: "Supabase Row Level Security 完全ガイド — マルチテナント・動的ポリシー・パフォーマンス最適化"
tags: supabase,個人開発,flutter,AI
published: true
---

# Supabase Row Level Security 完全ガイド — マルチテナント・動的ポリシー・パフォーマンス最適化

Row Level Security (RLS) は Supabase の安全な多ユーザー対応の核心です。「とりあえず enable する」段階を超え、マルチテナント設計・動的ポリシー・パフォーマンス最適化まで踏み込みます。

## RLS の基本

```sql
-- テーブルで RLS を有効化
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- SELECT ポリシー: 自分のタスクのみ取得可
CREATE POLICY "users_own_tasks_select"
ON tasks FOR SELECT
USING (auth.uid() = user_id);

-- INSERT ポリシー: 自分の user_id のみ挿入可
CREATE POLICY "users_own_tasks_insert"
ON tasks FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- UPDATE ポリシー
CREATE POLICY "users_own_tasks_update"
ON tasks FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- DELETE ポリシー
CREATE POLICY "users_own_tasks_delete"
ON tasks FOR DELETE
USING (auth.uid() = user_id);
```

## マルチテナント設計

### チームベースのアクセス制御

```sql
-- チームメンバーシップ管理
CREATE TABLE team_members (
  team_id  UUID REFERENCES teams(id),
  user_id  UUID REFERENCES auth.users(id),
  role     TEXT CHECK (role IN ('owner', 'admin', 'member', 'viewer')),
  PRIMARY KEY (team_id, user_id)
);

-- チームリソースへのポリシー
CREATE POLICY "team_members_can_access_projects"
ON projects FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM team_members tm
    WHERE tm.team_id = projects.team_id
      AND tm.user_id = auth.uid()
  )
);

-- 管理者のみ削除可
CREATE POLICY "team_admins_can_delete_projects"
ON projects FOR DELETE
USING (
  EXISTS (
    SELECT 1
    FROM team_members tm
    WHERE tm.team_id = projects.team_id
      AND tm.user_id = auth.uid()
      AND tm.role IN ('owner', 'admin')
  )
);
```

### Row Level Security と Claims

JWT カスタムクレームでロールを埋め込む:

```sql
-- auth.jwt() でカスタムクレームを取得
CREATE POLICY "admin_full_access"
ON admin_logs FOR ALL
USING (
  (auth.jwt() ->> 'user_role') = 'admin'
);
```

Supabase Auth Hook でカスタムクレームを追加:

```sql
-- custom_access_token hook (Database Webhooks)
CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event JSONB)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  claims JSONB;
  user_role TEXT;
BEGIN
  SELECT role INTO user_role
  FROM user_profiles
  WHERE id = (event->>'user_id')::UUID;

  claims := event->'claims';
  claims := jsonb_set(claims, '{user_role}', to_jsonb(COALESCE(user_role, 'member')));

  RETURN jsonb_set(event, '{claims}', claims);
END;
$$;
```

## 動的ポリシー

### 時間ベースのアクセス制御

```sql
-- 公開時刻になったら誰でも読める
CREATE POLICY "published_posts_are_public"
ON blog_posts FOR SELECT
USING (
  published_at <= NOW()
  OR auth.uid() = author_id  -- 著者は下書きも見える
);
```

### 階層的なリソース所有権

```sql
-- コメントはそのポストの閲覧権限があるユーザーが見える
CREATE POLICY "comments_visible_with_post"
ON comments FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM blog_posts bp
    WHERE bp.id = comments.post_id
      AND (bp.published_at <= NOW() OR bp.author_id = auth.uid())
  )
);
```

### RLS でのサブスクリプション制御

```sql
-- プレミアムコンテンツのアクセス制御
CREATE POLICY "premium_content_access"
ON premium_courses FOR SELECT
USING (
  -- 無料のコースは誰でも
  NOT is_premium
  OR
  -- プレミアムユーザーは全部
  EXISTS (
    SELECT 1
    FROM user_subscriptions us
    WHERE us.user_id = auth.uid()
      AND us.status = 'active'
      AND us.expires_at > NOW()
  )
);
```

## パフォーマンス最適化

### インデックス戦略

RLS ポリシーで使うカラムには必ずインデックスを:

```sql
-- user_id は RLS で頻繁に使うのでインデックス必須
CREATE INDEX idx_tasks_user_id ON tasks(user_id);
CREATE INDEX idx_projects_team_id ON projects(team_id);

-- 複合インデックスでカバリングクエリ
CREATE INDEX idx_team_members_user_team
ON team_members(user_id, team_id, role);

-- 部分インデックス: アクティブなサブスクリプションのみ
CREATE INDEX idx_active_subscriptions
ON user_subscriptions(user_id)
WHERE status = 'active' AND expires_at > NOW();
```

### ポリシーの `SECURITY DEFINER` 関数化

複雑な EXISTS サブクエリは関数に抽出してキャッシュ効率を上げる:

```sql
-- ヘルパー関数 (SECURITY DEFINER で RLS をバイパス)
CREATE OR REPLACE FUNCTION is_team_member(p_team_id UUID, p_role TEXT DEFAULT NULL)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM team_members
    WHERE team_id = p_team_id
      AND user_id = auth.uid()
      AND (p_role IS NULL OR role = p_role)
  );
$$;

-- シンプルなポリシー
CREATE POLICY "team_member_access"
ON projects FOR SELECT
USING (is_team_member(team_id));

CREATE POLICY "team_admin_delete"
ON projects FOR DELETE
USING (is_team_member(team_id, 'admin') OR is_team_member(team_id, 'owner'));
```

## RLS のデバッグ

### ポリシー動作の確認

```sql
-- 特定ユーザーとしてクエリを実行してテスト
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "user-uuid-here"}';
SELECT * FROM tasks;  -- RLS が適用された結果が返る

-- explain analyze でポリシーのコストを確認
EXPLAIN ANALYZE SELECT * FROM projects;
```

### RLS ポリシーの一覧確認

```sql
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
```

## Flutter クライアントでの実装

```dart
// RLS が透過的に働くので Dart 側は通常通り
class TaskRepository {
  final SupabaseClient _client;
  TaskRepository(this._client);

  // auth.uid() == user_id のタスクのみ返る (RLS による)
  Future<List<Task>> getTasks() async {
    final data = await _client
        .from('tasks')
        .select()
        .order('created_at', ascending: false);
    return data.map(Task.fromJson).toList();
  }

  // INSERT 時も user_id チェックが走る
  Future<void> createTask(String title) async {
    await _client.from('tasks').insert({
      'title': title,
      'user_id': _client.auth.currentUser!.id,
    });
  }
}
```

## まとめ

RLS のポイントを整理します。

| テーマ | ベストプラクティス |
|---|---|
| 基本設計 | ALL より SELECT/INSERT/UPDATE/DELETE を個別定義 |
| マルチテナント | team_members テーブル + EXISTS サブクエリ |
| パフォーマンス | RLS カラムにインデックス + 関数化でキャッシュ |
| デバッグ | SET LOCAL で特定ユーザーとしてテスト |
| JWT クレーム | custom_access_token hook でロールを埋め込む |

RLS を正しく設計すれば、アプリケーション層でのアクセス制御漏れを DB レベルで防げます。

---

*自分株式会社では Supabase RLS でマルチユーザー対応のライフマネジメントアプリを本番運用中 → [@kanta13jp1](https://x.com/kanta13jp1)*
