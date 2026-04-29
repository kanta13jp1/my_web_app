---
title: "Supabase マルチテナント設計 — RLS でテナント分離・管理者権限・招待フロー"
tags: supabase,AI,個人開発,programming
published: true
---

# Supabase マルチテナント設計 — RLS でテナント分離・管理者権限・招待フロー

チーム・組織機能を持つ SaaS の DB 設計パターンをまとめる。

## テナント (組織) スキーマ

```sql
-- 組織テーブル
CREATE TABLE organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- メンバーシップ
CREATE TABLE org_members (
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member')),
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (org_id, user_id)
);

-- データテーブルに org_id を持たせる
CREATE TABLE projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

## RLS でテナント分離

```sql
-- メンバーのみプロジェクト閲覧可
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;

CREATE POLICY "org members can view projects" ON projects
  FOR SELECT USING (
    org_id IN (
      SELECT org_id FROM org_members WHERE user_id = auth.uid()
    )
  );

-- admin 以上のみ削除可
CREATE POLICY "org admins can delete projects" ON projects
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM org_members
      WHERE org_id = projects.org_id
        AND user_id = auth.uid()
        AND role IN ('owner', 'admin')
    )
  );
```

## 招待フロー

```sql
CREATE TABLE org_invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  token TEXT UNIQUE DEFAULT gen_random_uuid()::TEXT,
  role TEXT DEFAULT 'member',
  expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '7 days',
  accepted_at TIMESTAMPTZ
);
```

```typescript
// Edge Function: 招待受諾
const { data: invite } = await supabase
  .from('org_invitations')
  .select('*')
  .eq('token', token)
  .gt('expires_at', new Date().toISOString())
  .is('accepted_at', null)
  .single();

if (!invite) throw new AppError('無効または期限切れの招待リンク', 'INVALID_INVITE', 400);

await supabase.from('org_members').insert({
  org_id: invite.org_id, user_id: userId, role: invite.role,
});
await supabase.from('org_invitations')
  .update({ accepted_at: new Date().toISOString() })
  .eq('id', invite.id);
```

## まとめ

```
テナント分離  → RLS の org_id 条件 (全テーブル統一)
権限階層     → owner > admin > member (3段階で十分)
招待トークン → UUID + 7日期限 + 使用済みフラグ
Flutter側   → 現在 org_id を Context/Provider で管理
```

マルチテナントは「最初から設計する」のが鉄則。後付けは RLS 漏れリスクが高い。
