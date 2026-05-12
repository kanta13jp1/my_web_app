---
title: "Supabase Auth Complete Guide — OAuth, Magic Link & Row Level Security"
tags: supabase,flutter,ai,indiedev
published: true
---

# Supabase Auth Complete Guide — OAuth, Magic Link & Row Level Security

Supabase Auth supports multiple authentication methods. This guide covers Google OAuth, Magic Link, and how to secure data access with Row Level Security (RLS).

## Supabase Auth Overview

```
User → [OAuth/Magic Link/Email] → Supabase Auth → JWT → RLS → PostgreSQL
```

Supabase Auth is built on GoTrue. The issued JWT is used to access all Supabase services (DB / Storage / Edge Functions).

## Flutter Setup

```yaml
# pubspec.yaml
dependencies:
  supabase_flutter: ^2.5.0
  google_sign_in: ^6.2.1
  app_links: ^6.1.0  # For Magic Link deep links
```

```dart
// main.dart
await Supabase.initialize(
  url: 'https://xxxx.supabase.co',
  anonKey: 'your-anon-key',
);
```

## Google OAuth

```dart
Future<void> signInWithGoogle() async {
  final googleUser = await GoogleSignIn(
    serverClientId: 'your-web-client-id.apps.googleusercontent.com',
  ).signIn();
  if (googleUser == null) return;

  final googleAuth = await googleUser.authentication;
  await supabase.auth.signInWithIdToken(
    provider: OAuthProvider.google,
    idToken: googleAuth.idToken!,
    accessToken: googleAuth.accessToken,
  );
}
```

## Magic Link (Passwordless Email Auth)

Secure sign-in without passwords — just an email address:

```dart
// Send Magic Link
await supabase.auth.signInWithOtp(
  email: 'user@example.com',
  emailRedirectTo: 'myapp://auth/callback',
);

// Receive via Deep Link
AppLinks().uriLinkStream.listen((uri) async {
  if (uri.toString().contains('auth/callback')) {
    await supabase.auth.getSessionFromUrl(uri);
  }
});
```

## Session Management

```dart
// Listen for auth state changes
supabase.auth.onAuthStateChange.listen((data) {
  final session = data.session;
  if (session != null) {
    router.go('/home');
  } else {
    router.go('/login');
  }
});

// Get current user
final user = supabase.auth.currentUser;
```

## Row Level Security (RLS) Setup

RLS ensures users can only access their own data:

```sql
-- Enable RLS
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;

-- Only own data can be read
CREATE POLICY "own_notes_select" ON notes
  FOR SELECT USING (auth.uid() = user_id);

-- Only own data can be inserted
CREATE POLICY "own_notes_insert" ON notes
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Only own data can be updated/deleted
CREATE POLICY "own_notes_update" ON notes
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "own_notes_delete" ON notes
  FOR DELETE USING (auth.uid() = user_id);
```

## Auth Verification in Edge Functions

```typescript
// supabase/functions/protected-action/index.ts
import { createClient } from 'npm:@supabase/supabase-js@2'

Deno.serve(async (req) => {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return new Response('Unauthorized', { status: 401 })

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } }
  )

  const { data: { user }, error } = await supabase.auth.getUser()
  if (error || !user) return new Response('Unauthorized', { status: 401 })

  return new Response(JSON.stringify({ userId: user.id }))
})
```

## Summary

Supabase Auth combines OAuth, Magic Link, and RLS to deliver passwordless, secure authentication. Integration with Flutter is straightforward via the `supabase_flutter` package.

---

Building an AI Life Management app with Flutter × Supabase at 自分株式会社. Sharing indie dev insights every week.
