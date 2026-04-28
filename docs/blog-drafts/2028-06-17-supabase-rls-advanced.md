---
title: "Supabase RLS 応用パターン — チーム共有・マルチテナント・管理者権限"
tags: supabase,AI,個人開発,programming
published: true
---

# Supabase RLS 応用パターン — チーム共有・マルチテナント・管理者権限

基本の「自分のデータだけ見える」を超えて、複雑な権限設計を RLS で実現する。

## チーム共有パターン

```sql
-- チームメンバーシップテーブル
CREATE TABLE team_members (
  team_id  UUID NOT NULL,
  user_id  UUID NOT NULL REFERENCES auth.users,
  role     TEXT NOT NULL CHECK (role IN ('owner', 'editor', 'viewer')),
  PRIMARY KEY (team_id, user_id)
);

-- プロジェクトはチーム全員が閲覧可
CREATE POLICY "team members can view projects"
  ON projects FOR SELECT
  USING (
    team_id IN (
      SELECT team_id FROM team_members
      WHERE user_id = auth.uid()
    )
  );

-- 編集はオーナー/エディターのみ
CREATE POLICY "editors can update projects"
  ON projects FOR UPDATE
  USING (
    team_id IN (
      SELECT team_id FROM team_members
      WHERE user_id = auth.uid()
        AND role IN ('owner', 'editor')
    )
  );
```

## マルチテナント: org_id での分離

```sql
-- JWT カスタムクレームで org_id を取得
CREATE OR REPLACE FUNCTION get_org_id()
RETURNS UUID AS $$
  SELECT (auth.jwt() ->> 'org_id')::UUID;
$$ LANGUAGE SQL STABLE;

-- 組織内データのみアクセス可
CREATE POLICY "org isolation"
  ON tasks FOR ALL
  USING (org_id = get_org_id());
```

```typescript
// Edge Function でカスタムクレームを JWT に付与
const { data: { session } } = await supabase.auth.getSession();
// または supabase.auth.updateUser() で app_metadata に org_id を保存
```

## 管理者権限: service_role を使わずに実現

```sql
-- 管理者テーブル
CREATE TABLE admins (
  user_id UUID PRIMARY KEY REFERENCES auth.users
);

-- 管理者はすべてのデータを閲覧可
CREATE POLICY "admins can view all"
  ON projects FOR SELECT
  USING (
    auth.uid() IN (SELECT user_id FROM admins)
    OR owner_id = auth.uid()  -- 自分のデータも引き続き見える
  );
```

## RLS のパフォーマンス最適化

```sql
-- NG: サブクエリが毎行評価される
USING (team_id IN (SELECT team_id FROM team_members WHERE user_id = auth.uid()));

-- OK: インデックスを活用できる形に書き換え
USING (
  EXISTS (
    SELECT 1 FROM team_members
    WHERE team_id = projects.team_id
      AND user_id = auth.uid()
  )
);

-- インデックスも忘れずに
CREATE INDEX idx_team_members_user_id ON team_members(user_id);
```

## まとめ

```
チーム共有     → team_members テーブル + role 列で RBAC
マルチテナント → JWT カスタムクレーム (org_id) で org 分離
管理者権限     → admins テーブル + OR 条件で重ねがけ
パフォーマンス → IN よりも EXISTS + インデックス
```

RLS は「誰が何を見られるか」の単一障害点。設計の迷いは必ず tests で検証する。
