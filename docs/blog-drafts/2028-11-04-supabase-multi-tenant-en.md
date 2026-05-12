---
title: "Supabase Multi-Tenant Design — RLS Tenant Isolation, Admin Roles, and Invite Flow"
tags: supabase,ai,indiedev,programming
published: true
---

# Supabase Multi-Tenant Design — RLS Tenant Isolation, Admin Roles, and Invite Flow

DB design patterns for SaaS apps with team and organization features.

## Tenant (Organization) Schema

```sql
-- Organizations table
CREATE TABLE organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Membership
CREATE TABLE org_members (
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member')),
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (org_id, user_id)
);

-- Data tables carry org_id
CREATE TABLE projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

## RLS for Tenant Isolation

```sql
-- Only org members can view projects
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;

CREATE POLICY "org members can view projects" ON projects
  FOR SELECT USING (
    org_id IN (
      SELECT org_id FROM org_members WHERE user_id = auth.uid()
    )
  );

-- Only admin+ can delete projects
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

## Invite Flow

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
// Edge Function: accept invitation
const { data: invite } = await supabase
  .from('org_invitations')
  .select('*')
  .eq('token', token)
  .gt('expires_at', new Date().toISOString())
  .is('accepted_at', null)
  .single();

if (!invite) throw new AppError('Invalid or expired invitation link', 'INVALID_INVITE', 400);

await supabase.from('org_members').insert({
  org_id: invite.org_id, user_id: userId, role: invite.role,
});
await supabase.from('org_invitations')
  .update({ accepted_at: new Date().toISOString() })
  .eq('id', invite.id);
```

## Summary

```
Tenant isolation  → RLS org_id condition (applied to every table)
Role hierarchy    → owner > admin > member (3 levels is enough)
Invite token      → UUID + 7-day expiry + used flag
Flutter side      → store current org_id in a Context/Provider
```

Multi-tenancy must be designed in from the start. Retrofitting RLS risks data leaks.
