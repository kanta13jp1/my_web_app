---
title: "Supabase RLS SECURITY DEFINER: Preventing Infinite Recursion in Admin Policies"
tags: Flutter,Supabase,buildinpublic,Dart,security
published: true
---

# Supabase RLS SECURITY DEFINER: Preventing Infinite Recursion in Admin Policies

## The Feature

[自分株式会社](https://my-web-app-b67f4.web.app/) added a user feedback collection system — feature requests, bug reports, and general comments. Two separate views:

1. **FeedbackPage** — form for logged-in users to submit feedback
2. **FeedbackListPage** — admin view to see all feedback and update status

The interesting part is the RLS setup. Admin policies that reference another RLS-protected table can cause infinite recursion — here's how to solve it.

---

## Schema

```sql
CREATE TABLE IF NOT EXISTS app_feedback (
  id         bigserial PRIMARY KEY,
  user_id    uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  category   text NOT NULL DEFAULT 'other', -- 'feature' | 'bug' | 'other'
  content    text NOT NULL,
  status     text NOT NULL DEFAULT 'new',   -- 'new' | 'reviewed' | 'implemented'
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE app_feedback ENABLE ROW LEVEL SECURITY;
```

Three `category` values, three `status` values. Simple enum-like constraint via `text` with application-level validation.

---

## RLS: The Infinite Recursion Problem

Users should see only their own feedback. Admins should see everything.

The naive approach:

```sql
-- Admin check that causes infinite recursion ❌
CREATE POLICY "admin_select_all_feedback" ON app_feedback
  FOR SELECT USING (
    (SELECT is_admin FROM user_profiles WHERE user_id = auth.uid())
  );
```

If `user_profiles` also has RLS enabled, evaluating this policy requires reading `user_profiles`, which triggers `user_profiles`'s RLS policy, which may reference `app_feedback`, which triggers `app_feedback`'s policy again — infinite recursion.

**Postgres error**: `ERROR: infinite recursion detected in policy for relation "user_profiles"`

---

## Fix: SECURITY DEFINER Function

A `SECURITY DEFINER` function runs with the privileges of the function owner (typically a superuser), bypassing RLS on any tables it reads:

```sql
CREATE OR REPLACE FUNCTION is_user_admin(check_user_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM user_profiles WHERE user_id = check_user_id),
    false
  );
$$;
```

`SECURITY DEFINER` + `STABLE` (reads DB but doesn't modify it) — the function can read `user_profiles` without triggering its RLS. `COALESCE(..., false)` safely handles the case where the user has no profile row.

Now the policies are clean:

```sql
-- Users see and insert only their own feedback
CREATE POLICY "users_insert_own_feedback" ON app_feedback
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_select_own_feedback" ON app_feedback
  FOR SELECT USING (auth.uid() = user_id);

-- Admins see and update everything — recursion-free
CREATE POLICY "admin_select_all_feedback" ON app_feedback
  FOR SELECT USING (is_user_admin(auth.uid()));

CREATE POLICY "admin_update_all_feedback" ON app_feedback
  FOR UPDATE
  USING     (is_user_admin(auth.uid()))
  WITH CHECK (is_user_admin(auth.uid()));
```

---

## Flutter: Submit Form

Direct Supabase insert — no Edge Function needed for simple inserts:

```dart
Future<void> _submitFeedback() async {
  if (!_formKey.currentState!.validate()) return;
  setState(() => _isSubmitting = true);

  try {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Login required');

    await supabase.from('app_feedback').insert({
      'user_id':  userId,
      'category': _selectedCategory,
      'content':  _contentController.text.trim(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback submitted!')),
      );
      Navigator.pop(context);
    }
  } catch (e) {
    // handle error
  } finally {
    if (mounted) setState(() => _isSubmitting = false);
  }
}
```

Three categories via `SegmentedButton` or `DropdownButton`: `'feature'`, `'bug'`, `'other'`.

---

## Flutter: Admin Status Update

```dart
Future<void> _updateStatus(int id, String newStatus) async {
  await supabase
      .from('app_feedback')
      .update({'status': newStatus}).eq('id', id);

  setState(() {
    final index = _feedbacks.indexWhere((f) => f['id'] == id);
    if (index != -1) _feedbacks[index]['status'] = newStatus;
  });
}
```

The `admin_update_all_feedback` RLS policy silently rejects this query for non-admins — no client-side guard needed. The DB enforces the permission.

`setState` updates the local list optimistically after the await so the UI refreshes immediately.

---

## Why SECURITY DEFINER and Not a Join

Alternative: join `user_profiles` directly in the policy:

```sql
-- Works but risks recursion if user_profiles has its own RLS ❌
CREATE POLICY "admin_select" ON app_feedback
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM user_profiles up WHERE up.user_id = auth.uid() AND up.is_admin)
  );
```

This works today but breaks the moment `user_profiles` adds an RLS policy that references any table with a similar cross-reference. `SECURITY DEFINER` is the durable fix — isolates the admin check in one place, reusable across all tables.

---

## Summary

| Pattern | Use When |
|---------|---------|
| `auth.uid() = user_id` | User owns the row |
| `user_id IS NULL OR auth.uid() = user_id` | Broadcast + personal (see notification patterns) |
| `SECURITY DEFINER` function | Admin check references another RLS-protected table |
| Direct `supabase.from().insert()` | Simple writes without business logic |

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #security #Dart
